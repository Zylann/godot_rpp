class_name RPP_Parser

# https://wiki.cockos.com/wiki/index.php/State_Chunk_Definitions
# Most of the data is skipped, it will be implemented as needed

enum ParsingContext {
	PROJECT,
	TRACK,
	ITEM
}

var _tokenizer : RPP_Tokenizer
var _project : RPP_Project


func _init(source: String) -> void:
	_tokenizer = RPP_Tokenizer.new(source)


func parse(project: RPP_Project) -> bool:
	var time_before := Time.get_ticks_usec()
	
	_project = project
	
	var token := RPP_Token.new()
	if not _tokenizer.expect_type(token, RPP_Token.Type.OPEN_BLOCK):
		return false
	
	if not _parse_block(ParsingContext.PROJECT):
		return false
	
	var time_spent_parsing := Time.get_ticks_usec() - time_before
	time_before = Time.get_ticks_usec()
	
	var ddd_beat := project.time_to_beat(1.411 + 1.0)
	
	# Post-process
	for track in project.tracks:
		for item in track.items:
			if item.source != null:
				var midi := item.source as RPP_MidiSource
				if midi != null:
					midi.update_cache(item, project)
	
	var time_spent_postprocess := Time.get_ticks_usec() - time_before
	
	print("Time spent parsing: ", time_spent_parsing, "us")
	print("Time spent post-processing: ", time_spent_postprocess, "us")
	
	return true


func _parse_block(context: ParsingContext) -> bool:
	var token := RPP_Token.new()
	
	if not _tokenizer.expect_type(token, RPP_Token.Type.STRING):
		return false
	
	match token.value:
		"REAPER_PROJECT": if not _parse_reaper_project(): return false
		"RECORD_CFG": if not _parse_record_cfg(): return false
		"APPLYFX_CFG": if not _parse_applyfx_cfg(): return false
		"RENDER_CFG": if not _parse_render_cfg(): return false
		"METRONOME": if not _parse_metronome(): return false
		"MASTERFXLIST": if not _parse_fxchain(context): return false
		"VST": if not _parse_vst(context): return false
		"JS": if not _parse_js(context): return false
		"MASTERPLAYSPEEDENV": if not _parse_masterplayspeedenv(): return false
		"TEMPOENVEX": if not _parse_tempoenvex(): return false
		"PROJBAY": if not _parse_projbay(): return false
		"TRACK": if not _parse_track(): return false
		"FXCHAIN": if not _parse_fxchain(context): return false
		"TAKEFX": if not _parse_fxchain(context): return false
		"ITEM": if not _parse_item(): return false
		"SOURCE": if not _parse_source(null): return false
		"PARMENV": if not _parse_parmenv(): return false
		
		"VOLENV":
			var env := RPP_SimpleEnvelope.new()
			if not _parse_envelope(env): return false
			var track := _get_last_track()
			track.pre_fx_volume_envelope = env
		
		"VOLENV2":
			var env := RPP_SimpleEnvelope.new()
			if not _parse_envelope(env): return false
			var track := _get_last_track()
			track.post_fx_volume_envelope = env
		
		"PANENV2":
			var env := RPP_SimpleEnvelope.new()
			if not _parse_envelope(env): return false
			var track := _get_last_track()
			track.post_fx_pan_envelope = env
		
		"POOLEDENV":
			var envelope := RPP_PooledEnvelope.new()
			_project.pooled_envelopes.append(envelope)
			return _parse_envelope(envelope)
		
		"AUXMUTEENV":
			var env := RPP_SimpleEnvelope.new()
			if not _parse_envelope(env): return false
			var receive := _get_last_receive()
			if receive == null:
				_make_error("No receive found to put mute envelope on")
				return false
			receive.mute_envelope = env
		
		"AUXVOLENV":
			var env := RPP_SimpleEnvelope.new()
			if not _parse_envelope(env): return false
			var receive := _get_last_receive()
			if receive == null:
				_make_error("No receive found to put volume envelope on")
				return false
			receive.volume_envelope = env
		
		"NOTES": if not _parse_notes(context): return false
		
		_:
			_make_error(str("Unknown block name \"", token.value, "\""))
			return false
	
	return true


