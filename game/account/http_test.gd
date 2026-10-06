extends SceneTree
var failures: Array[String] = []
func check(ok: bool, description: String) -> void:
	if ok: print("PASS: ",description)
	else:
		failures.append(description)
		push_error("FAIL: "+description)

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
	check(valid,"existing login and session restoration")
	client.sign_out()
	var long_email := "full.recovery.address.longer.than.twenty@example.com"
	for identifier in ["fixture",long_email,"unknown-account","  "+long_email+"  ","a".repeat(242)+"@example.com"]:
		var result: Dictionary = await client.request_password_reset(identifier)
		check(result.get("ok",false) and result.get("message") == client.RECOVERY_MESSAGE,"recovery accepts username/full email and uses generic confirmation")
	for spec in [["send-failed","could not be sent"],["not-configured","not configured"],["unavailable","temporarily unavailable"],["malformed","Unexpected recovery"],["false-success","Unexpected recovery"],["   ","Enter your username"],["a".repeat(255),"254 characters"]]:
		var result: Dictionary = await client.request_password_reset(spec[0])
		check(result.has("error") and spec[1] in result.error,"recovery failure is not reported as success: "+spec[1])
	var autoload := root.get_node("AFBCloud")
	autoload.service_url = client.service_url
	var login = load("res://account/login.tscn").instantiate()
	root.add_child(login)
	await process_frame
	login.set_recovery_mode(true)
	login.recovery_identifier.text = long_email
	check(login.recovery_identifier.text == long_email and login.recovery_identifier.max_length == 254,"recovery UI preserves full email beyond 20 characters")
	check(not login.password.visible and login.recovery_send.visible,"recovery mode exposes only recovery controls")
	await login.send_recovery()
	check("reset link has been sent" in login.message.text and not login.working and not login.recovery_send.disabled,"native recovery form completes against HTTP fixture")
	login.recovery_identifier.text = "send-failed"
	await login.send_recovery()
	check("could not be sent" in login.message.text and login.recovery_identifier.editable,"send error keeps recovery form usable")
	login.set_recovery_mode(false)
	check(login.username.max_length == 20 and login.password.visible and not login.recovery_identifier.visible,"return to sign-in restores username rules")
	login.toggle_mode()
	check(login.email.visible and login.email.max_length == 254,"registration keeps separate full recovery email")
	login.queue_free()
	await process_frame
	print("HTTP_TEST_RESULT: ", "PASS" if failures.is_empty() else str(failures))
	client.sign_out()
	client.queue_free()
	quit(0 if failures.is_empty() else 1)
