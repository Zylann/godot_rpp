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
	var item_muted_bg_color := item_bg_color.darkened(0.5)
	var item_muted_border_color := item_border_color.darkened(0.5)
	
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
		draw_rect(item_rect, item_muted_bg_color if item.muted else item_bg_color)
		
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
		
		draw_rect(item_rect, item_muted_border_color if item.muted else item_border_color, false)


func _draw_midi_notes(
	_unused_item: RPP_Item, 
	midi: RPP_MidiSource, 
	item_rect: Rect2, 
	time_to_px: float
) -> void:
	var note_height := maxf(item_rect.size.y / 16.0, 1.0)
	var note_color := Color(0,0,0,0.75)
	
	# [channel][note][instance]
	var channels : Array[Array] = []
	channels.resize(RPP_MidiSource.MAX_CHANNELS)
	for chan_index in channels.size():
		var notes : Array[PackedFloat64Array] = []
		notes.resize(RPP_MidiSource.MAX_NOTE)
		for i in notes.size():
			notes[i] = PackedFloat64Array()
		channels[chan_index] = notes
	
	for mi in midi.cached_messages_type.size():
		var mtype := midi.cached_messages_type[mi]
		var mchan := midi.cached_messages_channel[mi]
		var mtime := midi.cached_messages_time[mi]
		match mtype:
			RPP_MidiSource.MessageType.NOTE_ON:
				var nn := midi.cached_messages_data1[mi]
				var notes : Array[PackedFloat64Array] = channels[mchan]
				var ons := notes[nn]
				ons.append(mtime)
			RPP_MidiSource.MessageType.NOTE_OFF:
				var nn := midi.cached_messages_data1[mi]
				var notes : Array[PackedFloat64Array] = channels[mchan]
				var ons := notes[nn]
				assert(ons.size() > 0)
				var li := ons.size() - 1
				var otime := ons[li]
				ons.resize(li)
				var x1 := time_to_px * otime
				var x2 := time_to_px * mtime
				var nr := nn / float(RPP_MidiSource.MAX_NOTE)
				var y := note_height * 0.5 + (item_rect.size.y - note_height) * (1.0 - nr) \
					+ item_rect.position.y
				var note_rect := Rect2(item_rect.position.x + x1, y, x2 - x1, note_height)
				draw_rect(note_rect, note_color)
			_:
				pass
