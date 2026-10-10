extends SceneTree
var failures=0
func _initialize()->void:call_deferred("run")
func run()->void:
 var boot=load("res://visual_lab/boot.tscn").instantiate();root.add_child(boot)
 for i in range(12):await process_frame
 var game=boot.game;game.set_process(false);game.fp_player.set_physics_process(false)
 var p=game.fp_player
 var stairs=[boot.get_node("ArtStudy").fire_escape]
 var basement=game.get_node("BasementExpansion")
 for child in basement.get_children():
  if child.get_script()!=null and child.get_script().resource_path.ends_with("fire_escape.gd"):stairs.append(child)
 for tower in stairs:
  for flight in tower.flights:
   for side in [-1.0,1.0]:
    p.position=flight.from+Vector3(side*.3,.12,0);p.velocity=Vector3.ZERO
    var dz:float=signf(flight.to.z-flight.from.z)
    var reached=false
    for tick in range(220):
     await physics_frame
     p.velocity.x=side*1.0;p.velocity.z=dz*3.4
     p.velocity.y=-.5 if p.is_on_floor() else p.velocity.y-18.0/60.0
     p.move_and_slide()
     if (p.position.z-flight.to.z)*dz>.32 and absf(p.position.y-flight.to.y)<.35:reached=true;break
    if not reached:
     failures+=1;print("RAIL_EDGE_BLOCKED flight=",flight.from," side=",side," at=",p.position)
     for i in range(p.get_slide_collision_count()):print(" CONTACT ",p.get_slide_collision(i).get_collider().get_path()," normal=",p.get_slide_collision(i).get_normal())
 print("RAIL_EDGE_RESULT failures=",failures)
 quit(1 if failures>0 else 0)
