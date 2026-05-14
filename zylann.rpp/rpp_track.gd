class_name RPP_Track

var name: String = ""
var fx_list: Array[RPP_Fx] = []
var guid: String = ""
var color := Color()
var use_custom_color := false
var volume := 0.0 # Linear
var pan := 0.0
var muted := false
var solo := false
var inverted_phase := false
var selected := false
var channel_count := 0
var items : Array[RPP_Item] = []
var pre_fx_volume_envelope: RPP_SimpleEnvelope
var post_fx_volume_envelope: RPP_SimpleEnvelope
