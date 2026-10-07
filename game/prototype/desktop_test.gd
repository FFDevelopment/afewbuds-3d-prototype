extends SceneTree
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool, description: String) -> void:
	if ok:print("PASS: ",description)
	else:failures.append(description);push_error("FAIL: "+description)
func frames(n: int=5) -> void:
	for i in n:await process_frame
func run() -> void:
	if not "QA" in OS.get_user_data_dir():quit(1);return
	var controls=root.get_node("DesktopInput")
	var cloud=root.get_node("AFBCloud")
	cloud.session={};cloud.launched=false
	if FileAccess.file_exists(cloud.ACTIVE):DirAccess.remove_absolute(ProjectSettings.globalize_path(cloud.ACTIVE))
	var game=load("res://prototype/apartment.tscn").instantiate()
	root.add_child(game)
	await frames(12)
	game.inventory_system.guide.skip();game._pause_gameplay()

	var districts=load("res://scripts/districts.gd")
	for sample in [[Vector3(0,0,0),"Roachwood"],[Vector3(40,0,0),"Roachwood"],[Vector3(72.99,0,0),"Roachwood"],[Vector3(73,0,0),"Half Baked Heights"],[Vector3(138.99,0,0),"Half Baked Heights"],[Vector3(139,0,0),"Paranoia Point"],[Vector3(175,6,0),"Paranoia Point"]]:
		check(districts.heading(sample[0])=="Bongchester / "+sample[1],"District at "+str(sample[0]))
	var original_position:Vector3=game.fp_player.position
	for x in [10.0,90.0,170.0,10.0]:
		game.fp_player.position=Vector3(x,0,10)
		game._process(0.0)
		check(game.fp_info.text.begins_with(districts.heading(game.fp_player.position)+"\n"),"Desktop HUD follows district crossing in either direction")
	game.fp_player.position=original_position
	game.status_label.text="Gameplay message"
	cloud.set_status("Saving to AFewBuds cloud…")
	cloud.set_status("Cloud saved — QA")
	check(game.status_label.text=="Gameplay message" and cloud.last_status=="Cloud saved — QA","Background sync stays recorded without replacing gameplay text")
	cloud.set_status("Cloud unavailable",true)
	check(game.status_label.text=="Cloud unavailable","Sync failures remain visible")
	cloud.set_status("Cloud saved — QA")
	check(game.status_label.text.is_empty(),"Recovered sync clears its old warning")
	controls.show_settings()
	await frames()
	check(is_instance_valid(controls.settings) and game.session_paused,"Settings preserve simulation pause")
	var event:=InputEventKey.new();event.physical_keycode=KEY_F;event.pressed=true
	controls.bindings.interact=KEY_F;controls.install_actions()
	check(controls.pressed(event,"interact"),"Rebound interact accepts new physical key")
	event.physical_keycode=KEY_E
	check(not controls.pressed(event,"interact"),"Rebound interact releases old key")
	controls.mouse_sensitivity=2;controls.save_preferences()
	var saved:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(controls.PATH))
	check(saved.bindings.interact==KEY_F and saved.mouse==2 and not cloud.baseline.has("bindings"),"Device controls persist separately from career")
	controls.close_settings()
	# Controller confirms the focused UI control without moving/clicking a pointer.
	var target:=Button.new();target.text="Focus fixture";target.focus_mode=Control.FOCUS_ALL;game.pause_overlay.add_child(target)
	var clicks:=[0];target.pressed.connect(func():clicks[0]+=1);target.grab_focus()
	var mouse_before:Vector2=root.get_mouse_position()
	var click:=InputEventJoypadButton.new();click.button_index=JOY_BUTTON_A;click.pressed=true
	controls._input(click);await frames(2)
	click.pressed=false;controls._input(click);await frames(2)
	check(clicks[0]==1 and root.get_mouse_position()==mouse_before,"Controller selects the focused button once without moving the mouse")
	target.queue_free()
	controls.bindings=controls.DEFAULTS.duplicate();controls.install_actions();controls.mouse_sensitivity=1
	game._resume_gameplay()
	check(game.fp_player.has_method("drive") and game.fp_player.has_method("stop"),"Desktop player exposes shared drive/stop controller API")
	check(is_equal_approx(game.fp_player.WALK_SPEED,3.4) and is_equal_approx(game.fp_player.SPRINT_SPEED,5.4) and is_equal_approx(game.fp_player.ACCELERATION,15.0) and is_equal_approx(game.fp_player.DECELERATION,20.0),"Desktop movement and sprint tuning matches mobile 3D core")
	check(is_equal_approx(game.fp_player.STAMINA_MAX,100.0) and is_equal_approx(game.fp_player.STAMINA_DRAIN,18.0) and is_equal_approx(game.fp_player.STAMINA_RECOVERY,14.0) and is_equal_approx(game.fp_player.STAMINA_REENABLE,25.0),"Desktop stamina tuning matches mobile 3D core")
	check(InputMap.has_action("fp_sprint"),"Desktop sprint input action remains installed")
	var capsule:CapsuleShape3D=game.fp_player.get_node("PlayerCapsule").shape
	check(is_equal_approx(capsule.radius,.26) and is_equal_approx(capsule.height,2.43) and is_equal_approx(game.fp_player.floor_snap_length,.32),"Desktop capsule and floor snap match mobile 3D core")
	check(game.fp_stamina_bar is ProgressBar and not game.fp_stamina_bar.visible,"Desktop stamina HUD starts unobtrusive at full stamina")
	game.fp_player.stamina=55
	game.fp_player.is_sprinting=true
	game._update_fp_stamina_hud()
	check(game.fp_stamina_bar.visible and game.fp_stamina_bar.value==55 and game.fp_stamina_label.text=="SPRINTING","Desktop stamina HUD reflects sprint state")
	game.fp_player.is_sprinting=false
	game.fp_player.exhausted=true
	game._update_fp_stamina_hud()
	check(game.fp_stamina_label.text=="EXHAUSTED","Desktop stamina HUD exposes exhaustion state")
	game.fp_player.exhausted=false
	game.fp_player.stamina=game.fp_player.STAMINA_MAX
	game._update_fp_stamina_hud()
	game.fp_player.enabled=true
	game.fp_player.wants_sprint=true
	game.fp_player._update_stamina(1.0,true,true)
	check(is_equal_approx(game.fp_player.stamina,82.0) and game.fp_player.is_sprinting,"Forward sprint drains 18 stamina per second")
	game.fp_player._update_stamina(5.0,true,true)
	check(game.fp_player.stamina==0.0 and game.fp_player.exhausted and not game.fp_player.is_sprinting,"Exhaustion stops sprint at zero stamina")
	game.fp_player._update_stamina(0.5,true,true)
	check(game.fp_player.stamina==0.0,"Recovery waits through its initial delay")
	game.fp_player._update_stamina(0.25,true,true)
	game.fp_player._update_stamina(1.0,true,true)
	check(game.fp_player.stamina<25.0 and game.fp_player.exhausted and not game.fp_player.is_sprinting,"Holding sprint cannot bypass exhaustion below 25 stamina")
	game.fp_player._update_stamina(1.0,true,true)
	game.fp_player._update_stamina(0.1,true,true)
	check(game.fp_player.is_sprinting and not game.fp_player.exhausted,"Sprint becomes available again after recovery threshold")
	game.fp_player._update_stamina(0.1,false,true)
	check(not game.fp_player.is_sprinting,"Sideways or backward movement cannot sprint")
	game.fp_player.wants_sprint=false
	game.fp_player.exhausted=false
	game.fp_player.stamina=game.fp_player.STAMINA_MAX
	game.fp_player.recovery_delay_left=0.0
	var yaw:float=game.fp_player.yaw
	game.fp_player.look(Vector2(10,0))
	var first:float=absf(game.fp_player.yaw-yaw)
	controls.mouse_sensitivity=2;yaw=game.fp_player.yaw;game.fp_player.look(Vector2(10,0))
	check(is_equal_approx(absf(game.fp_player.yaw-yaw),first*2),"Camera sensitivity changes actual rotation")
	controls.mouse_sensitivity=1
	var joy:=InputEventJoypadButton.new();joy.button_index=JOY_BUTTON_DPAD_UP;joy.pressed=true
	game._input(joy);await frames()
	check(game.phone_open and not game.fp_player.enabled,"Controller phone action opens modal and stops movement")
	for dimensions in [Vector2i(1280,720),Vector2i(1280,800),Vector2i(1920,1080),Vector2i(2560,1080)]:
		root.size=dimensions;await frames()
		for app in ["home","advancements","settings","products","shop","contacts"]:
			game._open_phone_app(app);await frames()
			var rect:Rect2=game.phone_panel.get_global_rect()
			check(rect.size.y>rect.size.x*1.5,"Portrait aspect at %s in %s" % [dimensions,app])
			check(rect.position.x>=0 and rect.end.x<=root.get_visible_rect().size.x and rect.end.y<=root.get_visible_rect().size.y,"Phone fits %s in %s" % [dimensions,app])
			if "--capture-desktop" in OS.get_cmdline_user_args() and app=="home":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("/tmp/afb-desktop/phone-%dx%d.png" % [dimensions.x,dimensions.y])
		if DisplayServer.get_name()!="headless":
			for spot in [Vector2(.5,.5),Vector2(.12,.25),Vector2(.88,.75)]:
				game._open_phone_app("home");await frames()
				var tile:Control=game.phone_list.get_child(1).get_child(1)
				var point:Vector2=tile.get_global_rect().position+tile.size*spot
				root.warp_mouse(point);await frames(2)
				click.pressed=true;controls._input(click);await frames(2)
				click.pressed=false;controls._input(click);await frames(2)
				check(game.phone_current_app=="shop","A selects visible category at %s / %s" % [dimensions,spot])
	controls.show_settings();await frames()
	if "--capture-desktop" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/afb-desktop/settings.png")
	controls.close_settings()
	game.queue_free();await frames(4)
	print("DESKTOP_TEST_RESULT: ","PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
