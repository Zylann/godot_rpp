class_name RPP_Item

# Start position of the item in seconds
var position := 0.0

# Length of the item in seconds
var length := 0.0

# Time in seconds from which to start playback of the source
var slip_offset := 0.0
var fade_in_length := 0.0
var fade_out_length := 0.0

var muted := false
var selected := false
var iid := 0
var iguid := ""
var guid := ""
var name := ""

var volume := 0.0
var pan := 0.0

var fx_list : Array[RPP_Fx] = []
var notes := ""

var source : RPP_ItemSource
