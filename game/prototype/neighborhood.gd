extends "res://scripts/neighborhood.gd"
## Prototype layout follows the supplied apartment/shop/house plan in world metres.
const BLOCK_OFFSET := Vector3.ZERO
const HOUSE_ENTRY := Vector3(35, 1.4, 3.2)
const APARTMENT_BOUNDS := AABB(Vector3(-5.1, 0, -10.3), Vector3(10.2, 4.4, 16.4))
var door_open := false
var door_tween: Tween
const MAP_RECT := Rect2(-32, -36, 105, 75)
const ROAD_RECTS := [Rect2(-32,12,105,10), Rect2(-32,-21,105,4), Rect2(-15,-36,6,75), Rect2(48,-36,6,75)]
var building_bounds: Array[AABB] = []
var grass_bounds: Array[Rect2] = []
var tile_textures: Array[Texture2D] = []
var exterior_shader: Shader
var surface_materials: Dictionary = {}
var surface_shader: Shader
var house_controls: RefCounted
var client_visits: RefCounted
var weather: RefCounted
var property_opportunity: RefCounted
var bark_material: ShaderMaterial
var map_doors: Array = []
var lamps: Array = []

func setup(owner_node: Node3D) -> void:
	super.setup(owner_node)
	position = BLOCK_OFFSET
	weather = load("res://prototype/weather.gd").new()
	weather.setup(self)
	weather.moon.light_cull_mask = 2
	visible = true
	controls.hide()
	for child in get_children():
		if child is MeshInstance3D:
			child.layers = child.layers | 2
		elif child is Label3D:
			child.set_draw_flag(Label3D.FLAG_DOUBLE_SIDED, false)
	outdoor_sun.light_cull_mask = 2
	property_opportunity=load("res://prototype/property_opportunity.gd").new()
	property_opportunity.setup(self)

func _surface(kind: int, color: String) -> ShaderMaterial:
	var key := str(kind)+color
	if surface_materials.has(key): return surface_materials[key]
	if surface_shader == null:
		surface_shader = Shader.new()
		surface_shader.code = """shader_type spatial;
render_mode diffuse_burley;
uniform vec4 tint : source_color;
uniform int kind = 0;
varying vec3 world_pos;
varying vec3 world_normal;
void vertex(){ world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL); }
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment(){
 vec2 p=abs(world_normal.y)>0.6?world_pos.xz:(abs(world_normal.z)>0.6?world_pos.xy:world_pos.zy);
 float grain=hash(floor(p*95.0)); vec3 c=tint.rgb*(0.96+grain*0.07);
 if(kind==1){vec2 b=vec2(p.x/0.48+mod(floor(p.y/0.22),2.0)*0.5,p.y/0.22);vec2 f=fract(b);float mortar=step(f.x,0.035)+step(f.y,0.07);c=mix(c*(0.94+hash(floor(b))*0.12),vec3(0.36,0.34,0.30),clamp(mortar,0.0,1.0));}
 if(kind==2){vec2 f=fract(p/1.5);float seam=step(f.x,0.008)+step(f.y,0.008);c*=1.0-clamp(seam,0.0,1.0)*0.35;}
 if(kind==3){c*=0.96+hash(floor(p*75.0))*0.08;}
 if(kind==4){float row=step(fract(p.y*7.0),0.08);c*=1.0-row*0.4;}
 ALBEDO=c; ROUGHNESS=0.92;
}"""
	var mat := ShaderMaterial.new()
	mat.shader = surface_shader
	mat.set_shader_parameter("tint", Color(color))
	mat.set_shader_parameter("kind", kind)
	surface_materials[key]=mat
	return mat

