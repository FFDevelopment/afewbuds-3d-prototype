extends "res://account/cloud.gd"
var remote: Dictionary = {}
var fail_network := false
var reject_save := false
var writes := 0
func request_rpc(method: String, payload: Dictionary) -> Dictionary:
	await get_tree().process_frame
	if fail_network: return {"error": "offline"}
	if method == "afb_validate_session": return {"account_id": "test-A", "username": "QA"}
	if method == "afb_login":
		if payload.get("p_password") != "mock-password": return {"error": "invalid_credentials"}
		return {"account_id": "test-A", "session_token": "mock", "username": "QA"}
	if method == "afb_get_save": return {"exists": not remote.is_empty(), "save_json": remote.duplicate(true)}
	if method == "afb_set_save":
		if reject_save: return {"ok": false, "reason": "cloud_newer"}
		remote = payload.p_save_json.duplicate(true)
		writes += 1
		return {"ok": true, "saved_unix": remote.get("saved_unix", 0)}
	return {"ok": true}
