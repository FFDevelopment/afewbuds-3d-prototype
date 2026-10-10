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
 var count:=0
 for n in game.neighborhood.get_children():
  if not n is MeshInstance3D:continue
  var title=str(n.name)
  if not (title.begins_with("RearBuilding") or title.begins_with("OppositeBuilding") or title.begins_with("OuterHouse") or title.begins_with("EastResidence")):continue
  if title.contains("Roof") or title.contains("Foundation"):continue
  assert(is_equal_approx(n.mesh.size.y,10.5));count+=1
 var rows={}
 for record in game.neighborhood.window_layout_records:
  if record.building=="ApartmentUpper":continue
  rows[record.row]=true
  assert(record.at.y-record.floor>1.5)
  assert(record.ceiling-record.at.y>1.0)
 assert(rows.size()==3 and count>20)
 var garages:=0
 for n in game.neighborhood.get_children():
  if str(n.name).begins_with("GarageBrick"):
   assert(n.material_override is ShaderMaterial)
   assert(n.material_override.shader.resource_path=="res://visual_lab/surface.gdshader")
   garages+=1
 assert(garages==5)
 print("STORIES_GEOMETRY_PASS buildings=",count," rows=",rows.size()," garages=",garages)
 var shots=[
  ["three-story-street",Vector3(77,3.2,21),Vector3(89,5.2,-1)],
  ["rear-buildings",Vector3(9,3,-20),Vector3(18,5,-28)],
  ["garage-bricks",Vector3(82,2.8,-20),Vector3(83,2,-12)]
 ]
 for shot in shots:
  game.camera.global_position=shot[1];game.camera.look_at(shot[2])
  for i in range(2):await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(out+"/"+shot[0]+".png")
 print("STORIES_CAPTURE_PASS")
 quit()