func piece(label_text: String, pos: Vector3, size: Vector3, color: String, surface: int = 0) -> MeshInstance3D:
	# Paving is cut around recessed tree soil, so two materials never share a face.
	if surface == 2 and pos.y < 0 and label_text in ["FrontSidewalk","HouseSidewalk","FarSidewalk","AlleySidewalk","InnerAlleySidewalk","SidewalkReturn","ApartmentSideWalkR","RearCourtyard"]:
		var slabs: Array[Rect2] = [Rect2(Vector2(pos.x-size.x/2,pos.z-size.z/2),Vector2(size.x,size.z))]
		for x in [-7.0,9.0,24.5,45.5]:
			var hole := Rect2(Vector2(x-0.75,9.75),Vector2(1.5,1.5))
			var remaining: Array[Rect2] = []
			for slab in slabs:
				if not slab.intersects(hole):
					remaining.append(slab)
					continue
				var cut := slab.intersection(hole)
				for part in [Rect2(slab.position,Vector2(cut.position.x-slab.position.x,slab.size.y)),Rect2(Vector2(cut.end.x,slab.position.y),Vector2(slab.end.x-cut.end.x,slab.size.y)),Rect2(Vector2(cut.position.x,slab.position.y),Vector2(cut.size.x,cut.position.y-slab.position.y)),Rect2(Vector2(cut.position.x,cut.end.y),Vector2(cut.size.x,slab.end.y-cut.end.y))]:
					if part.size.x > 0.001 and part.size.y > 0.001: remaining.append(part)
			slabs=remaining
		var first: MeshInstance3D
		for slab in slabs:
			var part := _raw_piece(label_text,Vector3(slab.get_center().x,pos.y,slab.get_center().y),Vector3(slab.size.x,size.y,slab.size.y),color,surface)
			if first == null: first = part
		return first
	return _raw_piece(label_text,pos,size,color,surface)

func _raw_piece(label_text: String, pos: Vector3, size: Vector3, color: String, surface: int = 0) -> MeshInstance3D:
	var mesh := _box(pos, size, color)
	mesh.name = label_text
	var tile: int=-1
	var tint: String=color
	if surface == 1:
		tile=0
		tint="f0e4d3"
	elif surface == 2:
		tile=2
		tint="e1dfd5"
	elif surface == 4:
		tile=3
		tint="e4e7e5"
	elif surface == 3:
		tile=5
		tint="c3c3b9"
		if label_text in ["Street","RearAlley","SideStreet","ShopParking"]:
			tile=1
			tint="d7d5cb"
		elif label_text == "HouseLawn":
			tile=4
			tint="dde3ca"
		elif label_text == "HouseDoor":
			tile=6
			tint="b39772"
		elif label_text == "ShopAwning":
			tile=-1
			tint="315e4c"
	if label_text == "EntrancePath":
		tile=2
		tint="e1dfd5"
	elif label_text == "ExteriorDoor":
		tile=6
		tint="b39772"
	elif label_text in ["EntryTrim","EntryLintel","WindowFrame","WindowSill"]:
		tile=7
	mesh.material_override = _material(tint,tile)
	if label_text == "TreeTrunk":
		if bark_material == null:
			bark_material=ShaderMaterial.new()
			bark_material.shader=load("res://prototype/bark.gdshader")
		mesh.material_override=bark_material
	return mesh

func building(label_text: String, pos: Vector3, size: Vector3, color: String, windows: bool = true) -> void:
	var bounds := AABB(pos, size)
	building_bounds.append(bounds)
	if is_zero_approx(pos.y):
		piece(label_text+"Foundation",Vector3(pos.x+size.x/2,-0.08,pos.z+size.z/2),Vector3(size.x,0.16,size.z),"777567",2)
	piece(label_text, pos + size / 2.0, size, color, 1)
	piece(label_text + "Roof", pos + Vector3(size.x/2, size.y+0.1, size.z/2), Vector3(size.x+0.3, 0.2, size.z+0.3), "454647", 3)
	var front := Vector3.FORWARD if label_text == "OppositeBuilding" else Vector3.BACK
	if label_text == "OuterHouse": front = Vector3.RIGHT if pos.x < 0 else Vector3.LEFT
	var center := pos + size/2.0
	var door_center := Vector3(center.x,0,center.z) + front * (size.z/2 if front.z != 0 else size.x/2)
	if windows:
		for normal in [Vector3.BACK,Vector3.FORWARD,Vector3.LEFT,Vector3.RIGHT]:
			var tangent := Vector3.RIGHT if normal.z != 0 else Vector3.BACK
			var width: float = size.x if normal.z != 0 else size.z
			var depth: float = size.z if normal.z != 0 else size.x
			var columns := maxi(2,int(width/2.4))
			for row in range(int(size.y/2.7)):
				for col in range(columns):
					var offset := (float(col)+0.5)*width/columns-width/2
					if is_zero_approx(pos.y) and normal == front and row == 0 and absf(offset) < 1.4: continue
					var point: Vector3 = Vector3(center.x,pos.y+1.7+row*2.7,center.z)+normal*(depth/2+0.05)+tangent*offset
					facade_window(point,normal)
	if is_zero_approx(pos.y) and windows:
		entrance(door_center,front)

