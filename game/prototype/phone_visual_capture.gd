extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	root.disable_3d=true
	RenderingServer.set_default_clear_color(Color("18231b"))
	var desktop:=ResourceLoader.exists("res://prototype/apartment.tscn")
	var game=load("res://prototype/apartment.tscn" if desktop else "res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in range(20):await process_frame
	game.set_process(false);game.neighborhood.set_process(false)
	game.gameplay_ready=true;game.session_paused=false;game.tutorial_active=false;game.daily_report_pending=false
	game.tutorial_panel.hide();game.pause_overlay.hide();game.daily_report_panel.hide();game.tutorial_phone_coach.hide()
	game.phone_open=true;game.phone_panel.show()
	if not desktop:root.size=Vector2i(720,1280)
	game.status_label.hide()
	var output:=OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(output)
	for app in ["home","realestate","property","system","visitor"]:
		if app=="visitor":
			game._open_phone_app("home");game.customer_waiting=true;game.customer_answered=false;game.customer_departing=false;game._refresh_door_alert()
		elif app=="property":game._phone_open_property_from_business("apartment")
		else:game._open_phone_app(app)
		for i in range(12):await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join(app+".png"))
		if app=="home":
			for icon in game.phone_list.find_children("*","TextureRect",true,false):print("ICON_RECT ",icon.size)
		print("PHONE_CAPTURE ",app," rect=",game.phone_panel.get_global_rect()," minimum=",game.phone_panel.get_combined_minimum_size())
	game.phone_open=false;game.phone_panel.hide();game.inventory_system.set_process(false)
	for i in range(3):await process_frame
	game.queue_free()
	for i in range(3):await process_frame
	quit()
