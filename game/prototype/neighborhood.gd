extends "res://scripts/neighborhood.gd"
## Prototype layout follows the supplied apartment/shop/house plan in world metres.
const BLOCK_OFFSET := Vector3.ZERO
const HOUSE_ENTRY := Vector3(35, 1.4, 3.2)
const APARTMENT_BOUNDS := AABB(Vector3(-5.1, 0, -10.3), Vector3(10.2, 4.4, 16.4))
const Swing = preload("res://prototype/door_swing.gd")
var door_open_angle := PI/2.0
var door_open := false
var door_pass_through:=false
var door_tween: Tween
const MAP_RECT := Rect2(-32, -36, 233, 75)
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
const ScalePolicy=preload("res://scripts/scale_policy.gd")
const TreeLayout=preload("res://prototype/east_expansion.gd")
var window_layout_records:Array[Dictionary]=[]
var location_ops: RefCounted
var collision_timer:=0.0
var police_station:Node3D
var bench_seating=preload("res://prototype/bench_seating.gd").new()
var couch_seated:=false
var couch_stand:=Vector3.ZERO

func setup(owner_node: Node3D) -> void:
	bench_seating.setup(self)
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
	location_ops=load("res://scripts/location_ops.gd").new()
	location_ops.setup(self)

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
	if pos.y < 0 and ((surface == 2 and label_text in ["FrontSidewalk","HouseSidewalk","FarSidewalk","AlleySidewalk","InnerAlleySidewalk","SidewalkReturn","ApartmentSideWalkR","RearCourtyard","EastPaving"]) or label_text == "HouseLawn"):
		var slabs: Array[Rect2] = [Rect2(Vector2(pos.x-size.x/2,pos.z-size.z/2),Vector2(size.x,size.z))]
		for site in TreeLayout.TREE_SITES:
			var hole := Rect2(Vector2(site.x,site.z)-Vector2.ONE*TreeLayout.TREE_BED_SIZE/2,Vector2.ONE*TreeLayout.TREE_BED_SIZE)
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
	_mark_exterior_ground_visual(mesh,pos,size)
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
	# Background residences have three complete stories, rather than a stretched
	# two-row facade. The playable apartment upper shell keeps its own layout.
	var residential := label_text in ["RearBuilding","OppositeBuilding","OuterHouse","EastResidence"]
	var story_height := 3.5 if residential else 3.24
	var window_center := 2.04
	if residential: size.y = story_height * 3.0
	else: size.y *= ScalePolicy.BACKGROUND_BUILDING_SCALE_Y
	var bounds := AABB(pos, size)
	building_bounds.append(bounds)
	if is_zero_approx(pos.y): _obstacle(pos.x+size.x/2,pos.z+size.z/2,size.x,size.z)
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
			for row in range(roundi(size.y/story_height) if residential else int(size.y/story_height)):
				for col in range(columns):
					var offset := (float(col)+0.5)*width/columns-width/2
					if is_zero_approx(pos.y) and normal == front and row == 0 and absf(offset) < 1.4: continue
					var point: Vector3 = Vector3(center.x,pos.y+window_center+row*story_height,center.z)+normal*(depth/2+0.05)+tangent*offset
					window_layout_records.append({"at":point,"floor":pos.y+row*story_height,"ceiling":minf(pos.y+(row+1)*story_height,pos.y+size.y),"building":label_text,"row":row})
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
	facade_part("EntryRecess",at+Vector3.UP*1.475+normal*0.025,Vector3(1.55,2.95,0.045),normal,"252a27")
	facade_part("ExteriorDoor",at+Vector3.UP*1.425+normal*0.055,Vector3(1.18,2.85,0.065),normal,"4a493d")
	for side in [-1.0,1.0]:
		facade_part("EntryTrim",at+Vector3.UP*1.475+tangent*side*0.76+normal*0.13,Vector3(0.12,2.95,0.26),normal,"c7baa1")
	facade_part("EntryLintel",at+Vector3.UP*3.0+normal*0.13,Vector3(1.65,0.16,0.26),normal,"c7baa1")
	facade_part("DoorGlass",at+Vector3.UP*1.92+normal*0.10,Vector3(0.72,0.8,0.025),normal,"586e70")
	facade_part("DoorHandle",at+Vector3.UP*1.30+tangent*0.42+normal*0.14,Vector3(0.055,0.22,0.09),normal,"b6a87e")
	facade_part("EntryCanopy",at+Vector3.UP*3.28+normal*0.45,Vector3(2.0,0.12,1.0),normal,"414b44")
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
	var before:=get_children()
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
	for child in get_children():
		if child not in before and child is Node3D:
			child.position=at+(child.position-at)*ScalePolicy.TREE_SCALE
			child.scale*=ScalePolicy.TREE_SCALE

