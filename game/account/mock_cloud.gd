extends "res://account/cloud.gd"
var remote: Dictionary = {}
var fail_network := false
var writes := 0
func request_rpc(method: String, payload: Dictionary) -> Dictionary:
	await get_tree().process_frame
	if fail_network: return {"error": "offline"}
	if method == "afb_get_save": return {"exists": not remote.is_empty(), "save_json": remote.duplicate(true)}
	if method == "afb_set_save":
		var save: Dictionary = payload.p_save_json
		if int(save.get("_afb_base_revision", -1)) != int(remote.get("_afb_revision", 0)): return {"ok": false, "reason": "save_conflict"}
		remote = save.duplicate(true)
		remote["_afb_revision"] = int(remote.get("_afb_base_revision", 0)) + 1
		writes += 1
		return {"ok": true, "revision": remote._afb_revision}
	return {"ok": true}
