extends Control


var _project : RPP_Project


func _ready() -> void:
	# Testing
	var path := "D:/Projets/Musique/OSphere/City/city.rpp"
	#var path := "D:/Projets/Musique/Robocraft/rc1.rpp"
	#var path := "D:/Projets/Audio/Enfer Liquide/Episodes/Episode 8/enfer_liquide_ep8.RPP"
	#var path := "./test_projects/test1.rpp"
	var project := RPP_Project.load_from_file(path)
	set_project(project)


func set_project(project: RPP_Project) -> void:
	_project = project
	queue_redraw()


func get_project() -> RPP_Project:
	return _project


func _draw() -> void:
	if _project.tracks.size() == 0:
		return
	
	var vseparation := 1.0
	var track_height := size.y / _project.tracks.size() - vseparation
	var total_len := _project.get_total_length()
	
	var time_begin := 0.0
	var time_end := total_len * 0.3
	
	if time_begin >= time_end:
		return
	
	var marker_default_color := Color(0.6, 0.0, 0.0)
	
	for track_index in _project.tracks.size():
		var track := _project.tracks[track_index]
		_draw_track(
			track, 
			Rect2(
				Vector2(0, track_index * (track_height + vseparation)), 
				Vector2(size.x, track_height)
			),
			time_begin,
			time_end
		)
	
	var time_to_px := size.x / (time_end - time_begin)
	
	for marker in _project.markers:
		var x := time_to_px * marker.time
		var color := marker_default_color
		if marker.use_custom_color:
			color = marker.color
		draw_line(Vector2(x, 0), Vector2(x, size.y), color)


func _draw_track(track: RPP_Track, track_rect: Rect2, time_begin: float, time_end: float) -> void:
	if time_begin >= time_end:
		return
	
	var item_base_color := Color(0.5, 0.5, 0.5)
	if track.use_custom_color:
		item_base_color = track.color
	var item_bg_color := item_base_color#.lightened(0.25)
	var item_border_color := item_base_color.darkened(0.25)
	
	var fade_color := Color(0.5, 0.0, 0.0)
	
	var time_to_px := track_rect.size.x / (time_end - time_begin)
	
	for item in track.items:
		if item.position > time_end:
			continue
		if item.position + item.length < time_begin:
			continue
		var item_rect := Rect2(
			track_rect.position.x + time_to_px * item.position,
			track_rect.position.y,
			time_to_px * item.length,
			track_rect.size.y
		)
		draw_rect(item_rect, item_bg_color)
		
		if item.source != null:
			var midi := item.source as RPP_MidiSource
			if midi != null:
				_draw_midi_notes(item, midi, item_rect, time_to_px)
		
		if item.fade_in_length > 0.0:
			var len_px := item.fade_in_length * time_to_px
			if len_px > 1.0:
				draw_line(
					Vector2(item_rect.position.x, item_rect.position.y + item_rect.size.y),
					Vector2(item_rect.position.x + len_px, item_rect.position.y),
					fade_color
				)
		
		if item.fade_out_length > 0.0:
			var len_px := item.fade_out_length * time_to_px
			if len_px > 1.0:
				var end_x := item_rect.position.x + item_rect.size.x
				draw_line(
					Vector2(end_x, item_rect.position.y + item_rect.size.y),
					Vector2(end_x - len_px, item_rect.position.y),
					fade_color
				)
		
		draw_rect(item_rect, item_border_color, false)


func _draw_midi_notes(
	item: RPP_Item, 
	midi: RPP_MidiSource, 
	item_rect: Rect2, 
	time_to_px: float
) -> void:
	var note_height := maxf(item_rect.size.y / 16.0, 1.0)
	var note_color := Color(0,0,0,0.75)
	
	var mcount := midi.get_message_count()
	# note => [start ticks]
	var notes : Dictionary[int, PackedInt32Array] = {}
	var ticks := 0
	var tick_to_beat := 1.0 / midi.ticks_per_quarter_note
	
	# TODO Proper support for slip offset and looping
	
	for mi in mcount:
		var mtype := midi.get_message_type(mi)
		
		match mtype:
			RPP_MidiSource.MessageType.NOTE_ON:
				var mticks := midi.get_message_start_offset(mi)
				ticks += mticks
				var nn := midi.get_message_data1(mi)
				if notes.has(nn):
					var st : PackedInt32Array = notes[nn]
					st.append(ticks)
				else:
					notes[nn] = PackedInt32Array([ticks])
			
			RPP_MidiSource.MessageType.NOTE_OFF:
				var mticks := midi.get_message_start_offset(mi)
				ticks += mticks
				var nn := midi.get_message_data1(mi)
				assert(notes.has(nn))
				var st : PackedInt32Array = notes[nn]
				assert(st.size() > 0)
				var last_index = st.size() - 1
				var begin_ticks := st[last_index]
				var end_ticks := ticks
				st.resize(last_index)
				var begin_beats := begin_ticks * tick_to_beat
				var end_beats := end_ticks * tick_to_beat
				var t0 := item.position - item.slip_offset
				# Tempo changes make this really tricky
				var begin_rtime := _project.get_rtime_from_beat(t0, begin_beats)
				var end_rtime := _project.get_rtime_from_beat(t0, end_beats)
				var nr := nn / float(RPP_MidiSource.MAX_NOTE)
				var y := note_height * 0.5 + (item_rect.size.y - note_height) * (1.0 - nr) \
					+ item_rect.position.y
				var x1 := begin_rtime * time_to_px
				var x2 := end_rtime * time_to_px
				var note_rect := Rect2(item_rect.position.x + x1, y, x2 - x1, note_height)
				draw_rect(note_rect, note_color)
			
			_:
				pass
