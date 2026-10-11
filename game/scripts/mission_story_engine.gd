extends RefCounted
## Additive side-mission engine; chapters 1-5 and old saves remain unchanged.
const SCHEMA_VERSION=1
const MISSIONS=[
 {"id":"house_crew_rhythm","title":"Find Your Rhythm","speaker":"Kobi","description":"Complete two harvests and three production-worker tasks after establishing the house.","unlock":"house_entry","requires":[],"reward_cash":175,"reward_xp":60,"reward_rep":2,
 "objectives":[{"metric":"harvests","label":"Harvests","target":2},{"metric":"worker_tasks","label":"Worker tasks","target":3}]},
 {"id":"house_regular_flow","title":"Keep Them Coming Back","speaker":"Malik","description":"Complete four sales, including two dealer sales.","unlock":"house_entry","requires":["house_crew_rhythm"],"reward_cash":225,"reward_xp":80,"reward_rep":3,
 "objectives":[{"metric":"sales","label":"Total sales","target":4},{"metric":"dealer_sales","label":"Dealer sales","target":2}]}
]
var host:Node
var state:Dictionary={}
func setup(owner:Node)->void:
 host=owner
 var stored:Variant=host.location_state.get("mission_story",{})
 if not stored is Dictionary:stored={}
 host.location_state["mission_story"]=stored
 state=stored
 if not state.get("entries",{}) is Dictionary:state["entries"]={}
 if not state.has("entries"):state["entries"]={}
 state["schema"]=SCHEMA_VERSION
 sync_unlocks()
func definition(id:String)->Dictionary:
 for entry in MISSIONS:
  if str(entry.id)==id:return entry
 return {}
func unlocked(entry:Dictionary)->bool:
 if str(entry.get("unlock",""))=="house_entry" and not bool(host.property_opportunity_state.get("first_entry",false)):return false
 for prerequisite in entry.get("requires",[]):
  if str(state.entries.get(str(prerequisite),{}).get("status",""))!="claimed":return false
 return true
func sync_unlocks()->void:
 if host==null:return
 for entry in MISSIONS:
  var id:String=str(entry.id)
  if state.entries.has(id) or not unlocked(entry):continue
  state.entries[id]={"status":"active","progress":{},"accepted_day":host.game_day}
func progress(id:String,metric:String)->int:
 var record_data:Dictionary=state.entries.get(id,{})
 return maxi(0,int(record_data.get("progress",{}).get(metric,0)))
func ready(id:String)->bool:
 var entry:Dictionary=definition(id)
 if entry.is_empty():return false
 var record_data:Dictionary=state.entries.get(id,{})
 if str(record_data.get("status","")) not in ["active","ready"]:return false
 for objective in entry.objectives:
  if progress(id,str(objective.metric))<int(objective.target):return false
 return true
func record(metric:String,amount:int=1,context:Dictionary={})->void:
 if amount<=0 or metric.is_empty():return
 sync_unlocks()
 for entry in MISSIONS:
  var id:String=str(entry.id)
  var record_data:Dictionary=state.entries.get(id,{})
  if str(record_data.get("status",""))!="active":continue
  if entry.has("property") and str(context.get("property",""))!=str(entry.property):continue
  var counters:Dictionary=record_data.get("progress",{})
  var changed:bool=false
  for objective in entry.objectives:
   if str(objective.metric)!=metric:continue
   counters[metric]=mini(int(objective.target),maxi(0,int(counters.get(metric,0)))+amount)
   changed=true
  if not changed:continue
  record_data["progress"]=counters
  state.entries[id]=record_data
  if ready(id):
   record_data["status"]="ready"
   state.entries[id]=record_data
func claim(id:String)->bool:
 sync_unlocks()
 if not ready(id):return false
 var record_data:Dictionary=state.entries.get(id,{})
 if str(record_data.get("status",""))!="ready":return false
 var entry:Dictionary=definition(id)
 record_data["status"]="claimed"
 record_data["claimed_day"]=host.game_day
 state.entries[id]=record_data
 host.cash+=maxi(0,int(entry.get("reward_cash",0)))
 host._add_progress(maxi(0,int(entry.get("reward_xp",0))),maxi(0,int(entry.get("reward_rep",0))))
 host._update_cash_ui()
 sync_unlocks()
 host._save_game()
 if host.has_method("_refresh_phone"):host._refresh_phone()
 return true
func render(parent:VBoxContainer)->void:
 sync_unlocks()
 var heading:Label=Label.new()
 heading.text="SIDE MISSIONS"
 heading.add_theme_font_size_override("font_size",21)
 parent.add_child(heading)
 if state.entries.is_empty():
  var hint:Label=Label.new()
  hint.text="Side missions unlock after you establish the house."
  hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  parent.add_child(hint)
 for entry in MISSIONS:
  var id:String=str(entry.id)
  if not state.entries.has(id):continue
  var data:Dictionary=state.entries[id]
  var title:Label=Label.new()
  title.text="%s · %s (%s)" % [str(entry.speaker),str(entry.title),str(data.get("status","active")).to_upper()]
  title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  parent.add_child(title)
  var detail:Label=Label.new()
  detail.text=str(entry.description)
  for objective in entry.objectives:
   detail.text+="\n%s: %d/%d" % [str(objective.label),progress(id,str(objective.metric)),int(objective.target)]
  detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  parent.add_child(detail)
  if str(data.get("status",""))=="ready":
   var button:Button=Button.new()
   button.text="CLAIM $%d REWARD" % int(entry.reward_cash)
   button.pressed.connect(claim.bind(id))
   parent.add_child(button)
