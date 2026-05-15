class_name RPP_Track

var name: String = ""
var fx_list: Array[RPP_Fx] = []
var guid: String = ""
var color := Color()
var use_custom_color := false
var volume := 1.0 # Linear
var pan := 0.0
var muted := false
var solo := false
var inverted_phase := false
var selected := false
var channel_count := 0
var items : Array[RPP_Item] = []
var pre_fx_volume_envelope: RPP_SimpleEnvelope
var post_fx_volume_envelope: RPP_SimpleEnvelope
var post_fx_pan_envelope: RPP_SimpleEnvelope
var parent_send := true


func debug_print(base_indent: String = "", num: int = -1) -> void:
	var header := ""
	if num >= 0:
		header += str("[", num, "]")
	if name != "":
		header += str(" ", name)
	if muted or solo:
		header += " ["
		if muted:
			header += "Muted"
		if solo:
			if muted:
				header += " | "
			header += "Solo"
		header += "]"
	
	if header != "":
		print(base_indent, header)
	
	var indent1 := base_indent + "    "
	var indent2 := indent1 + "    "

	print(indent1, "volume: ", linear_to_db(volume), "dB")
	print(indent1, "pan: ", pan)
	
	print(indent1, "fx: ", fx_list.size())
	for fx in fx_list:
		print(indent2, fx.name)
	
	print(indent1, "items: ", items.size())
