extends SceneTree
var game:Node3D
var inv:Node
var ops:RefCounted
var failures:=0
var checks:=0
func _initialize():call_deferred("run")
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;push_error("FAIL: "+message)
 else:print("PASS: ",message)
func stand(id:String):
 game.camera.position=inv.POSITIONS[id]+Vector3(0,.34,2)
 game.camera.look_at(inv.POSITIONS[id])
func empty_bag():
 game.location_state.carried_seeds={};game.location_state.carried_fertilizer=0
 game.location_state.property_storage=[];inv.state.backpack={}
func run():
 var desktop:bool=ResourceLoader.exists("res://prototype/apartment.tscn")
 game=load("res://prototype/apartment.tscn" if desktop else "res://scenes/main.tscn").instantiate();root.add_child(game)
 for i in 12:await process_frame
 game.set_process(false);game.neighborhood.set_process(false)
 if desktop:game.fp_player.set_physics_process(false)
 else:game.neighborhood.physics_body.set_physics_process(false)
 for timer in game.find_children("*","Timer",true,false):timer.stop()
 game.session_paused=false;game.tutorial_active=false;game.daily_report_pending=false;game.customer_waiting=false
 game.tutorial_panel.hide();game.pause_overlay.hide();game.daily_report_panel.hide();game.phone_open=false;game.phone_panel.hide()
 inv=game.inventory_system;inv.set_process(false);ops=game.neighborhood.location_ops
 inv.ensure_state();inv.state.backpack_level=1;empty_bag()
 game.location_state.pickup_seeds={};game.location_state.pickup_fertilizer=0;game.location_state.deliveries={}
 game.location_state.active_property="apartment";game.location_state.operation_contents_property="apartment"
 var controls=root.get_node("DesktopInput")
 controls.controller_active=true
 game.fp_player.enabled=true;game.fp_player.desired=Vector2(0,-1)
 check(not game.fp_player.sprint_request(Vector2(0,-1),false),"Full forward stick alone walks")
 game.fp_player.toggle_controller_sprint()
 check(game.fp_player.sprint_request(Vector2(0,-1),false),"Clicking L3 toggles forward sprint on")
 game.fp_player.toggle_controller_sprint()
 check(not game.fp_player.sprint_request(Vector2(0,-1),false),"Second L3 click toggles sprint off")
 check(game.fp_player.sprint_request(Vector2(0,-1),true),"Holding keyboard Shift requests sprint")
 game.fp_player.toggle_controller_sprint()
 check(not game.fp_player.sprint_request(Vector2(0,1),false) and not game.fp_player.controller_sprint_toggled,"Stopping forward movement clears sprint toggle")
 game.fp_player.exhausted=true;game.fp_player.controller_sprint_toggled=true
 check(not game.fp_player.sprint_request(Vector2(0,-1),false),"Exhaustion clears controller sprint request")
 game.fp_player.exhausted=false
 game._process(0);inv._process(0)
 check(not game.fp_hint.visible,"Bottom-left key legend removed")
 check(inv.phone_button!=null and inv.phone_button.position.y>inv.backpack_button.position.y,"Phone shortcut appears below Backpack")
 var joy:=InputEventJoypadButton.new();joy.button_index=JOY_BUTTON_DPAD_UP;joy.pressed=true
 game._input(joy)
 check(game.phone_open,"Default D-pad Up opens Phone")
 game._input(joy)
 check(game.phone_open,"D-pad Up in the phone stays available for menu navigation")
 game._toggle_phone()
 joy.button_index=JOY_BUTTON_DPAD_RIGHT
 game._input(joy)
 check(inv.is_open(),"Default D-pad Right opens Backpack")
 inv.close()
 check(controls.assign_binding("backpack","controller",JOY_BUTTON_RIGHT_STICK),"Backpack controller action can be rebound")
 joy.button_index=JOY_BUTTON_DPAD_RIGHT
 check(not controls.pressed(joy,"backpack"),"Old Backpack binding is released")
 joy.button_index=JOY_BUTTON_RIGHT_STICK;game._input(joy)
 check(inv.is_open(),"Rebound controller button opens Backpack")
 var saved:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(controls.PATH))
 check(int(saved.pad_bindings.backpack)==JOY_BUTTON_RIGHT_STICK,"Controller binding persists in device preferences")
 check(not controls.assign_binding("backpack","controller",JOY_BUTTON_B),"Menu Back button stays reserved")
 check(not controls.assign_binding("backpack","controller",JOY_BUTTON_DPAD_UP),"Duplicate controller bindings are rejected")
 game.location_state.carried_seeds={"Purple Dream":2};inv.render()
 for i in 4:await process_frame
 controls.ensure_focus();var card:Control=root.gui_get_focus_owner()
 check(card!=null and card.has_meta("navigation_key"),"Controller initially focuses an inventory item")
 var cursor_before:Vector2=root.get_mouse_position()
 joy.button_index=JOY_BUTTON_A;controls._input(joy)
 for i in 4:await process_frame
 controls.ensure_focus()
 check(not inv.selected.is_empty() and root.get_mouse_position()==cursor_before,"A selects an item without pointer movement")
 check(root.gui_get_focus_owner()!=null and root.gui_get_focus_owner().has_meta("navigation_key"),"Inventory refresh preserves focused item")
 var before:Control=root.gui_get_focus_owner();joy.button_index=JOY_BUTTON_DPAD_UP;controls._input(joy)
 check(root.gui_get_focus_owner()!=before,"D-pad moves focus through inventory controls")
 check(inv.is_open(),"D-pad Up navigates an open backpack instead of closing it")
 inv.close();game._pause_gameplay();controls.show_settings()
 var pad_rows:=0;var keyboard_backpack:=false
 for button in controls.settings.find_children("*","Button",true,false):
  if button.get_meta("binding_device","")=="controller":pad_rows+=1
  if button.get_meta("binding_device","")=="keyboard" and button.get_meta("binding_action","")=="backpack":keyboard_backpack=true
 check(pad_rows==controls.PAD_DEFAULTS.size() and keyboard_backpack,"Settings shows separate controller and keyboard bindings including Backpack")
 controls.close_settings();game.session_paused=false;game.pause_overlay.hide()
 stand("apartment:packing");game.untrimmed_inventory={"Purple Dream":3};game.trimmed_inventory={};game.bagged_inventory={}
 inv.open_container("packing");inv.select_item("apartment:packing","raw|Purple Dream");inv.process_selected()
 for frame in 4:await process_frame
 joy.button_index=JOY_BUTTON_A;joy.pressed=true;controls._input(joy)
 for target in game.trim_targets:
  if target.visible:
   var movement:Vector2=target.position-game.trim_scissors.position
   game._controller_work_tick(movement.length()/400.0,movement.normalized())
 joy.pressed=false;controls._input(joy)
 check(int(game.trimmed_inventory.get("Purple Dream",0))==3,"Controller trims all buds without a mouse")
 game._close_trim_minigame();inv.select_item("apartment:packing","trimmed|Purple Dream");inv.process_selected()
 for frame in 4:await process_frame
 for i in 3:
  joy.pressed=true;controls._input(joy)
  var movement:Vector2=game.bag_target_panel.position-game.bag_bud_token.position
  game._controller_work_tick(movement.length()/400.0,movement.normalized())
  joy.pressed=false;controls._input(joy)
 game._seal_current_bag()
 check(int(game.bagged_inventory.get("Purple Dream",0))==3,"Controller fills and seals product without a mouse")
 inv.close();controls.bindings=controls.DEFAULTS.duplicate();controls.pad_bindings=controls.PAD_DEFAULTS.duplicate();controls.install_actions();controls.save_preferences()
 game.queue_free();await process_frame
 print("CONTROLLER_UI_TEST_RESULT: ","PASS" if failures==0 else "FAIL"," checks=",checks," failures=",failures)
 quit(0 if failures==0 else 1)
