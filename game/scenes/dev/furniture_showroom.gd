extends Node3D
## AFewBuds furniture study showroom. Preview meshes are procedural prototypes,
## not the final optimized furniture scenes.
## Scale guide is derived from prototype/player.gd BODY_HEIGHT=2.43,
## not verified Kobi/Rod/Malik mesh dimensions.
const ITEMS := [
	["Sprout Sofa", "Living Room"],
	["Petal Armchair", "Living Room"],
	["Stump Table", "Living Room"],
	["Leaf Rug", "Living Room"],
	["Bud Bookshelf", "Living Room"],
	["Sunbeam Lamp", "Living Room"],
	["Meadow Bed", "Bedroom"],
	["Clover Stool", "Bedroom"],
	["Berry Cabinet", "Bedroom"],
	["Hanging Planter", "Decor"],
	["Acorn Clock", "Decor"],
	["Foraging Table", "Utility"],
]
const OLIVE := Color("#80905d")
const DARK_GREEN := Color("#465f3a")
const LEAF := Color("#6e9947")
const CREAM := Color("#e7d9bf")
const WOOD := Color("#a87445")
const DARK_WOOD := Color("#68432d")
const ROSE := Color("#d98f93")
const GOLD := Color("#e5bb69")

var fly_camera: Camera3D
var look_dragging := false
var speed := 7.0

func _ready() -> void:
	_build_room()
	_build_items()
	_build_scale_guide()
	_build_camera()
	_build_overlay()

func _process(delta: float) -> void:
	if fly_camera == null:
		return
	var move := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): move.z -= 1.0
	if Input.is_key_pressed(KEY_S): move.z += 1.0
	if Input.is_key_pressed(KEY_A): move.x -= 1.0
	if Input.is_key_pressed(KEY_D): move.x += 1.0
	if Input.is_key_pressed(KEY_E): move.y += 1.0
	if Input.is_key_pressed(KEY_Q): move.y -= 1.0
	var rate := speed * (2.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0)
	fly_camera.global_position += fly_camera.global_basis * move.normalized() * rate * delta

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		look_dragging = event.pressed
	if event is InputEventMouseMotion and look_dragging:
		fly_camera.rotation.y -= event.relative.x * 0.004
		fly_camera.rotation.x = clampf(fly_camera.rotation.x - event.relative.y * 0.004, -1.4, 1.4)
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		fly_camera.position = Vector3(0, 9.5, 18)
		fly_camera.rotation = Vector3(-0.39, 0, 0)

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.77
	m.metallic = 0.02
	return m

func _box(parent: Node3D, p: Vector3, scale_size: Vector3, tint: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = scale_size
	node.mesh = mesh
	node.material_override = _mat(tint)
	node.position = p
	parent.add_child(node)
	return node

func _sphere(parent: Node3D, p: Vector3, scale_size: Vector3, tint: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = SphereMesh.new()
	node.material_override = _mat(tint)
	node.position = p
	node.scale = scale_size
	parent.add_child(node)
	return node

func _cyl(parent: Node3D, p: Vector3, radius: float, height: float, tint: Color, sides: int = 16) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	node.mesh = mesh
	node.material_override = _mat(tint)
	node.position = p
	parent.add_child(node)
	return node

func _label(parent: Node3D, text_value: String, p: Vector3, size: int = 46) -> void:
	var lbl := Label3D.new()
	lbl.text = text_value
	lbl.font_size = size
	lbl.pixel_size = 0.008
	lbl.modulate = Color("#2b3b2b")
	lbl.position = p
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	parent.add_child(lbl)

func _build_room() -> void:
	_box(self, Vector3(0, -0.22, -1), Vector3(25, 0.4, 24), Color("#e0d6c5"))
	_box(self, Vector3(0, 4, -13), Vector3(25, 8, 0.25), Color("#eee5d8"))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, -15)
	sun.light_energy = 1.3
	add_child(sun)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, 9, 0)
	fill.omni_range = 28.0
	fill.light_energy = 0.8
	add_child(fill)
	_label(self, "AFEWBUDS  /  FURNITURE STUDIES", Vector3(0, 5, -12.7), 82)

