extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1;push_error(message)
func run() -> void:
	var game: Node3D=load("res://prototype/apartment.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.session_paused=false
	game.tutorial_active=false
	game.daily_report_pending=false
	game.customer_waiting=false
	for name in ["tutorial_panel","daily_report_panel","pause_overlay","sale_panel","grow_panel","plant_direct_panel","bagging_panel","storage_panel","dealer_storage_panel","supply_inventory_panel","system_control_panel","trim_panel","bag_minigame_panel","peephole_panel"]:
		var panel=game.get(name)
		if panel!=null:panel.hide()
	game.visit_timer.stop()
	var n: Node3D=game.neighborhood
	game.set_process(false)
	game.fp_player.set_physics_process(false)
	n.set_process(false)
	n.active=true
	game.property_opportunity_state={}
	game.fp_player.position=Vector3(35,0.08,4.8)
	await physics_frame
	var opportunity: RefCounted=n.property_opportunity
	game.property_offer_unlocked=false
	opportunity.show_details()
	check(not opportunity.is_open(),"House details remain locked before Rod's offer")
	game.property_offer_unlocked=true
	game.camera.position=Vector3(35,1.98,4.8)
	game.camera.look_at(Vector3(35,1.3,3))
	var cash: float=game.cash
	var equipment: int=game.grow_tent_count
	game._use_target()
	check(opportunity.is_open() and game._any_modal_open(),"House entrance opens modal property details")
	check(not n.get_node("HouseEntrance").opened,"Viewing details does not open the house")
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE and not game.fp_player.enabled,"Details release cursor and stop player")
	opportunity.begin_tour()
	await create_timer(0.5).timeout
	check(opportunity.touring and not opportunity.is_open() and n.get_node("HouseEntrance").opened,"Tour opens real door without teleport")
	check(game.camera.position.distance_to(Vector3(35,1.98,4.8))<0.01,"Tour keeps player position")
	check(not game._any_modal_open(),"Tour releases modal movement lock")
	for point in [Vector3(30,1.64,0),Vector3(27,1.64,-9),Vector3(40,1.64,-10),Vector3(40,1.64,0),Vector3(32,1.64,-9),Vector3(36,1.64,-9)]:
		game.camera.position=point
		for i in range(21):opportunity.update(0.1)
	check(opportunity.visited().size()==6 and bool(game.property_opportunity_state.get("inspection_complete",false)),"Six room inspection complete")
	opportunity.end_tour()
	game._save_game()
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_PATH))
	check(data.property_opportunity_state.rooms.size()==6,"Tour progress saved with career")
	game.property_opportunity_state={}
	game._load_game()
	check(opportunity.visited().size()==6,"Tour progress restored")
	check(game.cash==cash and game.grow_tent_count==equipment,"Tour does not charge cash or award equipment")
	game.property_opportunity_state={"rooms":["living","bad", "living"]}
	check(opportunity.visited()==["living"],"Old/corrupt room IDs sanitized")
	game.property_opportunity_state={}
	opportunity.touring=true
	game.session_paused=true
	game.camera.position=Vector3(30,1.64,0)
	for i in range(30):opportunity.update(0.1)
	check(opportunity.visited().is_empty(),"Paused game does not advance inspection")
	game.session_paused=false
	opportunity.end_tour()
	game.session_paused=false
	opportunity.touring=true
	var key := InputEventKey.new()
	key.keycode=KEY_T
	key.pressed=true
	game._input(key)
	check(opportunity.is_open(),"T reviews touring property")
	key.keycode=KEY_ESCAPE
	game._input(key)
	check(not opportunity.is_open() and not opportunity.touring,"Escape closes details and ends tour")
	var trunk: MeshInstance3D=n.get_node("TreeTrunk")
	var soil: MeshInstance3D=n.get_node("TreeBed")
	check(trunk.material_override!=soil.material_override and trunk.material_override.shader.resource_path.ends_with("bark.gdshader"),"Tree trunks use bark independent of gravel")
	game.queue_free()
	await process_frame
	print("PROPERTY_TEST_RESULT: PASS" if failures==0 else "PROPERTY_TEST_RESULT: FAIL")
	quit(1 if failures else 0)
