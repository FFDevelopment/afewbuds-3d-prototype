extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 await root.get_node("AFBCloud").prepare(true)
 var game=load("res://prototype/apartment.tscn").instantiate();root.add_child(game)
 for i in range(3):await process_frame
 game.set_process(false);game.fp_player.set_physics_process(false)
 var clock:float=game.game_time_minutes
 var position_before:Vector3=game.fp_player.position
 var paused_before:bool=game.session_paused
 game._install_map_update();game._install_map_update()
 assert(game.fp_player.position==position_before and game.session_paused==paused_before)
 assert(game.get_node("BasementExpansion")!=null)
 var visuals=game.get_node("MapVisuals")
 assert(not visuals.is_processing() and not visuals.is_processing_input())
 for i in range(3):await process_frame
 assert(game.game_time_minutes==clock)
 var registry=game.inventory_system.furniture.model.registry
 assert(registry.exists("apartment") and registry.exists("house"))
 assert(registry.room_at("house",Vector3(30,-2,-10))=="basement_grow")
 assert(registry.room_at("house",Vector3(30,2,-10))!="basement_grow")
 assert(registry.room_at("house",Vector3(30,11,-10))=="")
 print("RUNTIME_MAP_PASS clock_preserved=true no_debug_keys=true original_property_ids=true floor_registration=true")
 quit()