func facade_part(label_text: String, at: Vector3, size: Vector3, normal: Vector3, color: String) -> void:
	piece(label_text,at,size if normal.z != 0 else Vector3(size.z,size.y,size.x),color)

func facade_window(at: Vector3, normal: Vector3) -> void:
	facade_part("WindowFrame",at,Vector3(0.95,1.35,0.1),normal,"c7baa1")
	facade_part("WindowGlass",at+normal*0.065,Vector3(0.79,1.17,0.035),normal,"46595c")
	facade_part("WindowMullion",at+normal*0.09,Vector3(0.04,1.17,0.025),normal,"c7baa1")
	facade_part("WindowSill",at+Vector3(0,-0.72,0)+normal*0.07,Vector3(1.08,0.1,0.24),normal,"a69f90")

func entrance(at: Vector3, normal: Vector3) -> void:
	var tangent := Vector3.RIGHT if normal.z != 0 else Vector3.BACK
	facade_part("EntryRecess",at+Vector3.UP*1.3+normal*0.025,Vector3(1.55,2.6,0.045),normal,"252a27")
	facade_part("ExteriorDoor",at+Vector3.UP*1.22+normal*0.055,Vector3(1.18,2.44,0.065),normal,"4a493d")
	for side in [-1.0,1.0]:
		facade_part("EntryTrim",at+Vector3.UP*1.3+tangent*side*0.76+normal*0.13,Vector3(0.12,2.6,0.26),normal,"c7baa1")
	facade_part("EntryLintel",at+Vector3.UP*2.65+normal*0.13,Vector3(1.65,0.16,0.26),normal,"c7baa1")
	facade_part("DoorGlass",at+Vector3.UP*1.65+normal*0.10,Vector3(0.72,0.8,0.025),normal,"586e70")
	facade_part("DoorHandle",at+Vector3.UP*1.05+tangent*0.42+normal*0.14,Vector3(0.055,0.22,0.09),normal,"b6a87e")
	facade_part("EntryCanopy",at+Vector3.UP*2.95+normal*0.45,Vector3(2.0,0.12,1.0),normal,"414b44")
	# Flush paths join the nearest sidewalk; these background doors stay closed.
	var distance: float = 2.5
	if normal.x > 0: distance = -18.0-at.x
	elif normal.x < 0: distance = at.x-57.0
	elif normal.z < 0: distance = at.z-26.0
	elif at.z < 0: distance = -24.0-at.z
	distance = maxf(0.6,distance)
	facade_part("EntrancePath",at+normal*(distance/2)+Vector3(0,-0.052,0),Vector3(1.8,0.11,distance),normal,"a9a394")

func fence(a: Vector3, b: Vector3) -> void:
	var length := a.distance_to(b)
	var along_x := absf(a.x-b.x) > absf(a.z-b.z)
	for index in range(int(ceil(length/0.6))+1):
		var at := a.lerp(b, float(index)/ceil(length/0.6))
		piece("FencePost", at+Vector3.UP*0.6, Vector3(0.065,1.2,0.065), "343c36")
	for height in [0.35, 1.0]:
		piece("FenceRail", (a+b)/2+Vector3.UP*height, Vector3(length,0.08,0.08) if along_x else Vector3(0.08,0.08,length), "343c36")
	# Explicit collider for thin rails: the automatic furniture filter skips them.
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 4
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(length,1.2,0.1) if along_x else Vector3(0.1,1.2,length)
	shape.shape = box
	body.add_child(shape)
	body.position = (a+b)/2+Vector3.UP*0.6
	add_child(body)

