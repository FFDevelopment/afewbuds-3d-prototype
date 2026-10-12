extends RefCounted
## AFewBuds mission/story system. Additive to existing Chapters 1–5 and saves.
## Progress is earned from actual in-game events, never simulated while offline.
const SCHEMA_VERSION=2
const SIDE_MISSIONS=[
 {"id":"small_favor","title":"A Small Favor","speaker":"Kobi","unlock":"chapter1","requires":[],"reward_cash":110,"reward_xp":35,"reward_rep":1,"description":"Help Kobi test a dependable first batch.","objectives":[{"metric":"harvests","label":"Harvest plants","target":2},{"metric":"grams_trimmed","label":"Trim grams","target":15}]},
 {"id":"earn_their_trust","title":"Earn Their Trust","speaker":"Malik","unlock":"chapter1","requires":["small_favor"],"reward_cash":150,"reward_xp":45,"reward_rep":2,"description":"Build repeat business with clean packaged product.","objectives":[{"metric":"sales","label":"Complete sales","target":5},{"metric":"bags_sealed","label":"Seal bags","target":3}]},
 {"id":"house_crew_rhythm","title":"Find Your Rhythm","speaker":"Kobi","unlock":"house","requires":[],"reward_cash":175,"reward_xp":60,"reward_rep":2,"description":"Prove the house grow operation and production staff work together.","objectives":[{"metric":"harvests","label":"House-era harvests","target":2},{"metric":"worker_tasks","label":"Production tasks","target":3}]},
 {"id":"house_regular_flow","title":"Keep Them Coming Back","speaker":"Malik","unlock":"house","requires":["house_crew_rhythm"],"reward_cash":225,"reward_xp":80,"reward_rep":3,"description":"Keep regular customers happy while your dealers build a route.","objectives":[{"metric":"sales","label":"Complete sales","target":4},{"metric":"dealer_sales","label":"Dealer sales","target":2}]}
]
const CHAPTER6_STEPS=[
 {"id":"supply","title":"Set the Standard","speaker":"Kobi","description":"Build a consistent supply for the new operation.","reward_cash":200,"reward_xp":65,"reward_rep":2,"objectives":[{"metric":"harvests","label":"New harvests","target":3},{"metric":"grams_trimmed","label":"Trimmed grams","target":35}]},
 {"id":"packing","title":"Pack with Purpose","speaker":"Kobi","description":"Train the crew, prepare clean orders and keep product moving.","reward_cash":240,"reward_xp":75,"reward_rep":2,"objectives":[{"metric":"bags_sealed","label":"Bags sealed","target":8},{"metric":"worker_tasks","label":"Crew tasks finished","target":4}]},
 {"id":"network","title":"The Word Spreads","speaker":"Malik","description":"Grow your client network and prove the distribution route.","reward_cash":300,"reward_xp":90,"reward_rep":3,"objectives":[{"metric":"sales","label":"Completed sales","target":8},{"metric":"dealer_sales","label":"Dealer sales","target":2}]},
 {"id":"stability","title":"Keep It Under Control","speaker":"Rod","description":"Build reserves before the next phase. Keep Heat below 35.","reward_cash":350,"reward_xp":110,"reward_rep":4,"max_heat":35.0,"objectives":[{"metric":"grams_stored","label":"Grams stored","target":35},{"metric":"bags_sealed","label":"More bags sealed","target":4}]},
 {"id":"finale","title":"Joint Junction","speaker":"Rod","description":"Finish five new sales, keep Heat low, then speak with Rod at the house.","reward_cash":700,"reward_xp":240,"reward_rep":6,"max_heat":25.0,"rod_finale":true,"objectives":[{"metric":"sales","label":"Final sales","target":5}]}
]
const CONTRACTS=[
 {"id":"small_harvest","title":"Fresh Harvest","description":"Harvest two plants for this job.","reward_cash":110,"reward_xp":30,"reward_rep":1,"objectives":[{"metric":"harvests","label":"Harvests","target":2}]},
 {"id":"packing_shift","title":"Packing Shift","description":"Trim 20g and seal four bags.","reward_cash":140,"reward_xp":35,"reward_rep":1,"objectives":[{"metric":"grams_trimmed","label":"Trimmed grams","target":20},{"metric":"bags_sealed","label":"Sealed bags","target":4}]},
 {"id":"regular_round","title":"Regular Route","description":"Complete four sales with your customers or crew.","reward_cash":125,"reward_xp":35,"reward_rep":1,"objectives":[{"metric":"sales","label":"Sales","target":4}]}
]
var host:Node
var state:Dictionary={}
var dialogue_mode:String=""

