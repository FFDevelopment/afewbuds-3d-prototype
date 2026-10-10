extends SceneTree
var failures:=0
var checks:=0
class ExitProbe extends Node:
 var quitting:=false
 var saved:=false
 var failed:=""
 func quit_failed(message:String):failed=message;quitting=false
 func quit_saved():saved=true;quitting=false
func _initialize():call_deferred("run")
func check(value:bool,message:String):
 checks+=1
 if not value:failures+=1;push_error("FAIL: "+message)
 else:print("PASS: "+message)
func buttons(node:Node) -> Array[String]:
 var result:Array[String]=[]
 for button in node.find_children("*","Button",true,false):result.append(button.text)
 return result
func run():
 var desktop:bool=ResourceLoader.exists("res://prototype/apartment.tscn")
 var game=load("res://prototype/apartment.tscn" if desktop else "res://scenes/main.tscn").instantiate();root.add_child(game)
 for i in 12:await process_frame
 game.set_process(false);game.neighborhood.set_process(false)
 for timer in game.find_children("*","Timer",true,false):timer.stop()
 game.inventory_system.guide.skip();game.tutorial_panel.hide();game.daily_report_panel.hide();game.daily_report_pending=false
 game._resume_gameplay();game._pause_gameplay()
 var inv:Node=game.inventory_system
 var menu:Node=inv.session_menu
 check(buttons(menu.body)==["RESUME GAME","SETTINGS","HELP","SAVE & QUIT"],"Pause presents Resume, Settings, Help and Save & Quit in order")
 menu.show_page("settings")
 check("ACCOUNT SETTINGS" in buttons(menu.body),"Account settings are available from Pause")
 if desktop:check("CONTROLS & DISPLAY" in buttons(menu.body),"Desktop settings retain controller and display controls")
 menu.show_page("help")
 check("START GUIDE" in buttons(menu.body),"Pause Help offers the version-specific tutorial")
 menu._process(0)
 check(menu.panel.get_global_rect().size.y<=game.get_viewport().get_visible_rect().size.y,"Scrollable Help stays inside viewport")
 menu.show_page("home");game._open_phone_app("home")
 check("Settings" in buttons(game.phone_panel),"Preview phone dock provides Settings without removing Pause settings")
 game.phone_open=false;game.phone_panel.hide()
 menu.on_cloud_event("offline");game._resume_gameplay()
 check(game.session_paused and menu.cloud_locked,"Lost session verification prevents resuming gameplay")
 menu.on_cloud_event("active");game._resume_gameplay()
 check(not game.session_paused and not menu.cloud_locked,"Verified connection permits explicitly resuming")
 if desktop:
  var cloud=root.get_node("AFBCloud")
  cloud.session={"account_id":"fixture", "session_token":"fixture", "username":"QA"}
  cloud.pending={"cash":123}
  cloud.blocked=true;cloud.block_reason="save_conflict"
  game._on_cloud_status("Cloud conflict — saved locally.")
  check(menu.cloud_state=="save_conflict" and menu.cloud_locked,"Save conflict is distinct from another active session")
  check(not cloud.session.is_empty() and not cloud.pending.is_empty(),"Save conflict preserves login and pending progress")
  cloud.session={};cloud.pending={};cloud.blocked=false;cloud.block_reason=""
  menu.on_cloud_event("active")
 game._pause_gameplay()
 var probe:=ExitProbe.new();root.add_child(probe);inv.session_menu=probe
 game.cash=1234
 await game._phone_safe_quit()
 check(probe.saved and game.last_save_ok,"Save and Quit verifies a fresh successful save before exiting")
 var saved:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_PATH))
 check(int(saved.cash)==1234,"Quit saves current career data")
 probe.saved=false;game.reset_in_progress=true
 await game._phone_safe_quit()
 check(not probe.saved and not probe.failed.is_empty(),"Failed save keeps the game open and reports the problem")
 game.reset_in_progress=false;inv.session_menu=menu
 if desktop:
  check(game.status_label.anchor_top==0 and game.status_label.offset_top>=0 and game.status_label.has_theme_stylebox_override("normal"),"Desktop messages use a top-screen backing bubble")
  check(game.fp_prompt.has_theme_stylebox_override("normal") and game.fp_prompt.offset_top==inv.nearby_button.offset_top,"Desktop native and inventory prompts share style and bottom-center position")
 else:
  inv._process(0)
  check(game.neighborhood.action.has_meta("modern_interaction"),"Mobile native interactions receive shared modern styling")
  check(game.neighborhood.action.anchor_right==1 and inv.nearby_button.anchor_right==1,"Both mobile prompt producers remain bottom-right")

 game.status_label.text="Collected your order."
 game._tick_status_notification(0)
 game._tick_status_notification(3.9)
 check(game.status_label.visible,"Top notification remains visible for nearly four seconds")
 game._tick_status_notification(0.2)
 check(not game.status_label.visible and game.status_label.text.is_empty(),"Top notification and bubble disappear after four seconds")
 game.status_label.text="Collected your order.";game._tick_status_notification(0)
 check(game.status_label.visible,"A repeated message can appear again after expiry")
 game._resume_gameplay()
 inv.overlay.show()
 var touch_panel:=ScrollContainer.new();inv.overlay.add_child(touch_panel);touch_panel.position=Vector2(30,30);touch_panel.size=Vector2(200,140)
 var touch_list:=VBoxContainer.new();touch_panel.add_child(touch_list)
 var touch_button:=Button.new();touch_button.text="Touch target";touch_button.custom_minimum_size=Vector2(180,90);touch_list.add_child(touch_button)
 var filler:=Control.new();filler.custom_minimum_size=Vector2(180,1000);touch_list.add_child(filler)
 var taps:Array[int]=[0];touch_button.pressed.connect(func():taps[0]+=1)
 inv.inventory_scrolls.clear();inv.inventory_scrolls.append(touch_panel)
 for i in 3:await process_frame
 var touch:=InputEventScreenTouch.new();touch.index=3;touch.position=touch_button.get_global_rect().get_center();touch.pressed=true
 check(inv.handle_inventory_touch(touch),"Inventory captures a touch over an item card")
 var drag:=InputEventScreenDrag.new();drag.index=3;drag.position=touch.position-Vector2(0,65)
 inv.handle_inventory_touch(drag);touch.pressed=false;touch.position=drag.position;inv.handle_inventory_touch(touch)
 check(touch_panel.scroll_vertical>0 and taps[0]==0,"Swiping item cards scrolls without selecting or transferring")
 touch_panel.scroll_vertical=0
 for i in 2:await process_frame
 touch.position=touch_button.get_global_rect().get_center();touch.pressed=true;inv.handle_inventory_touch(touch);touch.pressed=false;inv.handle_inventory_touch(touch)
 check(taps[0]==1,"Stationary touch still selects the item")
 touch_panel.queue_free();inv.inventory_scrolls.clear();inv.overlay.hide()

 game.queue_free();probe.queue_free();await process_frame
 print("SESSION_UI_TEST_RESULT: ","PASS" if failures==0 else "FAIL"," checks=",checks," failures=",failures)
 quit(0 if failures==0 else 1)
