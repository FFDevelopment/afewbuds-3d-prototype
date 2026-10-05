extends SceneTree
var game: Node3D

func _initialize() -> void:
	call_deferred("run")

func capture(filename: String) -> void:
	for i in range(8):
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
	await capture("04-phone.png")
	game._toggle_phone()
	game.dealer_locker_level = 1
	game.products["Purple Dream"]["stock"] = 10
	game._open_dealer_storage_panel()
	await capture("05-dealer-storage.png")
	quit()