func setup(owner:Node)->void:
 host=owner
 var stored:Variant=host.location_state.get("mission_story",{})
 if not (stored is Dictionary):stored={}
 state=stored as Dictionary
 if not (state.get("entries",{}) is Dictionary):state["entries"]={}
 if not state.has("entries"):state["entries"]={}
 if not (state.get("chapter6",{}) is Dictionary):state["chapter6"]={}
 if not (state.get("jobs",{}) is Dictionary):state["jobs"]={}
 if not (state.get("contacts",{}) is Dictionary):state["contacts"]={}
 var chapter:Dictionary=state["chapter6"]
 if not chapter.has("started"):chapter["started"]=false
 if not chapter.has("stage"):chapter["stage"]=0
 if not (chapter.get("progress",{}) is Dictionary):chapter["progress"]={}
 if not (chapter.get("rewards",{}) is Dictionary):chapter["rewards"]={}
 if not chapter.has("route"):chapter["route"]=""
 if not chapter.has("completed_day"):chapter["completed_day"]=-1
 var jobs:Dictionary=state["jobs"]
 if not jobs.has("active"):jobs["active"]=""
 if not jobs.has("claimed_day"):jobs["claimed_day"]=-1
 if not (jobs.get("progress",{}) is Dictionary):jobs["progress"]={}
 if not jobs.has("completed"):jobs["completed"]=0
 state["schema"]=SCHEMA_VERSION
 host.location_state["mission_story"]=state
 sync_unlocks()

func chapter5_stage()->int:
 return int(host.location_state.get("chapter_five",{}).get("stage",0))
func chapter5_complete()->bool:return chapter5_stage()>=6
func chapter6_started()->bool:return bool(state.get("chapter6",{}).get("started",false))
func chapter6_stage()->int:return clampi(int(state.get("chapter6",{}).get("stage",0)),0,CHAPTER6_STEPS.size())
func chapter6_complete()->bool:
 return chapter6_started() and chapter6_stage()>=CHAPTER6_STEPS.size()
func route_name()->String:
 return "Quiet Growth" if str(state.chapter6.get("route",""))=="quiet" else "Expanded Distribution"
func rod_available()->bool:
 if chapter5_stage()==5:return true
 if not chapter5_complete() or chapter6_complete():return false
 return not chapter6_started() or chapter6_stage()==CHAPTER6_STEPS.size()-1

func _chapter_one_done()->bool:
 return host.has_method("_story_chapter_one_complete") and bool(host._story_chapter_one_complete())
func _unlocked(definition:Dictionary)->bool:
 var gate:String=str(definition.get("unlock",""))
 if gate=="chapter1" and not _chapter_one_done():return false
 if gate=="house" and not bool(host.property_opportunity_state.get("first_entry",false)):return false
 for dependency in definition.get("requires",[]):
  if str(state.entries.get(str(dependency),{}).get("status",""))!="claimed":return false
 return true
func sync_unlocks()->void:
 if host==null:return
 for definition in SIDE_MISSIONS:
  var id:String=str(definition.id)
  if state.entries.has(id) or not _unlocked(definition):continue
  state.entries[id]={"status":"active","progress":{},"accepted_day":host.game_day}

func definition(id:String)->Dictionary:
 for entry in SIDE_MISSIONS:
  if str(entry.id)==id:return entry
 return {}
func contract(id:String)->Dictionary:
 for entry in CONTRACTS:
  if str(entry.id)==id:return entry
 return {}

func _progress(current:Dictionary,metric:String)->int:
 return maxi(0,int(current.get(metric,0)))
func progress(id:String,metric:String)->int:
 return _progress(state.entries.get(id,{}).get("progress",{}),metric)
