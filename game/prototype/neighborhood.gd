extends "res://scripts/neighborhood.gd"
## Prototype layout follows the supplied apartment/shop/house plan in world metres.
const BLOCK_OFFSET := Vector3.ZERO
const HOUSE_ENTRY := Vector3(35, 1.4, 3.2)
const APARTMENT_BOUNDS := AABB(Vector3(-5.1, 0, -10.3), Vector3(10.2, 4.4, 16.4))
var door_open := false
var door_tween: Tween
var building_bounds: Array[AABB] = []
var grass_bounds: Array[Rect2] = []
var surface_shader: Shader

func setup(owner_node: Node3D) -> void:
	super.setup(owner_node)
	position = BLOCK_OFFSET
	visible = true
	controls.hide()
	for child in get_children():
		if child is MeshInstance3D:
			child.layers = 2
		elif child is Label3D:
			child.set_draw_flag(Label3D.FLAG_DOUBLE_SIDED, false)
	outdoor_sun.light_cull_mask = 2

func _surface(kind: int, color: String) -> ShaderMaterial:
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
	return mat

func piece(label_text: String, pos: Vector3, size: Vector3, color: String, surface: int = 0) -> MeshInstance3D:
	var mesh := _box(pos, size, color)
	mesh.name = label_text
	mesh.material_override = _surface(surface, color)
	return mesh

