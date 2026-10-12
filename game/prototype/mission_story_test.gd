extends SceneTree
## One portable test exercises the story engine without changing a real save.
class FakeChapter:
 extends RefCounted
 var host:Node
 func meet_rod()->bool:
  if int(host.location_state.chapter_five.stage)!=5:return false
  host.location_state.chapter_five.stage=6
  return true
class FakeFurniture:
 extends Node
 var chapter:RefCounted
class FakeInventory:
 extends Node
 var furniture:Node
class FakeHost:
 extends Node3D
 var location_state:Dictionary={"chapter_five":{"stage":0,"rewards":{"settle":true}},"historic_preserved":{"value":77}}
 var property_opportunity_state:Dictionary={"first_entry":false}
 var game_day:int=7
 var heat:float=12.0
 var cash:int=200
 var xp:int=0
 var reputation:int=0
 var saves:int=0
 var updates:int=0
 var phone_open:bool=false
 var app:String=""
 var first_done:bool=false
 var inventory_system:Node
 var messages:Array[String]=[]
 func _story_chapter_one_complete()->bool:return first_done
 func _simulation_blocked()->bool:return false
 func _toggle_phone()->void:phone_open=not phone_open
 func _open_phone_app(name:String)->void:app=name
 func _add_progress(x:int,r:int)->void:xp+=x;reputation+=r
 func _update_cash_ui()->void:pass
 func _save_game()->void:saves+=1
 func _refresh_phone()->void:updates+=1
 func _push_phone_text(who:String,body:String)->void:messages.append(who+": "+body)
var checks:int=0
var fails:int=0
func check(ok:bool,note:String)->void:
 checks+=1
 if not ok:fails+=1;push_error("MISSION_STORY FAIL: "+note)
