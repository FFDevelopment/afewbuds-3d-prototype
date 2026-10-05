extends RefCounted

# Static main-room art. No save, simulation, input, collision or global RNG changes.
# Board samples are interior regions of the approved generated wood image: borders
# are built once in geometry, so the image's outer frame never tiles across the room.
const FLOOR_SIZE: Vector2 = Vector2(10.2, 10.0)
const FLOOR_CENTER: Vector3 = Vector3(0.0, 0.0, 1.0)
const BOARD_WIDTH: float = 0.25
const BOARD_TOP: float = -0.006
const BOARD_EDGE: float = -0.009
const BOARD_GAP: float = 0.003
const BOARD_BEVEL: float = 0.003
const RUG_CENTER: Vector3 = Vector3(-2.28, 0.006, 2.05)
const RUG_SIZE: float = 2.85
const ATLAS_SIZE: float = 1254.0
const WOOD_PATH: String = "res://assets/textures/living_hardwood_atlas.png"
const RUG_PATH: String = "res://assets/textures/living_leaf_rug.png"
const BOARD_SAMPLES: Array[Rect2] = [
	Rect2(270, 14, 581, 78), Rect2(613, 123, 616, 73),
	Rect2(486, 227, 738, 75), Rect2(218, 340, 1009, 70),
	Rect2(21, 450, 820, 74), Rect2(486, 562, 741, 73),
	Rect2(527, 687, 694, 70), Rect2(149, 803, 804, 73),
	Rect2(23, 930, 635, 78), Rect2(464, 1057, 760, 74),
	Rect2(548, 1170, 675, 66)
]

static func _quad(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, colors: PackedColorArray, indices: PackedInt32Array, points: Array[Vector3], texcoords: Array[Vector2], normal: Vector3, tint: Color) -> void:
	var start: int = vertices.size()
	for i: int in range(4):
		vertices.append(points[i])
		normals.append(normal)
		uvs.append(texcoords[i])
		colors.append(tint)
	# Godot uses clockwise front faces.
	indices.append_array(PackedInt32Array([start, start + 1, start + 2, start, start + 2, start + 3]))

static func _texture_material(path: String, roughness_value: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.albedo_texture = load(path) as Texture2D
	material.roughness = roughness_value
	material.metallic = 0.0
	material.metallic_specular = 0.22
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.texture_repeat = false
	material.uv1_scale = Vector3.ONE
	return material

static func add_main_floor(parent: Node3D) -> MeshInstance3D:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var indices: PackedInt32Array = PackedInt32Array()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 407904
	var count: int = 0
	var left: float = -FLOOR_SIZE.x * 0.5
	var right: float = FLOOR_SIZE.x * 0.5
	var front: float = -FLOOR_SIZE.y * 0.5
	for row: int in range(int(round(FLOOR_SIZE.y / BOARD_WIDTH))):
		var z0: float = front + float(row) * BOARD_WIDTH + BOARD_GAP * 0.5
		var z1: float = front + float(row + 1) * BOARD_WIDTH - BOARD_GAP * 0.5
		var cursor: float = left - rng.randf_range(0.18, 1.45)
		while cursor < right:
			var sample: Rect2 = BOARD_SAMPLES[rng.randi_range(0, BOARD_SAMPLES.size() - 1)]
			# Equal pixels per world unit on both axes: no stretched grain.
			var pixels_per_metre: float = sample.size.y / (BOARD_WIDTH - BOARD_GAP)
			var full_length: float = minf(2.45, sample.size.x / pixels_per_metre)
			var x0: float = maxf(left, cursor) + BOARD_GAP * 0.5
			var x1: float = minf(right, cursor + full_length) - BOARD_GAP * 0.5
			if x1 - x0 > 0.012:
				var top: Array[Vector3] = [Vector3(x0 + BOARD_BEVEL, BOARD_TOP, z0 + BOARD_BEVEL), Vector3(x1 - BOARD_BEVEL, BOARD_TOP, z0 + BOARD_BEVEL), Vector3(x1 - BOARD_BEVEL, BOARD_TOP, z1 - BOARD_BEVEL), Vector3(x0 + BOARD_BEVEL, BOARD_TOP, z1 - BOARD_BEVEL)]
				var edge: Array[Vector3] = [Vector3(x0, BOARD_EDGE, z0), Vector3(x1, BOARD_EDGE, z0), Vector3(x1, BOARD_EDGE, z1), Vector3(x0, BOARD_EDGE, z1)]
				var top_uv: Array[Vector2] = []
				var edge_uv: Array[Vector2] = []
				for i: int in range(4):
					top_uv.append((sample.position + Vector2((top[i].x - cursor) * pixels_per_metre, (top[i].z - z0) * pixels_per_metre)) / ATLAS_SIZE)
					edge_uv.append((sample.position + Vector2((edge[i].x - cursor) * pixels_per_metre, (edge[i].z - z0) * pixels_per_metre)) / ATLAS_SIZE)
				var shade: float = rng.randf_range(0.92, 1.0)
				var tint: Color = Color(shade, shade, shade)
				_quad(vertices, normals, uvs, colors, indices, top, top_uv, Vector3.UP, tint)
				var outward: Array[Vector3] = [Vector3.FORWARD, Vector3.RIGHT, Vector3.BACK, Vector3.LEFT]
				for i: int in range(4):
					var following: int = (i + 1) % 4
					_quad(vertices, normals, uvs, colors, indices, [edge[i], edge[following], top[following], top[i]], [edge_uv[i], edge_uv[following], top_uv[following], top_uv[i]], (Vector3.UP + outward[i]).normalized(), tint.darkened(0.08))
				count += 1
			cursor += full_length
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material: StandardMaterial3D = _texture_material(WOOD_PATH, 0.77)
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	mesh.surface_set_material(0, material)
	var floor: MeshInstance3D = MeshInstance3D.new()
	floor.name = "MainFloorPlanks"
	floor.mesh = mesh
	floor.position = FLOOR_CENTER
	floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	floor.set_meta("plank_count", count)
	floor.set_meta("board_width_metres", BOARD_WIDTH)
	parent.add_child(floor)
	return floor

static func add_living_rug(parent: Node3D) -> MeshInstance3D:
	# One square design at the established rug anchor; never tiled or projected
	# through a BoxMesh face atlas. The original entry/grow-room mats stay as-is.
	var rug: MeshInstance3D = MeshInstance3D.new()
	rug.name = "LivingRug"
	var mesh: PlaneMesh = PlaneMesh.new()
	mesh.size = Vector2.ONE * RUG_SIZE
	var material: StandardMaterial3D = _texture_material(RUG_PATH, 0.98)
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.45
	mesh.material = material
	rug.mesh = mesh
	rug.position = RUG_CENTER
	rug.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(rug)
	return rug