func _parse_reaper_project() -> bool:
	var token := RPP_Token.new()
	
	# TODO I don't know what this `0.1` number means
	if not _expect_number(token): return false
	
	if not _tokenizer.expect_type(token, RPP_Token.Type.STRING): return false
	_project.reaper_version = token.value
	
	# TODO I don't know what this `1623363331` number means
	if not _expect_number(token): return false
	
	while _tokenizer.read(token):
		if token.type == RPP_Token.Type.STRING:
			match token.value:
				"RIPPLE":
					if not _expect_number(token): return false
					_project.ripple = token.value != 0
				
				"GROUPOVERRIDE": if not _skip_numbers(3): return false
				
				"AUTOXFADE":
					if not _expect_number(token): return false
					_project.auto_cross_fade = token.value != 0
				
				"ENVATTACH": if not _skip_numbers(1): return false
				"POOLEDENVATTACH": if not _skip_numbers(1): return false
				"MIXERUIFLAGS": if not _skip_numbers(2): return false
				"PEAKGAIN": if not _skip_numbers(1): return false
				"FEEDBACK": if not _skip_numbers(1): return false
				"PANLAW": if not _skip_numbers(1): return false
				"PROJOFFS": if not _skip_numbers(3): return false
				"MAXPROJLEN": if not _skip_numbers(2): return false
				"GRID": if not _skip_numbers(8): return false
				"TIMEMODE": if not _skip_numbers(7): return false
				"VIDEO_CONFIG": if not _skip_numbers(3): return false
				"PANMODE": if not _skip_numbers(1): return false
				"CURSOR": if not _skip_numbers(1): return false
				"ZOOM": if not _skip_numbers(3): return false
				"VZOOMEX": if not _skip_numbers(2): return false
				"USE_REC_CFG": if not _skip_numbers(1): return false
				"RECMODE": if not _skip_numbers(1): return false
				"SMPTESYNC": if not _skip_numbers(11): return false
			
				"LOOP":
					if not _expect_number(token): return false
					_project.loop = token.value != 0
				
				"LOOPGRAN": if not _skip_numbers(2): return false
				"RECORD_PATH": if not _skip_strings(2): return false
				"RENDER_FILE": if not _skip_strings(1): return false
				"RENDER_PATTERN": if not _skip_strings(1): return false
				"RENDER_FMT": if not _skip_numbers(3): return false
				"RENDER_1X": if not _skip_numbers(1): return false
				"RENDER_RANGE": if not _skip_numbers(5): return false
				"RENDER_RESAMPLE": if not _skip_numbers(3): return false
				"RENDER_ADDTOPROJ": if not _skip_numbers(1): return false
				"RENDER_STEMS": if not _skip_numbers(1): return false
				"RENDER_DITHER": if not _skip_numbers(1): return false
				"TIMELOCKMODE": if not _skip_numbers(1): return false
				"TEMPOENVLOCKMODE": if not _skip_numbers(1): return false
				"ITEMMIX": if not _skip_numbers(1): return false
				"DEFPITCHMODE": if not _skip_numbers(2): return false
				"TAKELANE": if not _skip_numbers(1): return false
				"SAMPLERATE": if not _skip_numbers(3): return false
				"LOCK": if not _skip_numbers(1): return false
				"GLOBAL_AUTO": if not _skip_numbers(1): return false

				"TEMPO":
					if not _expect_number(token): return false
					_project.tempo_speed = token.value
					
					if not _expect_number(token): return false
					_project.tempo_signature_num = token.value
			
					if not _expect_number(token): return false
					_project.tempo_signature_denom = token.value
				
				"PLAYRATE": if not _skip_numbers(4): return false
				"SELECTION": if not _skip_numbers(2): return false
				"SELECTION2": if not _skip_numbers(2): return false
				"MASTERAUTOMODE": if not _skip_numbers(1): return false
				"MASTERTRACKHEIGHT": if not _skip_numbers(2): return false
				"MASTERPEAKCOL": if not _skip_numbers(1): return false
				"MASTERMUTESOLO": if not _skip_numbers(1): return false
				"MASTERTRACKVIEW": if not _skip_numbers(10): return false
				"MASTERHWOUT": if not _skip_numbers(8): return false
				"MASTER_NCH": if not _skip_numbers(2): return false
				"MASTER_VOLUME": if not _skip_numbers(5): return false
				"MASTER_FX": if not _skip_numbers(1): return false
				"MASTER_SEL": if not _skip_numbers(1): return false
				"MASTER_PANMODE": if not _skip_numbers(1): return false
				"MASTER_PANLAWFLAGS": if not _skip_numbers(1): return false
				
				"MARKER":
					if not _expect_number(token): return false
					var marker_number : int = token.value
					
					var existing_marker_index := _project.get_marker_index_by_number(marker_number)
					if existing_marker_index != -1:
						# Regions are defined by 2 consecutive MARKER tags with the same number
						
						if not _expect_number(token): return false
						var end_time = token.value
						
						if not _skip_strings(1): return false
						if not _skip_numbers(1): return false
						
						var marker := _project.markers[existing_marker_index]
						var region := marker.to_region(end_time)
						
						_project.markers.remove_at(existing_marker_index)
						_project.regions.append(region)
						
					else:
						var marker := RPP_Marker.new()
						marker.number = marker_number
						
						if not _expect_number(token): return false
						marker.time = token.value
						
						if not _expect_string_or_number(token): return false
						marker.name = str(token.value)
						
						if not _expect_number(token): return false
						var flags := int(token.value)
						const selected_bit = 1 << 3
						marker.selected = (flags & selected_bit) != 0
						
						if not _expect_number(token): return false
						var color_code := int(token.value)
						if color_code == 0:
							marker.use_custom_color = false
						else:
							var r := color_code & 0xff
							var g := (color_code >> 8) & 0xff
							var b := (color_code >> 16) & 0xff
							marker.use_custom_color = true
							marker.color = Color(r / 255.0, g / 255.0, b / 255.0)
						
						if not _skip_numbers(1): return false
						if not _skip_strings(1): return false
						
						if not _expect_guid(token): return false
						marker.guid = token.value

						if not _skip_numbers(1): return false
						
						_project.markers.append(marker)

				"TITLE":
					if not _expect_string(token): return false
					_project.title = token.value

				"AUTHOR":
					if not _expect_string(token): return false
					_project.author = token.value
				
				"ENVFADESZ10": if not _skip_numbers(1): return false
				"PANLAWFLAGS": if not _skip_numbers(1): return false
				
				_:
					_make_unknown_key_error(token.value)
					return false
		
		elif token.type == RPP_Token.Type.OPEN_BLOCK:
			if not _parse_block(ParsingContext.PROJECT):
				return false
		
		elif token.type == RPP_Token.Type.CLOSE_BLOCK:
			break
	
	return true


