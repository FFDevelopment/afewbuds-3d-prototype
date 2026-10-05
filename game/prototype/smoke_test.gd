extends SceneTree
var game: Node3D
var failures: Array[String] = []

func _initialize() -> void:
	ProjectSettings.set_setting("application/config/custom_user_dir_name", "AFewBuds-3D-Prototype-QA")
	call_deferred("run")

func check(condition: bool, label_text: String) -> void:
	if condition:
		print("PASS: ", label_text)
	else:
		failures.append(label_text)
		push_error("FAIL: " + label_text)

func frames(count: int = 4) -> void:
	for i in range(count):
		await physics_frame

func aim(player_pos: Vector3, target: Vector3) -> void:
	game.fp_player.position = player_pos
	game.fp_player.velocity = Vector3.ZERO
	game.camera.global_position = player_pos + Vector3.UP * game.fp_player.EYE_HEIGHT
	game.camera.look_at(target)
	game.fp_player.yaw = game.camera.rotation.y
	game.fp_player.pitch = game.camera.rotation.x
	game.fp_player.sync_camera()

func run() -> void:
	# QA never writes the player's normal prototype save.
	check("QA" in OS.get_user_data_dir(), "QA save directory isolated")
	if not "QA" in OS.get_user_data_dir():
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir())
	var save_path := "user://afewbuds_3d_prototype_save.json"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	game = load("res://prototype/apartment.tscn").instantiate()
	root.add_child(game)
	await frames()
	check(game.fp_ready and game.fp_player != null, "apartment and player initialize")
	check(game.session_paused, "instructions pause simulation on launch")
	check(game.fp_collisions.size() > 30, "physical room and furniture colliders exist")
	game._resume_gameplay()
	await frames()
	# Wall collision uses the real capsule and physics engine.
	game.fp_player.position = Vector3(4.2, 0.08, -2)
	var wall_hit: KinematicCollision3D = game.fp_player.move_and_collide(Vector3(2, 0, 0))
	check(wall_hit != null and game.fp_player.position.x < 4.75, "right wall blocks capsule")
	game.fp_player.position = Vector3(-2.28, 0.08, 2.0)
	var couch_hit: KinematicCollision3D = game.fp_player.move_and_collide(Vector3(0, 0, 1.0))
	check(couch_hit != null and game.fp_player.position.z < 2.5, "loveseat blocks capsule")
	game.fp_player.position = Vector3(0, 0.08, -3)
	var door_hit: KinematicCollision3D = game.fp_player.move_and_collide(Vector3(0, 0, -2))
	check(door_hit == null and game.fp_player.position.z < -4.8, "grow-room doorway is walkable")
	# Existing plant hitboxes now work from a freely positioned camera.
	aim(Vector3(-0.92, 0.08, -7.2), Vector3(-0.92, 1.0, -9.12))
	await frames()
	game._update_target()
	check(game.fp_target != null and game.fp_target.has_meta("plant_slot"), "ray selects plant within reach")
	game._use_target()
	check(game.plant_direct_panel.visible, "E opens original plant-care panel")
	var before: int = game.untrimmed_inventory.get("Purple Dream", 0)
	game._harvest_plant(0)
	check(int(game.untrimmed_inventory.get("Purple Dream", 0)) > before, "original harvest transfers product")
	game._close_direct_plant()
	var plant: Area3D = game._target_from_ray(Vector3(-0.92, 1.64, -4.5), Vector3(0, -0.1, -1))
	check(plant == null, "out-of-reach plant cannot be used")
	# Place a temporary target behind the partition to verify occlusion.
	game._add_interaction_area("QA_WallTarget", Vector3(3, 1.4, -4.4), Vector3(0.3, 0.3, 0.3), "station_supply", "grow")
	await frames()
	check(game._target_from_ray(Vector3(3, 1.4, -3.4), Vector3.FORWARD) == null, "wall blocks interaction through partition")
	game.get_node("QA_WallTarget").queue_free()
	aim(Vector3(1.8, 0.08, 0.78), Vector3(3.25, 1.35, 0.78))
	await frames()
	game._use_target()
	check(game.bagging_panel.visible, "bench opens original packaging pipeline")
	game._start_trim_minigame("Purple Dream")
	await frames()
	check(game.trim_panel.get_global_rect().end.y <= game.hud.size.y, "trim panel fits landscape viewport")
	for target in game.trim_targets:
		if is_instance_valid(target) and target.visible:
			var press := InputEventMouseButton.new()
			press.button_index = MOUSE_BUTTON_LEFT
			press.pressed = true
			press.position = game.trim_scissors.get_global_rect().get_center()
			game._input(press)
			var release := InputEventMouseButton.new()
			release.button_index = MOUSE_BUTTON_LEFT
			release.pressed = false
			release.position = target.get_global_rect().get_center()
			game._input(release)
	check(int(game.trimmed_inventory.get("Purple Dream", 0)) > 0, "mouse dragging trims harvested product")
	game._close_trim_minigame()
	game._start_bag_minigame("Purple Dream")
	await frames()
	check(game.bag_minigame_panel.get_global_rect().end.y <= game.hud.size.y, "bagging panel fits landscape viewport")
	for i in range(game.bag_target_units):
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		press.position = game.bag_bud_token.get_global_rect().get_center()
		game._input(press)
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.position = game.bag_target_panel.get_global_rect().get_center()
		game._input(release)
	game._seal_current_bag()
	check(int(game.bagged_inventory.get("Purple Dream", 0)) > 0, "mouse dragging and sealing creates packaged product")
	var old_stock: int = game.products["Purple Dream"].stock
	game._store_product("Purple Dream")
	check(int(game.products["Purple Dream"].stock) > old_stock, "packaged product transfers to storage")
	game._close_bagging_panel()
	aim(Vector3(-2.3, 0.08, -0.3), Vector3(-3.95, 1.3, -0.3))
	await frames()
	game._use_target()
	check(game.storage_panel.visible, "storage opens original inventory")
	game._close_storage_panel()
	aim(Vector3(-2.4, 0.08, -6.45), Vector3(-4.05, 1.3, -6.45))
	await frames()
	game._use_target()
	check(game.supply_inventory_panel.visible, "supply shelf opens seeds and fertilizer")
	game._close_supply_inventory_panel()
	aim(Vector3(2.8, 0.08, -6.65), Vector3(4.45, 1.8, -6.65))
	await frames()
	game._use_target()
	check(game.system_control_panel.visible, "wall terminal opens grow controls")
	game._close_system_control_panel()
	check(is_equal_approx(game.camera.global_position.y - game.fp_player.global_position.y, 1.90), "raised adult viewpoint stays above player feet")
	aim(Vector3(2.4, 0.08, -2.20), Vector3(3.95, 1.3, -2.20))
	await frames()
	game._use_target()
	check(game.dealer_storage_panel.visible, "E opens native dealer storage")
	await frames()
	check(not game.fp_player.enabled, "dealer storage locks walking")
	game.cash = 10000
	game.dealer_locker_level = 0
	game._buy_dealer_locker_upgrade()
	check(game.dealer_locker_level == 1 and game._dealer_locker_capacity() == 100 and game.cash == 9700, "first locker tier costs 300 and holds 100g")
	game.storage_level = 5
	game.products["Purple Dream"]["stock"] = 150
	game.locker_weed.clear()
	var moved: int = game._dealer_locker_add_from_storage("Purple Dream", 999999)
	check(moved == 100 and game.products["Purple Dream"]["stock"] == 50, "MAX transfer respects locker capacity and conserves stock")
	game._dealer_storage_transfer("Purple Dream", 5, false)
	check(game.locker_weed["Purple Dream"] == 95 and game.products["Purple Dream"]["stock"] == 55, "minus five returns dealer stock to storage")
	game._refresh_dealer_storage_panel()
	check(game.dealer_storage_list.find_children("", "Button", true, false).size() >= 6, "dealer rows provide transfer controls")
	game._close_active_panel()
	check(not game.dealer_storage_panel.visible, "Escape closes dealer storage")
	for tier in range(2, 5):
		game._buy_dealer_locker_upgrade()
		check(game.dealer_locker_level == tier and game._dealer_locker_capacity() == tier * 100, "locker upgrades sequentially to tier %d" % tier)
	check(game.premium_dealer_locker_root.visible and not game.get_node("LockerBody").visible, "premium locker replaces basic locker at tier III")
	game._use_target()
	await create_timer(0.4).timeout
	check(game.dealer_storage_panel.visible and game.premium_dealer_locker_open, "premium locker doors open before first-person menu")
	game._pause_gameplay()
	check(not game.dealer_storage_panel.visible, "pause hides locker controls")
	game._resume_gameplay()
	check(game.dealer_storage_panel.visible, "resume restores locker in first-person view")
	game._close_dealer_storage_panel()
	game._use_target()
	game._pause_gameplay()
	await create_timer(0.4).timeout
	check(not game.dealer_storage_panel.visible and not game.fp_station_opening, "pause cancels pending locker opening")
	game._resume_gameplay()
	game.grower_level = 6
	game.cash = 10000
	game.bagging_level = 1
	game._buy_supply("Bagging Bench III")
	check(game.bagging_level == 1 and game.cash == 10000, "bench III requires bench II")
	game._buy_supply("Bagging Bench II")
	var bench_cash: int = game.cash
	game._buy_supply("Bagging Bench III")
	check(game.bagging_level == 3 and game.cash == bench_cash - 850, "bench III purchase charges 850")
	await frames()
	check(game.get_node("BenchIIIBackBoard").visible and not game.get_node("BenchLowerShelf").visible, "bench III replaces old lower furniture")
	check(game.get_node("BenchIIIBackBoard").has_node("PrototypeCollision"), "newly purchased bench has collision")
	var collider_count: int = game.fp_collisions.size()
	game._apply_visual_upgrades()
	check(game.fp_collisions.size() == collider_count, "repeated upgrades do not duplicate collision")
	game.trimmed_inventory["Purple Dream"] = 17
	var bags_before: int = game.bagged_inventory.get("Purple Dream", 0)
	game._start_bag_minigame("Purple Dream")
	var batches := 0
	while game.bag_minigame_panel.visible and batches < 20:
		var remaining: int = game.trimmed_inventory["Purple Dream"]
		check(game.bag_target_units >= 1 and game.bag_target_units <= mini(4, remaining), "continuous target fits 1–4g and remaining product")
		game.bag_current_units = game.bag_target_units
		game._seal_current_bag()
		batches += 1
		if game.trimmed_inventory["Purple Dream"] > 0:
			check(game.bag_minigame_panel.visible and game.bag_current_units == 0, "bench III continues next bag without reopening")
	check(batches > 1 and not game.bag_minigame_panel.visible and game.bagged_inventory["Purple Dream"] == bags_before + 17, "continuous bagging finishes and conserves all product")
	game._close_bagging_panel()
	# Latest furniture must line up with its first-person targets.
	check(is_equal_approx(game.get_node("BenchTop").position.z, 0.78), "bench moved toward front door")
	check(is_equal_approx(game.get_node("StorageBack").position.z, -0.06), "shelves moved toward front door")
	var counter: MeshInstance3D = game.get_node("KitchenCounter")
	var frame: MeshInstance3D = game.get_node("GrowDoorFrameR")
	check(counter.position.x - counter.mesh.size.x / 2 > frame.position.x + frame.mesh.size.x / 2, "kitchen clears grow-room door frame")
	check(game.get_node("ScaleBody").position.x - game.get_node("ScaleBody").mesh.size.x / 2 >= game.get_node("BenchTop").position.x - game.get_node("BenchTop").mesh.size.x / 2, "scale sits inside tabletop front edge")
	check(is_equal_approx(game.get_node("PackingScaleText").rotation_degrees.y, -90), "scale display faces player")
	game.storage_level = 4
	game._apply_visual_upgrades()
	check(game.storage_vault.position.is_equal_approx(Vector3(-4.33, 0, -0.30)), "vault anchor remains unchanged")
	game.storage_level = 5
	game._apply_visual_upgrades()
	check(game.hidden_stash_interior_root.position.is_equal_approx(Vector3(-4.57, 0, -0.30)), "stash moves toward wall without moving along it")
	game._open_storage_panel()
	check(game.fp_station_opening, "stash animation blocks movement")
	game._pause_gameplay()
	await create_timer(0.35).timeout
	check(not game.storage_panel.visible, "pause cancels pending stash menu")
	game._resume_gameplay()
	game._open_storage_panel()
	await create_timer(0.35).timeout
	check(game.storage_panel.visible, "stash opens normally after resume")
	game._close_storage_panel()
	game.seed_inventory.clear()
	for seed_name in game.SEED_ORDER:
		game.seed_inventory[seed_name] = 1
	game.seed_inventory["Future QA Hybrid"] = 1
	game.plant_slots[2]["stage"] = -1
	game._open_direct_plant(2)
	await frames()
	var seed_buttons := 0
	for button in game.plant_direct_box.find_children("", "Button", true, false):
		if button.text.ends_with(" (1)"): seed_buttons += 1
	check(seed_buttons == game.seed_inventory.size(), "picker lists every owned seed including future genetics")
	game._close_direct_plant()
	var position_before: Vector3 = game.fp_player.position
	game._toggle_phone()
	await frames()
	check(game.phone_open and not game.fp_player.enabled, "phone releases cursor and locks movement")
	game._toggle_phone()
	game._go_to_view("main_workbench")
	check(game.fp_player.position.distance_to(position_before) < 0.1, "closing menus does not teleport player")
	game._save_game()
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	check(saved.get("runtime", {}).has("prototype_player"), "save includes first-person position")
	var cash_before: int = game.cash
	game.cash = 1
	game._load_game()
	check(game.cash == cash_before, "local save reload restores gameplay")
	print("PROTOTYPE_TEST_RESULT: ", "PASS" if failures.is_empty() else str(failures))
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	quit(0 if failures.is_empty() else 1)
