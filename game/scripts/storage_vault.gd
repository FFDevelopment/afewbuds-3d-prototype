extends Node3D

# Actual, lightweight 3D furniture (not a flat picture). Local +Z is the front.
# Fits inside the old left-wall shelf bay. Inventory remains owned by main.gd.
const CAPACITY_GRAMS: int = 400
const ANCHOR: Vector3 = Vector3(-4.33, 0.0, -0.30)
const FACING: float = PI / 2.0
const BODY_SIZE: Vector3 = Vector3(2.28, 2.28, 0.62)
const METAL_TEXTURE: Texture2D = preload("res://assets/textures/brushed_metal.png")
const BRAND_TEXTURE: Texture2D = preload("res://assets/branding/afb_logo.png")
var steel: StandardMaterial3D
var dark_steel: StandardMaterial3D
var green: StandardMaterial3D
var silver: StandardMaterial3D
var rubber: StandardMaterial3D
var wheel: Node3D
var wheel_tween: Tween

func _ready() -> void:
	steel = _material(Color("adb3b4"), 0.64, 0.50, true)
	dark_steel = _material(Color("465254"), 0.56, 0.62, true)
	green = _material(Color("4c962c"), 0.48, 0.35)
	silver = _material(Color("d5dbd8"), 0.65, 0.31, true)
	rubber = _material(Color("182521"), 0.06, 0.85)
	_build()

func _material(color: Color, metallic: float, roughness: float, textured: bool = false) -> StandardMaterial3D:
	var result: StandardMaterial3D = StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = metallic
	result.roughness = roughness
	if textured:
		result.albedo_texture = METAL_TEXTURE
		result.uv1_triplanar = true
		result.uv1_scale = Vector3(2.0, 2.0, 2.0)
	return result

func _mesh(part_name: String, mesh: Mesh, pos: Vector3, material: Material, parent: Node3D = self) -> MeshInstance3D:
	var part: MeshInstance3D = MeshInstance3D.new()
	part.name = part_name
	part.mesh = mesh
	part.material_override = material
	part.position = pos
	parent.add_child(part)
	return part

func _box(part_name: String, pos: Vector3, dimensions: Vector3, material: Material, parent: Node3D = self) -> MeshInstance3D:
	var shape: BoxMesh = BoxMesh.new()
	shape.size = dimensions
	return _mesh(part_name, shape, pos, material, parent)

func _cylinder(part_name: String, pos: Vector3, radius: float, height: float, material: Material, front: bool = false, parent: Node3D = self, segments: int = 32) -> MeshInstance3D:
	var shape: CylinderMesh = CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = segments
	shape.rings = 1
	var part: MeshInstance3D = _mesh(part_name, shape, pos, material, parent)
	if front:
		part.rotation.x = PI / 2.0
	return part

func _ring(part_name: String, center: Vector3, inner: float, outer: float, material: Material) -> void:
	var ring: TorusMesh = TorusMesh.new()
	ring.inner_radius = inner
	ring.outer_radius = outer
	ring.rings = 40
	ring.ring_segments = 10
	var part: MeshInstance3D = _mesh(part_name, ring, center, material)
	part.rotation.x = PI / 2.0

func _label(part_name: String, text: String, pos: Vector3, font_size: int, pixel_size: float, tint: Color) -> void:
	var label: Label3D = Label3D.new()
	label.name = part_name
	label.text = text
	label.position = pos
	label.font_size = font_size
	label.pixel_size = pixel_size
	label.modulate = tint
	label.outline_size = 0
	label.no_depth_test = false
	add_child(label)

