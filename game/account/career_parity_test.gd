extends SceneTree
## Fictional server fixture only. Uses mock RPCs and sandboxed Godot user://.
var checks: int = 0
var failures: int = 0

func check(ok: bool, reason: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + reason)
	else:
		print("PASS: ", reason)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	check("QA" in OS.get_user_data_dir(), "No live career location is available to the test")
	if failures > 0:
		quit(1)
		return
	var original: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://account/career_parity_fixture.json"))
	check(original is Dictionary, "Career fixture has valid JSON")
	if not original is Dictionary:
		quit(1)
		return
	var cloud = load("res://account/mock_cloud.gd").new()
	root.add_child(cloud)
	cloud.inventory_preview = false
	cloud.accept_session({"account_id": "test-A", "session_token": "mock", "username": "QA"}, false)
	cloud.remote = original.duplicate(true)
	cloud.server_revision = 8
	var result: Dictionary = await cloud.prepare()
	check(result.get("ok", false), "Desktop loads the account's authoritative server snapshot")
	var loaded: Dictionary = cloud.read_json(cloud.ACTIVE)
	check(loaded.location_state.furniture_v1.items.furniture_101.property == "house", "House tent remains installed")
	check(loaded.location_state.furniture_v1.items.furniture_102.property == "backpack", "Previously packed tent stays in backpack")
	check(loaded.production_worker_friend_name == "Malik" and loaded.friend_staff_roles.Malik == "production", "Named production worker is restored")
	check(loaded.friend_staff_roles.Tyler == "dealer" and loaded.location_state.staff_assignments.Tyler == "apartment", "Dealer and his property assignment are restored")
	check(loaded.location_state.container_inventory.containers["house:storage"]["product|Street Green"] == 21, "House stock survives server to desktop load")
	var next: Dictionary = loaded.duplicate(true)
	# Simulate moving the remaining house tent and transferring an existing dealer.
	next.location_state.furniture_v1.items.furniture_101.property = "backpack"
	next.location_state.furniture_v1.items.furniture_101.erase("position")
	next.location_state.furniture_v1.items.furniture_101.erase("yaw")
	next.location_state.furniture_v1.items.furniture_101.locked = false
	next.location_state.staff_assignments.Tyler = "house"
	next.saved_unix = int(next.saved_unix) + 7
	cloud.queue_save(next)
	await cloud.flush()
	while cloud.busy:
		await process_frame
	check(cloud.remote.location_state.furniture_v1.items.furniture_101.property == "backpack" and not cloud.remote.location_state.furniture_v1.items.furniture_101.has("position"), "Packed tent is not accidentally reinstalled on upload")
	check(cloud.remote.location_state.furniture_v1.items.furniture_102.property == "backpack", "The other packed tent is not lost")
	check(cloud.remote.location_state.staff_assignments.Tyler == "house", "Transferred dealer stays associated with the house")
	check(cloud.remote.production_worker_friend_name == "Malik" and cloud.remote.friend_staff_roles.Malik == "production", "Production role survives desktop save")
	check(cloud.remote.location_state.container_inventory.containers["apartment:storage"]["product|Purple Dream"] == 16 and cloud.remote.future_field.preserve_me, "Unrelated property stock and future save fields remain intact")
	# Simulate the phone saving a newer authoritative career to the same server.
	var phone: Dictionary = cloud.remote.duplicate(true)
	phone.location_state.staff_assignments.Tyler = "apartment"
	phone.production_worker_friend_name = "Malik"
	phone.saved_unix = int(phone.saved_unix) + 9
	cloud.remote = phone
	cloud.server_revision += 1
	result = await cloud.prepare()
	check(result.get("ok", false), "Desktop reopening receives newer phone career")
	loaded = cloud.read_json(cloud.ACTIVE)
	check(loaded.location_state.staff_assignments.Tyler == "apartment", "Desktop follows the phone's newer dealer assignment")
	check(loaded.location_state.furniture_v1.items.furniture_101.property == "backpack" and loaded.location_state.furniture_v1.items.furniture_102.property == "backpack", "Desktop keeps both tents packed after handoff")
	# The server must reject any desktop write with an older revision.
	cloud.remote.location_state.staff_assignments.Tyler = "house"
	cloud.server_revision += 1
	next = loaded.duplicate(true)
	next.location_state.staff_assignments.Tyler = "apartment"
	cloud.queue_save(next)
	await cloud.flush()
	while cloud.busy:
		await process_frame
	check(cloud.blocked and cloud.block_reason == "save_conflict", "Concurrent phone update blocks a stale desktop save")
	check(cloud.remote.location_state.staff_assignments.Tyler == "house", "Server's newer worker assignment cannot be overwritten by stale desktop")
	cloud.queue_free()
	await process_frame
	print("CAREER_PARITY_RESULT: ", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
