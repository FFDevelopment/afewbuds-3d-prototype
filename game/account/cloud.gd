extends Node
signal sync_changed(message: String)
signal session_event(state: String)
var play_id: String = ""
var revision: int = 0
var handoff_pending := false
var heartbeat_busy := false
var last_contact := 0
var heartbeat_elapsed := 0.0
# Existing public AFewBuds API configuration; no admin/service-role credentials.
const BASE := "https://nlrrnhdcjrnfuftyoaqn.supabase.co"
const API_KEY := "sb_publishable_f8LrZYozO8h2xAvn90L-gw_dZiaUwTY"
const CONNECTION_NOTE := "Sign in to continue your career. Your cloud career is shared between mobile and desktop."
const LEGACY_ACTIVE := "user://afewbuds_3d_prototype_save.json"
var ACTIVE:String="user://play_runtime_"+str(OS.get_process_id())+".json"
const SESSION := "user://account_session.json"
var inventory_preview := false
var service_url := BASE
var session: Dictionary = {}
var remote_signature := ""
var career_key := "guest"
var baseline: Dictionary = {}
var pending: Dictionary = {}
var busy := false
var blocked := false
var block_reason := ""
var launched := false
var generation := 0
var leaderboard_error := ""
var sync_warning := false
var last_status := "Local guest save"
var remember := false

func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}

func write_json(path: String, data: Dictionary) -> bool:
	var f := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if f == null: return false
	f.store_string(JSON.stringify(data))
	f.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path)) == OK

func normalize(value: Variant) -> Dictionary:
	if value is Array: value = value[0] if not value.is_empty() else {}
	if value is Dictionary and value.get("value") is Dictionary: value = value.value
	return value if value is Dictionary else {}

const RECOVERY_RETURN_URL := "https://ffdevelopment.github.io/afewbuds-cloud-test/"
const RECOVERY_MESSAGE := "If that AFewBuds account has a recovery email, a reset link has been sent."

func request_password_reset(identifier: String) -> Dictionary:
	var value := identifier.strip_edges()
	if value.is_empty(): return {"error": "Enter your username or saved recovery email."}
	if value.length() > 254: return {"error": "Enter an email address of 254 characters or fewer."}
	var result := await request_json("/functions/v1/afb-password-reset", {"username": value, "return_url": RECOVERY_RETURN_URL})
	if result.has("error"):
		match str(result.error):
			"recovery_email_not_configured": return {"error": "Password recovery email is not configured yet."}
			"recovery_email_send_failed": return {"error": "The reset email could not be sent right now. Try again later."}
			"recovery_service_unavailable": return {"error": "Password recovery is temporarily unavailable."}
		return result
	if result.get("ok") != true:
		return {"error": "Unexpected recovery response. Please try again later."}
	# Never infer or expose whether this identifier matches an account.
	return {"ok": true, "message": RECOVERY_MESSAGE}

func request_rpc(method: String, payload: Dictionary) -> Dictionary:
	if inventory_preview and method in ["afb_set_save","afb_save_career","afb_begin_play","afb_play_heartbeat","afb_release_play","afb_leaderboard_report"]:return {"error":"Inventory preview cannot write to live careers."}
	return await request_json("/rest/v1/rpc/" + method, payload)

func wire_numbers(value: Variant) -> Variant:
	# JSON.parse_string loads all JSON numbers as floats. PostgreSQL's existing
	# leaderboard readers require integer text (123), not decimal text (123.0).
	# Match the web client's integer encoding without rounding fractional state.
	if value is float and is_finite(value) and absf(value) <= 9007199254740991.0 and value == floor(value):
		return int(value)
	if value is Dictionary:
		var normalized:Dictionary={}
		for key in value:normalized[key]=wire_numbers(value[key])
		return normalized
	if value is Array:
		var normalized:Array=[]
		for item in value:normalized.append(wire_numbers(item))
		return normalized
	return value

func request_json(path: String, payload: Dictionary) -> Dictionary:
	var request := HTTPRequest.new()
	request.timeout = 20.0
	add_child(request)
	var error := request.request(service_url + path, PackedStringArray(["Content-Type: application/json", "apikey: " + API_KEY]), HTTPClient.METHOD_POST, JSON.stringify(wire_numbers(payload), "", true, true))
	if error != OK:
		request.queue_free()
		return {"error": "Could not connect. Please retry."}
	var response: Array = await request.request_completed
	request.queue_free()
	if int(response[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"error": "Connection interrupted. Your local progress is retained."}
	var decoded: Variant = JSON.parse_string(response[3].get_string_from_utf8())
	if not decoded is Dictionary and not decoded is Array:
		return {"error": "Unexpected account service response. Please retry."}
	var data := normalize(decoded)
	if int(response[1]) < 200 or int(response[1]) >= 300:
		return {"error": str(data.get("error", data.get("message", "Account service unavailable.")))}
	return data

func fingerprint(save: Dictionary) -> String:
	return JSON.stringify(wire_numbers(save), "", true, true).sha256_text()

func set_status(message: String, attention: bool = false) -> void:
	sync_warning = attention
	last_status = message
	sync_changed.emit(message)

func accept_session(data: Dictionary, keep: bool) -> bool:
	if not data.has("session_token") or not data.has("account_id") or not data.has("username"): return false
	session = data.duplicate(true)
	remember = keep
	if keep: write_json(SESSION, session)
	elif FileAccess.file_exists(SESSION): DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION))
	return true

