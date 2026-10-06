extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
func run() -> void:
	var game = load("res://prototype/apartment.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.fp_player.set_physics_process(false)
	var world: Node3D=game.neighborhood
	world.set_process(false)
	game.property_offer_unlocked=true
	for id in ["ShopEntrance","HouseEntrance","StockroomDoor","BathroomDoor","BedroomDoor"]:
		var door: Node3D=world.get_node(id)
		var original_rotation: Vector3=door.rotation
		# Exercise a rotated hinge as well as the authored orientations.
		if id=="BedroomDoor": door.rotation.y=PI/2
		for side in [-1.0,1.0]:
			var approach: Vector3=door.to_global(Vector3(door.width*0.5,0,side*1.4))
			door.toggle(approach)
			door.toggle(approach) # Repeat input while animating must not queue a reversal.
			await create_timer(0.5).timeout
			var angle: float=side*PI/2
			check(door.opened and is_equal_approx(door.get_node("Leaf").rotation.y,angle),id+" opens away from side "+str(side))
			var obstructed: Vector3=door.to_global(Vector3(door.width*0.5,0,-side*0.5))
			door.toggle(obstructed)
			await create_timer(0.5).timeout
			check(door.opened and not door.busy and is_equal_approx(door.get_node("Leaf").rotation.y,angle),id+" closing protects actual sweep without flipping or queuing")
			door.toggle(approach)
			await create_timer(0.5).timeout
			check(not door.opened and is_zero_approx(door.get_node("Leaf").rotation.y),id+" closes on original hinge path")
		door.rotation=original_rotation
	for side in [-1.0,1.0]:
		game.fp_player.position=Vector3(0,0.08,6+side*1.4)
		world.toggle_door()
		await create_timer(0.5).timeout
		var angle: float=side*PI/2
		check(world.door_open and is_equal_approx(world.door_pivot.rotation.y,angle),"Apartment opens away from either side")
		game.fp_player.position=Vector3(0,0.08,6-side*0.5)
		world.toggle_door()
		await create_timer(0.5).timeout
		check(world.door_open and not world.transitioning and is_equal_approx(world.door_pivot.rotation.y,angle),"Apartment blocks occupied closing sweep")
		game.fp_player.position=Vector3(0,0.08,6+side*1.4)
		world.toggle_door()
		await create_timer(0.5).timeout
		check(not world.door_open and is_zero_approx(world.door_pivot.rotation.y),"Apartment closes using stored direction")
	game.queue_free()
	await process_frame
	print("DOORS_TEST_RESULT: PASS" if failures==0 else "DOORS_TEST_RESULT: FAIL")
	quit(1 if failures else 0)