func _build() -> void:
	# Feet rest on the floor at y=0; the rear clears the existing baseboard.
	for x: float in [-0.88, 0.88]:
		for z: float in [-0.20, 0.20]:
			_box("Foot", Vector3(x, 0.07, z), Vector3(0.25, 0.14, 0.22), rubber)
	_box("Cabinet", Vector3(0, 1.28, 0), BODY_SIZE, steel)
	_box("DoorGasket", Vector3(0, 1.29, 0.323), Vector3(2.13, 2.13, 0.026), rubber)
	_box("DoorFace", Vector3(0, 1.29, 0.352), Vector3(2.02, 2.02, 0.038), dark_steel)
	for x: float in [-1.08, 1.08]:
		_box("FrameSide", Vector3(x, 1.29, 0.335), Vector3(0.10, 2.25, 0.055), silver)
		_box("GreenEdge", Vector3(x * 0.93, 1.29, 0.377), Vector3(0.024, 1.92, 0.014), green)
	for y: float in [0.20, 2.38]:
		_box("FrameRail", Vector3(0, y, 0.335), Vector3(2.21, 0.08, 0.055), silver)
	for x: float in [-0.98, 0.98]:
		for y: float in [0.29, 2.29]:
			_cylinder("FrameBolt", Vector3(x, y, 0.393), 0.043, 0.042, silver, true, self, 6)
	# Nested metal discs and green trim form the heavy circular door.
	var center: Vector3 = Vector3(0, 1.21, 0.405)
	_cylinder("RoundDoor", center, 0.88, 0.052, silver, true)
	_cylinder("RoundDoorInset", center + Vector3(0, 0, 0.033), 0.765, 0.028, dark_steel, true)
	_ring("DoorGreenRing", center + Vector3(0, 0, 0.047), 0.697, 0.757, green)
	_cylinder("InnerDoor", center + Vector3(0, 0, 0.046), 0.667, 0.025, steel, true)
	for index: int in range(8):
		var angle: float = float(index) * TAU / 8.0
		_cylinder("DoorBolt%d" % index, center + Vector3(sin(angle) * 0.82, cos(angle) * 0.82, 0.043), 0.031, 0.03, silver, true, self, 6)
	# Side locking bars and proper vertical hinges; nothing projects into the aisle.
	for side: float in [-1.0, 1.0]:
		var bar: MeshInstance3D = _cylinder("LockingBar", Vector3(side * 0.66, 1.21, 0.481), 0.041, 0.65, silver)
		bar.rotation.z = PI / 2.0
		_box("LockReceiver", Vector3(side * 0.98, 1.21, 0.455), Vector3(0.14, 0.29, 0.12), steel)
	for y: float in [0.59, 1.93]:
		_box("HingeMount", Vector3(1.05, y, 0.393), Vector3(0.22, 0.24, 0.09), steel)
		_cylinder("Hinge", Vector3(1.15, y, 0.37), 0.076, 0.39, silver)
		for offset: float in [-0.177, 0.177]:
			_cylinder("HingeGreenBand", Vector3(1.15, y + offset, 0.37), 0.079, 0.034, green)
	# Six-spoke green hand wheel; meshes are real 3D so it reads correctly while looking around.
	wheel = Node3D.new()
	wheel.name = "HandWheel"
	wheel.position = Vector3(0, 1.21, 0.495)
	add_child(wheel)
	for index: int in range(6):
		var angle: float = float(index) * TAU / 6.0
		var handle: MeshInstance3D = _cylinder("Handle%d" % index, Vector3(sin(angle) * 0.385, cos(angle) * 0.385, 0), 0.044, 0.28, green, false, wheel, 16)
		handle.rotation.z = -angle
		var cap: MeshInstance3D = _cylinder("HandleCap%d" % index, Vector3(sin(angle) * 0.525, cos(angle) * 0.525, 0), 0.047, 0.041, silver, false, wheel, 16)
		cap.rotation.z = -angle
	_cylinder("WheelHub", Vector3(0, 0, 0.016), 0.253, 0.085, silver, true, wheel)
	_cylinder("WheelMedallion", Vector3(0, 0, 0.063), 0.216, 0.012, rubber, true, wheel)
	_leaf_emblem(wheel, Vector3(0, 0, 0.071))
	# Flush AFewBuds nameplate, using the approved AFB logo rather than a new brand.
	_box("BrandPlate", Vector3(-0.50, 2.14, 0.391), Vector3(0.95, 0.28, 0.025), rubber)
	var logo: Sprite3D = Sprite3D.new()
	logo.name = "AFBLogo"
	logo.texture = BRAND_TEXTURE
	logo.pixel_size = 0.235 / float(BRAND_TEXTURE.get_width())
	logo.position = Vector3(-0.82, 2.14, 0.409)
	logo.shaded = false
	add_child(logo)
	_label("BrandName", "AFEWBUDS", Vector3(-0.38, 2.19, 0.409), 38, 0.0020, Color("e5eddf"))
	_label("VaultName", "PREMIUM VAULT", Vector3(-0.38, 2.085, 0.409), 25, 0.0017, Color("a8d389"))
	_box("CapacityPlate", Vector3(0.65, 2.15, 0.391), Vector3(0.52, 0.29, 0.025), steel)
	_label("Capacity", "400g", Vector3(0.65, 2.20, 0.409), 50, 0.0025, Color("172e21"))
	_label("CapacityCaption", "STORAGE", Vector3(0.65, 2.075, 0.409), 25, 0.0018, Color("233d2a"))

func _leaf_emblem(parent: Node3D, center: Vector3) -> void:
	var shape: ImmediateMesh = ImmediateMesh.new()
	shape.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	# Stylized five-leaf emblem entirely inside the medallion.
	for index: int in range(5):
		var angle: float = deg_to_rad(float(index - 2) * 35.0)
		var direction: Vector3 = Vector3(sin(angle), cos(angle), 0)
		var across: Vector3 = Vector3(cos(angle), -sin(angle), 0)
		var start: Vector3 = center + Vector3(0, -0.08, 0)
		var tip: Vector3 = start + direction * (0.24 if index == 2 else 0.20)
		var middle: Vector3 = start + direction * 0.12
		for vertex: Vector3 in [start, middle + across * 0.033, tip, start, tip, middle - across * 0.033]:
			shape.surface_set_normal(Vector3(0, 0, 1))
			shape.surface_add_vertex(vertex)
	shape.surface_end()
	var leaf_material: StandardMaterial3D = _material(Color("9fd351"), 0.1, 0.55)
	leaf_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh("LeafEmblem", shape, Vector3.ZERO, leaf_material, parent)

func turn_handle() -> void:
	if wheel == null:
		return
	if wheel_tween != null and wheel_tween.is_running():
		wheel_tween.kill()
	wheel_tween = create_tween()
	wheel_tween.tween_property(wheel, "rotation:z", wheel.rotation.z + PI / 3.0, 0.22)

func world_bounds() -> AABB:
	var bounds: AABB = AABB()
	var has_bounds: bool = false
	var pending: Array[Node] = [self]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		pending.append_array(node.get_children())
		if node is MeshInstance3D:
			var visual: MeshInstance3D = node as MeshInstance3D
			var box: AABB = visual.global_transform * visual.get_aabb()
			bounds = bounds.merge(box) if has_bounds else box
			has_bounds = true
	return bounds
