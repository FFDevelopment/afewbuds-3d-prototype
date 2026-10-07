extends SceneTree
var failures:Array[String]=[]
var game:Node3D
var station:Node3D
func _initialize() -> void:call_deferred("run")
func check(ok:bool,text:String) -> void:
	if ok:print("PASS: ",text)
	else:failures.append(text);push_error("FAIL: "+text)
func frames(n:int=3) -> void:
	for i in n:await physics_frame
func run() -> void:
	if not "QA" in OS.get_user_data_dir():quit(1);return
	var cloud=root.get_node("AFBCloud");cloud.session={};cloud.launched=false
	if FileAccess.file_exists(cloud.ACTIVE):DirAccess.remove_absolute(ProjectSettings.globalize_path(cloud.ACTIVE))
	game=load("res://prototype/apartment.tscn").instantiate();root.add_child(game);await frames(8)
	station=game.neighborhood.police_station
	check(station.doors.size()==14 and station.rooms.size()==15,"Two-floor station has 14 working doors and 15 rooms")
	game.inventory_system.guide.skip()
	game._resume_gameplay();game.fp_player.enabled=false
	var player:CharacterBody3D=game.fp_player
	player.position=Vector3(135,.1,17)
	check(player.move_and_collide(Vector3(60,0,0))==null,"Native capsule crosses old east fence into police district")
	player.position=Vector3(199,.1,17)
	check(player.move_and_collide(Vector3(5,0,0))!=null,"New east fence contains player")
	for route in [[Vector3(132.5,.1,-1.6),Vector3(4.5,0,0)],[Vector3(188.5,.1,-12),Vector3(0,0,28)],[Vector3(161.5,.1,-30),Vector3(0,0,11)]]:
		player.position=route[0]
		check(player.move_and_collide(route[1])==null,"Native capsule passes repaired park exit or driveway "+str(route[0]))
	var panes_fit:=true
	for window in station.windows:panes_fit=panes_fit and window.aperture.encloses(window.bounds)
	check(panes_fit,"Window panes stay inside masonry apertures")
	var frames_clear:=true
	for part in station.parts:
		if part.id in ["WindowJamb","WindowRail","WindowMullion"]:
			for wall in station.wall_bounds:
				frames_clear=frames_clear and not part.bounds.intersects(wall)
	check(frames_clear,"Window frames clear adjacent walls")
	var upstairs_decks:Array[AABB]=[]
	for part in station.parts:
		if str(part.id) in ["UpperFloorWest","UpperFloorNorth","UpperFloorSouth"]:upstairs_decks.append(part.bounds)
	var stair_clips:Array[String]=[]
	var stair_nosings:=0
	for part in station.parts:
		var part_id:=str(part.id)
		if part_id=="StairNosing" and int(part.floor)==0:stair_nosings+=1
		if int(part.floor)==0 and (part_id.begins_with("Stair") or part_id=="ContinuousHandrail" or part_id=="RailWallBracket"):
			for deck in upstairs_decks:
				var overlap_x:float=minf(part.bounds.end.x,deck.end.x)-maxf(part.bounds.position.x,deck.position.x)
				var overlap_y:float=minf(part.bounds.end.y,deck.end.y)-maxf(part.bounds.position.y,deck.position.y)
				var overlap_z:float=minf(part.bounds.end.z,deck.end.z)-maxf(part.bounds.position.z,deck.position.z)
				if overlap_x>.005 and overlap_y>.005 and overlap_z>.005:stair_clips.append(part_id)
	check(stair_clips.is_empty(),"Stairwell walls and stairs do not clip through upstairs deck")
	for wall_id in ["Front","Rear","West","East"]:
		var wall_top:float=-INF
		for part in station.parts:
			if int(part.floor)==0 and str(part.id)==wall_id:wall_top=maxf(wall_top,part.bounds.end.y)
		check(absf(wall_top-station.STORY)<.01,"Downstairs "+wall_id+" wall closes to upstairs floor line")

	var door_trim_clips:Array[String]=[]
	for part in station.parts:
		var trim_id:=str(part.id)
		if trim_id not in ["DoorJamb","DoorHeader"]:continue
		for wall in station.wall_bounds:
			var ox:float=minf(part.bounds.end.x,wall.end.x)-maxf(part.bounds.position.x,wall.position.x)
			var oy:float=minf(part.bounds.end.y,wall.end.y)-maxf(part.bounds.position.y,wall.position.y)
			var oz:float=minf(part.bounds.end.z,wall.end.z)-maxf(part.bounds.position.z,wall.position.z)
			if ox>.003 and oy>.003 and oz>.003:door_trim_clips.append(trim_id)
	check(door_trim_clips.is_empty(),"Door jamb/header trim stays inside masonry openings")

	var side_width_mismatches:Array[String]=[]
	for door in station.doors:
		if bool(door.get_meta("side_door",false)):
			var expected_width:float=float(door.get_meta("plan_width",0.0))*.8
			if absf(float(door.width)-expected_width)>.001:side_width_mismatches.append(str(door.name))
	check(side_width_mismatches.is_empty(),"Side-door leaves fit scaled wall apertures")

	var buried_trim:Array[String]=[]
	for part in station.parts:
		if str(part.id).ends_with("Skirting") and minf(part.bounds.size.x,part.bounds.size.z)>.04:buried_trim.append(str(part.id))
	check(buried_trim.is_empty(),"Wall-base trim is surface-mounted and not buried in masonry")
	check(stair_nosings==19,"Top stair nosing stops at the upstairs landing edge")
	player.position=station.point(11.2,.1,30)
	game.camera.position=player.position+Vector3.UP*2.16;game.camera.look_at(station.point(11.2,1.6,28));await frames()
	game._use_target();await create_timer(.5).timeout
	check(station.get_node("PUBLIC_ENTRANCE").opened,"Native raycast interaction opens police entrance")
	for door in station.doors:
		if not door.opened:door.toggle(station.point(12,2.16,15))
	await create_timer(.5).timeout
	player.position=station.point(11.2,.1,30)
	check(player.move_and_collide(Vector3(0,0,-3.0))==null,"Open station entry permits physical capsule")
	# Use the actual CharacterBody slope solver along the entire staircase.
	player.position=station.point(21.5,.08,21);player.velocity=Vector3.ZERO
	game.set_process(false);player.enabled=true;player.yaw=0
	for action in ["fp_forward","fp_backward"]:
		Input.action_press(action)
		for i in range(200):await physics_frame
		Input.action_release(action)
		print("STAIR_END ",action," ",player.position)
		check(absf(player.position.y-(3.6 if action=="fp_forward" else 0))<.22,"Physical stair ascent/descent reaches correct floor "+action)
	player.enabled=false;player.set_physics_process(false)
	# Every room has physical standing clearance and a blocked external wall.
	for spec in [[7,0,5],[7,0,12],[20,0,4.5],[20,0,10.5],[20.3,0,26.5],[12,0,18.8],[7,3.6,9],[15,3.6,9.5],[23,3.6,5.3],[20,3.6,9.5],[6.5,3.6,25],[11,3.6,18],[15,3.6,14]]:
		player.position=station.point(spec[0],spec[1]+.08,spec[2])
		check(player.move_and_collide(Vector3(0,-.5,0))!=null,"Room has physical floor "+str(spec))
	player.position=station.point(.6,3.68,25)
	check(player.move_and_collide(Vector3(-2,0,0))!=null,"Upper window prevents falling through wall")
	game._resume_gameplay()
	var seats=game.neighborhood.bench_seating
	check(seats.benches.size()==3,"Existing park retains three usable benches")
	for i in seats.benches.size():
		var b:Dictionary=seats.benches[i]
		player.position=b.at+Basis(Vector3.UP,b.facing)*Vector3(0,.08,-1.1);player.sync_camera()
		print("SEAT_READY ",game._any_modal_open()," ",game.neighborhood.transitioning," ",seats.target()," ",game.camera.position)
		var before:=player.position;seats.use("bench_"+str(i))
		check(seats.seated==i and absf(game.camera.position.y-1.5626)<.01,"Bench uses shared rig seated eyes "+str(i))
		check(seats.stand() and player.position.distance_to(before)<.1,"Bench restores safe standing position "+str(i))
	if "--capture-police" in OS.get_cmdline_user_args():
		game._resume_gameplay();game.phone_panel.hide();game.phone_open=false
		for spec in [["front",Vector3(160,0,11),Vector3(160,3.5,0)],["lobby",station.point(11,0,26),station.point(12,1.4,23)],["stairs",station.point(21.5,0,21),station.point(21.5,3.6,13.5)],["upper",station.point(16,3.6,16),station.point(12,4.6,22)]]:
			player.position=spec[1];game.camera.position=spec[1]+Vector3.UP*2.16;game.camera.look_at(spec[2]);player.yaw=game.camera.rotation.y;player.pitch=game.camera.rotation.x;await frames(4)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/afb-desktop/police-"+spec[0]+".png")
	for audio in game.find_children("*","AudioStreamPlayer",true,false):audio.stop();audio.stream=null
	await create_timer(.15).timeout;game.queue_free();await frames()
	print("POLICE_TEST_RESULT: ","PASS" if failures.is_empty() else str(failures));quit(0 if failures.is_empty() else 1)
