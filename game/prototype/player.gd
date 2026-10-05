extends CharacterBody3D
## Movement owns only the player body; all simulation stays in AFewBuds.
const WALK_SPEED := 3.0
const RUN_SPEED := 4.8
const LOOK_SENSITIVITY := 0.0022
const EYE_HEIGHT := 1.64
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
	capsule.height = 1.75
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = 0.88
	add_child(shape)

func look(relative: Vector2) -> void:
	yaw = wrapf(yaw - relative.x * LOOK_SENSITIVITY, -PI, PI)
	pitch = clampf(pitch - relative.y * LOOK_SENSITIVITY, -1.35, 1.35)
	sync_camera()

func _physics_process(delta: float) -> void:
	var direction := Vector3.ZERO
	if enabled:
		var axis := Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))).limit_length()
		direction = Basis(Vector3.UP, yaw) * Vector3(axis.x, 0, axis.y)
	var speed := RUN_SPEED if Input.is_physical_key_pressed(KEY_SHIFT) else WALK_SPEED
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