func _objectives_ready(counters:Dictionary,objectives:Array)->bool:
 for objective in objectives:
  if _progress(counters,str(objective.metric))<int(objective.target):return false
 return true
func _increase(counters:Dictionary,objectives:Array,metric:String,amount:int)->bool:
 var changed:bool=false
 for objective in objectives:
  if str(objective.metric)!=metric:continue
  var cap:int=maxi(1,int(objective.target))
  var prior:int=_progress(counters,metric)
  counters[metric]=mini(cap,prior+amount)
  if int(counters[metric])>prior:changed=true
 return changed
func ready(id:String)->bool:
 var info:Dictionary=definition(id)
 if info.is_empty():return false
 var entry:Dictionary=state.entries.get(id,{})
 if str(entry.get("status","")) not in ["active","ready"]:return false
 return _objectives_ready(entry.get("progress",{}),info.get("objectives",[]))

func chapter6_objectives()->Array:
 if not chapter6_started() or chapter6_complete():return []
 var objectives:Array=CHAPTER6_STEPS[chapter6_stage()].objectives.duplicate(true)
 if chapter6_stage()==0:
  var focus:String=str(state.contacts.get("kobi",""))
  for objective in objectives:
   if objective.metric=="grams_trimmed":
    objective.target=40 if focus=="quality" else (30 if focus=="speed" else 35)
 elif chapter6_stage()==2:
  var route:String=str(state.chapter6.get("route","quiet"))
  var malik:String=str(state.contacts.get("malik",""))
  for objective in objectives:
   if objective.metric=="dealer_sales":
    objective.target=(4 if route=="distribution" else 2)+(1 if malik=="dealers" else (-1 if malik=="regulars" else 0))
 return objectives
func chapter6_ready()->bool:
 if not chapter6_started() or chapter6_complete():return false
 var info:Dictionary=CHAPTER6_STEPS[chapter6_stage()]
 if not _objectives_ready(state.chapter6.get("progress",{}),chapter6_objectives()):return false
 return float(host.heat)<=float(info.get("max_heat",101.0))

func record(metric:String,amount:int=1,context:Dictionary={})->void:
 if amount<=0 or metric.is_empty():return
 sync_unlocks()
 for info in SIDE_MISSIONS:
  var id:String=str(info.id)
  var data:Dictionary=state.entries.get(id,{})
  if str(data.get("status","")) not in ["active","ready"]:continue
  if info.has("property") and str(context.get("property",""))!=str(info.property):continue
  var count:Dictionary=data.get("progress",{})
  if not _increase(count,info.objectives,metric,amount):continue
  data["progress"]=count
  if ready(id):data["status"]="ready"
  state.entries[id]=data
 if chapter6_started() and not chapter6_complete():
  _increase(state.chapter6["progress"],chapter6_objectives(),metric,amount)
 var jobs:Dictionary=state.jobs
 var active:String=str(jobs.get("active",""))
 if not active.is_empty():
  var job:Dictionary=contract(active)
  if not job.is_empty():_increase(jobs["progress"],job.objectives,metric,amount)

func _award(cash:int,xp:int,reputation:int)->void:
 host.cash+=maxi(0,cash)
 host._add_progress(maxi(0,xp),maxi(0,reputation))
 host._update_cash_ui()
func _notify(speaker:String,body:String)->void:
 if host.has_method("_push_phone_text"):host._push_phone_text(speaker,body)
func _persist()->void:
 host._save_game()
 if host.has_method("_refresh_phone"):host._refresh_phone()

func claim(id:String)->bool:
 sync_unlocks()
 if not ready(id):return false
 var data:Dictionary=state.entries[id]
 if str(data.get("status",""))=="claimed":return false
 var info:Dictionary=definition(id)
 data["status"]="claimed"
 data["claimed_day"]=host.game_day
 state.entries[id]=data
 _award(int(info.reward_cash),int(info.reward_xp),int(info.reward_rep))
 sync_unlocks()
 _notify(str(info.speaker),"Good work on "+str(info.title)+". Your reward is in. More opportunities are waiting.")
 _persist()
 return true

