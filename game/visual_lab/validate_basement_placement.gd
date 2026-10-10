extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var boot=load("res://visual_lab/boot.tscn").instantiate();root.add_child(boot)
 for i in range(12):await process_frame
 var game=boot.game
 game.set_process(false);game.fp_player.set_physics_process(false);game.neighborhood.set_process(false)
 game.session_paused=false;game.tutorial_active=false;game.daily_report_pending=false
 var inv=game.inventory_system;inv.set_process(false)
 var editor=inv.furniture;editor.set_process(false)
 var model=editor.model
 game.cash=50000;game.property_opportunity_state={"acquired":true,"first_entry":true,"relocated":true}
 game.packing_employee_active=false;game.production_worker_pending_action=""
 model.setup(game)
 var id:String=model.own("grow_tent","backpack")
 assert(not id.is_empty())
 game.fp_player.position=Vector3(29,-3.78,-5);game.fp_player.sync_camera()
 assert(editor.inside("house"))
 editor.property="house";editor.selected=id;editor.yaw=0
 assert(editor.placement_floor()==-3.8)
 editor.point=Vector3(29,-3.8,-10)
 await physics_frame
 assert(editor.obstacle().is_empty(),editor.obstacle())
 assert(model.place(id,"house",editor.point,0),model.error)
 assert(is_equal_approx(model.state.items[id].position[1],-3.8))
 editor.equipment_world.sync()
 assert(is_equal_approx(editor.equipment_world.rendered[id].position.y,-3.8))
 var slot:int=int(model.state.items[id].slots[0])
 assert(model.can_plant(slot) and model.slot_property(slot)=="house")
 assert(is_equal_approx(game.plant_visuals[slot].global_position.y,-3.54))
 assert(game.neighborhood.house_controls.grow_snapshot().tents>=1)
 game.open_house_system()
 var apartment_light:bool=game.grow_lights_on
 var house_light:bool=bool(game.house_control_state.get("grow_lights",false))
 game._activate_room_interaction("grow_light_switch")
 assert(bool(game.house_control_state.get("grow_lights",false))!=house_light and game.grow_lights_on==apartment_light)
 game._close_system_control_panel()
 # Saved JSON and normal model setup keep the basement height and plant slot identity.
 var saved:Dictionary=JSON.parse_string(JSON.stringify(model.state))
 game.location_state.furniture_v1=saved;model.setup(game)
 assert(is_equal_approx(model.state.items[id].position[1],-3.8))
 assert(int(model.state.items[id].slots[0])==slot)
 var second:String=model.own("tent_1","backpack")
 assert(not model.validate(second,"house",Vector3(29,-3.8,-10),0).is_empty())
 assert(not model.validate(second,"house",Vector3(43,-3.8,-10),0).is_empty(),"Stair aisle must be reserved")
 assert(not model.validate(second,"house",Vector3(30,-1.9,-10),0).is_empty(),"Midair placement rejected")
 # Existing upstairs items with the same horizontal footprint must not block downstairs.
 var upstairs:String=model.own("tent_1","backpack")
 model.state.items[upstairs].property="house";model.state.items[upstairs].position=[34,0,-10]
 assert(model.validate(second,"house",Vector3(34,-3.8,-10),0).is_empty())
 model.lock(id,false)
 assert(model.pack(id),model.error)
 assert(model.place(id,"house",Vector3(34,-3.8,-6),90),model.error)
 editor.equipment_world.sync()
 assert(is_equal_approx(editor.equipment_world.rendered[id].position.y,-3.8))
 print("BASEMENT_EQUIPMENT_PASS placement=true plant_height=true saved_height=true property_isolation=true move_pack=true stair_clearance=true")
 quit()