func building(label_text: String, pos: Vector3, size: Vector3, color: String, windows: bool = true) -> void:
	var bounds := AABB(pos, size)
	building_bounds.append(bounds)
	piece(label_text, pos + size / 2.0, size, color, 1)
	piece(label_text + "Roof", pos + Vector3(size.x/2, size.y+0.1, size.z/2), Vector3(size.x+0.3, 0.2, size.z+0.3), "454647", 3)
	if windows:
		for row in range(int(size.y / 2.7)):
			for col in range(int(size.x / 2.4)):
				var point := pos + Vector3(1.2 + col*2.4, 1.7+row*2.7, size.z+0.04)
				piece("WindowFrame", point, Vector3(0.95,1.35,0.08), "c7baa1")
				piece("WindowGlass", point+Vector3(0,0,0.05), Vector3(0.79,1.17,0.03), "46595c")
				piece("WindowMullion", point+Vector3(0,0,0.075), Vector3(0.04,1.17,0.02), "c7baa1")

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
	piece("BaseFront",Vector3(19.5,-0.14,16.05),Vector3(75,0.2,19.9),"62665b",3)
	piece("BaseRear",Vector3(19.5,-0.14,-14.15),Vector3(75,0.2,7.7),"62665b",3)
	piece("BaseLeft",Vector3(-11.55,-0.14,-2.1),Vector3(12.9,0.2,16.4),"62665b",3)
	piece("BaseRight",Vector3(31.05,-0.14,-2.1),Vector3(51.9,0.2,16.4),"62665b",3)
	# No exterior mesh enters the full apartment footprint, including grow room.
	piece("Street", Vector3(19,-0.18,17), Vector3(78,0.3,10), "505452",3)
	piece("FrontSidewalk", Vector3(20,-0.10,9.1), Vector3(76,0.18,6), "a9a394",2)
	piece("FarSidewalk", Vector3(20,-0.10,24), Vector3(76,0.18,4), "a9a394",2)
	piece("RearAlley", Vector3(20,-0.10,-14), Vector3(76,0.18,6), "555a57",3)
	piece("LeftStreet", Vector3(-12,-0.18,-3), Vector3(6,0.3,28), "505452",3)
	piece("RightStreet", Vector3(51,-0.18,-3), Vector3(6,0.3,28), "505452",3)
	piece("ApartmentSideWalkL", Vector3(-7,-0.10,-2), Vector3(3.8,0.18,17), "a9a394",2)
	piece("ApartmentSideWalkR", Vector3(8.5,-0.10,-2), Vector3(6.6,0.18,17), "a9a394",2)
	piece("HouseSideWalk", Vector3(45.5,-0.10,-2), Vector3(4.8,0.18,20), "a9a394",2)
	piece("ShopParking", Vector3(18,-0.10,-7), Vector3(12,0.18,10), "626560",3)
	piece("HouseRearYard", Vector3(35,-0.10,-9.5), Vector3(16,0.18,3), "686b5c",3)
	# Keep the apartment roofline above the actual ceiling, not inside the rooms.
	building("ApartmentUpper",Vector3(-5.1,4.4,-10.3),Vector3(10.2,5.4,16.4),"8e5743")
	building("CornerShop",Vector3(12,0,-2),Vector3(10,3.6,8),"925c42",false)
	piece("ShopGlass",Vector3(17,1.55,6.08),Vector3(8.6,2.5,0.12),"617776")
	piece("ShopAwning",Vector3(17,2.9,6.6),Vector3(10.3,0.25,1.2),"315e4c",3)
	for x in [13.0,16.0,19.0,21.0]:
		piece("ShopFrame",Vector3(x,1.55,6.2),Vector3(0.08,2.5,0.08),"c0b292")
	_label("CORNER MARKET",Vector3(17,3.3,6.18),0.008)
	building("House",Vector3(27,0,-8),Vector3(16,3.5,11),"986848",false)
	# A true sloped hip roof, instead of overlapping stacked slabs.
	var vertices := PackedVector3Array([Vector3(26.6,3.6,-8.4),Vector3(43.4,3.6,-8.4),Vector3(43.4,3.6,3.4),Vector3(26.6,3.6,3.4),Vector3(32,6,-2.5),Vector3(38,6,-2.5)])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in [0,5,4,0,1,5,1,2,5,2,4,5,2,3,4,3,0,4]:
		st.add_vertex(vertices[index])
	st.generate_normals()
	var roof := MeshInstance3D.new()
	roof.name = "HouseHipRoof"
	roof.mesh = st.commit()
	roof.material_override = _surface(4,"383e42")
	add_child(roof)
	for x in [29.5,32.0,38.0,40.5]:
		piece("HouseWindowFrame",Vector3(x,1.8,3.08),Vector3(1.4,1.8,0.14),"d1c3a4")
		piece("HouseWindow",Vector3(x,1.8,3.17),Vector3(1.2,1.6,0.05),"495f61")
	piece("HouseDoor",Vector3(35,1.4,3.13),Vector3(1.7,2.8,0.16),"554630",3)
	piece("HousePath",Vector3(35,-0.08,5.6),Vector3(2.4,0.14,5),"a9a394",2)
	for x in [30.25,39.75]:
		var lawn := Rect2(Vector2(x-3.25,3.3),Vector2(6.5,4.8))
		grass_bounds.append(lawn)
		piece("HouseLawn",Vector3(x,-0.045,5.7),Vector3(6.5,0.06,4.8),"586d3e",3)
		fence(Vector3(x-3.25,0,8.2),Vector3(x+3.25,0,8.2))
	fence(Vector3(27,0,3.2),Vector3(27,0,8.2))
	fence(Vector3(43,0,3.2),Vector3(43,0,8.2))
	_label("HOUSE FOR SALE",Vector3(40,1.45,8.3),0.005)
	piece("SaleSignPost",Vector3(40,0.65,8.3),Vector3(0.08,1.3,0.08),"c7baa1")
	# Rear buildings start beyond the alley, over nine metres behind the grow room.
	for x in [-15.0,-3.0,9.0,21.0,33.0,45.0]:
		building("RearBuilding",Vector3(x,0,-27),Vector3(10,8,7),"806957")
		building("OppositeBuilding",Vector3(x,0,27),Vector3(10,7,7),"817363")
	for x in [-7.0,9.0,24.5,45.5]:
		piece("TreeBed",Vector3(x,-0.035,10.5),Vector3(1.5,0.05,1.5),"4c4737",3)
		tree(Vector3(x,0,10.5))
	for x in [-4.0,18.0,41.0]:
		piece("LampPost",Vector3(x,2.0,23),Vector3(0.13,4,0.13),"303a36")
		piece("LampHead",Vector3(x,4,23),Vector3(0.45,0.25,0.45),"cfbd91")
	for x in range(-16,57,4):
		for z in [16.7,17.0]:
			piece("RoadStripe",Vector3(x,-0.012,z),Vector3(2.4,0.012,0.1),"c3a04c")
	for x in [8.5,45.5]:
		for z in range(13,22,2):
			piece("Crosswalk",Vector3(x,-0.01,z),Vector3(2.8,0.01,0.65),"c3c0b0")
	for x in [14.0,18.0,22.0]:
		piece("ParkingLine",Vector3(x,0.004,-7),Vector3(0.06,0.014,4),"b9b9a9")
	# Continuous visible containment outside the side streets and rear alley.
	fence(Vector3(-18,0,-18),Vector3(57,0,-18))
	fence(Vector3(-18,0,26),Vector3(57,0,26))
	fence(Vector3(-18,0,-18),Vector3(-18,0,26))
	fence(Vector3(57,0,-18),Vector3(57,0,26))
	_label("APARTMENTS",Vector3(0,3.45,6.16),0.006)
	var sun := DirectionalLight3D.new()
	outdoor_sun = sun
	sun.rotation_degrees = Vector3(-48,-30,0)
	sun.light_color = Color("f4e4c9")
	sun.light_energy = 0.65
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

func _process(_delta: float) -> void:
	if not is_instance_valid(host) or not host.fp_ready: return
	active = not indoors(host.fp_player.position)
	controls.hide()
	var night: bool = host.day_phase == "NIGHT"
	outdoor_sun.light_energy = 0.08 if night else 0.65
	outdoor_environment.background_color = Color("202c41") if night else Color("b5c7d0")
	host.camera.environment = outdoor_environment if active else null

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
	host.status_label.text = "Rod's property offer is ready. Tours and ownership are coming later." if host.property_offer_unlocked else "This house is not available yet. Keep building your operation and watch for Rod's text."