func begin_chapter6(route:String)->bool:
 if not chapter5_complete() or chapter6_started():return false
 if route not in ["quiet","distribution"]:return false
 state.chapter6={"started":true,"stage":0,"progress":{},"rewards":{},"route":route,"completed_day":-1}
 dialogue_mode=""
 _notify("Rod","Joint Junction starts today. "+("Keep the operation quiet and controlled." if route=="quiet" else "Grow a bigger dealer network, but control the extra attention."))
 _notify("Kobi","First assignment: harvest and prepare a consistent new batch. Check Story on your phone.")
 _persist()
 return true

func claim_chapter6(from_rod:bool=false)->bool:
 if not chapter6_ready():return false
 var stage:int=chapter6_stage()
 var info:Dictionary=CHAPTER6_STEPS[stage]
 if bool(info.get("rod_finale",false)) and not from_rod:return false
 var id:String=str(info.id)
 if bool(state.chapter6.rewards.get(id,false)):return false
 state.chapter6.rewards[id]=true
 var cash:int=int(info.reward_cash)
 var rep:int=int(info.reward_rep)
 if stage==0:
  if str(state.contacts.get("kobi",""))=="quality":rep+=3
  elif str(state.contacts.get("kobi",""))=="speed":cash+=60
 if stage==2:
  if str(state.contacts.get("malik",""))=="regulars":rep+=2
  elif str(state.contacts.get("malik",""))=="dealers":cash+=100
 state.chapter6.stage=stage+1
 state.chapter6.progress={}
 if chapter6_complete():
  state.chapter6.completed_day=host.game_day
  _notify("Rod","Joint Junction is established. Chapter 6 complete. Keep taking local jobs while we plan the next part of Bongchester.")
 else:
  var next:Dictionary=CHAPTER6_STEPS[chapter6_stage()]
  _notify(str(next.speaker),"Next: "+str(next.title)+". "+str(next.description))
 _award(cash,int(info.reward_xp),rep)
 dialogue_mode=""
 _persist()
 return true

func accept_job(id:String)->bool:
 if not _chapter_one_done() or contract(id).is_empty():return false
 if not str(state.jobs.get("active","")).is_empty():return false
 if int(state.jobs.get("claimed_day",-1))>=host.game_day:return false
 state.jobs["active"]=id
 state.jobs["progress"]={}
 state.jobs["accepted_day"]=host.game_day
 _persist()
 return true
func job_ready()->bool:
 var id:String=str(state.jobs.get("active",""))
 if id.is_empty():return false
 var entry:Dictionary=contract(id)
 return not entry.is_empty() and _objectives_ready(state.jobs.get("progress",{}),entry.objectives)
func claim_job()->bool:
 if not job_ready():return false
 var entry:Dictionary=contract(str(state.jobs.active))
 state.jobs.active=""
 state.jobs.progress={}
 state.jobs.claimed_day=host.game_day
 state.jobs.completed=int(state.jobs.get("completed",0))+1
 _award(int(entry.reward_cash),int(entry.reward_xp),int(entry.reward_rep))
 _notify("Malik","That local job is finished. Collect another after your next in-game day begins.")
 _persist()
 return true

func open_rod()->bool:
 if not rod_available() or host._simulation_blocked():return false
 if chapter5_stage()==5:dialogue_mode="chapter5_rod"
 elif not chapter6_started():dialogue_mode="chapter6_intro"
 else:dialogue_mode="chapter6_finale"
 if not host.phone_open:host._toggle_phone()
 if not host.phone_open:dialogue_mode="";return false
 host._open_phone_app("task")
 return true

func open_contact(speaker:String)->bool:
 if not chapter6_started() or chapter6_complete() or speaker not in ["kobi","malik"]:return false
 if speaker=="kobi" and chapter6_stage()!=0:return false
 if speaker=="malik" and chapter6_stage()!=2:return false
 dialogue_mode="advice_"+speaker
 if host.has_method("_refresh_phone"):host._refresh_phone()
 return true

