class_name RPP_TempoEnvelope extends RPP_Envelope


var _point_gradual_transitions := PackedByteArray()


func append_point(time: float, value: float, gradual: bool) -> void:
	_point_positions.append(time)
	_point_values.append(value)
	_point_gradual_transitions.append(1 if gradual else 0)


func get_point_gradual_transition(i: int) -> bool:
	return _point_gradual_transitions[i] != 0
