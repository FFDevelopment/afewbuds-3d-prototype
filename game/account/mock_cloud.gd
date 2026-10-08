extends "res://account/cloud.gd"
var remote: Dictionary = {}
var fail_network := false
var reject_save := false
var writes := 0
var server_revision := 0
var active_play := ""
var heartbeat_state := "active"
var json_roundtrip := false
func request_rpc(method: String, payload: Dictionary) -> Dictionary:
	await get_tree().process_frame
	if fail_network: return {"error": "offline"}
	if method == "afb_validate_session": return {"account_id": "test-A", "username": "QA"}
	if method == "afb_login":
		if payload.get("p_password") != "mock-password": return {"error": "invalid_credentials"}
		return {"account_id": "test-A", "session_token": "mock", "username": "QA"}
	if method == "afb_begin_play":
		active_play=str(payload.p_play_id)
		return {"state":"active","exists":not remote.is_empty(),"save_json":remote.duplicate(true),"revision":server_revision}
	if method == "afb_play_heartbeat":return {"state":heartbeat_state}
	if method == "afb_release_play":return {"ok":true}
	if method == "afb_get_save": return {"exists": not remote.is_empty(), "save_json": remote.duplicate(true)}
	if method == "afb_save_career":
		if str(payload.p_play_id)!=active_play:return {"ok":false,"reason":"session_replaced"}
		if int(payload.p_revision)!=server_revision:return {"ok":false,"reason":"save_conflict"}
		if reject_save: return {"ok": false, "reason": "cloud_newer"}
		remote = JSON.parse_string(JSON.stringify(wire_numbers(payload.p_save_json), "", true, true)) if json_roundtrip else payload.p_save_json.duplicate(true)
		writes += 1
		server_revision+=1
		return {"ok": true, "revision":server_revision,"saved_unix": remote.get("saved_unix", 0)}
	return {"ok": true}