func _parse_record_cfg() -> bool:
	var token := RPP_Token.new()
	# TODO I don't know what this is
	
	while _tokenizer.read(token):
		match token.type:
			RPP_Token.Type.CLOSE_BLOCK:
				break
			RPP_Token.Type.STRING:
				# Binary?
				continue
			_:
				_make_unexpected_token_error(token)
	
	return true


func _parse_applyfx_cfg() -> bool:
	var token := RPP_Token.new()
	# TODO I don't know what this is
	
	while _tokenizer.read(token):
		if token.type == RPP_Token.Type.CLOSE_BLOCK:
			break
		else:
			_make_error("Unhandled content")
	
	return true


func _parse_render_cfg() -> bool:
	var token := RPP_Token.new()
	# TODO I don't know what this is
	
	while _tokenizer.read(token):
		if token.type == RPP_Token.Type.CLOSE_BLOCK:
			break
		elif token.type == RPP_Token.Type.STRING:
			# Some binary stuff?
			continue
		else:
			_make_error("Unhandled content")
	
	return true


func _parse_metronome() -> bool:
	var token := RPP_Token.new()
	
	_skip_numbers(2)
	
	while _tokenizer.read(token):
		if token.type == RPP_Token.Type.CLOSE_BLOCK:
			break
		elif token.type == RPP_Token.Type.STRING:
			match token.value:
				"VOL": if not _skip_numbers(2): return false
				"FREQ": if not _skip_numbers(3): return false
				"BEATLEN": if not _skip_numbers(1): return false
				
				"SAMPLES":
					# Some files have 2 strings, some have 4.
					# The issue is that we can't differenciate string parameters from property
					# names without considering newlines.
					_tokenizer.set_newlines(true)
					while _tokenizer.expect(token):
						if token.type == RPP_Token.Type.STRING:
							continue
						elif token.type == RPP_Token.Type.NEWLINE:
							break
						else:
							_make_error(str("Unexpected token ", token.to_debug_string()))
							return false
					_tokenizer.set_newlines(false)
				
				"PATTERN": if not _skip_numbers(2): return false
				"PATTERNSTR": if not _skip_strings(1): return false
				"SPLIGNORE": if not _skip_numbers(2): return false
				"SPLDEF":
					if not _skip_numbers(2): return false
					if not _skip_strings(1): return false
					if not _skip_numbers(1): return false
					if not _skip_strings(1): return false
				"MULT": if not _skip_numbers(1): return false
				_:
					_make_unknown_key_error(token.value)
					return false
		else:
			_make_error("Unhandled content")
	
	return true


func _parse_vst(context: ParsingContext) -> bool:
	var token := RPP_Token.new()
	
	var vst := RPP_Vst.new()
	
	if not _expect_string(token):
		return false
	vst.name = token.value
	
	if not _expect_string(token):
		return false
	vst.filename = token.value
	
	if not _skip_numbers(1): return false
	if not _skip_strings(1): return false
	
	# VSTs have some kind of ID property that's sometimes an integer, sometimes integers with "<>",
	# I don't quite understand what they mean. An ID of some kind?
	if not _tokenizer.expect(token): return false
	if token.type != RPP_Token.Type.STRING and token.type != RPP_Token.Type.NUMBER:
		_make_error("Unexpected token")
		return false
	
	if not _skip_strings(1): return false
	
	while _tokenizer.read(token):
		if token.type == RPP_Token.Type.CLOSE_BLOCK:
			break
		elif token.type == RPP_Token.Type.STRING:
			# Binary
			continue
		else:
			_make_error(str("Unexpected token ", token.to_debug_string()))
			return false
	
	_append_fx(vst, context)
	
	return true


func _parse_js(context: ParsingContext) -> bool:
	var token := RPP_Token.new()
	
	var js := RPP_JesusonicFx.new()
	
	if not _expect_string(token): return false
	js.name = token.value
	
	_append_fx(js, context)
	
	if not _skip_strings(1): return false
	
	# Line where the block opened
	if not _skip_to_end_of_line(): return false
	# Line with a bunch of config I don't understand
	if not _skip_to_end_of_line(): return false
	
	if not _skip_type_n(RPP_Token.Type.CLOSE_BLOCK, 1): return false
	
	return true


