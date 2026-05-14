class_name RPP_ParamEnvelope extends RPP_Envelope

var parameter_name: String
var parameter_name2: String


func append_point(time: float, value: float) -> void:
	_point_positions.append(time)
	_point_values.append(value)
