extends SceneTree
# Keep imported Kobi, Rod and Malik in relaxed idle while stationary at work.
# Regression for walk animation continuing at packing, grow and storage stations.
var checks:=0
var failures:=0
func assert_ok(ok:bool,message:String) -> void:
 checks+=1
 if ok:print("PASS: ",message)
 else:failures+=1;push_error("FAIL: "+message)

func animation_is(avatar:Node3D,state:String) -> bool:
 if avatar==null:return false
 var animations:=avatar.find_children("*","AnimationPlayer",true,false)
 if animations.is_empty():return false
 for player in animations:
  if not str(player.current_animation).ends_with(state):return false
 return true

func _initialize() -> void:call_deferred("run")
func run() -> void:
 var game:Node3D=load("res://prototype/apartment.tscn").instantiate()
 root.add_child(game)
 for i in 20:await process_frame
 game.set_process(false)
 game.neighborhood.set_process(false)
 if game.fp_player!=null:game.fp_player.set_physics_process(false)
 for timer in game.find_children("*","Timer",true,false):timer.stop()
 game.gameplay_ready=true;game.session_paused=false;game.tutorial_active=false;game.daily_report_pending=false
 game.tutorial_panel.hide();game.pause_overlay.hide();game.daily_report_panel.hide()
 var inventory:Node=game.inventory_system
 inventory.set_process(false);inventory.furniture.set_process(false)
 inventory.guide.state.active=false;inventory.guide.state.completed=true
 var crew:RefCounted=game.neighborhood.location_ops.crew
 game.packing_employee_hired=true
 game.packing_employee_active=true
 game.production_worker_arrested=false
 game.production_worker_node.show()
 for character in ["Kobi","Malik","Rod"]:
  game.production_worker_friend_name=character
  for station in ["workbench","grow","storage","entry"]:
   var goal:Vector3=game._production_worker_station_position(station)
   game.production_worker_pending_action="trim"
   game.production_worker_task="Working at "+station
   game.production_worker_target_position=goal
   game.production_worker_node.set_meta("seated",false)
   game.production_worker_node.position=goal
   # A stale waypoint cannot leave the worker marching on the spot.
   game.production_worker_route_valid=true
   game.production_worker_route_destination=goal
   game.production_worker_route_index=0
   game.production_worker_route_points.clear()
   game.production_worker_route_points.append(goal+Vector3(1.5,0,0))
   crew.update_malik()
   assert_ok(animation_is(crew.malik_worker,"idle"),character+" uses standing idle at "+station)
   # Walking remains functional when travelling to a new task.
   game.production_worker_node.position=goal+Vector3(2,0,1)
   game._reset_production_worker_navigation()
   crew.update_malik()
   assert_ok(animation_is(crew.malik_worker,"walk"),character+" walks toward "+station)
   game.production_worker_node.position=goal
   game._reset_production_worker_navigation()
   crew.update_malik()
   assert_ok(animation_is(crew.malik_worker,"idle"),character+" stops walking at "+station)
 game.queue_free()
 await process_frame
 print("CREW_STATION_ANIMATION_RESULT: ","PASS" if failures==0 else "FAIL"," checks=",checks," failures=",failures)
 quit(0 if failures==0 else 1)