func tree(at: Vector3) -> void:
	piece("TreeTrunk", at+Vector3.UP*1.3, Vector3(0.36,2.6,0.36), "71563c", 3)
	for offset in [Vector3(-0.55,2.9,0),Vector3(0.55,3.2,0),Vector3(0,3.7,0.15)]:
		var crown := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.95
		sphere.height = 1.95
		crown.mesh = sphere
		crown.position = at+offset
		crown.material_override = _surface(3,"527046")
		add_child(crown)

func _build_block() -> void:
	var atlas: Texture2D = load("res://assets/neighborhood/exterior_atlas.webp")
	var image := atlas.get_image()
	if image.is_compressed(): image.decompress()
	for row in range(3):
		for column in range(3):
			var tile_image := image.get_region(Rect2i(column*418,row*418,418,418))
			tile_image.generate_mipmaps()
			tile_textures.append(ImageTexture.create_from_image(tile_image))
	exterior_shader=load("res://prototype/exterior.gdshader")
	house_controls = load("res://prototype/house_controls.gd").new()
	house_controls.setup(self)
	client_visits = load("res://prototype/client_visits.gd").new()
	client_visits.setup(self)
	# Continuous support under every lot, with the existing apartment cut out.
	piece("BaseFront",Vector3(20.5,-0.18,22.55),Vector3(105,0.2,32.9),"62665b",3)
	piece("BaseRear",Vector3(20.5,-0.18,-23.15),Vector3(105,0.2,25.7),"62665b",3)
	piece("BaseLeft",Vector3(-18.55,-0.18,-2.1),Vector3(26.9,0.2,16.4),"62665b",3)
	piece("BaseRight",Vector3(39.05,-0.18,-2.1),Vector3(67.9,0.2,16.4),"62665b",3)
	piece("Street", Vector3(20.5,-0.18,17), Vector3(105,0.3,10), "505452",3)
	piece("RearAlley", Vector3(20.5,-0.18,-19), Vector3(105,0.3,4), "555a57",3)
	# Split at intersections to avoid overlapping asphalt surfaces.
	for x in [-12.0,51.0]:
		for span in [Vector2(-36,-21),Vector2(-17,12),Vector2(22,39)]:
			piece("SideStreet",Vector3(x,-0.18,(span.x+span.y)/2),Vector3(6,0.3,span.y-span.x),"505452",3)
	# Sidewalks stop at side-road junctions instead of running across them.
	for span in [Vector2(-32,-15),Vector2(-9,48),Vector2(54,73)]:
		if span.x < 25 and span.y > 45:
			for segment in [Vector2(span.x,25),Vector2(45,span.y)]:
				piece("FrontSidewalk",Vector3((segment.x+segment.y)/2,-0.10,9.1),Vector3(segment.y-segment.x,0.18,6),"a9a394",2)
			piece("HouseSidewalk",Vector3(35,-0.10,10.15),Vector3(20,0.18,3.9),"a9a394",2)
		else:
			piece("FrontSidewalk",Vector3((span.x+span.y)/2,-0.10,9.1),Vector3(span.y-span.x,0.18,6),"a9a394",2)
		piece("FarSidewalk",Vector3((span.x+span.y)/2,-0.10,24),Vector3(span.y-span.x,0.18,4),"a9a394",2)
		piece("AlleySidewalk",Vector3((span.x+span.y)/2,-0.10,-22.5),Vector3(span.y-span.x,0.18,3),"a9a394",2)
		piece("InnerAlleySidewalk",Vector3((span.x+span.y)/2,-0.10,-15.7),Vector3(span.y-span.x,0.18,2.6),"a9a394",2)
	for x in [-16.5,-7.5,46.5,55.5]:
		for span in [Vector2(-36,-24),Vector2(-14.4,6.1),Vector2(26,39)]:
			piece("SidewalkReturn",Vector3(x,-0.10,(span.x+span.y)/2),Vector3(3,0.18,span.y-span.x),"a9a394",2)
	piece("ApartmentSideWalkR", Vector3(8.5,-0.10,-2.15), Vector3(6.6,0.18,16.3), "a9a394",2)
	piece("ShopParking", Vector3(18,-0.10,-6.15), Vector3(12,0.18,8.3), "626560",3)
	piece("HouseRearYard", Vector3(35,-0.10,-14.2), Vector3(20,0.18,0.4), "686b5c",3)
	piece("RearCourtyard",Vector3(8,-0.10,-12.35),Vector3(34,0.18,4.1),"a9a394",2)
	# Keep the apartment roofline above the actual ceiling, not inside the rooms.
	building("ApartmentUpper",Vector3(-5.1,4.4,-10.3),Vector3(10.2,5.4,16.4),"8e5743")
	# Thin brick exterior skins preserve the original room finishes and door opening.
	for side in [-1.0,1.0]:
		piece("ApartmentBrickSide",Vector3(side*5.115,2.2,-2.1),Vector3(0.01,4.4,16.4),"8e5743",1)
		if side>0:
			piece("ApartmentBrickFront",Vector3(side*3.075,2.2,6.115),Vector3(4.05,4.4,0.01),"8e5743",1)
		else:
			piece("ApartmentWindowBrickLeft",Vector3(-4.81,2.2,6.115),Vector3(0.58,4.4,0.01),"8e5743",1)
			piece("ApartmentWindowBrickRight",Vector3(-1.885,2.2,6.115),Vector3(1.67,4.4,0.01),"8e5743",1)
			piece("ApartmentWindowBrickBottom",Vector3(-3.62,0.755,6.115),Vector3(1.8,1.51,0.01),"8e5743",1)
			piece("ApartmentWindowBrickTop",Vector3(-3.62,3.595,6.115),Vector3(1.8,1.61,0.01),"8e5743",1)
	# Exterior stone trim surrounds the real opening, leaving glazing and blinds clear.
	for x in [-4.59,-2.65]:
		facade_part("WindowFrame",Vector3(x,2.15,6.19),Vector3(0.14,1.42,0.18),Vector3.BACK,"c7baa1")
	facade_part("WindowFrame",Vector3(-3.62,2.86,6.19),Vector3(2.08,0.14,0.18),Vector3.BACK,"c7baa1")
	facade_part("WindowSill",Vector3(-3.62,1.44,6.25),Vector3(2.16,0.14,0.36),Vector3.BACK,"a69f90")
	for x in [-1.08,1.08]:
		facade_part("EntryTrim",Vector3(x,1.51,6.20),Vector3(0.14,3.02,0.2),Vector3.BACK,"c7baa1")
	# Solid head reveal bridges the original interior frame to the exterior lintel.
	facade_part("EntryLintel",Vector3(0,3.01,5.96),Vector3(2.1,0.20,0.58),Vector3.BACK,"c7baa1")
	facade_part("EntryLintel",Vector3(0,3.09,6.20),Vector3(2.30,0.16,0.2),Vector3.BACK,"c7baa1")
	facade_part("WindowSill",Vector3(0,-0.025,6.23),Vector3(2.1,0.07,0.32),Vector3.BACK,"a69f90")
	piece("ApartmentBrickRear",Vector3(0,2.2,-10.315),Vector3(10.24,4.4,0.01),"8e5743",1)
	piece("ApartmentBrickHeader",Vector3(0,3.715,6.115),Vector3(2.1,1.37,0.01),"8e5743",1)
	load("res://prototype/interiors.gd").new().build(self)
	# A true sloped hip roof, instead of overlapping stacked slabs.
	var vertices := PackedVector3Array([Vector3(24.6,3.6,-14.4),Vector3(45.4,3.6,-14.4),Vector3(45.4,3.6,3.4),Vector3(24.6,3.6,3.4),Vector3(31,6.8,-5.5),Vector3(39,6.8,-5.5)])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in [0,5,4,0,1,5,1,2,5,2,4,5,2,3,4,3,0,4]:
		st.add_vertex(vertices[index])
	st.generate_normals()
	var roof := MeshInstance3D.new()
	roof.name = "HouseHipRoof"
	roof.mesh = st.commit()
	roof.material_override = _material("e4e7e5",3)
	add_child(roof)
	piece("CornerShopRoof",Vector3(17,3.7,2),Vector3(10.3,0.2,8.3),"454647",3)
	_hip_roof(Vector3(35,3.4,4.1),5.2,3.6,0.7)
	for x in [32.9,37.1]: piece("PorchPost",Vector3(x,1.77,5.4),Vector3(0.18,3.1,0.18),"d6cab3")
	piece("HousePath",Vector3(35,-0.08,5.6),Vector3(2.4,0.14,5),"a9a394",2)
	for x in [29.25,40.75]:
		var lawn := Rect2(Vector2(x-4.25,3.3),Vector2(8.5,4.8))
		grass_bounds.append(lawn)
		piece("HouseLawn",Vector3(x,-0.045,5.7),Vector3(8.5,0.06,4.8),"586d3e",3)
		fence(Vector3(x-4.25,0,8.2),Vector3(x+4.25,0,8.2))
	fence(Vector3(25,0,3.2),Vector3(25,0,8.2))
	fence(Vector3(45,0,3.2),Vector3(45,0,8.2))
	_label("HOUSE FOR SALE",Vector3(40,1.45,8.3),0.005)
	piece("SaleSignPost",Vector3(40,0.65,8.3),Vector3(0.08,1.3,0.08),"c7baa1")
	# Rear buildings start beyond the alley, over nine metres behind the grow room.
	for x in [-5.0,7.0,19.0,31.0]:
		building("RearBuilding",Vector3(x,0,-31),Vector3(10,8,7),"806957")
		building("OppositeBuilding",Vector3(x,0,27),Vector3(10,7,7),"817363")
	# Outer lots flank the side roads, fully inside the expanded border.
	for x in [-28.0,61.0]:
		for z in [-9.0,27.0]:
			building("OuterHouse",Vector3(x,0,z),Vector3(7,6,7),"806957")
	# Side-road extensions are deliberately clear to both fence ends.
	for x in [-12.0,51.0]:
		for z in range(-34,39,4):
			if (z >= -22 and z <= -16) or (z >= 11 and z <= 23): continue
			piece("SideRoadStripe",Vector3(x,-0.012,z),Vector3(0.1,0.012,2.0),"c3a04c")
	for x in [-7.0,9.0,24.5,45.5]:
		piece("TreeBed",Vector3(x,-0.055,10.5),Vector3(1.5,0.05,1.5),"4c4737",3)
		tree(Vector3(x,0,10.5))
	for x in [-4.0,18.0,41.0]:
		piece("LampPost",Vector3(x,2.0,23),Vector3(0.13,4,0.13),"303a36")
		piece("LampHead",Vector3(x,4,23),Vector3(0.45,0.25,0.45),"cfbd91")
		var lamp := OmniLight3D.new()
		lamp.position=Vector3(x,3.8,23)
		lamp.omni_range=8.0
		lamp.light_color=Color("ffdda5")
		lamp.light_cull_mask=2
		add_child(lamp)
		lamps.append(lamp)
	for x in range(-30,72,4):
		if (-17 < x and x < -7) or (46 < x and x < 56): continue
		for z in [16.7,17.0]:
			piece("RoadStripe",Vector3(x,-0.012,z),Vector3(2.4,0.012,0.1),"c3a04c")
	for x in [8.5,45.5]:
		for z in range(13,22,2):
			piece("Crosswalk",Vector3(x,-0.01,z),Vector3(2.8,0.01,0.65),"c3c0b0")
	for x in [14.0,18.0,22.0]:
		piece("ParkingLine",Vector3(x,0.004,-7),Vector3(0.06,0.014,4),"b9b9a9")
	# Continuous visible containment outside the side streets and rear alley.
	fence(Vector3(-32,0,-36),Vector3(73,0,-36))
	fence(Vector3(-32,0,39),Vector3(73,0,39))
	fence(Vector3(-32,0,-36),Vector3(-32,0,39))
	fence(Vector3(73,0,-36),Vector3(73,0,39))
	_label("APARTMENTS",Vector3(0,3.45,6.16),0.006)
	_car(18,-6.5,"7d8686",true)
	_car(-1,20.7,"415b50")
	_car(32,13.2,"8d4540")
	var sun := DirectionalLight3D.new()
	outdoor_sun = sun
	sun.rotation_degrees = Vector3(-48,-30,0)
	sun.light_color = Color("f4e4c9")
	sun.light_energy = 0.65
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 38.0
	add_child(sun)

