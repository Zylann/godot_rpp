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
const MAX_CHANNELS = 16

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

# Source MIDI messages.
# Series of:
# - u32  number of ticks between this message and the previous one in the current item
# - u8   message type (t) and channel, when applicable (c): cccctttt
# - u8   data1 (depends on message type)
# - u8   data2 (depends on message type)
# - u8   _unused
var _messages := PackedByteArray()

# Precalculated playback messages
var cached_messages_time := PackedFloat64Array()
var cached_messages_type := PackedByteArray()
var cached_messages_channel := PackedByteArray()
var cached_messages_data1 := PackedByteArray()
var cached_messages_data2 := PackedByteArray()

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


func find_note_on_index_from_off(from_index: int) -> int:
	var from_type := get_message_type(from_index)
	assert(from_type == MessageType.NOTE_OFF)
	var from_chan := get_message_channel(from_index)
	var from_nn := get_message_data1(from_index)
	var mi := from_index - 1
	while mi >= 0:
		var mtype := get_message_type(mi)
		if mtype == MessageType.NOTE_ON:
			var mchan := get_message_channel(mi)
			if mchan == from_chan:
				var mnn := get_message_data1(mi)
				if mnn == from_nn:
					return mi
		mi -= 1
	return -1


# Precalculates messages for playback within the item
# - Calculates times accounting for tempo changes
# - Generates note-on and note-off messages that could be missing due to item configuration
func update_cache(item: RPP_Item, project: RPP_Project) -> void:
	var item_slip_start_beats := project.time_to_beat(item.position - item.slip_offset)
	var item_start_beats := project.time_to_beat(item.position)
	var item_end_beats := project.time_to_beat(item.position + item.length)
	
	# Compute source message positions in beats
	assert(ticks_per_quarter_note > 0.0)
	var tick_to_beat := 1.0 / ticks_per_quarter_note
	var ticks := 0
	var src_message_count := get_message_count()
	var src_message_rbeats := PackedFloat64Array()
	for message_index in src_message_count:
		var message_offset_ticks := get_message_start_offset(message_index)
		ticks += message_offset_ticks
		var message_pos_rbeats : float = tick_to_beat * ticks
		src_message_rbeats.append(message_pos_rbeats)
	
	# Compute source length in beats
	# I assume MIDI items always end with an event that signals the end of the source,
	# I'm not sure where else I would get that info?
	var src_length_beats := 0.0
	for v in src_message_rbeats:
		src_length_beats = maxf(src_length_beats, v)
	
	var num_loops := ceili((item_end_beats - item_slip_start_beats) / src_length_beats)
	assert(num_loops > 0 and num_loops < 1000)
	
	var message_beats := PackedFloat64Array()
	var message_types := PackedByteArray()
	var message_channels := PackedByteArray()
	var message_data1 := PackedByteArray()
	var message_data2 := PackedByteArray()
	
	# Filter and loop messages (sections) within the item
	for loop_index in num_loops:
		var channels : Array[PackedByteArray] = []
		channels.resize(MAX_CHANNELS)
		for i in channels.size():
			var notes_oncount := PackedByteArray()
			notes_oncount.resize(MAX_NOTE)
			channels[i] = notes_oncount
		
		# Calculate section bounds
		var section_start_beats := item_slip_start_beats + loop_index * src_length_beats
		var section_end_beats := section_start_beats + src_length_beats
		if section_start_beats < item_start_beats:
			section_start_beats = item_start_beats
		if section_end_beats > item_end_beats:
			section_end_beats = item_end_beats
		
		# Fill section
		for message_index in src_message_count:
			var src_message_rbeat := src_message_rbeats[message_index]
			var message_beat := item_slip_start_beats + src_message_rbeat \
				+ loop_index * src_length_beats
			# Check if within the whole item
			if message_beat < item_start_beats:
				continue
			if message_beat > item_end_beats:
				continue
			
			var mtype := get_message_type(message_index)
			var mchan := get_message_channel(message_index)
			var mdata1 := get_message_data1(message_index)
			var mdata2 := get_message_data2(message_index)
			
			# Fix missing note-ons
			match mtype:
				MessageType.NOTE_ON:
					var nn := mdata1
					var oncounts := channels[mchan]
					var c := oncounts[nn]
					c += 1
					assert(c < 256)
					oncounts[nn] = c
				MessageType.NOTE_OFF:
					var nn := mdata1
					var oncounts := channels[mchan]
					var c := oncounts[nn]
					if c > 0:
						c -= 1
						oncounts[nn] = c
					else:
						# Missing note start within loop [section],
						# create a new note start at the beginning of the section
						message_beats.append(section_start_beats)
						message_types.append(MessageType.NOTE_ON)
						message_channels.append(mchan)
						message_data1.append(nn)
						# We have to look upstream to find velocity
						var start_mi := find_note_on_index_from_off(message_index)
						assert(start_mi >= 0)
						var start_data2 := get_message_data2(start_mi)
						message_data2.append(start_data2)
				_:
					pass
			
			message_beats.append(message_beat)
			message_types.append(mtype)
			message_channels.append(mchan)
			message_data1.append(mdata1)
			message_data2.append(mdata2)
			
		# Fix missing note-offs
		for chan_index in channels.size():
			var oncounts := channels[chan_index]
			for nn in oncounts.size():
				var c := oncounts[nn]
				for i in c:
					message_beats.append(section_end_beats)
					message_types.append(MessageType.NOTE_OFF)
					message_channels.append(chan_index)
					message_data1.append(nn)
					message_data2.append(0)
	
	# Convert beats to time relative to the start of the item
	var message_times := PackedFloat64Array()
	for i in message_beats.size():
		var beat := message_beats[i]
		var t := project.get_rtime_from_beat(0.0, beat) - item.position
		message_times.append(t)
	
	cached_messages_type = message_types
	cached_messages_time = message_times
	cached_messages_channel = message_channels
	cached_messages_data1 = message_data1
	cached_messages_data2 = message_data2
