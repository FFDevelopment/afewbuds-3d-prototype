extends Node
# Exercise imported resources inside the exported PCK using an isolated guest.
func _ready() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://prototype/apartment.tscn").instantiate()
	get_tree().root.add_child(game)
	for i in range(6): await get_tree().physics_frame
	var valid: bool = game.fp_ready and game.neighborhood.tile_textures.size()==9 and game.neighborhood.house_controls.shades.size()==11
	game.queue_free()
	await get_tree().process_frame
	print("EXPORTED_WORLD_RESULT: PASS" if valid else "EXPORTED_WORLD_RESULT: FAIL")
	get_tree().quit(0 if valid else 1)