func _build_door_hinge() -> void:
	super._build_door_hinge()
	# Match the structural opening, then overlap the leaf with recessed stops.
	var leaf: MeshInstance3D = door_pivot.get_node("Door")
	leaf.mesh = leaf.mesh.duplicate()
	leaf.mesh.size = Vector3(2.08,2.98,0.14)
	leaf.global_position = Vector3(0,1.505,6.0)
	for part in door_pivot.get_children():
		if part != leaf and part is Node3D:
			part.global_position.z += 0.16
	# Change the pivot without changing any part's closed world transform.
	var parts := door_pivot.get_children()
	for part in parts: part.reparent(host,true)
	door_pivot.position = Vector3(-1.04,0,6.0)
	for part in parts: part.reparent(door_pivot,true)
	for side in [-1.0,1.0]:
		host._add_box("EntryJamb",Vector3(side*1.055,1.51,5.94),Vector3(0.15,3.02,0.44),Color("c8c2b7"),0.8)
		host._add_box("EntryStop",Vector3(side*1.015,1.51,6.11),Vector3(0.08,3.02,0.10),Color("a49d90"),0.8)
	host._add_box("EntryHead",Vector3(0,3.035,5.94),Vector3(2.24,0.15,0.44),Color("c8c2b7"),0.8)
	host._add_box("EntryThreshold",Vector3(0,0.002,5.98),Vector3(2.1,0.024,0.56),Color("746b59"),0.8)