func restore_session() -> Dictionary:
	var saved := read_json(SESSION)
	if saved.is_empty(): return {}
	var result := await request_rpc("afb_validate_session", {"p_session_token": saved.get("session_token", "")})
	if result.has("error"): return result
	if not result.has("username") or str(result.get("account_id", "")) != str(saved.get("account_id", "")):
		return {"error": "session_invalid"}
	saved.merge(result, true)
	accept_session(saved, true)
	return saved

func cache_path() -> String:
	if career_key=="guest":return "user://career_guest.json"
	return "user://" + ("career_" if inventory_preview else "shared_career_") + career_key + ".json"

func settings_path() -> String:
	return "user://desktop_" + career_key + ".json"

func prepare(guest: bool = false, use_cloud: bool = false) -> Dictionary:
	# Preserve the old prototype guest career before any account can replace ACTIVE.
	if not FileAccess.file_exists("user://guest_migrated.json"):
		var original := read_json(LEGACY_ACTIVE)
		if original.is_empty():original=read_json(ACTIVE)
		if not original.is_empty(): write_json("user://career_guest.json", {"save": original, "remote_signature": "", "dirty": false})
		write_json("user://guest_migrated.json", {"done": true})
	blocked = false
	block_reason = ""
	pending = {}
	generation += 1
	if guest:
		session = {}
		career_key = "guest"
		baseline = read_json(cache_path()).get("save", {})
		if not FileAccess.file_exists(settings_path()):
			var old_pose: Dictionary = baseline.get("runtime", {}).get("prototype_player", {})
			if not old_pose.is_empty(): write_json(settings_path(), old_pose)
		remote_signature = ""
	else:
		career_key = str(session.account_id).sha256_text().substr(0, 24)
		var remote:Dictionary
		if inventory_preview:remote=await request_rpc("afb_get_save", {"p_session_token": session.session_token})
		else:
			if play_id.is_empty():play_id=new_play_id()
			handoff_pending=false
			for attempt in 45:
				remote=await request_rpc("afb_begin_play", {"p_session_token":session.session_token,"p_play_id":play_id})
				if remote.get("state","")!="waiting":break
				set_status("Closing the other play session and loading its latest save...")
				await get_tree().create_timer(0.5).timeout
			if remote.get("state","")!="active":return {"error":remote.get("error","Another device switch is still finishing. Please try again.")}
			revision=int(remote.get("revision",0));last_contact=Time.get_ticks_msec()
		if remote.has("error"): return remote
		var cloud: Dictionary = remote.get("save_json", {}) if remote.get("exists", false) else {}
		if int(cloud.get("save_schema", 0)) > 2: return {"error": "This career needs a newer desktop build. Please update."}
		remote_signature = fingerprint(cloud)
		var cached := read_json(cache_path())
		if inventory_preview and cached.get("inventory_preview",false):cloud=cached.get("save",{});remote_signature=fingerprint(cloud)
		if cached.get("dirty", false):
			if str(cached.get("remote_signature", "")) not in [remote_signature, JSON.stringify(cloud, "", true, true).sha256_text()] and fingerprint(cached.get("save", {})) != remote_signature and not use_cloud:
				return {"conflict": true, "error": "Another version saved this career. Continue from cloud to keep its progress. Your desktop copy will be backed up."}
			if use_cloud:
				write_json(cache_path() + ".backup", cached)
				baseline = cloud
			else: baseline = cached.get("save", {})
		else: baseline = cloud
	# First account launch must never adopt the guest active file.
	if not baseline.is_empty():
		if not write_json(ACTIVE, baseline): return {"error": "Cannot write the local career file."}
	elif FileAccess.file_exists(ACTIVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ACTIVE))
	launched = true
	set_status("Signed in as " + str(session.username) if not session.is_empty() else "Local guest career")
	return {"ok": true}

func shared_save(raw: Dictionary) -> Dictionary:
	var save := baseline.duplicate(true)
	save.merge(raw, true)
	var runtime: Dictionary = baseline.get("runtime", {}).duplicate(true)
	runtime.merge(raw.get("runtime", {}), true)
	runtime.erase("prototype_player")
	# Fixed-camera position belongs to the regular version, not free movement.
	for key in ["current_view", "current_room"]:
		if baseline.get("runtime", {}).has(key): runtime[key] = baseline.runtime[key]
		else: runtime.erase(key)
	save["runtime"] = runtime
	# The desktop introduction must not complete/reset the regular guided lesson.
	if not session.is_empty():
		for key in ["tutorial_seen", "tutorial_active", "tutorial_step", "tutorial_slot", "tutorial_harvest_strain"]:
			if baseline.has(key): save[key] = baseline[key]
	save.erase("_afb_base_revision")
	save.erase("_afb_revision")
	return save

