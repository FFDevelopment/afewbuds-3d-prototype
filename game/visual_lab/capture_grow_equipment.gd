extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var boot=load("res://visual_lab/boot.tscn").instantiate();root.add_child(boot)
 for i in range(12):await process_frame
 var game=boot.game;var study=boot.get_node("ArtStudy")
 game.set_process(false);game.fp_player.set_physics_process(false);game.inventory_system.set_process(false)
 var editor=game.inventory_system.furniture;editor.set_process(false);var model=editor.model
 game.property_opportunity_state={"acquired":true,"first_entry":true,"relocated":true}
 game.packing_employee_active=false;game.production_worker_pending_action="";game.cash=50000
 model.state.items={}
 var positions=[27.8,29.9,33.0,37.1];var skus=["tent_1","tent_2","grow_tent","tent_4"]
 for i in range(4):
  var id="review_tent_"+str(i)
  model.state.items[id]={"sku":skus[i],"property":"house","position":[positions[i],-3.8,-9.5],"yaw":0,"locked":false,"condition":100,"upgrades":{}}
 for sku in ["water_kit","ventilation"]:
  model.state.items[sku]={"sku":sku,"property":"backpack","locked":false,"condition":100,"upgrades":{}}
 model.ensure_slots()
 for slot in range(game.plant_slots.size()):game.plant_slots[slot]=game._empty_plant_slot()
 # Actual basement walls, not fabricated supports. Verify valid mounts and reject floating ones.
 for spec in [["water_kit",Vector3(26.375,-2.6,-5.0)],["ventilation",Vector3(26.425,-2.6,-6.2)]]:
  var id:String=spec[0];var at:Vector3=spec[1]
  assert(model.has_mount_support(id,at,90),"No mounting support: "+id)
  assert(model.place(id,"house",at,90),model.error)
  model.lock(id,false)
  assert(not model.validate(id,"house",at+Vector3(1,0,0),90).is_empty(),"Floating utility accepted")
  assert(not model.validate(id,"house",Vector3(at.x,-.5,at.z),90).is_empty(),"High mount accepted")
 game.house_control_state["grow_lights"]=true;game.house_control_state["grow_ventilation"]=true
 editor.sync_world()
 for i in range(4):
  var visual=editor.equipment_world.rendered["review_tent_"+str(i)].get_node("GrowEquipmentVisual")
  assert(visual.get_meta("fixture_tier")==1 and visual.find_child("BasicLightReflector",true,false)!=null)
  assert(visual.lamp.visible)
 await physics_frame
 # Use the actual aim/obstacle path to ensure the mount control can place against the wall.
 editor.selected="water_kit";editor.property="house";editor.wall_mount=true
 game.camera.global_position=Vector3(29,-1.7,-5);game.camera.look_at(Vector3(26,-2.15,-5))
 editor.aim();assert(editor.wall_found)
 assert(editor.obstacle().is_empty(),editor.obstacle())
 editor.selected=""
 for node in game.find_children("*","Control",true,false):node.hide()
 study.label.get_parent().get_parent().hide()
 var out=OS.get_cmdline_user_args()[0]
 await shot(game,out,"basic-tents",Vector3(32.5,-1.3,-1.8),Vector3(32.5,-2.1,-9.5))
 await shot(game,out,"basic-light",Vector3(33,-2.3,-7),Vector3(33,-1.50,-9.5))
 for i in range(4):
  var id="review_tent_"+str(i);var cash:float=game.cash
  assert(model.upgrade(id),model.error);assert(is_equal_approx(cash-game.cash,320))
  editor.sync_world()
  var v=editor.equipment_world.rendered[id].get_node("GrowEquipmentVisual")
  assert(v.get_meta("fixture_tier")==2 and v.find_child("BasicLightReflector",true,false)==null and v.find_child("LEDDriver",true,false)!=null)
  if i<3:assert(editor.equipment_world.rendered["review_tent_"+str(i+1)].get_node("GrowEquipmentVisual").get_meta("fixture_tier")==1)
 await shot(game,out,"upgraded-tents",Vector3(32.5,-1.3,-1.8),Vector3(32.5,-2.1,-9.5))
 await shot(game,out,"upgraded-light",Vector3(33,-2.3,-7),Vector3(33,-1.50,-9.5))
 await shot(game,out,"wall-mounted-utilities",Vector3(29,-1.7,-3.7),Vector3(26.3,-2.03,-5.6))
 game.house_control_state["grow_lights"]=false;editor.sync_world()
 for i in range(4):
  var v=editor.equipment_world.rendered["review_tent_"+str(i)].get_node("GrowEquipmentVisual")
  assert(not v.lamp.visible and v.find_child("LEDDriver",true,false).visible)
  for m in v.emitters:assert(m.emission_energy_multiplier==0)
 # JSON reload retains height and light upgrade; moving and packing leave no utility visual behind.
 var saved=JSON.parse_string(JSON.stringify(model.state.items));assert(is_equal_approx(saved.water_kit.position[1],-2.6))
 assert(saved.review_tent_0.quality==2 and saved.review_tent_0.upgrades.light_kit)
 assert(model.place("water_kit","house",Vector3(26.375,-2.6,-3.9),90),model.error)
 editor.sync_world();assert(is_equal_approx(editor.equipment_world.rendered.water_kit.position.z,-3.9))
 model.lock("water_kit",false);assert(model.pack("water_kit"),model.error);editor.sync_world()
 assert(not editor.equipment_world.rendered.has("water_kit"))
 # Reproduce stash placement at an apartment wall above the baseboard.
 model.state.items["review_stash"]={"sku":"storage_5","property":"backpack","locked":false,"condition":100,"upgrades":{}}
 editor.selected="review_stash";editor.property="apartment";editor.wall_mount=false;editor.build_preview()
 game.camera.global_position=Vector3(-1.5,2.16,4.3);game.camera.look_at(Vector3(-5,2.16,4.3))
 editor.aim();await physics_frame
 assert(editor.wall_found and editor.obstacle().is_empty(),"Stash preview: "+editor.obstacle())
 assert(model.place("review_stash","apartment",editor.point,editor.yaw),model.error)
 editor.clear_preview();editor.selected="";editor.sync_world();await physics_frame
 for item in game.inventory_system.contents(model.container_of("review_stash")):
  game.inventory_system.set_amount(model.container_of("review_stash"),item,0)
 model.lock("review_stash",false);editor.selected="review_stash";editor.property="apartment";editor.build_preview();editor.aim()
 assert(editor.obstacle().is_empty(),"Stash cannot stay at its own saved mount: "+editor.obstacle())
 editor.clear_preview();editor.selected=""
 print("STASH_MOUNT_PASS baseboard_clear=true own_collision_excluded=true")
 print("GROW_EQUIPMENT_PASS four_tents=true per_tent_upgrade=true lights_off=true wall_mount_aim=true move_pack=true save_height=true")
 quit()
func shot(game:Node3D,out:String,id:String,at:Vector3,target:Vector3)->void:
 if DisplayServer.get_name()=="headless":return
 game.camera.global_position=at;game.camera.look_at(target)
 for i in range(3):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out+"/"+id+".png")
