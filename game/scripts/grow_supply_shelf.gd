extends Node3D

# Static reference-inspired grow-room shelf. Local -Z faces the room.
# Same utility-shelf footprint; decorative jars are not spendable inventory.
const ANCHOR: Vector3 = Vector3(-4.34, 0.06, -5.88)
var triangle_count: int = 0
var _materials: Dictionary = {}
var _parts: Array[MeshInstance3D] = []
var _status_label: Label3D

func _ready() -> void:
	name = "GrowSupplyUnit"
	var finish: Texture2D = load("res://assets/textures/brushed_metal.png") as Texture2D
	_make_material("frame", Color("46424f"), 0.72, finish)
	_make_material("back", Color("33333e"), 0.88, finish)
	_make_material("edge", Color("686173"), 0.61, finish)
	_make_material("lid", Color("292931"), 0.65, finish)
	_make_material("green", Color("6d8977"), 0.43)
	_make_material("purple", Color("86679a"), 0.48)
	_make_material("cream", Color("ddd9c2"), 0.94)
	_make_material("lilac", Color("cbaed9"), 0.91)
	_make_material("leaf", Color("57735c"), 0.94)
	_build()
	_batch()
	_status_label = Label3D.new()
	_status_label.name = "SupplyShelfStatus"
	_status_label.text = "SUPPLY SHELF I"
	_status_label.font_size = 26
	_status_label.pixel_size = 0.0024
	_status_label.position = Vector3(0, 2.40, -0.39)
	_status_label.modulate = Color("dce8d7")
	_status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_status_label)
	set_process(false)

func set_inventory_status(level: int, seeds: int, seed_capacity: int, fertilizer: int, fertilizer_capacity: int) -> void:
	if _status_label == null:
		return
	var over_seed: String = " OVER" if seeds > seed_capacity else ""
	var over_fert: String = " OVER" if fertilizer > fertilizer_capacity else ""
	_status_label.text = "SUPPLY SHELF %s\nSEEDS %d/%d%s  •  FERT %d/%d%s" % [_roman(clampi(level, 1, 3)), seeds, seed_capacity, over_seed, fertilizer, fertilizer_capacity, over_fert]

func _roman(level: int) -> String:
	match level:
		2: return "II"
		3: return "III"
		_: return "I"

func _make_material(key: String, color: Color, roughness_value: float, texture: Texture2D = null) -> void:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness_value
	mat.metallic = 0.12 if texture != null else 0.0
	mat.metallic_specular = 0.25
	mat.albedo_texture = texture
	mat.uv1_triplanar = texture != null
	mat.uv1_scale = Vector3(2.8, 2.8, 2.8)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_materials[key] = mat

func _add(part_name: String, mesh: Mesh, pos: Vector3, material_key: String, rotation_value: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var part: MeshInstance3D = MeshInstance3D.new()
	part.name = part_name
	part.mesh = mesh
	part.material_override = _materials[material_key]
	part.position = pos
	part.rotation_degrees = rotation_value
	add_child(part)
	_parts.append(part)
	return part

func _rounded(size: Vector3, radius: float) -> ArrayMesh:
	# Small face grids for softly bevelled edges, not a subdivided dense cube.
	var h: Vector3 = size * 0.5
	radius = minf(radius, minf(h.x, minf(h.y, h.z)) * 0.9)
	var core: Vector3 = h - Vector3.ONE * radius
	var verts: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	for n: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]:
		var u: Vector3 = Vector3.UP.cross(n).normalized() if absf(n.y) < 0.5 else Vector3.RIGHT
		var v: Vector3 = n.cross(u).normalized()
		var uh: float = absf(u.dot(h))
		var vh: float = absf(v.dot(h))
		var us: Array[float] = [-uh, -uh + radius * 0.3, -uh + radius, uh - radius, uh - radius * 0.3, uh]
		var vs: Array[float] = [-vh, -vh + radius * 0.3, -vh + radius, vh - radius, vh - radius * 0.3, vh]
		var first: int = verts.size()
		for py: float in vs:
			for px: float in us:
				var p: Vector3 = n * absf(n.dot(h)) + u * px + v * py
				var clamped: Vector3 = p.clamp(-core, core)
				var normal: Vector3 = (p - clamped).normalized()
				verts.append(clamped + normal * radius)
				normals.append(normal)
				uvs.append(Vector2(px, py))
		for y: int in range(5):
			for x: int in range(5):
				var a: int = first + y * 6 + x
				indices.append_array(PackedInt32Array([a, a + 6, a + 1, a + 1, a + 6, a + 7]))
	return _mesh(verts, normals, uvs, indices)

