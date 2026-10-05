extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if not "QA" in OS.get_user_data_dir(): quit(1); return
	var client = load("res://account/cloud.gd").new()
	root.add_child(client)
	client.service_url = "http://127.0.0.1:" + OS.get_environment("AFB_TEST_HTTP_PORT")
	var rejected: Dictionary = await client.request_rpc("afb_login", {"p_username": "fixture", "p_password": "wrong", "p_remember": false})
	var accepted: Dictionary = await client.request_rpc("afb_login", {"p_username": "fixture", "p_password": "fixture-password", "p_remember": true})
	var valid: bool = rejected.get("error") == "invalid_username_or_password" and client.accept_session(accepted, true)
	var restored: Dictionary = await client.restore_session()
	valid = valid and restored.get("username") == "fixture"
	print("HTTP_TEST_RESULT: ", "PASS" if valid else "FAIL")
	client.sign_out()
	client.queue_free()
	quit(0 if valid else 1)
