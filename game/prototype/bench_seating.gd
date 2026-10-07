extends RefCounted
## Measured midpoint of Eye_L/Eye_R in the shared rig's sit animation.
const RIG_SEAT_TOP:=.4682184907339378
const RIG_SEATED_EYES:=Vector3(0,1.562837,-.106215)
var world:Node3D
var benches:Array[Dictionary]=[]
var seated:=-1
var return_position:=Vector3.ZERO

static func eyes(at:Vector3,facing:float,seat_top:float) -> Vector3:
	return at+Basis(Vector3.UP,facing)*(RIG_SEATED_EYES+Vector3.UP*(seat_top-RIG_SEAT_TOP))

func setup(owner:Node3D) -> void:world=owner

func add(at:Vector3,facing:float,seat_top:float) -> void:
	benches.append({"at":at,"facing":facing,"seat_top":seat_top})

func target() -> String:
	if seated>=0:return "bench_"+str(seated)
	var closest:=-1;var distance:=2.0
	for i in range(benches.size()):
		var b:Dictionary=benches[i]
		var local:Vector3=Basis(Vector3.UP,b.facing).inverse()*(world.host.camera.position-b.at)
		# Approach the open front, never pull the player through the backrest.
		var d:=Vector2(local.x,local.z).length()
		if local.z<-.35 and absf(local.x)<1.4 and d<distance:
			closest=i;distance=d
	return "bench_"+str(closest) if closest>=0 else ""

func stand() -> bool:
	if seated<0:return true
	var b:Dictionary=benches[seated]
	var candidates:Array[Vector3]=[return_position]
	for x in [0.0,-.65,.65]:candidates.append(b.at+Basis(Vector3.UP,b.facing)*Vector3(x,.1,-1.05))
	var player:CharacterBody3D=world.host.fp_player
	for at in candidates:
		at.y=.1
		var query:=PhysicsShapeQueryParameters3D.new()
		query.shape=player.get_child(0).shape;query.transform=Transform3D(Basis.IDENTITY,at+Vector3.UP*1.215);query.collision_mask=1;query.exclude=[player.get_rid()]
		if not world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():continue
		player.position=at;player.velocity=Vector3.ZERO;seated=-1;player.sync_camera();return true
	world.host.status_label.text="The space in front of the bench is blocked."
	return false

func use(id:String) -> void:
	if world.transitioning or world.host._any_modal_open() or world.host.daily_report_pending:return
	if seated>=0:stand();return
	if id!=target() or not id.begins_with("bench_"):return
	var b:Dictionary=benches[int(id.trim_prefix("bench_"))]
	var player:CharacterBody3D=world.host.fp_player
	return_position=player.position;seated=int(id.trim_prefix("bench_"))
	player.position=eyes(b.at,b.facing,b.seat_top)-Vector3.UP*player.EYE_HEIGHT
	player.yaw=b.facing;player.pitch=0;player.velocity=Vector3.ZERO;player.sync_camera()
	world.host.status_label.text="Relaxing on the bench. Move to stand up."