func _build_block() -> void:
	house_controls=load("res://prototype/house_controls.gd").new()
	house_controls.setup(self)
	client_visits=load("res://prototype/client_visits.gd").new()
	client_visits.setup(self)
	var atlas: Texture2D=load("res://assets/neighborhood/exterior_atlas.webp")
	var image:=atlas.get_image()
	if image.is_compressed():image.decompress()
	image.generate_mipmaps()
	for row in range(3):
		for column in range(3):
			var tile_image:=image.get_region(Rect2i(column*418,row*418,418,418))
			tile_image.generate_mipmaps()
			tile_textures.append(ImageTexture.create_from_image(tile_image))
	exterior_shader=load("res://prototype/exterior.gdshader")
	exterior_box(Vector3(20.5,-0.20,1.5),Vector3(117,0.20,87),"c3c3b9",5)
	piece("Street", Vector3(20.5,-0.18,17), Vector3(117,0.3,10), "505452",3)
	piece("RearAlley", Vector3(20.5,-0.18,-19), Vector3(117,0.3,4), "555a57",3)
	# Split at intersections to avoid overlapping asphalt surfaces.
	for x in [-12.0,51.0]:
		for span in [Vector2(-42,-21),Vector2(-17,12),Vector2(22,45)]:
			piece("SideStreet",Vector3(x,-0.18,(span.x+span.y)/2),Vector3(6,0.3,span.y-span.x),"505452",3)
	# Sidewalks stop at side-road junctions instead of running across them.
	for span in [Vector2(-38,-15),Vector2(-9,48),Vector2(54,79)]:
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
		for span in [Vector2(-42,-24),Vector2(-14.4,6.1),Vector2(26,45)]:
			piece("SidewalkReturn",Vector3(x,-0.10,(span.x+span.y)/2),Vector3(3,0.18,span.y-span.x),"a9a394",2)
	# Preserve the cloud-test stone curb finish around the prototype's street mouths.
	for span in [Vector2(-38,-15),Vector2(-9,48),Vector2(54,79)]:
		for z in [12.0,22.0,-21.0,-17.0]:
			exterior_box(Vector3((span.x+span.y)/2,0.025,z),Vector3(span.y-span.x,0.12,0.12),"c8c4b9",7)
	for x in [-15.0,-9.0,48.0,54.0]:
		for span in [Vector2(-42,-21),Vector2(-17,12),Vector2(22,45)]:
			exterior_box(Vector3(x,0.025,(span.x+span.y)/2),Vector3(0.12,0.12,span.y-span.x),"c8c4b9",7)
	piece("ApartmentSideWalkR", Vector3(8.5,-0.10,-2.10), Vector3(6.6,0.18,16.4), "a9a394",2)
	piece("ShopParking", Vector3(18,-0.10,-6.15), Vector3(12,0.18,8.3), "626560",3)
	piece("HouseRearYard", Vector3(35,-0.10,-14.2), Vector3(20,0.18,0.4), "686b5c",3)
	piece("RearCourtyard",Vector3(8,-0.10,-12.35),Vector3(34,0.18,4.1),"a9a394",2)
	# Keep the apartment roofline above the actual ceiling, not inside the rooms.
	building("ApartmentUpper",Vector3(-5.1,4.4,-10.3),Vector3(10.2,5.4,16.4),"8e5743")
	# Thin brick exterior skins preserve the original room finishes and door opening.
	for side in [-1.0,1.0]:
		piece("ApartmentBrickSide",Vector3(side*5.115,2.2,-2.1),Vector3(0.01,4.4,16.4),"f0e4d3",1)
		if side>0:
			piece("ApartmentBrickFront",Vector3(side*3.075,2.2,6.115),Vector3(4.05,4.4,0.01),"f0e4d3",1)
		else:
			piece("ApartmentWindowBrickLeft",Vector3(-4.81,2.2,6.115),Vector3(0.58,4.4,0.01),"f0e4d3",1)
			piece("ApartmentWindowBrickRight",Vector3(-1.885,2.2,6.115),Vector3(1.67,4.4,0.01),"f0e4d3",1)
			piece("ApartmentWindowBrickBottom",Vector3(-3.62,0.755,6.115),Vector3(1.8,1.51,0.01),"f0e4d3",1)
			piece("ApartmentWindowBrickTop",Vector3(-3.62,3.595,6.115),Vector3(1.8,1.61,0.01),"f0e4d3",1)
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
	piece("ApartmentBrickRear",Vector3(0,2.2,-10.315),Vector3(10.24,4.4,0.01),"f0e4d3",1)
	piece("ApartmentBrickHeader",Vector3(0,3.715,6.115),Vector3(2.1,1.37,0.01),"f0e4d3",1)
	_obstacle(0,-2.1,10.2,16.4)
	load("res://prototype/interiors.gd").new().build(self)
	piece("CornerShopRoof",Vector3(17,3.7,2),Vector3(10.3,0.2,8.3),"454647",3)
	_hip_roof(Vector3(35,3.6,-5.5),20.8,17.8,3.2)
	_hip_roof(Vector3(35,3.4,4.1),5.2,3.6,0.7)
	for x in [32.9,37.1]: exterior_box(Vector3(x,1.77,5.4),Vector3(0.18,3.1,0.18),"d6cab3",7)
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
	for x in [-28.0]: # East-edge exteriors are reorganized by east_expansion.gd.
		for z in [-9.0,27.0]:
			building("OuterHouse",Vector3(x,0,z),Vector3(7,6,7),"806957")
	# Side-road extensions are deliberately clear to both fence ends.
	for x in [-12.0,51.0]:
		for z in range(-34,39,4):
			if (z >= -22 and z <= -16) or (z >= 11 and z <= 23): continue
			piece("SideRoadStripe",Vector3(x,-0.012,z),Vector3(0.1,0.012,2.0),"c3a04c")
	# Leave a clear approach to both crosswalks beside the wider tree trunks.
	for i in range(4):TreeLayout.plant(self,TreeLayout.TREE_SITES[i])
	for x in [-4.0,18.0,41.0]:
		piece("LampPost",Vector3(x,2.0,23),Vector3(0.13,4,0.13),"303a36")
		piece("LampHead",Vector3(x,4,23),Vector3(0.45,0.25,0.45),"cfbd91")
	for x in range(-30,72,4):
		if (-17 < x and x < -7) or (46 < x and x < 56): continue
		for z in [16.7,17.0]:
			piece("RoadStripe",Vector3(x,-0.012,z),Vector3(2.4,0.012,0.1),"c3a04c")
	for x in [8.5,45.5]:
		for z in range(13,22,2):
			piece("Crosswalk",Vector3(x,-0.01,z),Vector3(2.8,0.01,0.65),"c3c0b0")
	for x in [14.0,18.0,22.0]:
		piece("ParkingLine",Vector3(x,0.004,-6.5),Vector3(0.06,0.014,6.2),"b9b9a9")
	# Continuous visible containment outside the side streets and rear alley.
	fence(Vector3(-32,0,-36),Vector3(73,0,-36))
	fence(Vector3(-32,0,39),Vector3(73,0,39))
	fence(Vector3(-32,0,-36),Vector3(-32,0,39))
	# The east fence moves outward; all core geometry stays in place.
	load("res://prototype/east_expansion.gd").new().build(self)
	load("res://prototype/police_district.gd").new().build(self)
	police_station=load("res://prototype/police_station.gd").new();police_station.name="PoliceStation";add_child(police_station);police_station.build(self)
	_label("APARTMENTS",Vector3(0,3.45,6.16),0.006)
	_car(16,-6.5,"7d8686",true,PI/2)
	_car(-1,20.42,"415b50",false,PI)
	_car(20,-6.5,"8d4540",false,PI/2)
	for x in [-4.0,18.0,41.0]: _lamp(x,23.0)
	var sun := DirectionalLight3D.new()
	outdoor_sun = sun
	sun.rotation_degrees = Vector3(-48,-30,0)
	sun.light_color = Color("f4e4c9")
	sun.light_energy = 0.65
	sun.shadow_enabled=true
	sun.directional_shadow_max_distance=38.0
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
	return pos.y > -.5 and pos.y < 4.4 and pos.x > -5.1 and pos.x < 5.1 and pos.z > -10.3 and pos.z < 6.1

