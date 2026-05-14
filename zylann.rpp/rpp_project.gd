class_name RPP_Project

var reaper_version: String # "6.12c/x64"
var ripple: bool = false
var auto_cross_fade: bool = false
var loop: bool = false

var tempo_speed: float = 0
var tempo_signature_num: int = 0
var tempo_signature_denom: int = 0
var tempo_envelope: RPP_TempoEnvelope

var master_track := RPP_MasterTrack.new()
var tracks : Array[RPP_Track] = []

var markers: Array[RPP_Marker] = []


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
