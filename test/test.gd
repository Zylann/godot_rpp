extends Node


func _ready() -> void:
	var path := "D:/Projets/Musique/OSphere/City/city.rpp"
	var project := RPP_Project.load_from_file(path)
	print("Done")