func _append_fx(fx: RPP_Fx, context: ParsingContext) -> bool:
	match context:
		ParsingContext.PROJECT:
			var track := _get_last_track()
			track.fx_list.append(fx)
		
		ParsingContext.TRACK:
			var track := _get_last_track()
			track.fx_list.append(fx)
		
		ParsingContext.ITEM:
			var item := _get_last_item()
			if item == null:
				_make_error("Expected item to add FX on")
				return false
			item.fx_list.append(fx)

	return true


func _parse_masterplayspeedenv() -> bool:
	var token := RPP_Token.new()
	
	while _tokenizer.read(token):
		if token.type == RPP_Token.Type.CLOSE_BLOCK:
			break
		elif token.type == RPP_Token.Type.STRING:
			match token.value:
				"EGUID": if not _skip_guid(): return false
				"ACT": if not _skip_numbers(2): return false
				"VIS": if not _skip_numbers(3): return false
				"LANEHEIGHT": if not _skip_numbers(2): return false
				"ARM": if not _skip_numbers(1): return false
				"DEFSHAPE": if not _skip_numbers(3): return false
				_:
					_make_unknown_key_error(token.value)
					return false
		else:
			_make_error(str("Unexpected token ", token.to_debug_string()))
	
	return true


func _parse_tempoenvex() -> bool:
	var env := RPP_TempoEnvelope.new()
	if not _parse_envelope(env):
		return false
	_project.tempo_envelope = env
	return true


func _parse_projbay() -> bool:
	var token := RPP_Token.new()
	# TODO I don't know what this is
	
	while _tokenizer.read(token):
		if token.type == RPP_Token.Type.CLOSE_BLOCK:
			break
		else:
			_make_error("Unhandled content")
	
	return true


func _parse_track() -> bool:
	var token := RPP_Token.new()
	
	var track := RPP_Track.new()
	_project.tracks.append(track)
	
	if not _expect_guid(token): return false
	track.guid = token.value
	
	while _tokenizer.read(token):
		if token.type == RPP_Token.Type.CLOSE_BLOCK:
			break
		elif token.type == RPP_Token.Type.OPEN_BLOCK:
			if not _parse_block(ParsingContext.TRACK):
				return false
		elif token.type == RPP_Token.Type.STRING:
			match token.value:
				"NAME":
					if not _expect_string_or_number(token): return false
					track.name = str(token.value)
				
				"PEAKCOL":
					# ???????? bbbbbbbb gggggggg rrrrrrrr
					if not _expect_number(token): return false
					var i := int(token.value)
					if i == 16576:
						# This appears to be the value on tracks with no custom color?
						track.use_custom_color = false
					else:
						var r := (i & 0xff)
						var g := ((i >> 8) & 0xff)
						var b := ((i >> 16) & 0xff)
						track.color = Color(r / 255.0, g / 255.0, b / 255.0)
						track.use_custom_color = true
				
				"BEAT": if not _skip_numbers(1): return false
				"AUTOMODE": if not _skip_numbers(1): return false
				
				"VOLPAN":
					if not _expect_number(token): return false
					track.volume = token.value

					if not _expect_number(token): return false
					track.pan = token.value
					
					if not _skip_numbers(3): return false
				
				"MUTESOLO":
					if not _expect_number(token): return false
					track.muted = token.value != 0.0
					
					if not _expect_number(token): return false
					track.solo = token.value != 0.0 # Actually 2 when soloed for some reason
					
					if not _skip_numbers(1): return false
					
				"IPHASE":
					if not _expect_number(token): return false
					track.inverted_phase = token.value != 0.0
					

				"PLAYOFFS": if not _skip_numbers(2): return false
				"ISBUS": if not _skip_numbers(2): return false
				"BUSCOMP": if not _skip_numbers(5): return false
				"SHOWINMIX": if not _skip_numbers(8): return false

				"SEL":
					if not _expect_number(token): return false
					track.selected = token.value != 0.0
				
				"REC":
					# Sometimes 7 numbers, sometimes 8
					if not _skip_to_end_of_line(): return false
				
				"VU": if not _skip_numbers(1): return false
				
				"TRACKHEIGHT":
					# Saw it with 3 or 7 numbers
					if not _skip_to_end_of_line(): return false
				
				"INQ": if not _skip_numbers(8): return false
				
				"NCHAN":
					if not _expect_number(token): return false
					track.channel_count = token.value
				
				"FX": if not _skip_numbers(1): return false
				
				"TRACKID": 
					if not _expect_guid(token): return false
					var guid : String = token.value
					assert(guid == track.guid)
				
				"PERF": if not _skip_numbers(1): return false
				"MIDIOUT": if not _skip_numbers(1): return false
				
				"MAINSEND":
					if not _expect_number(token): return false
					track.parent_send = token.value != 0
					
					# I don't know what the second number means
					if not _skip_numbers(1): return false
				
				"PANLAWFLAGS": if not _skip_numbers(1): return false
				"FIXEDLANES": if not _skip_numbers(5): return false
				"FREEMODE": if not _skip_numbers(1): return false
				"LAYOUTS": if not _skip_strings(2): return false
				
				"AUXRECV":
					var receive := RPP_Receive.new()
					if not _expect_number(token): return false
					receive.source_track_index = token.value
					
					if not _skip_numbers(1): return false # Mode
					
					if not _expect_number(token): return false
					receive.volume = token.value

					if not _expect_number(token): return false
					receive.pan = token.value

					if not _expect_number(token): return false
					receive.mute = token.value != 0

					if not _expect_number(token): return false
					receive.mono_sum = token.value != 0

					if not _expect_number(token): return false
					receive.inverted_phase = token.value != 0
					
					if not _skip_to_end_of_line(): return false
					
					track.receives.append(receive)
				
				_:
					_make_unknown_key_error(token.value)
					return false
		else:
			_make_error("Unhandled content")
	
	return true


