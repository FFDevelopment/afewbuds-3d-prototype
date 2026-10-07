extends CharacterBody3D
## Shared AFewBuds first-person movement behavior for desktop/controller.
const WALK_SPEED := 3.4
const RUN_SPEED := 4.8
const ACCELERATION := 15.0
const DECELERATION := 20.0
const GRAVITY := 18.0
const BODY_HEIGHT := 2.43
const BODY_RADIUS := 0.26
const LOOK_SENSITIVITY := 0.0022
const EYE_HEIGHT := 2.16
var yaw := 0.0
var pitch := 0.0
var enabled := false
var view: Camera3D
var desired := Vector2.ZERO
var desired_speed := WALK_SPEED

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	floor_snap_length = 0.32
	floor_max_angle = deg_to_rad(48.0)
	floor_stop_on_slope = true
	max_slides = 6
	safe_margin = 0.025
	var capsule := CapsuleShape3D.new()
	capsule.radius = BODY_RADIUS
	capsule.height = BODY_HEIGHT
	var shape := CollisionShape3D.new()
	shape.name = "PlayerCapsule"
	shape.shape = capsule
	shape.position.y = BODY_HEIGHT / 2.0
	add_child(shape)

func drive(input_vector: Vector2, heading: float, speed: float = WALK_SPEED) -> void:
	desired = input_vector.limit_length(1.0)
	yaw = heading
	desired_speed = speed
	enabled = true

func stop() -> void:
	desired = Vector2.ZERO
	velocity = Vector3.ZERO
	enabled = false

func look(relative: Vector2) -> void:
	yaw = wrapf(yaw - relative.x * LOOK_SENSITIVITY * DesktopInput.mouse_sensitivity, -PI, PI)
	pitch = clampf(pitch - relative.y * LOOK_SENSITIVITY * DesktopInput.mouse_sensitivity * (-1.0 if DesktopInput.invert_y else 1.0), -1.35, 1.35)
	sync_camera()

func _physics_process(delta: float) -> void:
	if get_parent().neighborhood.bench_seating.seated >= 0:
		if enabled and Input.get_vector("fp_left","fp_right","fp_forward","fp_backward").length() > .05:
			get_parent().neighborhood.bench_seating.stand()
		if get_parent().neighborhood.bench_seating.seated >= 0:
			sync_camera()
			return
	if get_parent().neighborhood.couch_seated:
		if enabled and Input.get_vector("fp_left","fp_right","fp_forward","fp_backward").length() > .05:
			get_parent().neighborhood._toggle_couch()
		else:
			sync_camera()
			return
	if enabled:
		var axis := Input.get_vector("fp_left","fp_right","fp_forward","fp_backward")
		var aim: Vector2 = DesktopInput.stick(true) * DesktopInput.controller_sensitivity * delta * 2.2
		yaw = wrapf(yaw - aim.x, -PI, PI)
		pitch = clampf(pitch - aim.y * (-1.0 if DesktopInput.invert_y else 1.0), -1.35, 1.35)
		drive(axis,yaw,RUN_SPEED if Input.is_action_pressed("fp_sprint") else WALK_SPEED)
	else:
		desired = Vector2.ZERO
	var direction := Basis(Vector3.UP,yaw) * Vector3(desired.x,0,desired.y)
	var target := direction * desired_speed
	var rate := ACCELERATION if desired.length_squared() > .0025 else DECELERATION
	velocity.x = move_toward(velocity.x,target.x,rate*delta)
	velocity.z = move_toward(velocity.z,target.z,rate*delta)
	velocity.y = -.5 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	if position.y < -3.0:
		position = Vector3(0,0.1,1.2)
		velocity = Vector3.ZERO
	sync_camera()

func sync_camera() -> void:
	if view != null:
		view.global_position = global_position + Vector3.UP * EYE_HEIGHT
		view.rotation = Vector3(pitch,yaw,0)
