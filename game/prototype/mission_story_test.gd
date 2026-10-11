extends SceneTree
class FakeHost:
 extends Node3D
 var location_state:Dictionary={}
 var property_opportunity_state:Dictionary={}
 var game_day:int=8
 var cash:int=100
 var xp:int=0
 var rep:int=0
 var saves:int=0
 func _add_progress(x:int,r:int)->void:xp+=x;rep+=r
 func _update_cash_ui()->void:pass
 func _save_game()->void:saves+=1
 func _refresh_phone()->void:pass
var checks:int=0
var fails:int=0
func check(ok:bool,note:String)->void:
 checks+=1
 if not ok:fails+=1;push_error("MISSION_STORY FAIL: "+note)
func _initialize()->void:call_deferred("run")
func run()->void:
 var host:=FakeHost.new()
 root.add_child(host)
 host.location_state["chapter_five"]={"stage":5,"rewards":{"settle":true}}
 var quests:RefCounted=load("res://scripts/mission_story_engine.gd").new()
 quests.setup(host)
 check(quests.state.entries.is_empty(),"No mission before the house unlock")
 host.property_opportunity_state["first_entry"]=true
 quests.sync_unlocks()
 check(quests.state.entries.has("house_crew_rhythm") and not quests.state.entries.has("house_regular_flow"),"Prerequisites gate missions")
 quests.record("harvests",1)
 quests.record("worker_tasks",4)
 check(not quests.ready("house_crew_rhythm"),"Both targets required")
 quests.record("harvests",1)
 check(quests.ready("house_crew_rhythm") and quests.progress("house_crew_rhythm","worker_tasks")==3,"Worker count capped and ready")
 check(not quests.claim("house_regular_flow"),"Locked mission cannot pay")
 check(quests.claim("house_crew_rhythm") and host.cash==275 and host.xp==60,"First reward paid once")
 check(not quests.claim("house_crew_rhythm") and host.cash==275,"Duplicate claim refused")
 check(quests.state.entries.has("house_regular_flow"),"Next mission unlocked")
 quests.record("sales",4)
 quests.record("dealer_sales",2)
 check(quests.ready("house_regular_flow"),"Sale objectives complete")
 host.location_state=JSON.parse_string(JSON.stringify(host.location_state))
 var restored:RefCounted=load("res://scripts/mission_story_engine.gd").new()
 restored.setup(host)
 check(restored.ready("house_regular_flow") and not restored.claim("house_crew_rhythm"),"Progress and reward state survive JSON save")
 check(restored.claim("house_regular_flow") and host.cash==500,"Second reward pays")
 check(not restored.claim("house_regular_flow") and host.cash==500,"No duplicate on reload")
 check(host.location_state.chapter_five.stage==5 and host.saves==2,"Legacy chapter and claim count untouched")
 print("MISSION_STORY_RESULT: "+("PASS" if fails==0 else "FAIL")+" checks="+str(checks))
 host.queue_free()
 quit(0 if fails==0 else 1)