func _process(delta: float) -> void:
	if not is_instance_valid(host) or not host.fp_ready: return
	active = not indoors(host.fp_player.position)
	controls.hide()
	if door_pass_through and not transitioning:_refresh_apartment_door_collision()
	property_opportunity.update(delta)
	location_ops.update(delta)
	client_visits.update(delta)
	weather.update(delta)
	# Keep the animated sky visible through the apartment's real window.
	host.camera.environment = outdoor_environment

func leave_apartment() -> void:
	toggle_door()

func swing_blocked(pos: Vector3) -> bool:
	if pos.y >= 3.0: return false
	var point := Vector2(pos.x+1.04,pos.z-6.0)
	var angle := door_open_angle if door_open else Swing.away_angle(point)
	return Swing.blocked(point,2.08,angle,0.36)

func toggle_door() -> void:
	if transitioning: return
	if location_ops!=null and not location_ops.apartment_lease_active():
		host.status_label.text="Apartment lease released. The door is locked."
		return
	transitioning = true
	door_pass_through=true
	_set_apartment_door_collision(false)
	var opening := not door_open
	if opening:
		var point := Vector2(host.fp_player.position.x+1.04,host.fp_player.position.z-6.0)
		door_open_angle=Swing.away_angle(point)
	door_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	door_tween.tween_property(door_pivot,"rotation:y",door_open_angle if opening else 0.0,0.4)
	door_tween.tween_callback(func():
		door_open = opening
		transitioning = false
		_refresh_apartment_door_collision()
		host.status_label.text = "Front door open." if door_open else "Front door closed."
	)
	host.status_label.text = "Opening front door…" if opening else "Closing front door…"