func choose(option:String)->bool:
 match option:
  "close":
   dialogue_mode=""
   _persist()
   return true
  "chapter5_finish":
   if dialogue_mode!="chapter5_rod" or chapter5_stage()!=5:return false
   if not host.inventory_system.furniture.chapter.meet_rod():return false
   dialogue_mode=""
   _notify("Rod","You have my word. Chapter 5 is complete. Come see me again about Joint Junction.")
   _persist()
   return true
  "ch6_quiet","ch6_distribution":
   if dialogue_mode!="chapter6_intro":return false
   return begin_chapter6("quiet" if option=="ch6_quiet" else "distribution")
  "ch6_finish":
   if dialogue_mode!="chapter6_finale":return false
   return claim_chapter6(true)
  "kobi_quality","kobi_speed":
   if dialogue_mode!="advice_kobi" or chapter6_stage()!=0:return false
   state.contacts["kobi"]="quality" if option=="kobi_quality" else "speed"
   dialogue_mode=""
   _notify("Kobi","Quality requires 40g of trimming for extra reputation. Faster batches require 30g and add a cash bonus." if option=="kobi_quality" else "We'll move faster: 30g trimmed. The first mission will pay extra cash.")
   _persist()
   return true
  "malik_regulars","malik_dealers":
   if dialogue_mode!="advice_malik" or chapter6_stage()!=2:return false
   state.contacts["malik"]="regulars" if option=="malik_regulars" else "dealers"
   dialogue_mode=""
   _notify("Malik","We'll prioritize trusted regulars and keep dealer commitments lighter." if option=="malik_regulars" else "We'll push a larger dealer route for a bigger cash reward.")
   _persist()
   return true
 return false

func _label(parent:VBoxContainer,message:String,size:int=16)->void:
 var line:=Label.new()
 line.text=message
 line.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 line.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 line.add_theme_font_size_override("font_size",size)
 parent.add_child(line)
func _button(parent:VBoxContainer,title:String,action:Callable,disabled:bool=false)->void:
 var item:=Button.new()
 item.text=title
 item.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 item.custom_minimum_size.y=46.0
 item.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 item.disabled=disabled
 item.pressed.connect(action)
 parent.add_child(item)
func _objectives_text(counters:Dictionary,objectives:Array)->String:
 var lines:Array[String]=[]
 for objective in objectives:
  lines.append("%s: %d / %d" % [str(objective.label),mini(_progress(counters,str(objective.metric)),int(objective.target)),int(objective.target)])
 return "\n".join(lines)

func _dialogue(parent:VBoxContainer)->void:
 if dialogue_mode.is_empty():return
 _label(parent,"CONVERSATION",20)
 match dialogue_mode:
  "chapter5_rod":
   _label(parent,"ROD: This place is finally becoming an operation. The crew, the customers and the bills all matter. Show me you can keep it steady.")
   var story=host.inventory_system.furniture.chapter
   if story.ready():
    _button(parent,"Tell Rod we're ready · Finish Chapter 5",choose.bind("chapter5_finish"))
   else:
    _label(parent,"Finish the final Chapter 5 objectives and bring Heat down to 25 or less before Rod signs off.")
  "chapter6_intro":
   _label(parent,"ROD: We can keep building without moving again. How do you want Joint Junction to run? This choice affects the dealer targets in Chapter 6.")
   _button(parent,"Quiet growth · Fewer dealer deliveries",choose.bind("ch6_quiet"))
   _button(parent,"Expanded distribution · More dealer sales",choose.bind("ch6_distribution"))
  "chapter6_finale":
   _label(parent,"ROD: The operation has earned its name. One last check: deliver the remaining sales and make sure Heat is under control.")
   _button(parent,"Complete Joint Junction with Rod",choose.bind("ch6_finish"),not chapter6_ready())
  "advice_kobi":
   _label(parent,"KOBI: We can polish every batch or move steadily. Quality requires 40g trimmed for extra reputation; speed requires 30g for extra cash.")
   _button(parent,"Focus on quality · Reputation bonus",choose.bind("kobi_quality"))
   _button(parent,"Keep batches moving · Cash bonus",choose.bind("kobi_speed"))
  "advice_malik":
   _label(parent,"MALIK: Keep our regulars close or expand the dealer route? Regulars mean fewer required dealer sales; a dealer push pays more.")
   _button(parent,"Put regulars first · Reputation bonus",choose.bind("malik_regulars"))
   _button(parent,"Expand dealer routes · Cash bonus",choose.bind("malik_dealers"))
 _button(parent,"Back to Story",choose.bind("close"))