func _parse_fxchain(context: ParsingContext) -> bool:
	var token := RPP_Token.new()
	
	while _tokenizer.read(token):
		if token.type == RPP_Token.Type.CLOSE_BLOCK:
			break
		elif token.type == RPP_Token.Type.STRING:
			match token.value:
				"WNDRECT": if not _skip_numbers(4): return false
				"SHOW": if not _skip_numbers(1): return false
				"LASTSEL": if not _skip_numbers(1): return false
				"DOCKED": if not _skip_numbers(1): return false
				"BYPASS": if not _skip_numbers(3): return false
				"PRESETNAME": if not _skip_strings(1): return false
				"FLOATPOS": if not _skip_numbers(4): return false
				"FXID": if not _skip_guid(): return false
				"WAK": if not _skip_numbers(2): return false
				
				"WET":
					# Sometimes 1 number, sometimes 2 numbers
					if not _skip_to_end_of_line(): return false
				
				_:
					_make_unknown_key_error(token.value)
					return false
		elif token.type == RPP_Token.Type.OPEN_BLOCK:
			# Likely VST
			if not _parse_block(context):
				return false
		else:
			_make_error("Unhandled content")
	
	return true


func _parse_envelope(envelope: RPP_Envelope) -> bool:
	var token := RPP_Token.new()
	
	var tempo_envelope := envelope as RPP_TempoEnvelope
	var param_envelope := envelope as RPP_ParamEnvelope
	var pooled_envelope := envelope as RPP_PooledEnvelope
	
	while _tokenizer.read(token):
		if token.type == RPP_Token.Type.CLOSE_BLOCK:
			break
		elif token.type == RPP_Token.Type.STRING:
			match token.value:
				"EGUID": if not _skip_guid(): return false
				"ACT": if not _skip_numbers(2): return false
				"VIS": if not _skip_numbers(3): return false
				"LANEHEIGHT": if not _skip_numbers(2): return false
				"ARM": if not _skip_numbers(1): return false
				"DEFSHAPE": if not _skip_numbers(3): return false
				"VOLTYPE": if not _skip_numbers(1): return false
				
				"ID":
					if pooled_envelope == null:
						_make_error("Unexpected envelope type to have an ID")
						return false
					if not _expect_number(token): return false
					pooled_envelope.id = token.value
				
				"NAME":
					if pooled_envelope == null:
						_make_error("Unexpected envelope type to have a NAME")
						return false
					if not _expect_string(token): return false
					pooled_envelope.name = token.value
				
				"SRCLEN":
					if pooled_envelope == null:
						_make_error("Unexpected envelope type to have SRCLEN")
						return false
					if not _expect_number(token): return false
					pooled_envelope.length = token.value
				
				"LFO": if not _skip_numbers(7): return false
				
				"POOLEDENVINST":
					# TODO POOLEDENVINST: Not sure of what the numbers all represent
					#      My guess so far:
					#      <ID> <startpos> <length?> ...??...
					if not _skip_numbers(16): return false
				
				# Not sure why POOLEDENV doesn't use `PT` like every other envelopes
				"PT", "PPT":
					if not _expect_number(token): return false
					var position : float = token.value
					
					if not _expect_number(token): return false
					var value : float = token.value
					
					if tempo_envelope != null:
						if not _expect_number(token): return false
						var gradual : bool = (token.value == 0)
						tempo_envelope.append_point(position, value, gradual)
					
					if param_envelope != null:
						param_envelope.append_point(position, value)
					
					_skip_to_end_of_line()
				
				_:
					_make_unknown_key_error(token.value)
					return false
		else:
			_make_error("Unhandled content")
	
	return true


func _parse_parmenv() -> bool:
	var token := RPP_Token.new()
	
	var envelope := RPP_ParamEnvelope.new()
	
	# Seen the following sequences come up on different files:
	# <PARMENV number number number number
	# <PARMENV number number number number string
	# <PARMENV string number number number string
	
	_tokenizer.set_newlines(true)
	
	if not _expect_string_or_number(token): return false
	envelope.parameter_name = str(token.value)
	
	if not _skip_numbers(3): return false
	
	if not _tokenizer.expect(token): return false
	if token.type != RPP_Token.Type.NEWLINE:
		if token.type != RPP_Token.Type.STRING:
			_make_unexpected_token_error(token)
			return false
		envelope.parameter_name2 = token.value
		
		if not _skip_type_n(RPP_Token.Type.NEWLINE, 1): return false
	
	_tokenizer.set_newlines(false)
	
	if not _parse_envelope(envelope): return false
	
	var track := _get_last_track()
	if track.fx_list.size() == 0:
		_make_error("Expected FX in FX list")
		return false
	var fx := track.fx_list[track.fx_list.size() - 1]
	fx.param_envelopes.append(envelope)
	
	return true


