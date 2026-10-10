extends SceneTree
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var boot=load("res://visual_lab/boot.tscn").instantiate()
 root.add_child(boot)
 for i in range(3):await process_frame
 var study=boot.get_node("ArtStudy")
 var game=boot.game
 game.set_process(false);game.fp_player.set_physics_process(false)
 for node in game.find_children("*","Control",true,false):node.hide()
 game.session_paused=false
 game.pause_overlay.hide()
 study.label.get_parent().get_parent().hide()
 var out=OS.get_cmdline_user_args()[0]
 for index in [2,8,9]:
  study.goto_view(index)
  for revised in [true]:
   study.revised=revised;study.apply_look()
   for i in range(2):await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(out+"/view-"+str(index)+( "-revised" if revised else "-original")+".png")
 game.fp_player.position=Vector3(42.8,-3.7,-5.7);game.fp_player.sync_camera();game.camera.look_at(Vector3(44.63,-2.25,-5.7))
 for i in range(2):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out+"/panel-wall.png")
 game.open_house_system()
 var n:Node=game.system_control_panel
 while n!=game:
  if n is CanvasItem:n.show()
  n=n.get_parent()
 for child in game.system_control_panel.find_children("*","Control",true,false):child.show()
 for i in range(3):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out+"/panel-ui.png")
 print("VISUAL_LAB_CAPTURE_PASS")
 quit()
