extends SceneTree
var failures:=0
class Preview extends "res://account/cloud.gd":
 var reads:=0
 func request_json(_path:String,_payload:Dictionary) -> Dictionary:
  reads+=1
  return {"exists":true,"save_json":{"cash":1234,"save_schema":2}}
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
 if not ok:failures+=1;push_error(label)
 else:print("PASS ",label)
func run():
 var c=Preview.new();c.inventory_preview=true;root.add_child(c)
 c.accept_session({"account_id":"preview-qa","username":"QA","session_token":"fixture"},false)
 var result:Dictionary=await c.prepare()
 check(result.get("ok",false) and c.baseline.cash==1234,"Preview imports live career read-only")
 c.queue_save({"cash":777,"save_schema":2});await c.flush()
 check(c.reads==1 and c.read_json(c.cache_path()).save.cash==777,"Preview saves locally without cloud writes")
 for method in ["afb_set_save","afb_save_career","afb_begin_play","afb_play_heartbeat","afb_release_play","afb_leaderboard_report"]:
  var blocked:Dictionary=await c.request_rpc(method,{})
  check(blocked.has("error"),"Preview rejects "+method)
 await c.prepare()
 check(c.baseline.cash==777,"Preview restores separate local career")
 check(c.play_id.is_empty(),"Preview never claims a live play session")
 c.queue_free();await process_frame
 print("PREVIEW_TEST_RESULT: ","PASS" if failures==0 else "FAIL")
 quit(0 if failures==0 else 1)
