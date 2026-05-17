class_name RPP_Util

# Gets how many beats there are between tempo markers
static func get_beats_between_tempo_markers(
	t1: float,
	bpm1: float, 
	t2: float, 
	bpm2: float, 
	gradual: bool
) -> float:
	# Note: times are assumed to already have been affected by tempo changes
	
	var bps1 := bpm1 / 60.0
	
	if not gradual:
		return (t2 - t1) * bps1
	
	if t1 >= t2:
		return 0.0
	
	var bps2 := bpm2 / 60.0
	
	var tl := t2 - t1
	var a := (bps2 - bps1) / tl
	var b := bps1
	# I( a*x + b ) = (a/2)*(x^2) + b*x + C
	var integ := (a / 2.0) * (tl * tl) + b * tl
	
	return integ


# Get at which time the given beat position occurs between tempo markers
static func get_beat_time_between_tempo_markers(
	t1: float, 
	bpm1: float, 
	t2: float, 
	bpm2: float, 
	gradual: bool, 
	beat: float # beat position, relative to the first marker
) -> float:
	var bps1 := bpm1 / 60.0
	
	if not gradual or bpm1 == bpm2:
		if bps1 <= 0.0:
			return 0.0
		return beat / bps1
	
	if t1 >= t2:
		return 0.0
	
	var bps2 := bpm2 / 60.0
	
	var tl := t2 - t1
	var a := (bps2 - bps1) / tl
	var b := bps1
	# I( a*x + b ) = (a/2)*(x^2) + b*x + C
	# We want to know for which `x` the integral reaches the specified amount of beats
	var roots := _get_degree2_polynom_roots(a / 2.0, b, -beat)
	return roots[1]


static func _get_degree2_polynom_roots(a: float, b: float, c: float) -> PackedFloat64Array:
	if a == 0.0:
		return PackedFloat64Array()
	var r := b * b - 4.0 * a * c
	if r < 0.0:
		return PackedFloat64Array()
	var rr := sqrt(r)
	var d := 2.0 * a
	var r1 := (-b - rr) / d
	var r2 := (-b + rr) / d
	return PackedFloat64Array([r1, r2])