func _mesh(verts: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _box(part_name: String, pos: Vector3, size: Vector3, radius: float, material_key: String) -> void:
	_add(part_name, _rounded(size, radius), pos, material_key)

func _cylinder(part_name: String, pos: Vector3, bottom: float, top: float, height_value: float, material_key: String) -> void:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height_value
	mesh.radial_segments = 24
	mesh.rings = 1
	_add(part_name, mesh, pos, material_key)

func _jar(part_name: String, base: Vector3, radius: float, height_value: float, material_key: String, label_key: String, has_leaf: bool) -> void:
	_cylinder(part_name + "Heel", base + Vector3(0, 0.015, 0), radius * 0.86, radius, 0.030, material_key)
	_cylinder(part_name + "Body", base + Vector3(0, height_value * 0.45, 0), radius, radius, height_value * 0.78, material_key)
	_cylinder(part_name + "Shoulder", base + Vector3(0, height_value * 0.88, 0), radius, radius * 0.83, height_value * 0.10, material_key)
	_cylinder(part_name + "Cap", base + Vector3(0, height_value * 0.99, 0), radius * 0.96, radius * 0.96, height_value * 0.16, "lid")
	_cylinder(part_name + "CapRim", base + Vector3(0, height_value * 0.923, 0), radius * 0.99, radius * 0.99, 0.010, "edge")
	var label_center: Vector3 = base + Vector3(0, height_value * 0.45, -radius * 0.985)
	_box(part_name + "Label", label_center, Vector3(radius * 1.28, height_value * 0.52, 0.008), 0.006, label_key)
	if has_leaf:
		_leaf_mark(label_center + Vector3(0, -0.005, -0.006), radius * 0.52)

func _leaf_mark(center: Vector3, radius: float) -> void:
	var verts: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	for a: float in [-72.0, -47.0, -24.0, 0.0, 24.0, 47.0, 72.0]:
		var length_value: float = radius * (1.65 - absf(a) / 90.0)
		var dir: Vector2 = Vector2(sin(deg_to_rad(a)), cos(deg_to_rad(a)))
		var side: Vector2 = Vector2(-dir.y, dir.x)
		var first: int = verts.size()
		for p: Vector2 in [Vector2.ZERO, dir * length_value * 0.45 - side * radius * 0.20, dir * length_value, dir * length_value * 0.45 + side * radius * 0.20]:
			verts.append(center + Vector3(p.x, p.y, 0))
			normals.append(Vector3.FORWARD)
			uvs.append(Vector2.ZERO)
		indices.append_array(PackedInt32Array([first, first + 1, first + 2, first, first + 2, first + 3]))
	_add("LeafLabelMark", _mesh(verts, normals, uvs, indices), Vector3.ZERO, "leaf")
	_box("LeafStem", center + Vector3(0, -radius * 0.15, 0), Vector3(radius * 0.12, radius * 0.45, 0.001), 0.0002, "leaf")

func _build() -> void:
	# Tall recessed back, subtle edge highlights, three shelves, no extra cabinets.
	_box("RecessedBack", Vector3(0, 1.18, 0.30), Vector3(1.55, 2.15, 0.075), 0.016, "back")
	_box("FrameLeft", Vector3(-0.735, 1.18, 0.255), Vector3(0.09, 2.15, 0.12), 0.012, "frame")
	_box("FrameRight", Vector3(0.735, 1.18, 0.255), Vector3(0.09, 2.15, 0.12), 0.012, "frame")
	_box("FrameTop", Vector3(0, 2.21, 0.255), Vector3(1.55, 0.09, 0.12), 0.012, "frame")
	_box("FrameBottom", Vector3(0, 0.15, 0.255), Vector3(1.55, 0.09, 0.12), 0.012, "frame")
	for i: int in range(3):
		var y: float = 0.42 + float(i) * 0.72
		_box("Shelf%d" % i, Vector3(0, y, -0.015), Vector3(1.54, 0.092, 0.65), 0.014, "frame")
		_box("ShelfLip%d" % i, Vector3(0, y + 0.032, -0.331), Vector3(1.51, 0.007, 0.009), 0.002, "edge")
	_jar("LeafJar", Vector3(-0.43, 1.186, -0.125), 0.092, 0.278, "green", "cream", true)
	_jar("PurpleJar", Vector3(-0.18, 1.186, -0.125), 0.085, 0.206, "purple", "lilac", false)
	_box("StorageBox", Vector3(0.30, 0.580, -0.045), Vector3(0.54, 0.235, 0.37), 0.016, "frame")
	_box("StorageBoxLid", Vector3(0.30, 0.716, -0.045), Vector3(0.56, 0.060, 0.395), 0.012, "lid")
	_box("BoxHandleInset", Vector3(0.30, 0.603, -0.233), Vector3(0.17, 0.048, 0.009), 0.015, "lid")
	_box("BoxHandleInner", Vector3(0.30, 0.604, -0.239), Vector3(0.13, 0.020, 0.004), 0.006, "back")
	set_meta("shelf_heights", [0.42, 1.14, 1.86])
	set_meta("decorative_only", true)

func _batch() -> void:
	# One static mesh per material, avoiding dozens of prop draw calls on phones.
	for key: String in _materials:
		var verts: PackedVector3Array = PackedVector3Array()
		var normals: PackedVector3Array = PackedVector3Array()
		var uvs: PackedVector2Array = PackedVector2Array()
		var indices: PackedInt32Array = PackedInt32Array()
		for part: MeshInstance3D in _parts:
			if part.material_override != _materials[key]:
				continue
			for surface: int in range(part.mesh.get_surface_count()):
				var a: Array = part.mesh.surface_get_arrays(surface)
				var offset: int = verts.size()
				var points: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
				var ns: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
				var tex: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
				for i: int in range(points.size()):
					verts.append(part.transform * points[i])
					normals.append((part.basis * ns[i]).normalized())
					uvs.append(tex[i] if tex.size() > i else Vector2.ZERO)
				var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
				for i: int in idx:
					indices.append(offset + i)
		if not verts.is_empty():
			var mesh: MeshInstance3D = MeshInstance3D.new()
			mesh.name = "Shelf_" + key
			mesh.mesh = _mesh(verts, normals, uvs, indices)
			mesh.material_override = _materials[key]
			add_child(mesh)
			triangle_count += int(indices.size() / 3)
	for part: MeshInstance3D in _parts:
		remove_child(part)
		part.free()
	_parts.clear()

func world_bounds() -> AABB:
	var box: AABB = AABB()
	var started: bool = false
	for node: Node in get_children():
		if node is MeshInstance3D:
			var part: MeshInstance3D = node as MeshInstance3D
			var bounds: AABB = part.global_transform * part.get_aabb()
			box = box.merge(bounds) if started else bounds
			started = true
	return box
