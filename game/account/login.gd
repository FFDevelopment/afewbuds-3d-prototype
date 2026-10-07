extends Control
var box: VBoxContainer
var message: Label
var username: LineEdit
var password: LineEdit
var email: LineEdit
var remember: CheckBox
var updates: CheckBox
var register_mode := false
var working := false
var conflict_button: Button
var submit_button: Button
var mode_button: Button
var guest_button: Button
var forgot_button: Button
var recovery_mode := false
var recovery_identifier: LineEdit
var recovery_hint: Label
var recovery_send: Button
var recovery_back: Button
var center: CenterContainer
var scroll: ScrollContainer

func _ready() -> void:
	# Release templates disable --script; CI enters an isolated guest smoke test here.
	if DisplayServer.get_name() == "headless" and OS.get_cmdline_user_args().has("--export-smoke"):
		add_child(load("res://prototype/export_smoke.gd").new())
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("0b1310")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 16
	scroll.offset_top = 16
	scroll.offset_right = -16
	scroll.offset_bottom = -16
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	center = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	box = VBoxContainer.new()
	box.custom_minimum_size.x = 460
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)
	var logo := TextureRect.new()
	logo.texture = load("res://assets/branding/afb_app_icon.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size.y = 100
	box.add_child(logo)
	label("AFewBuds", 32)
	label("Welcome to Bongchester", 18)
	label("Progress saved on this device.", 16)
	username = field("Username")
	username.max_length = 20
	password = field("Password", true)
	email = field("Recovery email (optional for registration)")
	email.max_length = 254
	email.visible = false
	updates = CheckBox.new()
	updates.text = "Email me game updates"
	updates.visible = false
	box.add_child(updates)
	remember = CheckBox.new()
	remember.text = "Remember me on this computer"
	box.add_child(remember)
	submit_button = button("SIGN IN", submit)
	mode_button = button("Create account / Back to sign in", toggle_mode)
	forgot_button = button("Forgot password?", func(): set_recovery_mode(true))
	recovery_hint = label("Enter your AFewBuds username or saved recovery email. If several accounts share that email, use your username. The single-use reset link expires in 30 minutes.",16)
	recovery_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	recovery_identifier = field("Username or recovery email")
	recovery_identifier.max_length = 254
	recovery_identifier.text_submitted.connect(func(_text): send_recovery())
	recovery_send = button("SEND RESET EMAIL", send_recovery)
	recovery_back = button("Back to sign in", func(): set_recovery_mode(false))
	for control in [recovery_hint,recovery_identifier,recovery_send,recovery_back]: control.hide()
	guest_button = button("CONTINUE LOCAL CAREER", guest)
	var green := StyleBoxFlat.new()
	green.bg_color = Color("216b40")
	green.set_corner_radius_all(8)
	guest_button.add_theme_stylebox_override("normal", green)
	username.grab_focus()
	conflict_button = button("Continue from cloud (back up desktop copy)", load_cloud)
	conflict_button.hide()
	message = label(AFBCloud.CONNECTION_NOTE, 16)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	password.text_submitted.connect(func(_text): submit())
	get_viewport().size_changed.connect(fit_layout)
	fit_layout()

	working = true
	var restored: Dictionary = await AFBCloud.restore_session()
	working = false
	if restored.has("session_token"): await launch()
	elif restored.has("error"): message.text = "Could not restore sign-in. Sign in again or retry when connected."

func label(value: String, size: int) -> Label:
	var l := Label.new()
	l.text = value
	l.add_theme_font_size_override("font_size", size)
	box.add_child(l)
	return l

func field(placeholder: String, secret: bool = false) -> LineEdit:
	var f := LineEdit.new()
	f.placeholder_text = placeholder
	f.secret = secret
	f.custom_minimum_size.y = 42
	box.add_child(f)
	return f

func button(value: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = value
	b.custom_minimum_size.y = 42
	b.pressed.connect(callback)
	box.add_child(b)
	return b

func fit_layout() -> void:
	var view := get_viewport_rect().size
	box.custom_minimum_size.x = minf(460,maxf(260,view.x-48))
	center.custom_minimum_size.y = maxf(0,view.y-32)

func refresh_mode() -> void:
	username.visible = not recovery_mode
	password.visible = not recovery_mode
	email.visible = register_mode and not recovery_mode
	updates.visible = register_mode and not recovery_mode
	remember.visible = not recovery_mode
	submit_button.visible = not recovery_mode
	mode_button.visible = not recovery_mode
	forgot_button.visible = not recovery_mode
	guest_button.visible = not recovery_mode
	submit_button.text = "CREATE ACCOUNT" if register_mode else "SIGN IN"
	for control in [recovery_hint,recovery_identifier,recovery_send,recovery_back]: control.visible = recovery_mode
	conflict_button.hide()

func toggle_mode() -> void:
	if working: return
	register_mode = not register_mode
	recovery_mode = false
	refresh_mode()
	message.text = "Create account: choose a username and password (at least 8 characters), then submit." if register_mode else "Sign in with your existing AFewBuds account."

func set_recovery_mode(enabled: bool) -> void:
	if working: return
	recovery_mode = enabled
	register_mode = false
	password.clear()
	refresh_mode()
	message.text = "Open the link in your email to reset your password in the browser, then return here to sign in." if enabled else AFBCloud.CONNECTION_NOTE
	if enabled: recovery_identifier.grab_focus()
	else: username.grab_focus()

func send_recovery() -> void:
	if working or not recovery_mode: return
	working = true
	recovery_send.disabled = true
	recovery_back.disabled = true
	recovery_identifier.editable = false
	message.text = "Sending recovery email…"
	var result: Dictionary = await AFBCloud.request_password_reset(recovery_identifier.text)
	working = false
	recovery_send.disabled = false
	recovery_back.disabled = false
	recovery_identifier.editable = true
	message.text = str(result.get("error", result.get("message", "Password recovery is temporarily unavailable.")))
	if result.get("ok", false):
		message.text += " Open the link in your email, then return here to sign in."

func submit() -> void:
	if working or recovery_mode: return
	working = true
	message.text = "Connecting…"
	var payload := {"p_username": username.text.strip_edges(), "p_password": password.text, "p_remember": remember.button_pressed}
	if register_mode:
		payload["p_email"] = email.text.strip_edges() if not email.text.strip_edges().is_empty() else null
		payload["p_updates_opt_in"] = updates.button_pressed
	var result: Dictionary = await AFBCloud.request_rpc("afb_register" if register_mode else "afb_login", payload)
	password.clear()
	working = false
	if result.has("error"):
		message.text = str(result.error).replace("_", " ")
		return
	if not AFBCloud.accept_session(result, remember.button_pressed):
		message.text = "Incomplete sign-in response. Please retry."
		return
	await launch()

func launch(use_cloud: bool = false) -> void:
	working = true
	message.text = "Loading your shared career…"
	var result: Dictionary = await AFBCloud.prepare(false, use_cloud)
	working = false
	if result.get("ok", false): get_tree().change_scene_to_file("res://prototype/apartment.tscn")
	else:
		message.text = result.get("error", "Could not load career.")
		conflict_button.visible = result.get("conflict", false)

func load_cloud() -> void:
	if not working: await launch(true)

func guest() -> void:
	if working: return
	var result: Dictionary = await AFBCloud.prepare(true)
	if result.get("ok", false): get_tree().change_scene_to_file("res://prototype/apartment.tscn")
	else: message.text = result.get("error", "Could not load guest career.")
