extends CanvasLayer
var game: Node
var box: VBoxContainer
var notice: Label
var panel: PanelContainer
var metric := "revenue"
var period := "lifetime"
var listing: VBoxContainer
var working := false
var rankings_again:=false
var ranking_metrics:=["revenue","sales","dealer_sales","harvests","hybrids","raids","days","career_score"]

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
		user.max_length = 20
		var email := field(str(AFBCloud.session.get("email", "")) if AFBCloud.session.get("email") != null else "", "Recovery email")
		email.max_length = 254
		text("Save a recovery email so you can reset a forgotten password. Update emails are optional.")
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
	for value in ["Revenue", "Sales", "Dealer sales", "Harvests", "Hybrids", "Raids survived", "Days", "Career score"]: metrics.add_item(value)
	metrics.item_selected.connect(func(i): metric = ranking_metrics[i]; refresh_rankings())
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

func ranking_value(row: Dictionary, selected_metric: String) -> String:
	if not row.has("value") or row.value==null:return "Unavailable"
	return ("$" if selected_metric=="revenue" else "")+str(int(row.value))

func refresh_rankings() -> void:
	if working:
		rankings_again=true
		return
	working=true
	var selected_metric:=metric
	var selected_period:=period
	notice.text="Refreshing shared rankings…"
	# Finish the existing save/report path before reading this account's totals.
	# Never replace server totals with local counters or fabricate a missing zero.
	if not AFBCloud.session.is_empty() and not AFBCloud.blocked:
		if game!=null:game._save_game()
		await AFBCloud.flush()
		while AFBCloud.busy:await get_tree().process_frame
	var result: Dictionary=await AFBCloud.request_rpc("afb_leaderboard_get",{"p_metric":selected_metric,"p_range":selected_period,"p_limit":25,"p_session_token":AFBCloud.session.get("session_token")})
	working=false
	if selected_metric!=metric or selected_period!=period or rankings_again:
		rankings_again=false
		refresh_rankings()
		return
	for child in listing.get_children():listing.remove_child(child);child.queue_free()
	if result.has("error"):
		notice.text=str(result.error)
		return
	var me: Variant=own_ranking(result,AFBCloud.session)
	notice.text=("THIS WEEK" if selected_period=="weekly" else "LIFETIME")+" · "+selected_metric.replace("_"," ").capitalize()
	if me is Dictionary:
		notice.text+="\n"+str(AFBCloud.session.get("username","Your account"))+" — your rank: #%s — %s" % [me.get("rank","—"),ranking_value(me,selected_metric)]
	elif AFBCloud.session.is_empty():notice.text+="\nSign in to see your own rank."
	else:notice.text+="\nYour account is not ranked for this period yet."
	if not AFBCloud.leaderboard_error.is_empty():notice.text+="\nCareer saved, but leaderboard reporting failed: "+AFBCloud.leaderboard_error
	if AFBCloud.blocked or not AFBCloud.pending.is_empty():notice.text+="\nDesktop progress is not synced yet. "+AFBCloud.last_status
	for row in result.get("top",[]):
		var label:=Label.new()
		label.text="#%s   %s   —   %s" % [row.get("rank",""),row.get("username","Player"),ranking_value(row,selected_metric)]
		if str(row.get("account_id",""))==str(AFBCloud.session.get("account_id","signed-out")) or str(row.get("username","")).to_lower()==str(AFBCloud.session.get("username","signed-out")).to_lower():
			label.text+="  (You)";label.modulate=Color("b6f38a")
		label.custom_minimum_size.y=34
		listing.add_child(label)

func own_ranking(result: Dictionary, session: Dictionary) -> Variant:
	# The public row and personal summary must identify the same account.
	# Prefer the exact account-id row when the response includes it; never use
	# a local career counter or another player's value as a fallback.
	var account_id:=str(session.get("account_id",""))
	if account_id.is_empty():return null
	for row in result.get("top",[]):
		if row is Dictionary and str(row.get("account_id",""))==account_id:return row
	var me: Variant=result.get("me")
	if me is Dictionary and str(me.get("account_id",""))==account_id:return me
	return null
