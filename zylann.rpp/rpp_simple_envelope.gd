class_name RPP_SimpleEnvelope extends RPP_Envelope


func append_point(position: float, value: float) -> void:
	_point_positions.append(position)
	_point_values.append(value)