func indoors(pos: Vector3) -> bool:
	return pos.x > -5.1 and pos.x < 5.1 and pos.z > -10.3 and pos.z < 6.1

func _process(delta: float) -> void:
	if not is_instance_valid(host) or not host.fp_ready: return
	active = not indoors(host.fp_player.position)
	controls.hide()
	property_opportunity.update(delta)
	client_visits.update(delta)
	weather.update(delta)
	# Keep the animated sky visible through the apartment's real window.
	host.camera.environment = outdoor_environment

func leave_apartment() -> void:
	toggle_door()

func swing_blocked(pos: Vector3) -> bool:
	if pos.y >= 3.0: return false
	# Test the capsule against samples of the actual inward quarter-circle sweep.
	var point := Vector2(pos.x + 1.04, pos.z - 6.0)
	for i in range(49):
		var angle := float(i)/48.0*PI/2.0
		var direction := Vector2(cos(angle),-sin(angle))
		var nearest := direction*clampf(point.dot(direction),0.0,2.08)
		if point.distance_to(nearest) < 0.36: return true
	return false

func toggle_door() -> void:
	if transitioning: return
	if swing_blocked(host.fp_player.position):
		host.status_label.text = "Door blocked — step back from the inward swing and press E again."
		return # No queued operation, state change or tween after a refusal.
	transitioning = true
	var opening := not door_open
	door_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	door_tween.tween_property(door_pivot,"rotation:y",PI/2.0 if opening else 0.0,0.4)
	door_tween.tween_callback(func():
		door_open = opening
		transitioning = false
		host.status_label.text = "Front door open." if door_open else "Front door closed."
	)
	host.status_label.text = "Opening front door…" if opening else "Closing front door…"