func refresh_controls() -> void:
	controls.hide()

func _interact() -> void:
	property_opportunity.show_details()

func location_label(pos: Vector3) -> String:
	if police_station!=null and police_station.covers(pos):return police_station.room_title(pos+Vector3.UP*2.16)
	if Rect2(12,-2,10,8).has_point(Vector2(pos.x,pos.z)): return "CENTRAL MARKET"
	if Rect2(25,-14,20,17).has_point(Vector2(pos.x,pos.z)): return "HOUSE" if bool(host.property_opportunity_state.get("relocated",false)) else "HOUSE TOUR"
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
	material.set_meta("lab_tile",tile)
	material.set_meta("lab_color",color)
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

func _car(x: float, z: float, color: String, pickup: bool = false, yaw: float = 0.0, police: bool = false) -> void:
	var vehicle=load("res://prototype/parked_vehicle.gd").new()
	vehicle.name="ParkedVehicle";add_child(vehicle)
	vehicle.position=Vector3(x,0,z);vehicle.rotation.y=yaw
	vehicle.scale=Vector3(.96,1,1)*ScalePolicy.CAR_SCALE
	vehicle.build(color,pickup,police)
	var footprint=Basis(Vector3.UP,yaw)*Vector3(4.9*.96,0,2.15)
	_obstacle(x,z,absf(footprint.x)*ScalePolicy.CAR_SCALE,absf(footprint.z)*ScalePolicy.CAR_SCALE)

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
	if door.name == "HouseEntrance" and not door.opened and not property_opportunity.touring and not bool(host.property_opportunity_state.get("relocated",false)) and door.to_local(host.fp_player.position).z >= 0.0:
		property_opportunity.show_details()
		return
	door.toggle(host.fp_player.position)

