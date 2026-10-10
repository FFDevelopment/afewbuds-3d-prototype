extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var boot=load("res://visual_lab/boot.tscn").instantiate();root.add_child(boot)
 for i in range(4):await process_frame
 var game=boot.game;var study=boot.get_node("ArtStudy")
 game.set_process(false);game.fp_player.set_physics_process(false)
 for node in game.find_children("*","Control",true,false):node.hide()
 study.label.get_parent().get_parent().hide()
 var out=OS.get_cmdline_user_args()[0]
 var cars=[];var police:=0;var pickup:=0
 for n in game.neighborhood.get_children():
  if not n.has_meta("parked_vehicle"):continue
  cars.append(n)
  if n.get_meta("variant")=="police":police+=1
  if n.get_meta("variant")=="pickup":pickup+=1
  assert(n.has_node("VehicleCollision"))
  var bounds:AABB
  var first:=true
  for mesh in n.find_children("*","MeshInstance3D",true,false):
   var bb=mesh.global_transform*mesh.get_aabb()
   bounds=bb if first else bounds.merge(bb);first=false
  # All parked geometry must fit its bay or stay in the curb strip.
  if n.position.z>12:
   assert(bounds.position.z>12.15 and bounds.end.z<21.85)
   assert(bounds.end.z<15.0 or bounds.position.z>19.0)
  elif n.position.x<25:
   var left:float=14.0 if n.position.x<18 else 18.0
   assert(bounds.position.x>left+.1 and bounds.end.x<left+3.9)
   assert(bounds.position.z> -9.6 and bounds.end.z< -3.4)
  elif n.position.z< -24:
   assert(bounds.position.x>149.3 and bounds.end.x<173.7)
   assert(bounds.end.x<158.5 or bounds.position.x>164.5)
  else:
   assert(bounds.position.x>179.3 and bounds.end.x<198.7)
   assert(bounds.end.x<185.5 or bounds.position.x>191.5)
   assert(bounds.position.z> -14 and bounds.end.z<1)
  await physics_frame
  var query=PhysicsRayQueryParameters3D.create(n.global_position+Vector3(0,4,0),n.global_position+Vector3(0,.1,0),1)
  var hit=game.get_world_3d().direct_space_state.intersect_ray(query)
  assert(not hit.is_empty() and hit.collider==n.get_node("VehicleCollision"))
 assert(cars.size()==12 and police==4 and pickup==1)
 print("PARKED_CARS_PASS count=",cars.size()," police=",police," pickup=",pickup," bay_clearance=true collision=true")
 var shots=[
  ["market-cars",Vector3(23.7,3.3,-13),Vector3(18,1,-6.5)],
  ["curb-sedan",Vector3(6,2.6,16),Vector3(-1,1,20.42)],
  ["police-cars",Vector3(159,3.4,-23.5),Vector3(153.5,1,-26.5)],
  ["public-parking",Vector3(189,5.8,3),Vector3(188,0,-7)]
 ]
 for shot in shots:
  game.camera.global_position=shot[1];game.camera.look_at(shot[2])
  for i in range(2):await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(out+"/"+shot[0]+".png")
 print("CARS_CAPTURE_PASS")
 quit()