func _get_last_track() -> RPP_Track:
	if _project.tracks.size() == 0:
		return _project.master_track
	var last_index := _project.tracks.size() - 1
	return _project.tracks[last_index]


func _get_last_item() -> RPP_Item:
	var track := _get_last_track()
	var last_index := track.items.size() - 1
	if last_index < 0:
		return null
	return track.items[last_index]


func _get_last_receive() -> RPP_Receive:
	var track := _get_last_track()
	var last_index := track.receives.size() - 1
	if last_index < 0:
		return null
	return track.receives[last_index]


func _parse_item() -> bool:
	var token := RPP_Token.new()
	
	var item := RPP_Item.new()
	
	var last_track_index := _project.tracks.size() - 1
	var track := _project.tracks[last_track_index]
	track.items.append(item)
	
	while _tokenizer.read(token):
		if token.type == RPP_Token.Type.CLOSE_BLOCK:
			break
		elif token.type == RPP_Token.Type.OPEN_BLOCK:
			# SOURCE
			if not _parse_block(ParsingContext.ITEM):
				push_error("Failed to parse item")
				return false
		elif token.type == RPP_Token.Type.STRING:
			match token.value:
				"POSITION":
					if not _expect_number(token): return false
					item.position = token.value
				
				"SNAPOFFS": if not _skip_numbers(1): return false
				
				"LENGTH":
					if not _expect_number(token): return false
					item.length = token.value
				
				"LOOP": if not _skip_numbers(1): return false
				"ALLTAKES": if not _skip_numbers(1): return false

				"FADEIN":
					if not _expect_number(token): return false
					# This is the kind of fade (fast start, slow start, linear...) but it's weird.
					# It is repeated again in a later token, and also the last setting is not even
					# an integer (5.1)
					#var kind : float = token.value
					
					if not _expect_number(token): return false
					item.fade_in_length = token.value
					
					# Sometimes it's 6 numbers, sometimes it's 7
					if not _skip_to_end_of_line(): return false
				
				"FADEOUT":
					if not _expect_number(token): return false
					#var kind : float = token.value
					
					if not _expect_number(token): return false
					item.fade_out_length = token.value
					
					# Sometimes it's 6 numbers, sometimes it's 7
					if not _skip_to_end_of_line(): return false
				
				"MUTE":
					if not _expect_number(token): return false
					item.muted = (token.value != 0)
					
					if not _skip_numbers(1): return false
					
				"BEAT": if not _skip_numbers(1): return false
				
				"SEL":
					if not _expect_number(token): return false
					item.selected = (token.value != 0)
				
				"IGUID":
					if not _expect_guid(token): return false
					item.iguid = token.value
					
				"IID":
					if not _expect_number(token): return false
					item.iid = token.value
				
				"NAME":
					#if not _expect_string_or_number(token): return false
					# Maybe some day I'll have to consider that everything is always a string by default
					_tokenizer.set_numbers_as_strings(true)
					_expect_string(token)
					item.name = token.value
					_tokenizer.set_numbers_as_strings(false)
				
				"VOLPAN":
					if not _expect_number(token): return false
					item.volume = token.value

					if not _expect_number(token): return false
					item.pan = token.value
					
					if not _skip_numbers(2): return false
				
				"SOFFS":
					if not _expect_number(token): return false
					item.slip_offset = token.value
					
					# Sometimes there is a second number, which seems to be the double of the first.
					# But is it? Why?
					_tokenizer.set_newlines(true)
					while _tokenizer.expect(token):
						match token.type:
							RPP_Token.Type.NUMBER:
								continue
							RPP_Token.Type.NEWLINE:
								break
							_:
								_make_unexpected_token_error(token)
								return false
					_tokenizer.set_newlines(false)
				
				"PLAYRATE":
					if not _expect_number(token): return false
					item.playrate = token.value
					
					if not _expect_number(token): return false
					item.preserve_pitch = token.value != 0
					
					# I don't know what the other numbers are
					if not _skip_numbers(4): return false
				
				"CHANMODE": if not _skip_numbers(1): return false
				
				"GUID":
					if not _expect_guid(token): return false
					item.guid = token.value
				
				"IMGRESOURCEFLAGS": if not _skip_numbers(1): return false
				
				"NOTESWND": 
					# Probably the position and size of the window to edit item notes
					if not _skip_numbers(4): return false
				
				"TAKEFX_NCH": if not _skip_numbers(1): return false
				"RECPASS": if not _skip_numbers(1): return false
				
				_:
					_make_unknown_key_error(token.value)
					return false
		else:
			_make_error(str("Unexpected token ", token.to_debug_string()))
			return false
	
	return true


