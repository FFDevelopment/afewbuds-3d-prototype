extends Node3D
const Swing = preload("res://prototype/door_swing.gd")
var open_angle := PI/2.0
var opened := false
var busy := false
var pass_through := false
var width := 1.5
var host: Node3D

func toggle(player: Vector3) -> void:
	if busy: return
	if name == "HouseEntrance" and not opened and not host.property_offer_unlocked and to_local(player).z >= 0.0:
		host.status_label.text = "This house is not available yet. Watch for Rod’s property offer."
		return
	var p := to_local(player)
	var point := Vector2(p.x,p.z)
	var angle := open_angle if opened else Swing.away_angle(point)
	# Closing uses the stored opening direction; changing sides never flips the leaf.
	if not opened: open_angle=angle
	busy = true
	pass_through=true
	_set_leaf_collision(false)
	host.neighborhood.transitioning = true
	var leaf: Node3D = get_node("Leaf")
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(leaf,"rotation:y",0.0 if opened else open_angle,0.4)
	tween.tween_callback(func():
		opened = not opened
		busy = false
		refresh_collision()
		host.neighborhood.transitioning = false
	)

func _set_leaf_collision(solid: bool) -> void:
	for body in get_node("Leaf").find_children("*","StaticBody3D",true,false):
		if not body.has_meta("solid_layer"):body.set_meta("solid_layer",body.collision_layer)
		body.collision_layer=int(body.get_meta("solid_layer")) if solid else 0
func refresh_collision() -> void:
	var point: Vector3=get_node("Leaf").to_local(host.fp_player.global_position)
	pass_through=busy or Vector2(point.x,point.z).distance_to(Vector2(clampf(point.x,0,width),0))<.42
	_set_leaf_collision(not pass_through)
func _physics_process(_delta: float) -> void:
	if pass_through and not busy:refresh_collision()
