extends SceneTree
var game: Node3D

func _initialize() -> void:
	call_deferred("run")

func capture(filename: String) -> void:
	for i in range(8):
		if is_instance_valid(game) and filename != "00-instructions.png":
			game.session_paused=false
			game.pause_overlay.hide()
		await process_frame
	await RenderingServer.frame_post_draw
	var args := OS.get_cmdline_user_args()
	var output := args[0] if not args.is_empty() else OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(output)
	root.get_texture().get_image().save_png(output.path_join(filename))

func aim(pos: Vector3, target: Vector3) -> void:
	game.fp_player.position = pos
	game.fp_player.velocity = Vector3.ZERO
	game.camera.global_position = pos + Vector3.UP * game.fp_player.EYE_HEIGHT
	game.camera.look_at(target)
	game.fp_player.yaw = game.camera.rotation.y
	game.fp_player.pitch = game.camera.rotation.x

func run() -> void:
	var login = load("res://account/login.tscn").instantiate()
	root.add_child(login)
	await capture("00-account-entry.png")
	login.toggle_mode()
	await capture("00-registration.png")
	login.set_recovery_mode(true)
	login.recovery_identifier.text = "full.recovery.address.longer.than.twenty@example.com"
	await capture("00-password-recovery.png")
	login.queue_free()
	await process_frame
	await root.get_node("AFBCloud").prepare(true)
	game = load("res://prototype/apartment.tscn").instantiate()
	root.add_child(game)
	await capture("00-instructions.png")
	game._resume_gameplay()
	aim(Vector3(-1.7, 0.08, 3.5), Vector3(2.0, 1.4, -1.3))
	await capture("01-apartment.png")
	aim(Vector3(0, 0.08, -6.7), Vector3(0, 1.25, -9.1))
	await capture("02-grow-room.png")
	game._open_bagging_panel()
	await capture("03-packaging.png")
	game._close_bagging_panel()
	game._toggle_phone()
	game.customer_waiting = true
	game.customer_answered = false
	game._refresh_door_alert()
	await capture("04-phone.png")
	game._toggle_phone()
	game.dealer_locker_level = 1
	game.products["Purple Dream"]["stock"] = 10
	game._open_dealer_storage_panel()
	await capture("05-dealer-storage.png")
	game._close_dealer_storage_panel()
	game.bagging_level = 3
	game.dealer_locker_level = 3
	game._apply_visual_upgrades()
	game._sync_dealer_locker_visual()
	aim(Vector3(0.7, 0.08, 1.4), Vector3(4.3, 1.5, -0.7))
	await capture("06-upgraded-furniture.png")
	game._set_premium_dealer_locker_open(true)
	await create_timer(0.4).timeout
	aim(Vector3(2.0, 0.08, -1.8), Vector3(4.4, 1.5, -2.2))
	await capture("07-premium-locker.png")

	game.customer_waiting = false
	game._refresh_door_alert()
	aim(Vector3(0, 0.08, 3.5), Vector3(0, 1.7, 8))
	await capture("08-door-closed.png")
	game.neighborhood.toggle_door()
	await create_timer(0.5).timeout
	await capture("09-door-open.png")
	aim(Vector3(0, 0.08, 9), Vector3(0, 1.8, 5.84))
	await capture("10-outside-return.png")
	game.neighborhood.toggle_door()
	await create_timer(0.5).timeout
	await capture("11-outside-closed.png")
	aim(Vector3(4, 0.08, 14), Vector3(35, 1.8, 3))
	await capture("12-neighborhood.png")
	game._toggle_phone()
	game._open_phone_app("advancements")
	await capture("13-advancements.png")
	game._open_phone_app("bills")
	await capture("14-water-bill.png")
	game._toggle_phone()
	aim(Vector3(35,0.08,10),Vector3(35,2.4,2))
	await capture("16-house-yard.png")
	aim(Vector3(3,0.08,15),Vector3(0,4.0,6))
	await capture("17-apartment-brick.png")
	aim(Vector3(3,0.08,23),Vector3(0,1.8,27))
	await capture("18-opposite-entrances.png")
	aim(Vector3(-12,0.08,5),Vector3(-24,1.8,-5))
	await capture("19-side-entrances.png")

	for door_name in ["ShopEntrance", "HouseEntrance", "StockroomDoor", "BathroomDoor", "BedroomDoor"]:
		game.neighborhood.get_node(door_name).toggle(Vector3(0,0,20))
		await create_timer(0.45).timeout
	aim(Vector3(20.5,0.08,4.6),Vector3(15.5,1.3,0.0))
	await capture("20-shop-interior.png")
	aim(Vector3(17.5,0.08,0.2),Vector3(19,1.5,7))
	await capture("21-shop-window-out.png")
	aim(Vector3(14.2,0.08,0.4),Vector3(12.8,1.2,-1))
	await capture("22-stockroom.png")
	aim(Vector3(35,0.08,1.7),Vector3(35,1.5,-8))
	await capture("23-house-hall.png")
	aim(Vector3(32.3,0.08,0.5),Vector3(28,1.0,-2))
	await capture("24-living.png")
	aim(Vector3(29,0.08,-7.8),Vector3(28,1.2,-13))
	await capture("25-kitchen.png")
	aim(Vector3(37,0.08,-8),Vector3(36.5,1.2,-12))
	await capture("26-bedroom.png")
	aim(Vector3(40,0.08,-8),Vector3(42,1.4,-12))
	await capture("27-grow-preview.png")
	aim(Vector3(38,0.08,0),Vector3(41,1.2,-4))
	await capture("28-packing-preview.png")
	aim(Vector3(32.7,0.08,-8),Vector3(32.7,1.1,-12))
	await capture("29-bathroom.png")
	aim(Vector3(17,0.08,9),Vector3(17,1.5,2))
	await capture("30-shop-window-in.png")

	game.game_time_minutes = 22*60
	game._update_day_night_visuals()
	aim(Vector3(17,0.08,9),Vector3(17,1.5,2))
	await capture("31-shop-night.png")
	aim(Vector3(30,0.08,0.8),Vector3(29.2,1.5,8))
	await capture("32-house-night-out.png")
	game.game_time_minutes = 12*60
	game._update_day_night_visuals()
	var plan := Camera3D.new()
	game.add_child(plan)
	plan.projection = Camera3D.PROJECTION_ORTHOGONAL
	plan.size = 118
	plan.position = Vector3(20.5,85,3.5)
	plan.rotation_degrees = Vector3(-90,0,0)
	plan.environment = game.neighborhood.outdoor_environment
	plan.make_current()
	game.fp_hud.hide()
	await capture("15-top-down.png")
	# Review-only cutaways of real geometry; gameplay keeps ceilings and roofs.
	game.neighborhood.get_node("HouseCeiling").hide()
	game.neighborhood.get_node("HouseHipRoof").hide()
	plan.size = 23
	plan.position = Vector3(35,45,-5.5)
	await capture("33-house-plan.png")
	game.neighborhood.get_node("ShopCeiling").hide()
	game.neighborhood.get_node("CornerShopRoof").hide()
	plan.size = 12
	plan.position = Vector3(17,35,2)
	await capture("34-shop-plan.png")
	var schedule := FileAccess.open(OS.get_cmdline_user_args()[0].path_join("interior-openings.json"),FileAccess.WRITE)
	schedule.store_string(JSON.stringify(game.neighborhood.get_meta("interior_openings"),"  "))
	quit()
