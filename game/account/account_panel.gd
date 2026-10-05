extends CanvasLayer
var game: Node
var box: VBoxContainer
var notice: Label
var panel: PanelContainer
var metric := "revenue"
var period := "lifetime"
var listing: VBoxContainer
var working := false

func _ready() -> void:
	layer = 100
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.05, 0.03, 0.95)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(680, 660)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func text(value: String) -> Label:
	var l := Label.new()
	l.text = value
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(l)
	return l

func button(value: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = value
	b.custom_minimum_size.y = 40
	b.pressed.connect(callback)
	box.add_child(b)
	return b

func field(value: String, hint: String, secret: bool = false) -> LineEdit:
	var f := LineEdit.new()
	f.text = value
	f.placeholder_text = hint
	f.secret = secret
	f.custom_minimum_size.y = 40
	box.add_child(f)
	return f

func close() -> void:
	if working: return
	game.account_overlay = null
	queue_free()

func show_account() -> void:
	text("AFewBuds Account")
	if AFBCloud.session.is_empty():
		text("Guest career — saved only on this computer.")
	else:
		text("Signed in as " + str(AFBCloud.session.username))
		var user := field(str(AFBCloud.session.username), "Username")
		var email := field(str(AFBCloud.session.get("email", "")) if AFBCloud.session.get("email") != null else "", "Recovery email")
		var updates := CheckBox.new()
		updates.text = "Email me game updates"
		updates.button_pressed = AFBCloud.session.get("updates_opt_in", false)
		box.add_child(updates)
		var current := field("", "Current password (to confirm changes)", true)
		var next := field("", "New password (only to change password)", true)
		button("Save profile", func():
			if working: return
			working = true
			var result: Dictionary = await AFBCloud.request_rpc("afb_account_update_profile", {"p_session_token": AFBCloud.session.session_token, "p_current_password": current.text, "p_username": user.text.strip_edges(), "p_email": email.text.strip_edges() if not email.text.strip_edges().is_empty() else null, "p_updates_opt_in": updates.button_pressed})
			current.clear()
			working = false
			notice.text = str(result.get("error", "Account updated.")).replace("_", " ")
			if not result.has("error"):
				var merged: Dictionary = AFBCloud.session.duplicate()
				merged.merge(result, true)
				AFBCloud.accept_session(merged, AFBCloud.remember)
		)
		button("Change password", func():
			if working: return
			working = true
			var result: Dictionary = await AFBCloud.request_rpc("afb_account_change_password", {"p_session_token": AFBCloud.session.session_token, "p_current_password": current.text, "p_new_password": next.text, "p_remember": AFBCloud.remember})
			current.clear()
			next.clear()
			working = false
			notice.text = str(result.get("error", "Password updated.")).replace("_", " ")
			if not result.has("error"): AFBCloud.accept_session(result, AFBCloud.remember)
		)
	notice = text(AFBCloud.last_status)
	button("Save and return to sign-in", leave)
	button("Close", close)

func leave() -> void:
	if working: return
	working = true
	game._save_game()
	await AFBCloud.flush()
	while AFBCloud.busy: await get_tree().process_frame
	AFBCloud.sign_out()
	game.get_tree().change_scene_to_file("res://account/login.tscn")

func show_leaderboard() -> void:
	text("AFewBuds · Global Leaderboard")
	var metrics := OptionButton.new()
	for value in ["Revenue", "Sales", "Days"]: metrics.add_item(value)
	metrics.item_selected.connect(func(i): metric = ["revenue", "sales", "days"][i]; refresh_rankings())
	box.add_child(metrics)
	var periods := OptionButton.new()
	periods.add_item("Lifetime")
	periods.add_item("This week")
	periods.item_selected.connect(func(i): period = "weekly" if i == 1 else "lifetime"; refresh_rankings())
	box.add_child(periods)
	notice = text("Loading…")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(620, 370)
	box.add_child(scroll)
	listing = VBoxContainer.new()
	listing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(listing)
	button("Refresh", refresh_rankings)
	button("Close", close)
	refresh_rankings()

func refresh_rankings() -> void:
	if working: return
	working = true
	var result: Dictionary = await AFBCloud.request_rpc("afb_leaderboard_get", {"p_metric": metric, "p_range": period, "p_limit": 25, "p_session_token": AFBCloud.session.get("session_token")})
	working = false
	for child in listing.get_children(): child.queue_free()
	notice.text = str(result.get("error", "Shared rankings across regular and 3D AFewBuds."))
	if result.get("me") is Dictionary: notice.text += "  Your rank: #" + str(result.me.get("rank", "—"))
	for row in result.get("top", []):
		var l := Label.new()
		l.text = "#%s   %s   —   %s%s" % [row.get("rank", ""), row.get("username", "Player"), "$" if metric == "revenue" else "", row.get("value", 0)]
		l.custom_minimum_size.y = 34
		listing.add_child(l)