func _mark_exterior_ground_visual(mesh: MeshInstance3D, at: Vector3, size: Vector3) -> void:
	# The desktop adapter used to auto-create a solid StaticBody3D for every
	# sufficiently large BoxMesh. Roads, sidewalks, parking slabs, lawns and
	# 12 cm curbs therefore became separate floor colliders with snagging lips.
	# Keep this low exterior geometry visual-only; apartment.gd installs one
	# continuous flat physics floor underneath the playable neighborhood.
	var top:=at.y+size.y*.5
	var bottom:=at.y-size.y*.5
	if size.y<=.31 and bottom<=.05 and top<=.15:
		mesh.set_meta("no_collision",true)
		mesh.set_meta("exterior_ground_visual",true)

func exterior_box(at: Vector3, size: Vector3, color: String, tile: int=-1, glow: float=0.0) -> MeshInstance3D:
	var part:=_box(at,size,color)
	_mark_exterior_ground_visual(part,at,size)
	part.material_override=_material(color,tile,glow)
	return part
func _toggle_couch() -> void:
	if couch_seated:
		host.fp_player.position=couch_stand
		couch_seated=false
	else:
		couch_stand=host.fp_player.position
		couch_seated=true
		host.fp_player.position=host.inventory_system.furniture.equipment_world.seat_eye()-Vector3.UP*host.fp_player.EYE_HEIGHT
		host.fp_player.yaw=0;host.fp_player.pitch=0
	host.fp_player.sync_camera()

func _lamp(x: float, z: float) -> void:
	_cylinder(Vector3(x,2.0,z),0.065,4.0,"29362e")
	_obstacle(x,z,0.18,0.18)
	exterior_box(Vector3(x,4.06,z),Vector3(0.42,0.46,0.42),"dec89d",-1,0.6)
	exterior_box(Vector3(x,4.35,z),Vector3(0.50,0.08,0.50),"29362e")
	var light:=OmniLight3D.new()
	light.position=Vector3(x,3.7,z)
	light.light_color=Color("ffd2a1")
	light.omni_range=8.0
	light.light_energy=0.0
	add_child(light)
	light.light_cull_mask=2
	lamps.append(light)


func _obstacle(x: float,z: float,width: float,depth: float) -> void:
	obstacles.append(Rect2(x-width/2,z-depth/2,width,depth))
func _cylinder(at: Vector3,radius: float,height: float,color: String,angles: Vector3=Vector3.ZERO) -> void:
	_car_wheel(at,radius,height,color,angles)

func _set_apartment_door_collision(solid: bool) -> void:
	for body in door_pivot.find_children("*","StaticBody3D",true,false):
		if not body.has_meta("solid_layer"):body.set_meta("solid_layer",body.collision_layer)
		body.collision_layer=int(body.get_meta("solid_layer")) if solid else 0
func _refresh_apartment_door_collision() -> void:
	var p:Vector3=door_pivot.to_local(host.fp_player.global_position)
	door_pass_through=transitioning or Vector2(p.x,p.z).distance_to(Vector2(clampf(p.x,0,2.08),0))<.42
	_set_apartment_door_collision(not door_pass_through)
