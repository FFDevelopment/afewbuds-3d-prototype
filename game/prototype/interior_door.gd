extends Node3D
const Swing = preload("res://prototype/door_swing.gd")
var open_angle := PI/2.0
var opened := false
var busy := false
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
	if Swing.blocked(point,width,angle,0.38):
		host.status_label.text = "Door blocked — step clear of the doorway and press E again."
		return
	if not opened: open_angle=angle
	busy = true
	host.neighborhood.transitioning = true
	var leaf: Node3D = get_node("Leaf")
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(leaf,"rotation:y",0.0 if opened else open_angle,0.4)
	tween.tween_callback(func():
		opened = not opened
		busy = false
		host.neighborhood.transitioning = false
	)
