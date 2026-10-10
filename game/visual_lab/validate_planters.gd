extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var boot=load("res://visual_lab/boot.tscn").instantiate();root.add_child(boot)
 for i in range(12):await process_frame
 var game=boot.game;var study=boot.get_node("ArtStudy")
 game.set_process(false);game.fp_player.set_physics_process(false)
 var player=game.fp_player
 for x in [-4.25,4.25]:
  player.position=Vector3(x,.1,8.4);player.velocity=Vector3.ZERO
  for tick in range(60):
   await physics_frame
   player.velocity=Vector3(0,-.5 if player.is_on_floor() else player.velocity.y-18.0/60.0,-3.4)
   player.move_and_slide()
  assert(player.position.z>7.35 and player.position.z<7.6,"Planter collision missing or misplaced: "+str(player.position))
 var basement=game.get_node("BasementExpansion")
 for label in basement.find_children("*","Label3D",true,false):
  assert(not label.text.contains("BASEMENT GROW ROOM"),"Stair sign still present")
 print("PLANTER_COLLISION_PASS both_pots=true basement_stair_text_removed=true")
 quit()