func _initialize()->void:call_deferred("run")
func run()->void:
 var host:=FakeHost.new()
 root.add_child(host)
 var inv:=FakeInventory.new()
 host.add_child(inv)
 var furniture:=FakeFurniture.new()
 inv.add_child(furniture)
 furniture.chapter=FakeChapter.new()
 furniture.chapter.host=host
 inv.furniture=furniture
 host.inventory_system=inv
 var engine:RefCounted=load("res://scripts/mission_story_engine.gd").new()
 engine.setup(host)
 check(engine.state.entries.is_empty() and not engine.chapter6_started(),"Old careers don't unlock side missions before Chapter 1")
 host.first_done=true
 engine.sync_unlocks()
 check(engine.state.entries.has("small_favor") and not engine.state.entries.has("earn_their_trust"),"Chapter 1 unlocks Kobi's starter mission with prerequisites")
 engine.record("harvests",100)
 check(not engine.ready("small_favor") and engine.progress("small_favor","harvests")==2,"Progress is capped and both objectives matter")
 engine.record("grams_trimmed",15)
 check(engine.ready("small_favor"),"Kobi mission becomes ready on valid events")
 check(engine.claim("small_favor") and host.cash==310,"Kobi's cash reward is issued exactly once")
 check(not engine.claim("small_favor") and host.cash==310,"Claimed rewards cannot be duplicated")
 engine.record("sales",5);engine.record("bags_sealed",3)
 check(engine.ready("earn_their_trust") and engine.claim("earn_their_trust"),"Malik's follow-up unlocks after the first claim")
 var old_cash:int=host.cash
 check(engine.accept_job("small_harvest"),"A neighborhood job can be accepted")
 engine.record("harvests",2)
 check(engine.job_ready() and engine.claim_job() and host.cash==old_cash+110,"Repeatable job pays after real actions")
 check(not engine.claim_job() and not engine.accept_job("packing_shift"),"Only one completed job per in-game day")
 host.game_day+=1
 check(engine.accept_job("packing_shift"),"Next in-game day unlocks another job")
 engine.record("grams_trimmed",20)
 check(not engine.job_ready(),"Packing job requires all its objectives")
 engine.record("bags_sealed",4)
 check(engine.job_ready() and engine.claim_job(),"A different job completes with fresh post-acceptance progress")
 host.property_opportunity_state.first_entry=true
 engine.sync_unlocks()
 check(engine.state.entries.has("house_crew_rhythm"),"House milestone adds independent post-move side missions")
 host.location_state.chapter_five.stage=5
 check(engine.rod_available() and engine.open_rod() and host.app=="task","Rod opens the real Story phone dialogue at Chapter 5 finale")
 check(engine.choose("chapter5_finish") and engine.chapter5_complete(),"Rod physically finishes the existing Chapter 5 state")
 check(engine.rod_available() and not engine.chapter6_started(),"Rod remains available to introduce the next chapter")
 check(engine.open_rod() and engine.choose("ch6_quiet"),"Quiet chapter route is a persistent, meaningful dialogue choice")
 check(not engine.begin_chapter6("distribution") and str(engine.state.chapter6.route)=="quiet","Chapter route cannot be selected twice")
 check(engine.open_contact("kobi") and engine.choose("kobi_speed"),"Kobi's production dialogue changes the mission goal")
 var first_steps:Array=engine.chapter6_objectives()
 check(int(first_steps[1].target)==30,"Fast batch choice actually lowers first trim target")
 engine.record("harvests",3);engine.record("grams_trimmed",30)
 check(engine.chapter6_ready() and engine.claim_chapter6(),"Chapter 6 supply stage completes and pays")
 check(engine.chapter6_stage()==1 and not engine.claim_chapter6(),"No second claim without the next stage objectives")
 engine.record("bags_sealed",8);engine.record("worker_tasks",4)
 check(engine.chapter6_ready() and engine.claim_chapter6(),"Crew packing stage completes")
 check(engine.open_contact("malik") and engine.choose("malik_dealers"),"Malik's story choice adjusts dealer route rewards and targets")
 var network:Array=engine.chapter6_objectives()
 check(int(network[1].target)==3,"Quiet dealer route with Malik's push requires three dealer sales")
 engine.record("sales",8);engine.record("dealer_sales",2)
 check(not engine.chapter6_ready(),"Route objectives cannot be skipped")
 engine.record("dealer_sales",1)
 check(engine.chapter6_ready() and engine.claim_chapter6(),"Complete dealer route after all sales are recorded")
 host.heat=42.0
 engine.record("grams_stored",35);engine.record("bags_sealed",4)
 check(not engine.chapter6_ready(),"High Heat blocks Chapter 6's safety milestone")
 host.heat=20.0
 check(engine.chapter6_ready() and engine.claim_chapter6(),"Stabilized operation advances after Heat comes down")
 engine.record("sales",5)
 check(engine.chapter6_ready() and not engine.claim_chapter6(),"Rod finale cannot be claimed remotely from the phone")
 check(engine.rod_available() and engine.open_rod() and engine.choose("ch6_finish"),"Rod conversation completes Joint Junction in person")
 check(engine.chapter6_complete() and not engine.rod_available(),"Finished chapter cannot be replayed")
 old_cash=host.cash
 check(not engine.claim_chapter6(true) and host.cash==old_cash,"Finale rewards cannot duplicate")
 var original_stage:int=int(host.location_state.chapter_five.stage)
 var saved:Dictionary=JSON.parse_string(JSON.stringify(host.location_state))
 host.location_state=saved
 var restored:RefCounted=load("res://scripts/mission_story_engine.gd").new()
 restored.setup(host)
 check(restored.chapter6_complete() and int(host.location_state.chapter_five.stage)==original_stage,"New story is restored without resetting Chapter 5")
 check(int(host.location_state.historic_preserved.value)==77 and int(restored.state.jobs.completed)==2,"Unrelated legacy state and job history survive a JSON save")
 var snapshot:String=JSON.stringify(restored.state)
 host.game_day+=20
 check(snapshot==JSON.stringify(restored.state),"Offline time/day change cannot complete missions or manufacture cash")
 var panel:=VBoxContainer.new()
 root.add_child(panel)
 restored.render(panel)
 check(panel.get_child_count()>8,"Story journal renders progress and repeatable jobs without a new location")
 panel.queue_free()
 host.queue_free()
 print("MISSION_STORY_RESULT: "+("PASS" if fails==0 else "FAIL")+" checks="+str(checks)+" failures="+str(fails))
 quit(1 if fails>0 else 0)
