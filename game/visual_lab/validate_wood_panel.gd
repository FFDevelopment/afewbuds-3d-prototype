extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var boot=load("res://visual_lab/boot.tscn").instantiate();root.add_child(boot)
 for i in range(12):await process_frame
 var game=boot.game;var study=boot.get_node("ArtStudy")
 game.set_process(false);game.fp_player.set_physics_process(false)
 game.session_paused=false;game.tutorial_active=false;game.daily_report_pending=false
 var controls=game.neighborhood.house_controls
 var basement=game.get_node("BasementExpansion")
 var old_room:bool=basement.room_lights_on
 var apartment_states=[game.grow_room_light_on,game.grow_lights_on,game.ventilation_on]
 var mat=game.neighborhood.get_node("HouseFloor").material_override
 assert(mat.shader.resource_path.ends_with("wood.gdshader"))
 assert(game.get_node("MainFloorPlanks").material_override.shader==mat.shader)
 var doors=0
 for door in game.neighborhood.map_doors:
  for n in door.find_children("*","MeshInstance3D",true,false):
   if str(n.name).ends_with("Panel") or str(n.name).ends_with("Inset"):
    assert(n.material_override.shader==mat.shader);doors+=1
 assert(doors>=8)
 assert(controls.switches.grow_lights.at.y<-.5)
 game.fp_player.position=Vector3(43,-3.78,-5.7)
 game.fp_player.sync_camera();game.camera.look_at(controls.switches.grow_lights.at)
 await physics_frame
 assert(controls.nearby()=="house_system","Basement panel must be reachable through normal interaction")
 controls.use("house_system")
 assert(game.system_control_panel.visible and game.house_system_context)
 assert(game.system_control_status.text.begins_with("HOUSE"))
 assert(game._any_modal_open())
 var start:Vector3=game.fp_player.position
 game._activate_room_interaction("grow_room_light_switch")
 assert(basement.room_lights_on!=old_room)
 assert(apartment_states==[game.grow_room_light_on,game.grow_lights_on,game.ventilation_on])
 game._activate_room_interaction("grow_room_light_switch")
 assert(basement.room_lights_on==old_room)
 # No equipment means disabled controls rather than toggling apartment equipment.
 var state:Dictionary=controls.grow_snapshot()
 if state.tents==0:
  assert(game.system_control_panel.find_child("System_grow_light_switch",true,false).disabled)
 if not state.ventilation:
  assert(game.system_control_panel.find_child("System_ventilation_switch",true,false).disabled)
 game._close_system_control_panel()
 assert(not game.house_system_context and not game.system_control_panel.visible)
 assert(game.fp_player.position==start,"Closing must not teleport to apartment")
 game._open_system_control_panel()
 assert(not game.house_system_context and game.system_control_status.text.begins_with("ROOM STATUS"))
 game._close_system_control_panel()
 study.revised=false;study.apply_look()
 study.revised=true;study.apply_look()
 assert(game.neighborhood.get_node("HouseFloor").material_override==mat)
 print("WOOD_HOUSE_PANEL_PASS wooden_door_parts=",doors," property_isolation=true reachable=true close_position_preserved=true")
 quit()
