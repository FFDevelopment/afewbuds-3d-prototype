extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label_text: String) -> void:
	if ok: print("PASS: ", label_text)
	else:
		failures += 1
		push_error(label_text)
func run() -> void:
	check("QA" in OS.get_user_data_dir(), "cloud tests isolated")
	if failures: quit(1); return
	var cloud = load("res://account/mock_cloud.gd").new()
	root.add_child(cloud)
	cloud.inventory_preview=false
	cloud.write_json(cloud.ACTIVE, {"cash": 321, "runtime": {"prototype_player": {"x": 1.5, "z": 2}}})
	var rejected: Dictionary = await cloud.request_rpc("afb_login", {"p_password": "wrong"})
	check(rejected.has("error"), "invalid credentials remain on sign-in")
	var login: Dictionary = await cloud.request_rpc("afb_login", {"p_password": "mock-password"})
	check(cloud.accept_session(login, true), "valid existing-account response accepted")
	cloud.session = {}
	var remembered: Dictionary = await cloud.restore_session()
	check(remembered.get("username") == "QA" and cloud.session.session_token == "mock", "remembered session validates and restores")
	cloud.remote = {"lifetime_revenue":98765,"advancement_stats":{"sales":321,"dealer_sales":84},"cash": 400, "save_schema": 2, "future_field": {"keep": true}, "runtime": {"current_view": "main_grow_door", "future": 7}}
	var result: Dictionary = await cloud.prepare()
	check(result.get("ok", false) and cloud.remote_signature == cloud.fingerprint(cloud.remote), "account career restores existing API save")
	check(cloud.read_json(cloud.ACTIVE).get("lifetime_revenue")==98765 and cloud.read_json(cloud.ACTIVE).get("advancement_stats",{}).get("sales")==321,"Existing account lifetime and sales load without guest zeros")
	var save := {"cash": 500, "save_schema": 2, "runtime": {"prototype_player": {"x": 2}, "current_view": "fp_walk"}}
	cloud.queue_save(save)
	await cloud.flush()
	while cloud.busy: await process_frame
	check(cloud.remote.cash == 500 and cloud.writes == 1, "desktop uploads shared progression")
	check(cloud.remote.get("lifetime_revenue")==98765 and cloud.remote.get("advancement_stats",{}).get("sales")==321,"Desktop save preserves account leaderboard totals")
	check(not cloud.remote.runtime.has("prototype_player") and cloud.remote.runtime.current_view == "main_grow_door", "camera isolated from shared save")
	check(cloud.remote.future_field.keep and cloud.remote.runtime.future == 7, "unknown root and runtime fields retained")
	check(cloud.read_json(cloud.settings_path()).x == 2, "camera persisted per account on desktop")
	cloud.remote.cash = 700
	cloud.queue_save({"cash": 550, "save_schema": 2})
	await cloud.flush()
	while cloud.busy: await process_frame
	check(cloud.blocked and cloud.remote.cash == 700, "concurrent regular save blocks stale desktop upload")
	result = await cloud.prepare()
	check(result.get("conflict", false), "pending desktop conflict requires cloud restore decision")
	result = await cloud.prepare(false, true)
	check(result.get("ok", false) and cloud.baseline.cash == 700, "explicit cloud restore backs up pending desktop career")
	check(FileAccess.file_exists(cloud.cache_path()+".backup"), "conflicting desktop career retained as backup")
	cloud.fail_network = true
	cloud.queue_save({"cash": 725, "save_schema": 2})
	await cloud.flush()
	while cloud.busy: await process_frame
	check(cloud.read_json(cloud.cache_path()).dirty and not cloud.pending.is_empty(), "offline save remains pending locally")
	cloud.fail_network = false
	await cloud.flush()
	check(cloud.remote.cash == 725 and not cloud.read_json(cloud.cache_path()).dirty, "network retry uploads pending progress")
	cloud.reject_save = true
	cloud.queue_save({"cash": 800, "save_schema": 2})
	await cloud.flush()
	while cloud.busy: await process_frame
	check(cloud.blocked and cloud.remote.cash == 725, "server rejection never reports a successful save")
	cloud.reject_save = false
	cloud.session = {"account_id": "test-B", "session_token": "mock2", "username": "QB"}
	cloud.remote = {}
	await cloud.prepare()
	check(not FileAccess.file_exists(cloud.ACTIVE), "new account never imports previous account active save")
	cloud.remote = {"save_schema": 999}
	result = await cloud.prepare()
	check(result.has("error"), "newer schema cannot be loaded into older desktop")
	await cloud.prepare(true)
	check(cloud.baseline.cash == 321, "original prototype guest save survives account slot preparation")
	check(cloud.read_json(cloud.settings_path()).x == 1.5, "original prototype camera migrates to desktop settings")
	cloud.queue_save({"cash": 350, "runtime": {"prototype_player": {"x": 2.5}}})
	await cloud.prepare(true)
	check(cloud.baseline.cash == 350 and cloud.read_json(cloud.settings_path()).x == 2.5, "local gameplay and camera survive restart separately")
	cloud.queue_free()
	print("CLOUD_TEST_RESULT: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
