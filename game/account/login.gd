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

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("0b1310")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
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
	label("3D Edition · AFewBuds Account", 18)
	username = field("Username")
	password = field("Password", true)
	email = field("Email (optional for registration)")
	email.visible = false
	updates = CheckBox.new()
	updates.text = "Email me game updates"
	updates.visible = false
	box.add_child(updates)
	remember = CheckBox.new()
	remember.text = "Remember me on this computer"
	box.add_child(remember)
	button("SIGN IN", submit)
	button("Create account / Back to sign in", toggle_mode)
	var continue_button := button("CONTINUE LOCAL CAREER", guest)
	var green := StyleBoxFlat.new()
	green.bg_color = Color("216b40")
	green.set_corner_radius_all(8)
	continue_button.add_theme_stylebox_override("normal", green)
	username.grab_focus()
	conflict_button = button("Continue from cloud (back up desktop copy)", load_cloud)
	conflict_button.hide()
	message = label(AFBCloud.CONNECTION_NOTE, 16)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	password.text_submitted.connect(func(_text): submit())

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

func toggle_mode() -> void:
	if working: return
	register_mode = not register_mode
	email.visible = register_mode
	updates.visible = register_mode
	message.text = "Create account: choose a username and password (at least 8 characters), then submit." if register_mode else "Sign in with your existing AFewBuds account."
	for child in box.get_children():
		if child is Button and child.text in ["SIGN IN", "CREATE ACCOUNT"]:
			child.text = "CREATE ACCOUNT" if register_mode else "SIGN IN"

func submit() -> void:
	if working: return
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
