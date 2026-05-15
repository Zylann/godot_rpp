class_name RPP_Tokenizer

const DEBUG_HISTORY = true

var _source: String = ""
var _pos: int = 0
var _line_index := 0
var _with_newline_tokens := false
var _numbers_as_strings := false

# Had to add this feature to rewind parsing due to the existence of VARIABLE parameter properties,
# such as `PT`, that I have no idea how to parse
var _pushed_tokens : Array[RPP_Token] = []

# [RPP_Token, line_index]
var _debug_history : Array[Array] = []


func _init(s: String) -> void:
	_source = s


func get_line_index() -> int:
	return _line_index


func set_newlines(enable: bool) -> void:
	_with_newline_tokens = enable


func is_newlines_enabled() -> bool:
	return _with_newline_tokens


func set_numbers_as_strings(enable: bool) -> void:
	_numbers_as_strings = enable


func is_numbers_as_strings() -> bool:
	return _numbers_as_strings


func expect_type(out_token: RPP_Token, type: RPP_Token.Type) -> bool:
	var ok := expect(out_token)
	if out_token.type != type:
		_make_error(str(
			"Expected ", RPP_Token.Type.find_key(type), ", got ", out_token.to_debug_string()
		))
		return false
	return ok


func expect(out_token: RPP_Token) -> bool:
	var ok := read(out_token)
	if not ok:
		_make_error("Unexpected end of file")
	return ok


func read(out_token: RPP_Token) -> bool:
	var ok : bool
	var pt : RPP_Token = _pushed_tokens.pop_back()
	if pt != null:
		out_token.type = pt.type
		out_token.value = pt.value
		ok = true
	else:
		ok = _read(out_token)
		if DEBUG_HISTORY:
			if ok:
				_debug_history.append([
					out_token.duplicate(),
					_line_index
				])
			#if not ok:
				#print("ERR ln ", _line_index + 1)
			#else:
				#print("- ", out_token.to_debug_string(), " ln ", _line_index + 1)
	return ok


func print_debug_history() -> void:
	var n := 100
	var begin := maxi(_debug_history.size() - n, 0)
	var end := mini(begin + n, _debug_history.size())
	for i in range(begin, end):
		var entry : Array = _debug_history[i]
		var token : RPP_Token = entry[0]
		var line_index : int = entry[1]
		print("- ", token.to_debug_string(), " ln ", line_index + 1)


func push(token: RPP_Token) -> void:
	_pushed_tokens.append(token)


func _read(out_token: RPP_Token) -> bool:
	while _pos < _source.length():
		var c := _source[_pos]
		
		if c == "\n":
			_line_index += 1
			_pos += 1
			if _with_newline_tokens:
				out_token.type = RPP_Token.Type.NEWLINE
				out_token.value = null
				return true
			continue
		
		if c == "\r":
			_pos += 1
			continue
		
		if c == " " or c == "\t":
			_pos += 1
			continue
		
		if c == "<":
			out_token.type = RPP_Token.Type.OPEN_BLOCK
			out_token.value = null
			_pos += 1
			return true
		
		if c == ">":
			out_token.type = RPP_Token.Type.CLOSE_BLOCK
			out_token.value = null
			_pos += 1
			return true
		
		if c == "{":
			# All usages of braces I found so far are for GUIDs
			var begin_pos := _pos + 1
			var end_pos := _source.find("}", begin_pos)
			var s := _source.substr(begin_pos, end_pos - begin_pos)
			out_token.type = RPP_Token.Type.GUID
			out_token.value = s
			_pos = end_pos + 1
			return true
		
		if c == "\"":
			# Quoted string
			# TODO Find out if we have to handle escaping.
			#      Backslashes seem to not be escaped at all in paths, they appear once.
			var pos := _pos + 1
			if pos >= _source.length():
				_make_error("Unexpected end of file")
				return false
			var end_pos := _source.find("\"", pos)
			out_token.value = _source.substr(pos, end_pos - pos)
			out_token.type = RPP_Token.Type.STRING
			_pos = end_pos + 1
			return true
		
		if c == "|":
			# Full-line string regardless of spaces. Used in notes
			var begin_pos := _pos + 1
			var end_pos := _source.find("\n", _pos)
			if end_pos == -1:
				_make_error("Unexpected end of file")
				return false
			var s := _source.substr(begin_pos, end_pos - begin_pos)
			out_token.type = RPP_Token.Type.STRING
			out_token.value = s
			_pos = end_pos
			return true
		
		if (
			c.is_valid_ascii_identifier() or "/+".contains(c)
			or (_numbers_as_strings and (c.is_valid_int() or c == "-"))
		):
			var end_pos := _find_unquoted_string_end(_pos)
			assert(end_pos > _pos)
			out_token.type = RPP_Token.Type.STRING
			out_token.value = _source.substr(_pos, end_pos - _pos)
			_pos = end_pos
			return true
		
		if c.is_valid_int() or c == "-":
			var pos := _pos + 1
			var number_chars := "0123456789."
			while pos < _source.length():
				c = _source[pos]
				if number_chars.find(c) == -1:
					break
				pos += 1
				
			# Fallback to string if the boundary character is not supposed to be in the number.
			# Because of:
			# - Weird ID in VST blocks that sometimes contains `<>`
			# - Unquoted base64
			# - `12:bypass` in PARMENV
			if c.is_valid_ascii_identifier() or "+=</:".contains(c):
				var end_pos := _find_unquoted_string_end(_pos + 1)
				out_token.type = RPP_Token.Type.STRING
				out_token.value = _source.substr(_pos, end_pos - _pos)
				_pos = end_pos
				return true
				
			var s := _source.substr(_pos, pos - _pos)
			var v := s.to_float()
			out_token.value = v
			out_token.type = RPP_Token.Type.NUMBER
			_pos = pos
			return true
		
		_make_error(str("Unexpected character \"", c, "\""))
		return false
	
	return false


func _find_unquoted_string_end(pos0: int) -> int:
	var endchars = " \n\t\r"
	var c := _source[pos0]
	if endchars.contains(c):
		return pos0
	var pos := pos0 + 1
	while pos < _source.length():
		c = _source[pos]
		if endchars.contains(c):
			break
		pos += 1
	return pos


func _make_error(msg: String) -> void:
	if DEBUG_HISTORY:
		print_debug_history()
	push_error(msg, " at line ", _line_index + 1)
	assert(false)
