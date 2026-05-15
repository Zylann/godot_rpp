class_name RPP_AudioSource extends RPP_ItemSource

enum Type {
	VORBIS,
	FLAC,
	WAVE,
	MP3,
	OTHER
}

var file_type : Type
var file_path := ""

var is_section := false
var section_start := 0.0
var section_length := 0.0 # 0 means full length
var section_overlap := 0.0