func _build_camera() -> void:
	fly_camera = Camera3D.new()
	fly_camera.current = true
	fly_camera.position = Vector3(0, 9.5, 18)
	fly_camera.rotation = Vector3(-0.39, 0, 0)
	fly_camera.fov = 65.0
	add_child(fly_camera)

func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var top := Label.new()
	top.text = "AFewBuds Furniture Showroom  •  WASD fly  •  E/Q up/down  •  Right-drag look  •  Shift speed  •  R reset"
	top.position = Vector2(20, 16)
	top.add_theme_color_override("font_color", Color("#293a2b"))
	top.add_theme_font_size_override("font_size", 19)
	layer.add_child(top)

func _build_items() -> void:
	for i in range(ITEMS.size()):
		var col := i % 4
		var row_index := int(i / 4)
		var display := Node3D.new()
		display.name = ITEMS[i][0].replace(" ", "")
		display.position = Vector3((float(col) - 1.5) * 5.6, 0, -float(row_index) * 6.1 + 5.0)
		add_child(display)
		_box(display, Vector3(0, 0.035, 0), Vector3(4.9, 0.07, 4.6), Color("#f2ecde"))
		_label(display, ITEMS[i][0] + "\n" + ITEMS[i][1], Vector3(0, 2.9, -1.8), 49)
		_make_piece(display, i)

func _build_scale_guide() -> void:
	# 2.43m player collision body reference. This is NOT a character model.
	var guide := Node3D.new()
	guide.name = "PlayerBodyScaleReference_2p43m"
	guide.position = Vector3(10.7, 0.0, 7.1)
	add_child(guide)
	var translucent := _mat(Color(0.2, 0.36, 0.42, 0.45))
	translucent.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var torso := _cyl(guide, Vector3(0, 1.2, 0), 0.25, 1.8, Color("#8bada5"))
	torso.material_override = translucent
	_sphere(guide, Vector3(0, 2.2, 0), Vector3(0.23, 0.23, 0.23), Color("#8bada5")).material_override = translucent
	_box(guide, Vector3(0, 0.015, 0), Vector3(1.2, 0.03, 1.2), CREAM)
	_label(guide, "PLAYER CONTROLLER SCALE\n2.43m collision body\n(Not Kobi / Rod / Malik mesh)", Vector3(0, 3.1, 0), 35)

func _leaf(n: Node3D, p: Vector3, size: Vector3, rotation_z: float, tint: Color) -> void:
	var leaf := _sphere(n, p, size, tint)
	leaf.rotation.z = rotation_z

