extends "res://scripts/neighborhood.gd"
## Reuse the .64 block, but place its apartment entrance at the real room door.
## The player body and camera remain owned by the first-person controller.
const BLOCK_OFFSET := Vector3(16, 0, 11.5)
var door_open := false
var door_tween: Tween

func setup(owner_node: Node3D) -> void:
	super.setup(owner_node)
	position = BLOCK_OFFSET
	visible = true
	controls.hide()
	# Remove the original fake apartment door; our hinged room door is shared.
	for child in get_children():
		if child is MeshInstance3D and child.position.is_equal_approx(Vector3(-16, 1.4, -5.42)):
			remove_child(child)
			child.queue_free()
		# Keep the sidewalk outside the apartment floor, with a flush threshold.
		elif child is MeshInstance3D and child.position.is_equal_approx(Vector3(0, 0, -4)):
			child.mesh.size.z = 5.4
			child.position.z = -2.7
			child.position.y = -0.08
		elif child is MeshInstance3D and child.mesh is BoxMesh and child.mesh.size.is_equal_approx(Vector3(64, 0.3, 48)):
			child.position.y = -0.18
		elif child is MeshInstance3D and child.mesh is BoxMesh and child.mesh.size.is_equal_approx(Vector3(60, 0.16, 4)):
			child.position.y = -0.08
		elif child is MeshInstance3D and child.mesh is BoxMesh and child.mesh.size.is_equal_approx(Vector3(60, 0.18, 0.24)):
			child.mesh.size.y = 0.02
			child.position.y = 0.005
		elif child is MeshInstance3D and child.mesh is BoxMesh and child.mesh.size.is_equal_approx(Vector3(0.025, 0.01, 5.6)):
			child.mesh.size.z = 5.3
			child.position = Vector3(child.position.x, 0.006, -2.7)
		elif child is MeshInstance3D and child.mesh is BoxMesh and child.mesh.size.is_equal_approx(Vector3(0.5, 1.4, 18)):
			child.mesh.size.z = 20
			child.position.z = 4.3
	# Visible end barriers plus rear fencing contain all walkable pavement.
	_box(Vector3(0, 0.75, 14.2), Vector3(59, 1.5, 0.25), "817c65")
	_box(Vector3(-25.05, 0.75, -5.5), Vector3(7.9, 1.5, 0.25), "817c65")
	# Cover remaining rear gaps between the three street-front properties.
	_box(Vector3(-8.7, 0.75, -5.5), Vector3(4.4, 1.5, 0.25), "817c65")
	_box(Vector3(4.75, 0.75, -5.5), Vector3(4.5, 1.5, 0.25), "817c65")
	_box(Vector3(25, 0.75, -5.5), Vector3(8, 1.5, 0.25), "817c65")
	# A flush landing bridges the old floor edge and sidewalk.
	_box(Vector3(-16, -0.08, -5.5), Vector3(2.1, 0.16, 0.65), "b7b2a7")

	# Outdoor sun illuminates only outdoor geometry, including through the door.
	for child in get_children():
		if child is MeshInstance3D:
			child.layers = 2
		elif child is Label3D:
			child.set_draw_flag(Label3D.FLAG_DOUBLE_SIDED, false)
	outdoor_sun.light_cull_mask = 2

func _building(pos: Vector3, size: Vector3, color: String) -> void:
	if pos.is_equal_approx(Vector3(-16, 0, -10)):
		# The apartment is the actual interior, not a solid facade cube.
		return
	super._building(pos, size, color)

func _process(_delta: float) -> void:
	if not is_instance_valid(host) or not host.fp_ready:
		return
	active = host.fp_player.position.z > 6.1
	controls.hide()
	var night: bool = host.day_phase == "NIGHT"
	outdoor_sun.light_energy = 0.08 if night else 0.65
	outdoor_environment.background_color = Color("202c41") if night else Color("b5c7d0")
	outdoor_environment.ambient_light_energy = 0.35 if night else 0.4
	host.camera.environment = outdoor_environment if active else null

func leave_apartment() -> void:
	toggle_door()

func toggle_door() -> void:
	if transitioning:
		return
	# Never sweep the leaf through the player or shut it across the capsule.
	var pos: Vector3 = host.fp_player.position
	if pos.y < 3.1 and Vector2(pos.x + 0.94, pos.z - 5.84).length() < 2.25:
		host.status_label.text = "Step clear of the door's swing, then press E."
		return
	door_open = not door_open
	transitioning = true
	door_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	door_tween.tween_property(door_pivot, "rotation:y", -PI / 2.0 if door_open else 0.0, 0.4)
	door_tween.tween_callback(func(): transitioning = false)
	host.status_label.text = "Door open — walk through. E closes it from either side." if door_open else "Front door closed."

func refresh_controls() -> void:
	controls.hide()

func _interact() -> void:
	host.status_label.text = "Rod's property offer is ready. Tours and ownership are coming later." if host.property_offer_unlocked else "This house is not available yet. Keep building your operation and watch for Rod's text."
