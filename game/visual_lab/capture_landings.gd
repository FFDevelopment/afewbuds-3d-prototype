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
 var shots=[
  ["second-floor",Vector3(8.3,5.95,-7.4),Vector3(5.1,5.95,-7.4)],
  ["third-floor",Vector3(8.3,9.45,2.2),Vector3(5.1,9.45,2.2)],
  ["front-planters",Vector3(8,2.2,14),Vector3(0,1.5,6.8)],
  ["fire-escape-doors",Vector3(17,8.5,12),Vector3(5.1,6.5,-2.5)]
 ]
 for shot in shots:
  game.camera.global_position=shot[1];game.camera.look_at(shot[2])
  for i in range(2):await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(out+"/"+shot[0]+".png")
 print("LANDING_CAPTURE_PASS")
 quit()