func refresh_controls() -> void:
	controls.hide()

func _interact() -> void:
	property_opportunity.show_details()

func location_label(pos: Vector3) -> String:
	if Rect2(12,-2,10,8).has_point(Vector2(pos.x,pos.z)): return "CENTRAL MARKET"
	if Rect2(25,-14,20,17).has_point(Vector2(pos.x,pos.z)): return "HOUSE TOUR"
	return "NEIGHBORHOOD"

func _interior_piece(id: String, at: Vector3, size: Vector3, color: String, kind: int = 0) -> MeshInstance3D:
	var mesh := _box(at,size,color)
	mesh.name=id
	mesh.material_override = _material("f0e4d3",0) if kind==1 else (_material(color,6) if kind==3 else (_material(color,2) if kind==2 else _material(color)))
	return mesh

func _material(color: String, tile: int = -1, glow: float = 0.0) -> Material:
	var key := "%s:%d:%f" % [color, tile, glow]
	if materials.has(key): return materials[key]
	var material: Material
	if tile >= 0:
		var textured := ShaderMaterial.new()
		textured.shader = exterior_shader
		textured.set_shader_parameter("surface_texture", tile_textures[tile])
		textured.set_shader_parameter("tint", Color(color))
		textured.set_shader_parameter("tile_meters", Vector3(2.4, 1.2, 2.4) if tile == 0 else Vector3(2.0, 2.0, 2.0))
		material = textured
	else:
		var plain := StandardMaterial3D.new()
		plain.albedo_color = Color(color)
		plain.roughness = 0.70
		if glow > 0.0:
			plain.emission_enabled = true
			plain.emission = Color(color)
			plain.emission_energy_multiplier = glow
		material = plain
	materials[key] = material
	return material

