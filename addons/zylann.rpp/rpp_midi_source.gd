class_name RPP_MidiSource extends RPP_ItemSource

# https://wiki.cockos.com/wiki/index.php/StateChunkAndRppMidiFormat

# https://wiki.cockos.com/wiki/index.php/MIDI_Specification
enum MessageType {
	NOTE_ON = 0x9,
	NOTE_OFF = 0x8,
	POLYPHONIC_KEY_PRESSURE = 0xa,
	CONTROL_CHANGE = 0xb,
	PROGRAM_CHANGE = 0xc,
	CHANNEL_AFTERTOUCH = 0xd,
	PITCH_WHEEL = 0xe,
	# The following nibble is not a channel
	SYSTEM = 0xf
}

const MESSAGE_LENGTH = 8
const MAX_NOTE = 128

# According to the MIDI spec on Reaper wiki:
# "A Tick is the smallest increment of a beat; based upon the resolution of the device or
# application being used."
# https://wiki.cockos.com/wiki/index.php/MIDI_Glossary#TICK
# I'm confused by how I'm supposed to relate this to BPM and time in seconds.
# So far I feel like here, a "quarter note" actually corresponds to a beat. Maybe I'm mistaken,
# but so far this checks out with what I found in files:
# I made a MIDI item in a project at 120 BPM 4/4 with 1 note per beat,
# and found there was exactly one Note-On every 960 ticks.
# Which corresponds to the 960 QN in HASDATA lines.
var ticks_per_quarter_note : int

# Series of:
# - u32  number of ticks between this message and the previous one in the current item
# - u8   message type (t) and channel, when applicable (c): cccctttt
# - u8   data1 (depends on message type)
# - u8   data2 (depends on message type)
# - u8   _unused
var _messages := PackedByteArray()

var guid: String


func get_message_count() -> int:
	@warning_ignore("integer_division")
	return _messages.size() / MESSAGE_LENGTH


func append_message(offset: int, type: MessageType, channel: int, data1: int, data2: int) -> void:
	var i := get_message_count()
	_messages.resize(_messages.size() + MESSAGE_LENGTH)
	set_message_start_offset(i, offset)
	set_message_type(i, type)
	set_message_channel(i, channel)
	set_message_data1(i, data1)
	set_message_data2(i, data2)


func set_message_start_offset(i: int, v: int) -> void:
	var c := get_message_count()
	assert(i >= 0 and i < c)
	assert(v >= 0)
	_messages.encode_u32(i * MESSAGE_LENGTH + 0, v)


func get_message_start_offset(i: int) -> int:
	var c := get_message_count()
	assert(i >= 0 and i < c)
	return _messages.decode_u32(i * MESSAGE_LENGTH + 0)


func set_message_type(i: MessageType, v: int) -> void:
	var c := get_message_count()
	assert(i >= 0 and i < c)
	assert(v >= 0 and v < 16)
	var a := i * MESSAGE_LENGTH + 4
	var d := _messages.decode_u8(a)
	d = (d & 0xf0) | v
	_messages.encode_u8(a, d)


func get_message_type(i: int) -> MessageType:
	var c := get_message_count()
	assert(i >= 0 and i < c)
	var mt := (_messages.decode_u8(i * MESSAGE_LENGTH + 4) & 0x0f)
	return mt as MessageType


func set_message_channel(i: int, v: int) -> void:
	var c := get_message_count()
	assert(i >= 0 and i < c)
	assert(v >= 0 and v < 16)
	var a := i * MESSAGE_LENGTH + 4
	var d := _messages.decode_u8(a)
	d = (d & 0x0f) | (v << 4)
	_messages.encode_u8(a, d)


func get_message_channel(i: int) -> int:
	var c := get_message_count()
	assert(i >= 0 and i < c)
	return (_messages.decode_u8(i * MESSAGE_LENGTH + 4) >> 4) & 0x0f


func set_message_data1(i: int, v: int) -> void:
	var c := get_message_count()
	assert(i >= 0 and i < c)
	assert(v >= 0 and v < 256)
	_messages.encode_u8(i * MESSAGE_LENGTH + 5, v)


func get_message_data1(i: int) -> int:
	var c := get_message_count()
	assert(i >= 0 and i < c)
	return _messages.decode_u8(i * MESSAGE_LENGTH + 5)


func set_message_data2(i: int, v: int) -> void:
	var c := get_message_count()
	assert(i >= 0 and i < c)
	assert(v >= 0 and v < 256)
	_messages.encode_u8(i * MESSAGE_LENGTH + 6, v)


func get_message_data2(i: int) -> int:
	var c := get_message_count()
	assert(i >= 0 and i < c)
	return _messages.decode_u8(i * MESSAGE_LENGTH + 6)
