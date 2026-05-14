class_name RPP_Marker

var number := 1
var time := 0.0
var name := ""
var guid := ""
var selected := false


func to_region(end_time: float) -> RPP_Region:
	var r := RPP_Region.new()
	r.number = number
	r.time = time
	r.name = name
	r.guid = guid
	r.selected = selected
	assert(end_time >= time)
	r.end_time = end_time
	return r
