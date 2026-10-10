extends SceneTree
## Exercises the *actual playable desktop scene*, not only mocked cloud JSON.
## All files are in tools/test.py's isolated AFewBuds-3D-Prototype-QA user dir.
var failures: int = 0
var checks: int = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func _test_loaded(game: Node3D, expected_property: String, expected_dealer_property: String) -> void:
	var state: Dictionary = game.location_state
	var model: RefCounted = game.inventory_system.furniture.model
	var crew: RefCounted = game.neighborhood.location_ops.crew
	check(int(model.state.get("schema", 0)) >= 2, "Real furniture registry uses versioned inventory")
	check(model.state.items.has("furniture_101") and model.state.items.has("furniture_102"), "Both phone-owned tent IDs survive the real game boot")
	if model.state.items.has("furniture_101") and model.state.items.has("furniture_102"):
		check(str(model.state.items.furniture_101.get("property")) == expected_property, "Recently placed tent matches saved property")
		check(str(model.state.items.furniture_102.get("property")) == "backpack", "Previously packed tent stays in backpack")
		check(game.inventory_system.contents("backpack").get("furniture|furniture_102",0) == 1, "Packed tent remains accessible in the actual backpack")
		check(game.inventory_system.furniture.equipment_world != null, "Furniture renderer initialized")
	check(str(game.production_worker_friend_name) == "Malik", "Production worker identity loaded")
	check(str(game.friend_staff_roles.get("Tyler", "")) == "dealer", "Friend dealer identity loaded")
	check(str(state.get("staff_assignments", {}).get("Tyler", "")) == expected_dealer_property, "Dealer property matches latest phone snapshot")
	check(crew.assignment("Tyler") == expected_dealer_property, "Computer/crew UI adapter shows correct property")
	check(crew.role("Malik") == "production", "Production worker role survives real scene initialization")

func _boot() -> Node3D:
	var game: Node3D = load("res://prototype/apartment.tscn").instantiate()
	root.add_child(game)
	for i in range(12):
		await process_frame
	game.set_process(false)
	game.neighborhood.set_process(false)
	game.fp_player.set_physics_process(false)
	for timer in game.find_children("*", "Timer", true, false):
		timer.stop()
	return game

func run() -> void:
	check("QA" in OS.get_user_data_dir(), "Never read or write a live career directory")
	if failures:
		quit(1)
		return
	var cloud: Node = root.get_node("AFBCloud")
	check(not bool(cloud.launched) and cloud.session.is_empty(), "Cloud connections are disabled throughout test")
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://account/career_parity_fixture.json"))
	if not source is Dictionary:
		check(false, "Phone-style fixture is valid JSON")
		quit(1)
		return
	var game_save: Dictionary = (source as Dictionary).duplicate(true)
	# Simulate phone's most recent transaction: a formerly packed tent is
	# installed at the apartment while another tent stays stored, and Tyler
	# is the apartment dealer. The desktop must not invent another layout.
	game_save.location_state.furniture_v1.items.furniture_101.property = "apartment"
	game_save.location_state.furniture_v1.items.furniture_101.position = [0.0, 0.0, -9.1]
	game_save.location_state.furniture_v1.items.furniture_101.locked = true
	game_save.location_state.staff_assignments.Malik = "house"
	game_save.location_state.staff_assignments.Tyler = "apartment"
	check(cloud.write_json(cloud.ACTIVE, game_save), "Write phone's saved career to isolated QA location")
	var game: Node3D = await _boot()
	_test_loaded(game, "apartment", "apartment")
	# Refreshing the world and visiting inventory/computer must not write
	# older default equipment/worker assignments over the loaded save.
	game.inventory_system.furniture.equipment_world.sync()
	_test_loaded(game, "apartment", "apartment")
	game._save_game()
	var roundtrip: Dictionary = cloud.read_json(cloud.ACTIVE)
	check(str(roundtrip.location_state.furniture_v1.items.furniture_101.property) == "apartment", "Save after game boot preserves recently installed tent")
	check(str(roundtrip.location_state.furniture_v1.items.furniture_102.property) == "backpack", "Save after game boot does not lose packed tent")
	check(str(roundtrip.location_state.staff_assignments.Tyler) == "apartment", "Save after game boot does not reset apartment dealer")
	check(str(roundtrip.friend_staff_roles.Tyler) == "dealer" and str(roundtrip.production_worker_friend_name) == "Malik", "Save after game boot retains both worker identities")
	check(int(roundtrip.location_state.container_inventory.containers["apartment:storage"].get("product|Purple Dream", -1)) == 16, "Saving never merges distinct properties' stock")
	game.queue_free()
	await process_frame
	# A second cold start must match the same persisted phone career.
	var reloaded: Node3D = await _boot()
	_test_loaded(reloaded, "apartment", "apartment")
	reloaded.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(cloud.ACTIVE))
	print("REAL_SCENE_CAREER_RESULT: ", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
