extends Node
signal sync_changed(message: String)
# This build has no live account transport. Tests inject an in-memory service.
# Live integration requires a separate, explicitly authorized change.
const CONNECTION_NOTE := "Account connection is not enabled in this prototype yet. Continue with your local career."
const ACTIVE := "user://afewbuds_3d_prototype_save.json"
const SESSION := "user://account_session.json"
var session: Dictionary = {}
var revision := 0
var career_key := "guest"
var baseline: Dictionary = {}
var pending: Dictionary = {}
var busy := false
var blocked := false
var launched := false
var generation := 0
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

func request_rpc(_method: String, _payload: Dictionary) -> Dictionary:
	# Deliberately no HTTPRequest, endpoint, API key, or live fallback.
	return {"error": CONNECTION_NOTE}

func set_status(message: String) -> void:
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
	saved.merge(result, true)
	accept_session(saved, true)
	return saved

func cache_path() -> String:
	return "user://career_" + career_key + ".json"

func settings_path() -> String:
	return "user://desktop_" + career_key + ".json"

func prepare(guest: bool = false, use_cloud: bool = false) -> Dictionary:
	# Preserve the old prototype guest career before any account can replace ACTIVE.
	if not FileAccess.file_exists("user://guest_migrated.json"):
		var original := read_json(ACTIVE)
		if not original.is_empty(): write_json("user://career_guest.json", {"save": original, "revision": 0, "dirty": false})
		write_json("user://guest_migrated.json", {"done": true})
	blocked = false
	pending = {}
	generation += 1
	if guest:
		session = {}
		career_key = "guest"
		baseline = read_json(cache_path()).get("save", {})
		if not FileAccess.file_exists(settings_path()):
			var old_pose: Dictionary = baseline.get("runtime", {}).get("prototype_player", {})
			if not old_pose.is_empty(): write_json(settings_path(), old_pose)
		revision = 0
	else:
		career_key = str(session.account_id).sha256_text().substr(0, 24)
		var remote := await request_rpc("afb_get_save", {"p_session_token": session.session_token})
		if remote.has("error"): return remote
		var cloud: Dictionary = remote.get("save_json", {}) if remote.get("exists", false) else {}
		if int(cloud.get("save_schema", 0)) > 2: return {"error": "This career needs a newer desktop build. Please update."}
		revision = int(cloud.get("_afb_revision", 0))
		var cached := read_json(cache_path())
		if cached.get("dirty", false):
			if int(cached.get("revision", -1)) != revision and not use_cloud:
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
	return save

func queue_save(raw: Dictionary) -> void:
	if not launched: return
	var save := shared_save(raw)
	var pose: Dictionary = raw.get("runtime", {}).get("prototype_player", {})
	if not pose.is_empty(): write_json(settings_path(), pose)
	write_json(cache_path(), {"save": save, "revision": revision, "dirty": not session.is_empty()})
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
		outgoing["_afb_base_revision"] = revision
		set_status("Saving to AFewBuds cloud…")
		var result := await request_rpc("afb_set_save", {"p_session_token": session.session_token, "p_save_json": outgoing})
		if epoch != generation: break
		if result.has("error") or not result.get("ok", false):
			if pending.is_empty(): pending = outgoing
			blocked = str(result.get("reason", "")) in ["save_conflict", "client_update_required", "save_schema_newer", "cloud_newer"]
			set_status("Cloud conflict — saved locally. Return to sign-in to load the newer career." if blocked else "Saved locally. Cloud unavailable — retry with F5.")
			break
		revision = int(result.get("revision", revision))
		baseline["_afb_revision"] = revision
		write_json(cache_path(), {"save": baseline, "revision": revision, "dirty": not pending.is_empty()})
		set_status("Cloud saved — " + str(session.username))
		await request_rpc("afb_leaderboard_report", {"p_session_token": session.session_token})
	busy = false

func sign_out() -> void:
	generation += 1
	launched = false
	session.clear()
	pending = {}
	blocked = false
	if FileAccess.file_exists(SESSION): DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION))
