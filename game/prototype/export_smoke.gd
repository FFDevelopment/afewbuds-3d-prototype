extends Node
# Exercise imported resources inside the exported PCK using an isolated guest.
func _ready() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://prototype/apartment.tscn").instantiate()
	get_tree().root.add_child(game)
	for i in range(6): await get_tree().physics_frame
	var valid: bool = game.fp_ready and game.neighborhood.tile_textures.size()==9 and game.neighborhood.house_controls.shades.size()==11
	for character in ["Malik","Rod"]:
		var model:Node3D=game.neighborhood.location_ops.crew.character_instance(character)
		valid=valid and model.find_children("*","Skeleton3D",true,false).size()==1
		model.free()
	valid=valid and game.neighborhood.has_meta("east_landmarks")
	valid=valid and game.neighborhood.police_station.doors.size()==14 and game.neighborhood.police_station.has_node("StationStructure")
	valid=valid and game.neighborhood.bench_seating.benches.size()==3
	valid=valid and game.has_method("_build_real_estate_app") and game.neighborhood.location_ops.has_method("utility_state")
	valid=valid and game.fp_stamina_bar is ProgressBar and game.fp_player.STAMINA_MAX==100.0
	game.fp_player.enabled=true
	game.fp_player.wants_sprint=true
	game.fp_player._update_stamina(1.0,true,true)
	valid=valid and is_equal_approx(game.fp_player.stamina,82.0) and game.fp_player.is_sprinting
	game.queue_free()
	await get_tree().process_frame
	print("EXPORTED_WORLD_RESULT: PASS" if valid else "EXPORTED_WORLD_RESULT: FAIL")
	get_tree().quit(0 if valid else 1)
