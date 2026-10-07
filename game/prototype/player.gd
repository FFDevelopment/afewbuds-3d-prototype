extends CharacterBody3D
## Movement owns only the player body; all simulation stays in AFewBuds.
const WALK_SPEED := 3.4
const RUN_SPEED := 4.8
const LOOK_SENSITIVITY := 0.0022
const EYE_HEIGHT := 2.16
var yaw := 0.0
var pitch := 0.0
var enabled := false
var view: Camera3D

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.25
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.27
	capsule.height = 2.43
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = 1.215
	add_child(shape)

func look(relative: Vector2) -> void:
	yaw = wrapf(yaw - relative.x * LOOK_SENSITIVITY * DesktopInput.mouse_sensitivity, -PI, PI)
	pitch = clampf(pitch - relative.y * LOOK_SENSITIVITY * DesktopInput.mouse_sensitivity * (-1.0 if DesktopInput.invert_y else 1.0), -1.35, 1.35)
	sync_camera()

func _physics_process(delta: float) -> void:
	if get_parent().neighborhood.bench_seating.seated>=0:
		if enabled and Input.get_vector("fp_left","fp_right","fp_forward","fp_backward").length()>.05:get_parent().neighborhood.bench_seating.stand()
		if get_parent().neighborhood.bench_seating.seated>=0:sync_camera();return
	if get_parent().neighborhood.couch_seated:
		if enabled and Input.get_vector("fp_left","fp_right","fp_forward","fp_backward").length() > 0.05:
			get_parent().neighborhood._toggle_couch()
		else:
			sync_camera()
			return
	var direction := Vector3.ZERO
	if enabled:
		var axis := Input.get_vector("fp_left","fp_right","fp_forward","fp_backward")
		var aim: Vector2 = DesktopInput.stick(true) * DesktopInput.controller_sensitivity * delta * 2.2
		yaw = wrapf(yaw - aim.x, -PI, PI)
		pitch = clampf(pitch - aim.y * (-1.0 if DesktopInput.invert_y else 1.0), -1.35, 1.35)
		direction = Basis(Vector3.UP, yaw) * Vector3(axis.x, 0, axis.y)
	var speed := RUN_SPEED if Input.is_action_pressed("fp_sprint") else WALK_SPEED
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	velocity.y = -0.5 if is_on_floor() else velocity.y - 18.0 * delta
	move_and_slide()
	if position.y < -3.0:
		position = Vector3(0, 0.1, 1.2)
		velocity = Vector3.ZERO
	sync_camera()

func sync_camera() -> void:
	if view != null:
		view.global_position = global_position + Vector3.UP * EYE_HEIGHT
		view.rotation = Vector3(pitch, yaw, 0)
