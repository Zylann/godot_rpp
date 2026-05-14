extends Control


var _project : RPP_Project


func _ready() -> void:
	# Testing
	var path := "D:/Projets/Musique/OSphere/City/city.rpp"
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
