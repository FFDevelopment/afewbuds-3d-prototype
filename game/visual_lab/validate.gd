extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var boot=load("res://visual_lab/boot.tscn").instantiate()
 root.add_child(boot)
 for i in range(12):await process_frame
 var study=boot.get_node("ArtStudy")
 assert(study.changes.size()>20,"Missing material pass")
 study.revised=false;study.apply_look()
 assert(not study.detail.visible)
 for item in study.proportions:assert(item.node.transform==item.before)
 for item in study.changes:assert(item.node.material_override==item.before)
 study.revised=true;study.apply_look()
 for item in study.changes:assert(item.node.material_override==item.after)
 for item in study.proportions:
  assert(item.node.transform==item.after)
  if item.node.has_meta("visual_lab_floor"):
   var top:float=item.node.position.y+item.node.mesh.size.y*item.node.scale.y*.5
   var bottom:float=item.node.position.y-item.node.mesh.size.y*item.node.scale.y*.5
   var floor_base:float=study.UPPER_FLOOR_BASE+(int(item.node.get_meta("visual_lab_floor"))-2)*study.UPPER_STORY_HEIGHT
   assert(bottom>floor_base+.11)
   assert(top<floor_base+study.UPPER_STORY_HEIGHT-.15)
 study.mobile=true;study.apply_look();assert(root.msaa_3d==Viewport.MSAA_DISABLED)
 for i in range(study.views.size()):
  study.goto_view(i)
  assert(boot.game.fp_player.position.is_equal_approx(study.views[i]))
 var cloud=root.get_node("AFBCloud")
 var reply=await cloud.request_json("/test",{})
 assert(reply.has("error"));assert(cloud.find_children("*","HTTPRequest",true,false).is_empty())
 assert(ProjectSettings.get_setting("application/config/custom_user_dir_name")=="AFewBuds-Visual-Lab-01")
 # Front-door pieces must use the exact same plaster as the rest of the room.
 var expected=boot.game.get_node("LeftWall").material_override
 for wall in ["RightWall","FrontWallL","FrontWallR","FrontWallHeader","FrontWindowLeft","FrontWindowRight","FrontWindowBottom","FrontWindowTop"]:
  var wall_node=boot.game.get_node_or_null(wall)
  if wall_node:assert(wall_node.material_override==expected,"Apartment wall mismatch: "+wall)
 var panes=0
 for node in boot.game.neighborhood.get_children():
  if not node is MeshInstance3D:continue
  var part=str(node.get_meta("fit_part",""))
  if part in ["HouseFrontWindow","HouseSideWindow","HouseRearWindow","BathroomWindow"]:
   panes+=1
   assert(node.material_override is StandardMaterial3D,"Opaque house window: "+part)
   assert(node.material_override.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA)
  if str(node.name).begins_with("HousePorchRoof"):
   assert("cull_disabled" in node.material_override.shader.code)
 assert(panes==10,"Expected all ten real house windows")
 var soffit=study.detail.get_node("HouseEaveSoffit")
 assert(soffit.position.y-soffit.mesh.size.y/2<3.5)
 assert(soffit.position.y+soffit.mesh.size.y/2>3.6)
 # The house floor/ceiling span all ten room lights. Compatibility defaults to eight.
 var max_house_lights=0
 var lamps=boot.game.find_children("*","OmniLight3D",true,false)
 for node in boot.game.neighborhood.get_children():
  if not node is MeshInstance3D:continue
  if not str(node.name) in ["HouseFloor","HouseCeiling"]:continue
  var bounds: AABB=node.global_transform*node.get_aabb()
  var overlapping=0
  for lamp in lamps:
   if (lamp.light_cull_mask & node.layers)==0:continue
   var radius:float=lamp.omni_range
   var light_bounds=AABB(lamp.global_position-Vector3.ONE*radius,Vector3.ONE*radius*2)
   if bounds.intersects(light_bounds):overlapping+=1
  max_house_lights=maxi(max_house_lights,overlapping)
 assert(max_house_lights<=int(ProjectSettings.get_setting("rendering/limits/opengl/max_lights_per_object")))
 print("HOUSE_LIGHT_BUDGET_PASS overlaps=",max_house_lights," limit=",ProjectSettings.get_setting("rendering/limits/opengl/max_lights_per_object"))
 print("HOUSE_WINDOWS_ROOF_PASS panes=",panes)
 var stairs=study.fire_escape
 assert(stairs.flights.size()==3 and stairs.landings.size()==4)
 for i in range(3):
  assert(is_equal_approx(stairs.flights[i].from.y,stairs.landings[i].y))
  assert(is_equal_approx(stairs.flights[i].to.y,stairs.landings[i+1].y))
 assert(stairs.landings[-1].x0<5.25,"Roof bridge must overlap roof")
 boot.game.set_process(false)
 boot.game.fp_player.set_physics_process(false)
 var player=boot.game.fp_player
 player.position=Vector3(6.02,.15,3.5);player.velocity=Vector3.ZERO
 var route=[Vector3(6.02,4.4,-7.3),Vector3(7.75,4.4,-7.3),Vector3(7.75,7.9,2.2),Vector3(6.02,7.9,2.2),Vector3(6.02,11.6,-7.3),Vector3(4.4,11.6,-7.3)]
 for target in route:
  var reached=false
  for tick in range(600):
   await physics_frame
   var flat=Vector3(target.x-player.position.x,0,target.z-player.position.z)
   if flat.length()<.11:
    reached=true;break
   var direction=flat.normalized()
   player.velocity.x=direction.x*3.4;player.velocity.z=direction.z*3.4
   player.velocity.y=-.5 if player.is_on_floor() else player.velocity.y-18.0/60.0
   player.move_and_slide()
  assert(reached,"Fire escape blocked at "+str(player.position)+" toward "+str(target))
  assert(absf(player.position.y-target.y)<.35,"Wrong landing height: "+str(player.position))
 print("FIRE_ESCAPE_WALK_PASS roof=",player.position)
 assert(not boot.game.neighborhood.indoors(Vector3(0,11.6,0)),"Roof classified indoors")
 assert(boot.game.neighborhood.indoors(Vector3(0,2,0)),"Apartment interior lost")
 assert(study.solid_details.size()>=5)
 var basement=boot.game.get_node("BasementExpansion")
 assert(basement.cut_count>=2,"Stair opening must cut house floor and terrain")
 player.position=Vector3(43.8,.12,-7.8);player.velocity=Vector3.ZERO
 for target in [Vector3(43.8,-1.9,-13),Vector3(42,-1.9,-13),Vector3(42,-3.8,-7.8),Vector3(42,-3.8,-6.6),Vector3(42,-1.9,-13),Vector3(43.8,-1.9,-13),Vector3(43.8,0,-7.8)]:
  var reached=false
  for tick in range(600):
   await physics_frame
   var flat=Vector3(target.x-player.position.x,0,target.z-player.position.z)
   if flat.length()<.11:reached=true;break
   var direction=flat.normalized()
   player.velocity.x=direction.x*3.4;player.velocity.z=direction.z*3.4
   player.velocity.y=-.5 if player.is_on_floor() else player.velocity.y-18.0/60.0
   player.move_and_slide()
  assert(reached,"Basement blocked at "+str(player.position)+" toward "+str(target))
  assert(absf(player.position.y-target.y)<.35,"Basement height mismatch "+str(player.position))
 print("BASEMENT_ROUND_TRIP_PASS cuts=",basement.cut_count)
 print("VISUAL_LAB_VALIDATION_PASS materials=",study.changes.size()," details=",study.detail.get_child_count())
 quit()