class RPP_ItemSourceSection:
	var length := 0.0
	var start_position := 0.0
	var overlap := 0.0


func _parse_source(section: RPP_ItemSourceSection) -> bool:
	var token := RPP_Token.new()
	
	if not _expect_string(token): return false
	var type_str : String = token.value
	
	var audio_source : RPP_AudioSource
	var midi_source : RPP_MidiSource
	var source : RPP_ItemSource
	
	match type_str:
		"VORBIS":
			audio_source = RPP_AudioSource.new()
			audio_source.file_type = RPP_AudioSource.Type.VORBIS
			source = audio_source
		"FLAC":
			audio_source = RPP_AudioSource.new()
			audio_source.file_type = RPP_AudioSource.Type.FLAC
			source = audio_source
		"WAVE":
			audio_source = RPP_AudioSource.new()
			audio_source.file_type = RPP_AudioSource.Type.WAVE
			source = audio_source
		"MP3":
			audio_source = RPP_AudioSource.new()
			audio_source.file_type = RPP_AudioSource.Type.MP3
			source = audio_source
		"SECTION":
			if not _parse_source_section():
				return false
			#if not _tokenizer.expect_type(token, RPP_Token.Type.CLOSE_BLOCK):
				#return false
			return true
		"MIDI":
			midi_source = RPP_MidiSource.new()
			source = midi_source
		_:
			_make_error(str("Unknown source \"", type_str, "\""))
			return false
	
	if section != null and audio_source != null:
		audio_source.is_section = true
		audio_source.section_length = section.length
		audio_source.section_start = section.start_position
		audio_source.section_overlap = section.overlap
	
	var track := _get_last_track()
	if track.items.size() == 0:
		_make_error("Expected last item")
		return false
	var item := track.items[track.items.size() - 1]
	item.source = source
	
	while _tokenizer.read(token):
		if token.type == RPP_Token.Type.CLOSE_BLOCK:
			break
		elif token.type == RPP_Token.Type.STRING:
			match token.value:
				"FILE":
					if not _expect_string(token): return false
					audio_source.file_path = token.value
					
					# I saw MP3 have a number after the path. Not sure if it's specific to MP3.
					if audio_source.file_type == RPP_AudioSource.Type.MP3:
						if not _skip_numbers(1): return false
				
				"HASDATA":
					if midi_source == null:
						_make_error("Expected MIDI item")
						return false
					
					# has data? (bool)
					if not _skip_numbers(1): return false
					
					if not _expect_number(token): return false
					var nticks : int = token.value
					
					if not _expect_string(token): return false
					var tunit : String = token.value
					if tunit != "QN":
						_make_error(str("Unknown tick unit ", tunit))
						return false
					midi_source.ticks_per_quarter_note = nticks
				
				# Can appear multiple times, not sure why
				"CCINTERP": if not _skip_numbers(1): return false
				
				"POOLEDEVTS": if not _skip_guid(): return false
				
				"E": if not _parse_midi_message(midi_source, false): return false
				"e": if not _parse_midi_message(midi_source, true): return false
				
				"CHASE_CC_TAKEOFFS": if not _skip_numbers(1): return false
				
				"GUID":
					if not _expect_guid(token): return false
					midi_source.guid = token.value
				
				"IGNTEMPO": if not _skip_numbers(4): return false
				"SRCCOLOR": if not _skip_numbers(1): return false
				
				"VELLANE":
					# Sometimes 3 numbers, sometimes 5 numbers
					if not _skip_to_end_of_line(): return false
				
				"CFGEDITVIEW": if not _skip_numbers(10): return false
				"KEYSNAP": if not _skip_numbers(1): return false
				"TRACKSEL": if not _skip_numbers(1): return false
				"EVTFILTER": if not _skip_numbers(18): return false
				"CFGEDIT": if not _skip_numbers(30): return false
				
				_:
					_make_unknown_key_error(token.value)
					return false
		else:
			_make_unexpected_token_error(token)
	
	return true


func _parse_source_section() -> bool:
	var token := RPP_Token.new()
	
	var section := RPP_ItemSourceSection.new()
	
	while _tokenizer.read(token):
		if token.type == RPP_Token.Type.CLOSE_BLOCK:
			break
		
		elif token.type == RPP_Token.Type.OPEN_BLOCK:
			if not _expect_string(token): return false
			match token.value:
				"SOURCE":
					# Note, we expect this to be the last element 
					if not _parse_source(section):
						return false
				_:
					_make_unknown_key_error(token.value)
					return false
		
		elif token.type == RPP_Token.Type.STRING:
			match token.value:
				"LENGTH":
					if not _expect_number(token): return false
					section.length = token.value
				
				"STARTPOS":
					if not _expect_number(token): return false
					section.start_position = token.value
					
				"OVERLAP":
					if not _expect_number(token): return false
					section.overlap = token.value
				
				"MODE":
					# Not sure what mode is. Maybe reverse?
					if not _expect_number(token): return false
				
				_:
					_make_unknown_key_error(token.value)
					return false
		else:
			_make_error("Unhandled content")
	
	return true


