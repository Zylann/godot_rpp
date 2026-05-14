class_name RPP_MidiSource extends RPP_ItemSource

enum MessageType {
	NOTE_ON = 0x9,
	NOTE_OFF = 0x8,
	CONTROL_CHANGE = 0xb
}

const MESSAGE_LENGTH = 8

# Series of:
# - u32  start offset: u32
# - u8   message type and channel: cccctttt
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
	return _messages.decode_u8(i * MESSAGE_LENGTH + 4) & 0x0f


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
