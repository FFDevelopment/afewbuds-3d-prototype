extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var boot=load("res://visual_lab/boot.tscn").instantiate();root.add_child(boot)
 for i in range(12):await process_frame
 var game=boot.game;game.set_process(false);game.fp_player.set_physics_process(false)
 var editor=game.inventory_system.furniture;editor.set_process(false)
 var equipment=editor.equipment_world;var model=editor.model
 var names=["BagStack","LabelRoll","ToolCup","ToolPenA","ToolPenB","ScissorBladeA","ScissorBladeB","ScissorHandleA","ScissorHandleB"]
 var id:String=model.primary("apartment","packing")
 assert(not id.is_empty())
 for name in names:
  var source=game.get_node(name)
  assert(equipment.originals.has(source.get_instance_id()),"Unowned packing prop: "+name)
  assert(not source.visible)
  assert(equipment.rendered[id].find_child(name,true,false)!=null,"Prop missing from owned bench: "+name)
 var jars=0
 for n in game.neighborhood.get_children():
  if n.get_meta("fit_part","")=="PackingJar":
   jars+=1;assert(not n.visible and equipment.originals.has(n.get_instance_id()),"Orphan house jar")
 assert(jars==3)
 # Exercise the same stored transform used by Arrange, then rebuild the model.
 var old_position:Array=model.state.items[id].position.duplicate()
 model.state.items[id].position=[old_position[0]-2.0,old_position[1],old_position[2]+1.0]
 model.state.items[id].yaw=180
 equipment.sync()
 for name in names:
  assert(not game.get_node(name).visible)
  assert(equipment.rendered[id].find_child(name,true,false)!=null)
 # Picking up removes the owned model without revealing the old fixed props.
 model.state.items[id].property="backpack";model.state.items[id].erase("position")
 equipment.sync()
 assert(not equipment.rendered.has(id))
 for name in names:assert(not game.get_node(name).visible)
 print("BENCH_PROP_OWNERSHIP_PASS attached_props=",names.size()," house_jars=",jars," moved_rotated_packed=true")
 quit()
