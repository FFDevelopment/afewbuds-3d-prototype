extends SceneTree
const Actions=preload("res://scripts/production_actions.gd")
func _initialize():call_deferred("run")
func run():
 var game=load("res://prototype/apartment.tscn").instantiate();root.add_child(game);game.hide()
 for n in game.find_children("*","CanvasLayer",true,false):n.hide()
 await process_frame
 game.set_process(false);game.neighborhood.set_process(false);game.fp_player.set_physics_process(false)
 game.session_paused=false;game.tutorial_active=false;game.daily_report_pending=false;game.tutorial_panel.hide();game.pause_overlay.hide();game.daily_report_panel.hide();game.visit_timer.stop()
 for n in game.find_children("*","CanvasLayer",true,false):n.hide()
 game.packing_employee_hired=true;game.packing_employee_active=true;game.production_worker_arrested=false;game.lay_low_active=false;game.production_worker_friend_name="Mike"
 var strain:String=game.SEED_ORDER[0]
 game.trimmed_inventory={strain:3};game.untrimmed_inventory={strain:3}
 game.plant_slots[0]={"strain":strain,"stage":game.STAGES.size()-1,"growth":100.0,"water":80.0,"health":100.0,"fertilizer":50.0,"dead":false};game._update_plant_visual(0)
 var camera:=Camera3D.new();root.add_child(camera);camera.current=true;camera.fov=65
 var light:=OmniLight3D.new();camera.add_child(light);light.omni_range=8;light.light_energy=2
 var sun:=DirectionalLight3D.new();root.add_child(sun);sun.rotation_degrees=Vector3(-35,-25,0);sun.light_energy=1.4
 game.production_worker_node.reparent(root,true);game.production_worker_node.show()
 var bench:Node3D=Actions.station(game);bench.reparent(root,true);bench.show()
 var plant:Node3D=game.plant_visuals[0];plant.reparent(root,true);plant.show()
 var crew=game.neighborhood.location_ops.crew
 for task in ["plant","water","fertilize"]:
  plant.get_node("Canopy").visible=task!="plant"
  game.production_worker_pending_action=task;game.production_worker_pending_slot=0 if task in Actions.GROW_TASKS else -1;game.production_worker_pending_strain=strain
  var at:Variant=Actions.target(game,task,game.production_worker_pending_slot)
  if not at is Vector3:push_error("Missing target");quit(1);return
  game.production_worker_target_position=at;game.production_worker_node.global_position=at;game.production_worker_action_dwell=Actions.duration(task)*.45
  crew.update_malik();var pose=crew.malik_worker.get_node("ProductionActions");pose.sync()
  var worker:Node3D=game.production_worker_node
  camera.global_position=worker.global_position+worker.global_basis*Vector3(-1.6,1.3,-1.4)
  camera.look_at(worker.global_position+Vector3(0,1.2,0)-worker.global_basis.z*.35)
  await process_frame;await process_frame;await RenderingServer.frame_post_draw
  var path:String="/tmp/production_"+task+".png"
  get_root().get_texture().get_image().save_png(path)
 print("PRODUCTION_CAPTURE_COMPLETE");quit()