func render(parent:VBoxContainer)->void:
 sync_unlocks()
 _label(parent,"STORY MISSIONS & LOCAL JOBS",21)
 _label(parent,"Only actions you take while playing count. Old career milestones, money, items and saved chapters are preserved.",14)
 _dialogue(parent)
 if not chapter5_complete():
  if chapter5_stage()==5:_label(parent,"Rod is waiting in the house living room. Go talk to him once the final Chapter 5 requirements are met.")
 else:
  if not chapter6_started():
   _label(parent,"CHAPTER 6 · JOINT JUNCTION",20)
   _label(parent,"Chapter 5 complete. Meet Rod in your house living room to choose your next route.")
  elif chapter6_complete():
   _label(parent,"CHAPTER 6 COMPLETE · JOINT JUNCTION",20)
   _label(parent,"The operation is established. Local jobs remain available every in-game day. More chapters will use this same system.")
  else:
   var stage:int=chapter6_stage()
   var entry:Dictionary=CHAPTER6_STEPS[stage]
   _label(parent,"CHAPTER 6 · %d/%d · %s" % [stage+1,CHAPTER6_STEPS.size(),str(entry.title)],20)
   _label(parent,"Rod's plan: "+route_name()+"\n"+str(entry.speaker)+": "+str(entry.description),16)
   _label(parent,_objectives_text(state.chapter6.progress,chapter6_objectives()),16)
   if entry.has("max_heat"):
    _label(parent,"Current Heat: %d · Required: %d or less" % [int(host.heat),int(entry.max_heat)],15)
   if stage==0:_button(parent,"Reply to Kobi · Choose production approach",open_contact.bind("kobi"))
   if stage==2:_button(parent,"Reply to Malik · Choose client approach",open_contact.bind("malik"))
   if bool(entry.get("rod_finale",false)):
    _label(parent,"When these conditions are satisfied, meet Rod in the living room to close Chapter 6.",15)
   else:
    _button(parent,"Complete mission · Claim $%d" % int(entry.reward_cash),claim_chapter6,not chapter6_ready())
 _label(parent,"SIDE MISSIONS",19)
 var completed:int=0
 var visible:int=0
 for info in SIDE_MISSIONS:
  var id:String=str(info.id)
  if not state.entries.has(id):continue
  var data:Dictionary=state.entries[id]
  if str(data.get("status",""))=="claimed":completed+=1;continue
  visible+=1
  _label(parent,"%s · %s" % [str(info.speaker),str(info.title)],17)
  _label(parent,str(info.description)+"\n"+_objectives_text(data.get("progress",{}),info.objectives),15)
  _button(parent,"Claim $%d · %d XP" % [int(info.reward_cash),int(info.reward_xp)],claim.bind(id),not ready(id))
 if visible==0:_label(parent,"Completed %d side missions. More jobs are below." % completed,15)
 else:_label(parent,"%d completed side missions." % completed,14)
 _label(parent,"LOCAL JOB BOARD · REPEATABLE",19)
 if not _chapter_one_done():
  _label(parent,"Finish Chapter 1's starting tasks to unlock neighborhood jobs.",15)
  return
 var active:String=str(state.jobs.get("active",""))
 if not active.is_empty():
  var job:Dictionary=contract(active)
  _label(parent,str(job.title)+"\n"+str(job.description)+"\n"+_objectives_text(state.jobs.get("progress",{}),job.objectives),16)
  _button(parent,"Collect job payout · $%d" % int(job.reward_cash),claim_job,not job_ready())
 elif int(state.jobs.get("claimed_day",-1))>=host.game_day:
  _label(parent,"Today's job is done. A new job can be accepted after you start the next in-game day.",15)
 else:
  _label(parent,"Choose one job. Complete it at your own pace; it won't expire while you're offline.",15)
  for job in CONTRACTS:
   _button(parent,str(job.title)+" · $%d / %d XP" % [int(job.reward_cash),int(job.reward_xp)],accept_job.bind(str(job.id)))
 _label(parent,"Total local jobs completed: %d" % int(state.jobs.get("completed",0)),14)
