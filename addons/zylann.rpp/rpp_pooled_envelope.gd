class_name RPP_PooledEnvelope extends RPP_Envelope

var id := 0
var name := ""
var length := 0.0

func append_point(position: float, value: float) -> void:
	_point_positions.append(position)
	_point_values.append(value)