func _parse_midi_message(midi_source: RPP_MidiSource, _unused_selected: bool) -> bool:
	_tokenizer.set_numbers_as_strings(true)
	
	var token := RPP_Token.new()
	
	if not _expect_string(token): return false
	var offset_s : String = token.value
	if not offset_s.is_valid_int():
		_make_error(str("Expected integer, got \"", offset_s, "\""))
		return false
	var offset : int = offset_s.to_int()
	
	if not _expect_string(token): return false
	var status_s : String = token.value
	if not status_s.is_valid_hex_number():
		_make_error(str("Expected hex integer, got \"", status_s, "\""))
		return false
	var status: int = status_s.hex_to_int()
	var message_type := ((status >> 4) & 0xf) as RPP_MidiSource.MessageType
	var channel := status & 0xf
	
	if not _expect_string(token): return false
	var data1_s : String = token.value
	if not data1_s.is_valid_hex_number():
		_make_error(str("Expected integer, got \"", data1_s, "\""))
		return false
	var data1 := data1_s.hex_to_int()

	if not _expect_string(token): return false
	var data2_s : String = token.value
	if not data2_s.is_valid_hex_number():
		_make_error(str("Expected integer, got \"", data2_s, "\""))
		return false
	var data2 := data2_s.hex_to_int()
	
	# TODO There may be an additional field "prequantized_offset", havent seen it yet
	# "Optional field only exists for midi events that have been quantized. 
	# It is the difference between the note's position and where its position was 
	# before it was quantized "
	
	midi_source.append_message(offset, message_type, channel, data1, data2)
	
	_tokenizer.set_numbers_as_strings(false)
	
	return true


func _parse_notes(context: ParsingContext) -> bool:
	# Not sure yet when exactly these numbers come up, that might not be correct
	if context == ParsingContext.PROJECT:
		if not _skip_numbers(2): return false
	
	var token := RPP_Token.new()
	var text := ""
	
	while _tokenizer.expect(token):
		match token.type:
			RPP_Token.Type.STRING:
				var line : String = token.value
				if text.length() > 0:
					text += "\n"
				text += line
			
			RPP_Token.Type.CLOSE_BLOCK:
				break
			
			_:
				_make_unexpected_token_error(token)
				return false
	
	match context:
		ParsingContext.PROJECT:
			_project.notes = text
		ParsingContext.ITEM:
			var item := _get_last_item()
			if item == null:
				_make_error("No item to put notes on")
				return false
			item.notes = text
	
	return true


func _make_error(msg: String) -> void:
	if RPP_Tokenizer.DEBUG_HISTORY:
		_tokenizer.print_debug_history()
	push_error(msg, " at line ", _tokenizer.get_line_index() + 1)
	assert(false)


func _make_unknown_key_error(key: String) -> void:
	_make_error(str("Unknown key `", key, "`"))


func _make_unexpected_token_error(token: RPP_Token) -> void:
	_make_error(str("Unexpected token ", token.to_debug_string()))


func _skip_numbers(count: int) -> bool:
	return _skip_type_n(RPP_Token.Type.NUMBER, count)


func _skip_strings(count: int) -> bool:
	return _skip_type_n(RPP_Token.Type.STRING, count)


func _skip_to_end_of_line() -> bool:
	var prev_newlines := _tokenizer.is_newlines_enabled()
	var prev_stro := _tokenizer.is_numbers_as_strings()
	
	_tokenizer.set_newlines(true)
	_tokenizer.set_numbers_as_strings(true)
	
	var token := RPP_Token.new()
	while _tokenizer.expect(token):
		match token.type:
			RPP_Token.Type.STRING:
				continue
			#RPP_Token.Type.NUMBER:
				#continue
			RPP_Token.Type.GUID:
				continue
			RPP_Token.Type.NEWLINE:
				break
			_:
				_make_unexpected_token_error(token)
				return false

	_tokenizer.set_newlines(prev_newlines)
	_tokenizer.set_numbers_as_strings(prev_stro)

	return true


func _skip_guid() -> bool:
	return _skip_type_n(RPP_Token.Type.GUID, 1)


func _expect_number(token: RPP_Token) -> bool:
	return _tokenizer.expect_type(token, RPP_Token.Type.NUMBER)


func _expect_string(token: RPP_Token) -> bool:
	return _tokenizer.expect_type(token, RPP_Token.Type.STRING)


func _expect_guid(token: RPP_Token) -> bool:
	return _tokenizer.expect_type(token, RPP_Token.Type.GUID)


func _expect_string_or_number(token: RPP_Token) -> bool:
	if not _tokenizer.expect(token):
		return false
	if token.type == RPP_Token.Type.NUMBER:
		return true
	if token.type == RPP_Token.Type.STRING:
		return true
	_make_error(str("Expected number or string, got ", token.to_debug_string()))
	return false


func _skip_type_n(type: RPP_Token.Type, count: int) -> bool:
	assert(count > 0)
	var token := RPP_Token.new()
	for i in count:
		if not _tokenizer.expect_type(token, type):
			return false
	return true
