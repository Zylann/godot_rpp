class_name RPP_Envelope

var _point_positions := PackedFloat64Array()
var _point_values := PackedFloat64Array()


func get_point_count() -> int:
	return _point_positions.size()


func get_point_position(i: int) -> float:
	return _point_positions[i]


func get_point_value(i: int) -> float:
	return _point_values[i]
