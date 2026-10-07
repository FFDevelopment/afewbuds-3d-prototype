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
	await check_neighborhood()
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
	check(game.inventory_system.is_open(), "storage opens physical container inventory")
	game._close_storage_panel()
	aim(Vector3(-2.4, 0.08, -6.45), Vector3(-4.05, 1.3, -6.45))
	await frames()
	game._use_target()
	check(game.inventory_system.is_open(), "supply shelf opens seeds and fertilizer")
	game._close_supply_inventory_panel()
	aim(Vector3(2.8, 0.08, -6.65), Vector3(4.45, 1.8, -6.65))
	await frames()
	game._use_target()
	check(game.system_control_panel.visible, "wall terminal opens grow controls")
	game._close_system_control_panel()
	check(is_equal_approx(game.camera.global_position.y - game.fp_player.global_position.y, 2.16), "raised adult viewpoint stays above player feet")
	aim(Vector3(2.4, 0.08, -2.20), Vector3(3.95, 1.3, -2.20))
	await frames()
	game._use_target()
	check(not game.inventory_system.is_open(), "Unpurchased dealer container stays locked")
	await frames()
	check(not game.fp_player.enabled, "dealer storage locks walking")
	game.cash = 10000
	game.dealer_locker_level = 0
	game.neighborhood.location_ops.installing=true
	game._buy_dealer_locker_upgrade()
	game.neighborhood.location_ops.installing=false
	check(game.dealer_locker_level == 1 and game._dealer_locker_capacity() == 100 and game.cash == 10000, "paid locker installation does not charge twice and holds 100g")
	game._use_target()
	check(game.inventory_system.is_open(), "Purchased dealer container opens with E")
	game.storage_level = 5
	game.products["Purple Dream"]["stock"] = 150
	game.locker_weed.clear()
	var moved: int = game._dealer_locker_add_from_storage("Purple Dream", 999999)
	check(moved == 100 and game.products["Purple Dream"]["stock"] == 50, "MAX transfer respects locker capacity and conserves stock")
	game._dealer_storage_transfer("Purple Dream", 5, false)
	check(game.locker_weed["Purple Dream"] == 95 and game.products["Purple Dream"]["stock"] == 55, "minus five returns dealer stock to storage")
	game._refresh_dealer_storage_panel()
	check(game.inventory_system.confirm != null, "dealer container provides quantity transfer controls")
	game._close_active_panel()
	check(not game.inventory_system.is_open(), "Escape closes dealer storage")
	for tier in range(2, 5):
		game.neighborhood.location_ops.installing=true
		game._buy_dealer_locker_upgrade()
		game.neighborhood.location_ops.installing=false
		check(game.dealer_locker_level == tier and game._dealer_locker_capacity() == tier * 100, "locker upgrades sequentially to tier %d" % tier)
	check(game.premium_dealer_locker_root.visible and not game.get_node("LockerBody").visible, "premium locker replaces basic locker at tier III")
	game._use_target()
	await create_timer(0.4).timeout
	check(game.inventory_system.is_open() and game.premium_dealer_locker_open, "premium locker doors open before first-person menu")
	game._pause_gameplay()
	check(not game.inventory_system.is_open(), "pause hides locker controls")
	game._resume_gameplay()
	check(game.inventory_system.is_open(), "resume restores locker in first-person view")
	game._close_dealer_storage_panel()
	game._use_target()
	game._pause_gameplay()
	await create_timer(0.4).timeout
	check(not game.inventory_system.is_open() and not game.fp_station_opening, "pause cancels pending locker opening")
	game._resume_gameplay()
	game.grower_level = 6
	game.cash = 10000
	game.bagging_level = 1
	game.neighborhood.location_ops.installing=true
	game._buy_supply("Bagging Bench III")
	check(game.bagging_level == 1 and game.cash == 10000, "bench III requires bench II")
	game._buy_supply("Bagging Bench II")
	var bench_cash: int = game.cash
	game.neighborhood.location_ops.installing=true
	game._buy_supply("Bagging Bench III")
	check(game.bagging_level == 3 and game.cash == bench_cash - 850, "bench III purchase charges 850")
	game.neighborhood.location_ops.installing=false
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
	check(not game.has_node("WindowBuildingA") and not game.has_node("WindowBuildingB") and not game.has_node("WindowBuildingC"), "window placeholder squares removed")
	check(game.neighborhood.has_node("ApartmentWindow") and game.window_sun_disc == null, "real glazed window replaces fake sky and sun")
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
	check(game.hidden_stash_interior_root.position.is_equal_approx(Vector3(-4.69, 0, -0.30)), "stash moves toward wall without moving along it")
	aim(Vector3(-2.3, 0.08, -0.3), Vector3(-3.95, 1.3, -0.3))
	game._open_storage_panel()
	check(game.fp_station_opening, "stash animation blocks movement")
	game._pause_gameplay()
	await create_timer(0.35).timeout
	check(not game.inventory_system.is_open(), "pause cancels pending stash menu")
	game._resume_gameplay()
	game._open_storage_panel()
	await create_timer(0.35).timeout
	check(game.inventory_system.is_open(), "stash opens normally after resume")
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
	check(game.phone_panel.size.y > game.phone_panel.size.x * 1.35, "desktop phone maintains portrait proportions")
	check(game.phone_panel.get_global_rect().end.y <= game.hud.size.y, "portrait phone fits viewport")
	var phone_width_before_rewards: float = game.phone_panel.size.x
	game._open_phone_app("advancements")
	await frames()
	check(absf(game.phone_panel.size.x - phone_width_before_rewards) <= 2.0, "Rewards does not stretch portrait phone width")
	check(game.phone_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Rewards stays vertical-scroll only")
	game.customer_waiting = true
	game.customer_answered = false
	game._refresh_door_alert()
	await frames()
	check(game.knock_banner.size.x <= 520 and game.knock_banner.size.y <= 90, "visitor alert stays compact")
	check(game.knock_banner.get_global_rect().end.y < game.phone_panel.get_global_rect().position.y, "visitor alert sits above phone without overlap")
	game._toggle_phone()
	game._go_to_view("main_workbench")
	check(game.fp_player.position.distance_to(position_before) < 0.1, "closing menus does not teleport player")
	game._charge_water_use(3)
	game._finalize_daily_water_bill(false)
	var water_due: int = game.water_bill_due
	check(water_due >= 6, "water usage posts a separate utility bill")
	game.property_offer_unlocked = true
	game._save_game()
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	check(saved.get("runtime", {}).has("prototype_player"), "save includes first-person position")
	var cash_before: int = game.cash
	game.cash = 1
	game._load_game()
	check(game.water_bill_due == water_due and game.property_offer_unlocked, "water balance and property offer survive save reload")
	check(game.cash == cash_before, "local save reload restores gameplay")
	game._pay_water_bill()
	check(game.water_bill_due == 0 and game.cash == cash_before - water_due, "paying water bill deducts its exact balance")

	print("PROTOTYPE_TEST_RESULT: ", "PASS" if failures.is_empty() else str(failures))
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	quit(0 if failures.is_empty() else 1)

func check_neighborhood() -> void:
	var outside = game.neighborhood
	for bounds in outside.building_bounds:
		check(not bounds.intersects(outside.APARTMENT_BOUNDS), "exterior building stays outside apartment and grow-room volume")
	var mesh_overlap := false
	for child in outside.get_children():
		if child is MeshInstance3D and not str(child.name).begins_with("ApartmentWindow") and not str(child.name).begins_with("WindowFrame") and not str(child.name).begins_with("WindowSill") and not str(child.name).begins_with("Entry"):
			var actual_bounds: AABB = child.global_transform * child.get_aabb()
			mesh_overlap = mesh_overlap or actual_bounds.intersects(outside.APARTMENT_BOUNDS)
	check(not mesh_overlap, "actual exterior mesh bounds cannot enter apartment volume")
	for bounds in outside.building_bounds:
		var footprint := Rect2(Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.size.x,bounds.size.z))
		check(outside.MAP_RECT.encloses(footprint), "all buildings remain inside fence footprint")
		for road in outside.ROAD_RECTS:
			check(not footprint.intersects(road), "building leaves future road corridor clear")
	check(outside.get_node("ApartmentBrickFront").material_override == outside.get_node("ApartmentUpper").material_override, "lower exterior shares upper-floor brick material")
	# Both side roads must connect through front/rear junctions to the border.
	for x in [-12.0,51.0]:
		game.fp_player.position = Vector3(x,0.08,-30)
		check(game.fp_player.move_and_collide(Vector3(0,0,67)) == null, "side-road corridor stays clear through intersections")
	# Ground support at outer building lots and all four expansion approaches.
	for point in [Vector3(-24,0.05,-8),Vector3(65,0.05,28),Vector3(0,0.05,-28),Vector3(20,0.05,35),Vector3(-30,0.05,17),Vector3(70,0.05,17)]:
		var floor_query := PhysicsRayQueryParameters3D.create(point,point-Vector3.UP,1)
		check(not game.get_world_3d().direct_space_state.intersect_ray(floor_query).is_empty(), "outer lots and road ends have physical ground")
	var paths_clear := true
	for child in outside.get_children():
		if child is MeshInstance3D and str(child.name).begins_with("EntrancePath"):
			var path_bounds: AABB = child.global_transform * child.get_aabb()
			var path_rect := Rect2(Vector2(path_bounds.position.x,path_bounds.position.z),Vector2(path_bounds.size.x,path_bounds.size.z))
			for road in outside.ROAD_RECTS: paths_clear = paths_clear and not path_rect.intersects(road)
	check(paths_clear, "entrance paths end at sidewalks without entering roads")
	check(outside.get_node("HouseFloor").mesh.size.is_equal_approx(Vector3(20,0.15,17)), "larger house reserves intended interior footprint")
	for lawn in outside.grass_bounds:
		check((lawn.position.y >= 3.29 and lawn.end.y <= 8.11) or lawn == Rect2(118,-14,16,20), "grass stays in house yard or east park")
	check(not outside.swing_blocked(Vector3(0,0,5)) and not outside.swing_blocked(Vector3(0,0,7)) and outside.swing_blocked(Vector3(0,0,6)), "away swing permits both approaches and protects doorway")
	check(outside.visible and outside.position.is_equal_approx(Vector3.ZERO), "neighborhood adjoins real apartment")
	game.fp_player.position = Vector3(0, 0.08, 4.5)
	var closed_hit: KinematicCollision3D = game.fp_player.move_and_collide(Vector3(0, 0, 2.4))
	check(closed_hit != null and game.fp_player.position.z < 5.84, "closed front door blocks player")
	aim(Vector3(0, 0.08, 3.5), Vector3(0, 1.5, 5.84))
	await frames()
	game._use_target()
	await create_timer(0.5).timeout
	# Door animation runs on physics ticks; a wall-clock timer may finish
	# before enough ticks have elapsed during asset loading on a busy runner.
	for door_frame in range(60):
		if not outside.transitioning:break
		await physics_frame
	check(outside.door_open, "E opens hinged front door from inside")
	game.fp_player.position = Vector3(0, 0.08, 4.5)
	var passage_hit: KinematicCollision3D = game.fp_player.move_and_collide(Vector3(0, 0, 3.8))
	check(passage_hit == null and game.fp_player.position.z > 8.0, "open doorway permits continuous walk outside")
	await frames()
	check(game.current_room == "neighborhood" and game.camera.environment == outside.outdoor_environment, "walking outside sets exterior state without camera teleport")
	aim(Vector3(0, 0.08, 8.3), Vector3(0, 1.5, 5.84))
	await frames()
	game._use_target()
	await create_timer(0.5).timeout
	check(not outside.door_open, "E closes front door from outside")
	game.fp_player.position = Vector3(0, 0.08, 7.0)
	var return_hit: KinematicCollision3D = game.fp_player.move_and_collide(Vector3(0, 0, -2.0))
	check(return_hit != null and game.fp_player.position.z > 5.84, "closed door also blocks return")
	aim(Vector3(0, 0.08, 8.3), Vector3(0, 1.5, 5.84))
	await frames()
	game._use_target()
	await create_timer(0.5).timeout
	game.fp_player.position = Vector3(0, 0.08, 7)
	var entry_hit: KinematicCollision3D = game.fp_player.move_and_collide(Vector3(0, 0, -3.5))
	check(entry_hit == null and game.fp_player.position.z < 4, "open front door permits walking back inside")
	game.fp_player.position = Vector3(0, 0.08, 5)
	outside.toggle_door()
	await create_timer(.6).timeout
	check(not outside.door_open,"Closing permits player in swept arc")
	# Cross both curbs using the actual capsule, rather than a camera-only walk.
	game.fp_player.position = Vector3(5, 0.08, 9)
	var street_hit: KinematicCollision3D = game.fp_player.move_and_collide(Vector3(0, 0, 14))
	check(street_hit == null and game.fp_player.position.z > 22, "sidewalk and street are continuously walkable")
	# Seam audit: every low exterior surface is visual-only. One flat physics
	# floor owns walking support, so visual road/sidewalk/parking/curb height
	# differences cannot create capsule-snaring lips anywhere on the map.
	var ground:=game.get_node_or_null("PrototypeNeighborhoodGround") as StaticBody3D
	check(ground!=null, "one continuous neighborhood collision floor is installed")
	var ground_shape:CollisionShape3D=ground.get_child(0) if ground!=null and ground.get_child_count()>0 else null
	var ground_box:BoxShape3D=ground_shape.shape if ground_shape!=null and ground_shape.shape is BoxShape3D else null
	check(ground_box!=null and is_equal_approx(ground_box.size.x,outside.MAP_RECT.size.x) and is_equal_approx(ground_box.size.z,outside.MAP_RECT.size.y), "continuous floor covers the full playable map")
	var visual_ground_count:=0
	var visual_ground_has_collision:=false
	for node in outside.find_children("*","MeshInstance3D",true,false):
		if node.get_meta("exterior_ground_visual",false):
			visual_ground_count+=1
			visual_ground_has_collision=visual_ground_has_collision or node.has_node("PrototypeCollision")
	check(visual_ground_count>40, "whole-map audit finds all road sidewalk parking curb lawn and paint meshes")
	check(not visual_ground_has_collision, "no exterior ground visual owns a separate collision lip")
	game.fp_player.position = Vector3(51,0.08,37)
	var boundary_hit: KinematicCollision3D = game.fp_player.move_and_collide(Vector3(0, 0, 5))
	check(boundary_hit != null and game.fp_player.position.z < 39.1, "far fence contains player")
	game.fp_player.position = Vector3(-31, 0.08, 16)
	check(game.fp_player.move_and_collide(Vector3(-3, 0, 0)) != null, "side barrier contains player")
	aim(Vector3(40, 0.08, 10.2), Vector3(40, 1.4, 8.3))
	await frames()
	game.property_offer_unlocked = false
	game._use_target()
	check("not available" in game.status_label.text, "house preview respects locked story state")
	game.property_offer_unlocked = true
	game._use_target()
	check(outside.property_opportunity.is_open(), "house preview opens unlocked property details")
	outside.property_opportunity.end_tour()
	game.property_offer_unlocked = false
	var gated_door = outside.get_node("HouseEntrance")
	gated_door.toggle(Vector3(35,0.08,4.8))
	check(not gated_door.busy and not gated_door.opened, "house entry retains Chapter 4 gate")
	gated_door.toggle(Vector3(35,0.08,0))
	await create_timer(0.5).timeout
	check(gated_door.opened, "older save inside locked house can still exit")
	gated_door.toggle(Vector3(35,0.08,0))
	await create_timer(0.5).timeout
	game.property_offer_unlocked = true
	outside.property_opportunity.touring = true
	# Real player capsule tests through both entries, every room, and shop aisles.
	for spec in [["ShopEntrance",Vector3(20.55,0.08,7.8),Vector3(0,0,-3.2)], ["HouseEntrance",Vector3(35,0.08,4.8),Vector3(0,0,-3.2)]]:
		var door = outside.get_node(spec[0])
		game.fp_player.position = spec[1]
		check(game.fp_player.move_and_collide(spec[2]) != null, spec[0]+" closed leaf blocks entry")
		aim(spec[1],spec[1]+spec[2]+Vector3.UP*1.4)
		await frames()
		game._use_target()
		await create_timer(0.5).timeout
		check(door.opened, spec[0]+" opens with E")
		game.fp_player.position = spec[1]
		check(game.fp_player.move_and_collide(spec[2]) == null, spec[0]+" open aperture permits walking in")
		check(game.fp_player.move_and_collide(-spec[2]) == null, spec[0]+" open aperture permits walking out")
		door.toggle(spec[1])
		await create_timer(0.5).timeout
		check(not door.opened, spec[0]+" closes again")
	for door_name in ["BathroomDoor","BedroomDoor","StockroomDoor"]:
		outside.get_node(door_name).toggle(Vector3(0,0,20))
		await create_timer(0.45).timeout
	for route in [
		[Vector3(35,0.08,1),Vector3(35,0.08,-6)],
		[Vector3(35,0.08,0),Vector3(32,0.08,0)],
		[Vector3(35,0.08,0),Vector3(38,0.08,0)],
		[Vector3(28.75,0.08,-6),Vector3(28.75,0.08,-7.5)],
		[Vector3(28.75,0.08,-7.5),Vector3(26.5,0.08,-7.5)],
		[Vector3(26.5,0.08,-7.5),Vector3(26.5,0.08,-11.8)],
		[Vector3(32.65,0.08,-6),Vector3(32.65,0.08,-8.4)],
		[Vector3(36.5,0.08,-6),Vector3(36.5,0.08,-8.5)],
		[Vector3(41.1,0.08,-6),Vector3(41.1,0.08,-10.5)],
		[Vector3(20.5,0.08,4.8),Vector3(20.5,0.08,0.3)],
		[Vector3(17.7,0.08,4.5),Vector3(17.7,0.08,0.3)],
		[Vector3(14.3,0.08,2.0),Vector3(14.3,0.08,0.0)]]:
		game.fp_player.position = route[0]
		check(game.fp_player.move_and_collide(route[1]-route[0]) == null,"room circulation clear: "+str(route[1]))
	for route in [[Vector3(17,0.08,7),Vector3(0,0,-2)],[Vector3(29.2,0.08,4),Vector3(0,0,-2)]]:
		game.fp_player.position = route[0]
		check(game.fp_player.move_and_collide(route[1]) != null,"transparent display glazing blocks walking through")
	game.property_offer_unlocked = false
	aim(Vector3(0, 0.08, 3.5), Vector3(0, 1.5, 5.84))
	await frames()
	var inspect := InputEventKey.new()
	inspect.keycode = KEY_R
	inspect.pressed = true
	game._input(inspect)
	check(game._any_modal_open(), "R preserves front-door visitor interaction")
	game._close_active_panel()
	await frames()