func _make_piece(n: Node3D, id: int) -> void:
	match id:
		0: # upholstered sofa, visible cushions, arms, legs and accent pillow
			_box(n, Vector3(0, 0.67, 0), Vector3(2.75, 0.42, 1.0), OLIVE)
			_box(n, Vector3(0, 1.13, -0.42), Vector3(2.65, 0.94, 0.31), OLIVE)
			for x in [-1.27, 1.27]:
				_box(n, Vector3(x, 0.85, 0), Vector3(0.30, 0.75, 1.15), OLIVE)
			for x in [-0.65, 0.65]:
				_box(n, Vector3(x, 0.91, 0.09), Vector3(1.18, 0.18, 0.76), Color("#91a473"))
			for x in [-1.06, 1.06]:
				for z in [-0.35, 0.35]:
					_cyl(n, Vector3(x, 0.22, z), 0.095, 0.42, DARK_WOOD)
			_sphere(n, Vector3(0.6, 1.19, -0.13), Vector3(0.27, 0.27, 0.13), CREAM)
			for x in [-0.67, 0.67]:
				_sphere(n, Vector3(x, 1.34, -0.2), Vector3(0.55, 0.38, 0.20), Color("#91a473"))
		1: # armchair
			_box(n, Vector3(0, 0.6, 0), Vector3(1.38, 0.40, 1.03), ROSE)
			_box(n, Vector3(0, 1.22, -0.42), Vector3(1.35, 1.0, 0.26), ROSE)
			for x in [-0.68, 0.68]:
				# Separate rounded upholstered arms, rising gently toward the back.
				_box(n, Vector3(x, 0.72, 0.06), Vector3(0.28, 0.35, 0.96), Color("#b76e74"))
				_sphere(n, Vector3(x, 0.92, 0.17), Vector3(0.20, 0.18, 0.48), ROSE)
			_sphere(n, Vector3(0, 0.86, 0.13), Vector3(0.53, 0.15, 0.38), Color("#eda7a7"))
			_sphere(n, Vector3(0, 1.35, -0.37), Vector3(0.57, 0.46, 0.17), ROSE)
			for x in [-0.48, 0.48]:
				for z in [-0.38, 0.38]:
					_cyl(n, Vector3(x, 0.2, z), 0.08, 0.4, WOOD)
		2: # stump coffee table
			_cyl(n, Vector3(0, 0.48, 0), 0.88, 0.9, WOOD, 13)
			_cyl(n, Vector3(0, 0.95, 0), 1.05, 0.15, DARK_WOOD, 18)
			_cyl(n, Vector3(0, 1.04, 0), 0.86, 0.05, WOOD)
			_cyl(n, Vector3(-0.34, 1.19, 0), 0.17, 0.26, CREAM)
			_sphere(n, Vector3(-0.34, 1.38, 0), Vector3(0.30, 0.15, 0.18), LEAF)
		3: # leafy oval mat with raised vein
			_sphere(n, Vector3(0, 0.09, 0), Vector3(1.6, 0.06, 1.03), OLIVE)
			var vein := _box(n, Vector3(0, 0.155, 0), Vector3(0.06, 0.015, 1.6), Color("#bbbf85"))
			vein.rotation.y = 0.38
		4: # shelf with books and ceramic pots
			for x in [-0.94, 0.94]:
				_box(n, Vector3(x, 1.1, 0), Vector3(0.14, 2.2, 0.72), WOOD)
			for y in [0.15, 0.83, 1.52, 2.20]:
				_box(n, Vector3(0, y, 0), Vector3(2.05, 0.15, 0.75), WOOD)
			for x in [-0.55, -0.25, 0.05, 0.35]:
				_box(n, Vector3(x, 1.17, 0), Vector3(0.17, 0.56, 0.43), ROSE if x < 0 else DARK_GREEN)
			_cyl(n, Vector3(0.45, 1.76, 0), 0.22, 0.3, CREAM)
			_sphere(n, Vector3(0.45, 2.02, 0), Vector3(0.3, 0.2, 0.28), LEAF)
			for x in [-0.26, 0.05, 0.23]:
				_leaf(n, Vector3(0.45 + x, 2.16, 0), Vector3(0.18, 0.08, 0.12), 0.45, DARK_GREEN)
		5: # curved warm standing lamp
			_cyl(n, Vector3(0, 0.12, 0), 0.43, 0.22, DARK_WOOD)
			_cyl(n, Vector3(0, 1.04, 0), 0.09, 1.7, WOOD)
			_sphere(n, Vector3(0, 1.98, 0), Vector3(0.66, 0.56, 0.66), GOLD)
			_sphere(n, Vector3(0, 1.98, 0.08), Vector3(0.30, 0.30, 0.28), CREAM)
		6: # bed frame, headboard, duvet, pillows
			_box(n, Vector3(0, 0.33, 0), Vector3(2.35, 0.44, 2.70), WOOD)
			_box(n, Vector3(0, 0.67, 0.05), Vector3(2.15, 0.24, 2.45), CREAM)
			_box(n, Vector3(0, 0.87, 0.62), Vector3(2.1, 0.13, 1.3), OLIVE)
			_box(n, Vector3(0, 1.10, -1.28), Vector3(2.42, 1.65, 0.19), WOOD)
			for x in [-0.56, 0.56]:
				_box(n, Vector3(x, 0.83, -0.81), Vector3(0.83, 0.19, 0.47), CREAM)
		7: # clover seat
			_cyl(n, Vector3(0, 0.83, 0), 0.69, 0.20, OLIVE)
			for x in [-0.45, 0.45]:
				for z in [-0.36, 0.36]:
					_cyl(n, Vector3(x, 0.39, z), 0.09, 0.77, WOOD)
			for x in [-0.31, 0.31]:
				for z in [-0.25, 0.25]:
					_sphere(n, Vector3(x, 0.99, z), Vector3(0.43, 0.1, 0.39), LEAF)
		8: # cabinet with split front doors and handles
			_box(n, Vector3(0, 0.92, 0), Vector3(1.9, 1.55, 0.87), WOOD)
			for x in [-0.47, 0.47]:
				_box(n, Vector3(x, 0.92, 0.46), Vector3(0.88, 1.35, 0.08), DARK_WOOD)
				_sphere(n, Vector3(x * 0.32, 0.93, 0.55), Vector3(0.1, 0.1, 0.09), ROSE)
			for x in [-0.73, 0.73]:
				_box(n, Vector3(x, 0.10, 0), Vector3(0.15, 0.2, 0.65), DARK_WOOD)
			_sphere(n, Vector3(0.58, 1.83, 0), Vector3(0.55, 0.22, 0.35), LEAF)
		9: # finished hanging planter study: woven pot, rim, soil and trailing leaves
			_cyl(n, Vector3(0, 1.18, 0), 0.51, 0.62, WOOD, 24)
			_cyl(n, Vector3(0, 1.52, 0), 0.57, 0.12, DARK_WOOD, 24)
			_cyl(n, Vector3(0, 1.59, 0), 0.43, 0.035, Color("#49372c"), 24)
			# Four suspended cords meet at the overhead ring.
			for i in range(4):
				var angle := float(i) * PI * 0.5
				var x := cos(angle) * 0.37
				var z := sin(angle) * 0.37
				var cord := _cyl(n, Vector3(x * 0.5, 2.05, z * 0.5), 0.025, 1.2, CREAM, 8)
				cord.rotation.z = sin(angle) * 0.32
				cord.rotation.x = -cos(angle) * 0.32
			_cyl(n, Vector3(0, 2.66, 0), 0.11, 0.08, DARK_WOOD)
			for i in range(10):
				var a := float(i) * TAU / 10.0
				var x := cos(a) * 0.48
				var z := sin(a) * 0.48
				_leaf(n, Vector3(x, 1.75 + 0.08 * sin(a * 2.0), z), Vector3(0.22, 0.13, 0.12), -a, LEAF if i % 2 == 0 else DARK_GREEN)
				if i % 2 == 0:
					_cyl(n, Vector3(x * 1.2, 1.2, z * 1.2), 0.022, 0.80, DARK_GREEN, 7)
					_leaf(n, Vector3(x * 1.3, 1.04, z * 1.3), Vector3(0.18, 0.27, 0.13), a, LEAF)
					_leaf(n, Vector3(x * 1.2, 0.81, z * 1.2), Vector3(0.17, 0.23, 0.12), -a, DARK_GREEN)
		10: # acorn-themed wall clock (stand display for inspection)
			_cyl(n, Vector3(0, 1.2, 0), 0.79, 0.18, DARK_WOOD)
			_cyl(n, Vector3(0, 1.2, 0.105), 0.62, 0.035, CREAM)
			_box(n, Vector3(0.13, 1.32, 0.15), Vector3(0.035, 0.42, 0.025), DARK_WOOD)
			_box(n, Vector3(-0.14, 1.18, 0.15), Vector3(0.35, 0.035, 0.025), DARK_WOOD)
			_sphere(n, Vector3(0, 1.91, 0), Vector3(0.67, 0.26, 0.23), DARK_WOOD)
			_cyl(n, Vector3(0, 0.41, -0.17), 0.12, 0.82, WOOD)
		11: # general-purpose work and foraging table
			_box(n, Vector3(0, 1.07, 0), Vector3(2.45, 0.22, 1.36), WOOD)
			for x in [-1.00, 1.00]:
				for z in [-0.48, 0.48]:
					_box(n, Vector3(x, 0.54, z), Vector3(0.17, 1.04, 0.18), DARK_WOOD)
			_box(n, Vector3(0, 0.45, 0), Vector3(2.1, 0.13, 1.1), DARK_WOOD)
			_cyl(n, Vector3(0.65, 1.29, -0.3), 0.13, 0.30, CREAM)
			_sphere(n, Vector3(0.65, 1.52, -0.3), Vector3(0.27, 0.23, 0.25), LEAF)
