extends Node
var game: Node3D
func _ready() -> void:
 await AFBCloud.prepare(true)
 game = load("res://prototype/apartment.tscn").instantiate()
 add_child(game)
 var study = load("res://visual_lab/study.gd").new()
 study.name = "ArtStudy"
 add_child(study)
 study.setup(game)
