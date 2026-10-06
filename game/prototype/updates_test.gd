extends SceneTree
var game: Node3D
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
func aim(at: Vector3, inward: Vector3) -> void:
	game.camera.position=at+inward
	game.camera.position.y=1.9
	game.camera.look_at(at)
func ready_game() -> void:
	game=load("res://prototype/apartment.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._resume_gameplay()
	game.set_process(false)
	game.fp_player.set_physics_process(false)
	game.neighborhood.set_process(false)
	game.visit_timer.stop()
	await physics_frame
func run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://afewbuds_3d_prototype_save.json"))
	await ready_game()
	var n: Node3D=game.neighborhood
	var controls: RefCounted=n.house_controls
	check(controls.switches.size()==11,"Eight house rooms, grow service panel, two market circuits")
	check(controls.shades.size()==11,"Ten house shades and apartment blind")
	check(controls.switches.grow_lights.lamps.is_empty(),"No free house grow equipment")
	check(n.find_children("GrowTent*","MeshInstance3D",false,false).is_empty(),"Apartment tents do not populate house")
	var normals := {"living":Vector3.LEFT,"packing":Vector3.RIGHT,"entry_hall":Vector3.FORWARD,"cross_hall":Vector3.FORWARD,"kitchen":Vector3.FORWARD,"bathroom":Vector3.FORWARD,"bedroom":Vector3.FORWARD,"grow":Vector3.FORWARD,"market_stock":Vector3.LEFT,"market_front":Vector3.LEFT}
	for id in normals:
		aim(controls.switches[id].at,normals[id])
		check(controls.nearby()=="switch_"+id,"Reach correct switch: "+id)
		game._use_target()
		check(not controls.switches[id].lamp.visible,"E toggles room light: "+id)
		for extra in controls.switches[id].extra: check(not extra.lamp.visible,"Grouped fixtures toggle together")
		game._use_target()
		check(controls.switches[id].lamp.visible,"E restores room light: "+id)
	for id in controls.shades:
		var spec: Dictionary=controls.shades[id]
		var inward := Vector3.BACK if spec.at.z< -13 else (Vector3.RIGHT if spec.at.x<26 and id!="ApartmentBlind" else (Vector3.LEFT if spec.at.x>44 else Vector3.FORWARD))
		aim(spec.at,inward)
		check(controls.nearby()=="shade_"+id,"Reach inside covering: "+id)
		var before: bool=spec.closed
		game._use_target()
		await create_timer(0.4).timeout
		check(spec.closed!=before,"E operates covering: "+id)
		aim(spec.at,-inward)
		check(controls.nearby().is_empty(),"Cannot operate covering outdoors: "+id)
	# A wall between aim and control must prevent operation.
	aim(controls.switches.living.at,Vector3.RIGHT)
	check(controls.nearby()!="switch_living","Interior partition occludes switch")
	game.house_control_state["house_grow_tent_count"]=0
	game._save_game()
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_PATH))
	check(saved.house_control_state.ApartmentBlind and not saved.house_control_state.GrowSideShade,"Coverings serialize into shared career")
	var sky: RefCounted=n.weather
	game.game_time_minutes=720
	sky.update(0)
	check(sky.daylight>0.99 and sky.sun_direction.y>0.9,"Midday sun and daylight")
	game.game_time_minutes=0
	sky.update(0)
	check(sky.daylight<0.01 and sky.moon.visible,"Night moon and ambient transition")
	check(n.lamps[0].light_energy>0.7,"Street lamps illuminate at night")
	game.game_time_minutes=360
	sky.update(0)
	check(sky.sun_direction.x>0.9,"Sunrise in east")
	game.game_time_minutes=1080
	sky.update(0)
	check(sky.sun_direction.x< -0.9,"Sunset in west")
	game.queue_free()
	await process_frame
	await ready_game()
	controls=game.neighborhood.house_controls
	check(controls.shades.ApartmentBlind.closed and not controls.shades.GrowSideShade.closed,"Scene reload restores covering states")
	print("UPDATES_TEST_RESULT: PASS" if failures==0 else "UPDATES_TEST_RESULT: FAIL")
	quit(1 if failures else 0)
