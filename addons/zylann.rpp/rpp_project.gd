class_name RPP_Project

var title: String
var author: String
var notes: String

var reaper_version: String # "6.12c/x64"
var ripple: bool = false
var auto_cross_fade: bool = false
var loop: bool = false

# in BPM (beats per minute)
# Note: in Reaper, tempo changes don't affect the speed at which time progresses,
# but rather modifies the positions and lengths of everything in the file.
# If you have an item starting at 2 seconds, then increase BPM, that starting time will be reduced
# in the file. (unlike master `playrate`, which does affect the actual playback speed)
var tempo_speed: float = 0
var tempo_signature_num: int = 4
var tempo_signature_denom: int = 4
var tempo_envelope: RPP_TempoEnvelope

var master_track := RPP_MasterTrack.new()
var tracks : Array[RPP_Track] = []

var markers: Array[RPP_Marker] = []
var regions: Array[RPP_Region] = []

var pooled_envelopes: Array[RPP_PooledEnvelope] = []

const MAX_TIME = 99999.0


static func load_from_file(path: String) -> RPP_Project:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var content = f.get_as_text()
	f = null
	return load_from_text(content)


static func load_from_text(source: String) -> RPP_Project:
	var project := RPP_Project.new()
	var parser := RPP_Parser.new(source)
	if not parser.parse(project):
		return null
	return project


func get_marker_index_by_number(n: int) -> int:
	for i in markers.size():
		var m := markers[i]
		if m.number == n:
			return i
	return -1


func get_total_length() -> float:
	var end_time := 0.0
	for track in tracks:
		for item in track.items:
			end_time = maxf(end_time, item.position + item.length)
	return end_time


func time_to_beat(p_time: float) -> float:
	if tempo_envelope == null:
		return p_time / (tempo_speed / 60.0)

	var npt := tempo_envelope.get_point_count()
	if npt == 1:
		var bpm := tempo_envelope.get_point_value(0)
		return p_time / (bpm / 60.0)

	var beats := 0.0
	var last_pi := npt - 1
	
	for pi in npt:
		var t1 := tempo_envelope.get_point_position(pi)
		var t2 := MAX_TIME
		if pi != last_pi:
			t2 = tempo_envelope.get_point_position(pi + 1)
		assert(t2 > t1)
		
		var bpm1 := tempo_envelope.get_point_value(pi)
		var bpm2 := bpm1
		if pi != last_pi:
			bpm2 = tempo_envelope.get_point_value(pi + 1)
		
		var gradual := tempo_envelope.get_point_gradual_transition(pi)
		
		var te := t2
		var bpme := bpm2
		var done := false
		
		if p_time < t2:
			te = p_time
			if gradual:
				bpme = lerpf(bpm1, bpm2, (p_time - t1) / (t2 - t1))
			else:
				bpme = bpm1
			done = true
		
		var rbeats := RPP_Util.get_beats_between_tempo_markers(t1, bpm1, te, bpme, gradual)
		beats += rbeats
		
		if done:
			break
	
	return beats


# Gets how much time away a beat is from a reference time point, accounting for tempo changes.
# p_t0: reference time point in seconds
# p_beat: number of beats relative to the reference time point
func get_rtime_from_beat(p_t0: float, p_beat: float) -> float:
	if tempo_envelope == null:
		return p_beat * tempo_speed / 60.0
	
	if tempo_envelope.get_point_count() == 1:
		var bpm := tempo_envelope.get_point_value(0)
		return p_beat * bpm / 60.0
	
	#var beat_cache := _get_tempo_envelope_beat_cache()
	var npt := tempo_envelope.get_point_count()
	
	var pi1 := npt - 1
	var pi2 := npt
	
	# Time accumulated by tempo regions so far
	var dt := 0.0
	# Number of beats accumulated by tempo regions so far
	var dbeats := 0.0
	
	# Find tempo marker range in which t0 is
	for pi in range(1, npt):
		var t2 := tempo_envelope.get_point_position(pi)
		if t2 > p_t0:
			pi1 = pi - 1
			pi2 = pi
	
	# From t0, accumulate until we find the tempo range in which the beat is
	while pi1 < npt:
		var t1 := tempo_envelope.get_point_position(pi1)
		var t2 := MAX_TIME
		if pi2 < npt:
			t2 = tempo_envelope.get_point_position(pi2)
		assert(t2 > t1)
		
		var bpm1 := tempo_envelope.get_point_value(pi1)
		var bpm2 := bpm1
		if pi2 < npt:
			bpm2 = tempo_envelope.get_point_value(pi2)
		
		var gradual := tempo_envelope.get_point_gradual_transition(pi1)
		
		if p_t0 >= t1 and p_t0 < t2:
			# Start from t0
			if gradual:
				bpm1 = lerpf(bpm1, bpm2, (p_t0 - t1) / (t2 - t1))
			t1 = p_t0
		
		var lbeats := RPP_Util.get_beats_between_tempo_markers(t1, bpm1, t2, bpm2, gradual)
		
		if dbeats + lbeats < p_beat:
			dt += t2 - t1
			dbeats += lbeats
			pi1 += 1
			pi2 += 1
		else:
			# Found the tempo marker range in which our beat is
			var rbeats := p_beat - dbeats
			dt += RPP_Util.get_beat_time_between_tempo_markers(t1, bpm1, t2, bpm2, true, rbeats)
			break
	
	return dt


func debug_print() -> void:
	print("Default tempo: ", tempo_speed, " ", tempo_signature_num, "/", tempo_signature_denom)
	print("Markers: ", markers.size())
	print("Master:")
	master_track.debug_print("    ")
	print("Tracks:")
	for i in tracks.size():
		var track := tracks[i]
		track.debug_print("    ", i + 1)
