class_name RPP_Token

enum Type {
	OPEN_BLOCK,
	CLOSE_BLOCK,
	STRING,
	NUMBER,
	GUID,
	NEWLINE
}

var type : Type
var value = null


func to_debug_string() -> String:
	var tn : String = Type.find_key(type)
	if value != null:
		return str(tn, "(", value, ")")
	return tn


func duplicate() -> RPP_Token:
	var d := RPP_Token.new()
	d.type = type
	d.value = value
	return d