func _indoors(point: Vector3) -> bool:
	return indoors(point)

func _door_line_clear(at: Vector3) -> bool:
	var origin: Vector3 = host.camera.global_position
	var query := PhysicsRayQueryParameters3D.create(origin,at,2)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or origin.distance_to(hit.position)>=origin.distance_to(at)-0.12

func _hip_roof(center: Vector3, width: float, depth: float, rise: float) -> void:
	var w:=width/2.0
	var d:=depth/2.0
	var r:=maxf(0.0,w-d*0.55)
	var nw:=center+Vector3(-w,0,-d)
	var ne:=center+Vector3(w,0,-d)
	var sw:=center+Vector3(-w,0,d)
	var se:=center+Vector3(w,0,d)
	var rw:=center+Vector3(-r,rise,0)
	var re:=center+Vector3(r,rise,0)
	var triangles: Array[Vector3]=[nw,ne,re,nw,re,rw,se,sw,rw,se,rw,re,sw,nw,rw,ne,se,re]
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for vertex in triangles: surface.add_vertex(vertex)
	surface.generate_normals()
	var roof:=MeshInstance3D.new()
	roof.mesh=surface.commit()
	roof.material_override=_material("e4e7e5",3)
	roof.name="HousePorchRoof"
	add_child(roof)

func _car(x: float, z: float, color: String, pickup: bool = false) -> void:
	_car_box(Vector3(x,0.63,z),Vector3(4.5,0.64,1.8),color)
	_car_box(Vector3(x-0.2,1.18,z),Vector3(2.25 if not pickup else 1.6,0.7,1.65),color)
	_car_box(Vector3(x-0.2,1.21,z+0.84),Vector3(1.75 if not pickup else 1.20,0.44,0.03),"43606a")
	_car_box(Vector3(x-0.2,1.21,z-0.84),Vector3(1.75 if not pickup else 1.20,0.44,0.03),"43606a")
	_car_box(Vector3(x+0.94,1.21,z),Vector3(0.04,0.44,1.45),"43606a")
	_car_box(Vector3(x+2.26,0.57,z),Vector3(0.05,0.15,1.45),"b1b2a5")
	for side in [-1.0,1.0]:
		for axle in [-1.45,1.45]: _car_wheel(Vector3(x+axle,0.4,z+side*0.89),0.37,0.22,"252826",Vector3(PI/2,0,0))
		_car_box(Vector3(x+2.28,0.76,z+side*0.58),Vector3(0.04,0.22,0.35),"eee3ad",-1,0.15)

func _car_box(at: Vector3, size: Vector3, color: String, _tile: int = -1, glow: float = 0.0) -> void:
	var part := _box(at,size,color)
	part.name="ParkedCar"
	part.material_override=_material(color,-1,glow)
func _car_wheel(at: Vector3, radius: float, height: float, color: String, angles: Vector3) -> void:
	var wheel := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius=radius
	mesh.bottom_radius=radius
	mesh.height=height
	wheel.mesh=mesh
	wheel.material_override=_material(color)
	wheel.position=at
	wheel.rotation=angles
	add_child(wheel)

func use_interior_door(door: Node3D) -> void:
	if door.name == "HouseEntrance" and not door.opened and not property_opportunity.touring and door.to_local(host.fp_player.position).z >= 0.0:
		property_opportunity.show_details()
		return
	door.toggle(host.fp_player.position)