func queue_save(raw: Dictionary) -> void:
	if not launched: return
	var save := shared_save(raw)
	if inventory_preview:
		baseline=save
		write_json(cache_path(),{"save":save,"inventory_preview":true,"dirty":false})
		var preview_pose:Dictionary=raw.get("runtime",{}).get("prototype_player",{})
		if not preview_pose.is_empty():write_json(settings_path(),preview_pose)
		set_status("Progress saved on this device.")
		return
	var pose: Dictionary = raw.get("runtime", {}).get("prototype_player", {})
	if not pose.is_empty(): write_json(settings_path(), pose)
	write_json(cache_path(), {"save": save, "remote_signature": remote_signature, "dirty": not session.is_empty()})
	baseline = save
	if session.is_empty():
		set_status("Saved on this device — guest")
		return
	pending = save
	if not busy and not blocked: call_deferred("flush")

func flush() -> void:
	if busy or blocked or pending.is_empty() or session.is_empty(): return
	busy = true
	var epoch := generation
	while not pending.is_empty() and not blocked:
		var outgoing := pending.duplicate(true)
		pending = {}
		# The server atomically checks play ownership and revision. JSON text
		# comparisons are not a reliable substitute for that check.
		set_status("Saving to AFewBuds cloud…")
		var result := await request_rpc("afb_save_career", {"p_session_token": session.session_token,"p_play_id":play_id,"p_revision":revision,"p_save_json": outgoing})
		if epoch != generation: break
		if result.has("error") or not result.get("ok", false):
			if pending.is_empty(): pending = outgoing
			block_reason = str(result.get("reason", ""))
			blocked = block_reason in ["save_conflict", "client_update_required", "save_schema_newer", "cloud_newer","session_replaced","session_invalid"]
			set_status("Cloud conflict — saved locally. Return to sign-in to load the newer career." if blocked else "Saved locally. Cloud unavailable — retry with F5.", true)
			break
		revision=int(result.get("revision",revision+1));last_contact=Time.get_ticks_msec()
		remote_signature = fingerprint(outgoing)
		write_json(cache_path(), {"save": baseline, "remote_signature": remote_signature, "dirty": not pending.is_empty()})
		set_status("Cloud saved — " + str(session.username))
		var report := await request_rpc("afb_leaderboard_report", {"p_session_token": session.session_token})
		if epoch != generation: break
		leaderboard_error = str(report.get("error", ""))
		if not leaderboard_error.is_empty():set_status("Career saved. Leaderboard report failed — retry saving.", true)
	busy = false

func sign_out() -> void:
	play_id="";handoff_pending=false
	leaderboard_error = ""
	generation += 1
	launched = false
	session.clear()
	pending = {}
	blocked = false
	block_reason = ""
	if FileAccess.file_exists(SESSION): DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION))

func new_play_id() -> String:
	var h:String=Crypto.new().generate_random_bytes(16).hex_encode()
	return h.substr(0,8)+"-"+h.substr(8,4)+"-"+h.substr(12,4)+"-"+h.substr(16,4)+"-"+h.substr(20,12)
func _process(delta:float) -> void:
	if inventory_preview or not launched or session.is_empty() or blocked or handoff_pending:return
	heartbeat_elapsed+=delta
	if Time.get_ticks_msec()-last_contact>15000:session_event.emit("offline")
	if heartbeat_elapsed>=5.0 and not heartbeat_busy:
		heartbeat_elapsed=0.0;heartbeat()
func heartbeat() -> void:
	if heartbeat_busy:return
	heartbeat_busy=true
	var epoch:=generation
	var result:=await request_rpc("afb_play_heartbeat",{"p_session_token":session.session_token,"p_play_id":play_id})
	heartbeat_busy=false
	if epoch!=generation:return
	if result.has("error"):return
	var state:String=str(result.get("state",""))
	if state not in ["active","handoff","replaced"]:return
	last_contact=Time.get_ticks_msec()
	if state=="handoff":handoff_pending=true
	if state=="replaced":blocked=true;block_reason="session_replaced";launched=false
	session_event.emit(state)
func release_play() -> bool:
	if inventory_preview or session.is_empty():return true
	var result:=await request_rpc("afb_release_play",{"p_session_token":session.session_token,"p_play_id":play_id})
	return bool(result.get("ok",false))
func finish_handoff() -> void:
	await flush()
	while busy:await get_tree().process_frame
	if pending.is_empty():await release_play()
	sign_out()
	session_event.emit("replaced")
