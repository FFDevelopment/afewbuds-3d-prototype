extends "res://scripts/main.gd"
## Adapter over the pinned AFewBuds simulation. Uses the shared simulation with native account integration.
const Districts = preload("res://scripts/districts.gd")
const FirstPersonPlayer = preload("res://prototype/player.gd")
const REACH := 2.6
const WALL_NAMES := ["FrontWindowLeft", "FrontWindowRight", "FrontWindowBottom", "FrontWindowTop", "FrontWall", "FrontWallL", "FrontWallR", "FrontWallHeader", "RearWall", "LeftWall", "RightWall", "PartitionLeft", "PartitionRight", "PartitionHeader"]
var account_overlay: CanvasLayer
var fp_player: CharacterBody3D
var fp_ready := false
var fp_control := ""
var fp_container: String = ""
var fp_target: Area3D
var fp_crosshair: Label
var fp_prompt: Label
var fp_info: Label
var fp_hint: Label
var fp_stamina_bar: ProgressBar
var fp_stamina_label: Label
var fp_hud: Control
var fp_was_modal := true
var fp_collisions: Array[Dictionary] = []
var fp_collision_timer := 0.0
var fp_station_opening := false
var fp_open_epoch := 0
var fp_sync_warning := ""
var fp_status_text := ""
var fp_status_remaining := 0.0
var controller_work_held:bool=false

func _load_game() -> void:
	super._load_game()
	# The shared first-day guide replaces the legacy fixed-camera lesson.
	tutorial_seen = true
	tutorial_active = false

func _apply_cloud_boot_save() -> void:
	pass

func _ready() -> void:
	super._ready()
	fp_player = FirstPersonPlayer.new()
	fp_player.name = "FirstPersonPlayer"
	add_child(fp_player)
	fp_player.position = Vector3(0, 0.12, 1.2)
	fp_player.view = camera
	camera.near = 0.05
	camera.fov = 76.0
	var saved: Dictionary = AFBCloud.read_json(AFBCloud.settings_path()) if AFBCloud.launched else restored_runtime.get("prototype_player", {})
	if not saved.is_empty():
		fp_player.position = Vector3(clampf(float(saved.get("x", 0)), -31.5, 200.5), clampf(float(saved.get("y", 0.12)),0.0,3.8), clampf(float(saved.get("z", 1.2)), -35.5, 38.5))
		fp_player.yaw = float(saved.get("yaw", 0))
		fp_player.pitch = clampf(float(saved.get("pitch", 0)), -1.35, 1.35)
	# Reject invalid/interior-wall positions from stale desktop settings.
	if fp_player.position.z > -10.4 and fp_player.position.z < 6.1 and absf(fp_player.position.x) > 4.5 and absf(fp_player.position.x) < 5.4:
		fp_player.position = Vector3(0, 0.12, 1.2)
	_add_physical_collisions(self)
	_add_neighborhood_ground_collision()
	_add_prop_collisions()
	_add_station_targets()
	_setup_desktop_panels()
	_build_fp_hud()
	get_viewport().size_changed.connect(_setup_desktop_panels)
	AFBCloud.sync_changed.connect(_on_cloud_status)
	fp_ready = true
	current_view = "fp_walk"
	fp_player.sync_camera()
	_refresh_navigation_ui()
	if not session_paused and not tutorial_panel.visible:
		_pause_gameplay("WELCOME TO BONGCHESTER\n\nWASD to walk · Mouse to look · Shift to sprint (uses stamina)\nE to use a station or open/close the front door · P for phone\nEsc to pause · F5 to save\n\nOpen the front door and walk outside, then close it behind you. R at the door checks for visitors. Walk through the interior opening into the grow room. Harvest the ready Purple Dream plant, then take it to the packaging bench.\n\nYour progress saves automatically.")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if ProjectSettings.get_setting("application/config/custom_user_dir_name","")!="AFewBuds-Visual-Lab-01":
		call_deferred("_install_map_update")

func _install_map_update()->void:
	if has_node("MapVisuals"):return
	var map_visuals=load("res://visual_lab/runtime.gd").new()
	map_visuals.name="MapVisuals"
	add_child(map_visuals)
	map_visuals.setup(self)

func _process(delta: float) -> void:
	if not fp_ready:
		return
	# A non-ring view prevents the old fixed-view look system from steering the camera.
	super._process(delta)
	fp_collision_timer += delta
	if fp_collision_timer >= 0.25:
		fp_collision_timer = 0.0
		_sync_physical_collisions()
		if house_system_context and system_control_panel.visible:_refresh_system_control_panel()
	var modal := _any_modal_open() or daily_report_pending
	if modal:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif fp_was_modal:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	fp_was_modal = modal
	fp_player.enabled = not modal and not neighborhood.transitioning and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if not modal:
		current_view = "fp_walk"
		current_room = "neighborhood" if not neighborhood.indoors(fp_player.position) else ("grow" if fp_player.position.z < -4.0 else "main")
		_update_target()
	else:
		fp_target = null
	fp_crosshair.visible = not modal
	fp_prompt.visible = not modal and not fp_prompt.text.is_empty()
	fp_hint.visible = false
	_controller_work_tick(delta,DesktopInput.stick(false))
	if DesktopInput.controller_active:
		if trim_panel.visible and trim_harvest_amount>0:trim_instruction.text="Hold A / Cross and move the left stick to trim."
		if bag_minigame_panel.visible and bag_current_units<bag_target_units:bag_instruction.text="Hold A / Cross and move the left stick. Release over the bag to add up to %dg." % _packing_drop_size()
	fp_info.visible = not modal
	fp_info.text = "%s\n%s   ·   %s   ·   $%d" % [Districts.heading(fp_player.position), neighborhood.location_label(fp_player.position) if current_room == "neighborhood" else ("GROW ROOM" if current_room == "grow" else "LIVING ROOM"), _format_game_clock(), cash]
	fp_hint.text = "L3 click while moving forward: toggle sprint · Right stick: look · A: interact · D-pad Up: phone · Start: pause" if DesktopInput.controller_active else "%s/%s/%s/%s Walk · Shift + forward Sprint · %s Interact · %s Phone · Esc Pause · %s Save" % [DesktopInput.label("forward"),DesktopInput.label("left"),DesktopInput.label("backward"),DesktopInput.label("right"),DesktopInput.label("interact"),DesktopInput.label("phone"),DesktopInput.label("save")]
	_update_fp_stamina_hud()
	_hide_old_navigation()
	_tick_status_notification(delta)

func _input(event: InputEvent) -> void:
	if not fp_ready or is_instance_valid(DesktopInput.settings) or not DesktopInput.rebinding.is_empty():
		return
	if inventory_system.furniture.handle_placement_input(event):
		get_viewport().set_input_as_handled();return
	if event.is_pressed() and not event.is_echo():
		if DesktopInput.is_back(event):
			if not _close_active_panel():
				if session_paused:
					_resume_gameplay()
				else:
					_pause_gameplay()
			get_viewport().set_input_as_handled()
			return
		if get_viewport().gui_get_focus_owner() is LineEdit or get_viewport().gui_get_focus_owner() is TextEdit:
			return
		if event is InputEventJoypadButton and DesktopInput.pressed(event,"sprint") and not _any_modal_open():
			fp_player.toggle_controller_sprint();get_viewport().set_input_as_handled();return
		if DesktopInput.pressed(event,"backpack") and (not _any_modal_open() or (inventory_system.is_open() and event is InputEventKey)):
			if inventory_system.is_open():inventory_system.close()
			else:inventory_system.open_backpack()
			get_viewport().set_input_as_handled();return
		if DesktopInput.pressed(event,"save"):
			_phone_manual_save()
			get_viewport().set_input_as_handled()
			return
		if DesktopInput.pressed(event,"tour") and neighborhood.property_opportunity.touring and not _any_modal_open():
			neighborhood.property_opportunity.show_details()
			get_viewport().set_input_as_handled()
			return
		if DesktopInput.pressed(event,"phone") and ((phone_open and event is InputEventKey) or not _any_modal_open()):
			_toggle_phone()
			get_viewport().set_input_as_handled()
			return
		if DesktopInput.pressed(event,"visitor") and not _any_modal_open() and not daily_report_pending:
			_update_target()
			if _can_use_apartment_peephole() and fp_target != null and str(fp_target.get_meta("interaction_id", "")) == "station_door":
				if customer_waiting and peephole_checked:
					_open_customer_sale()
				else:
					_open_peephole()
			get_viewport().set_input_as_handled()
			return
		if DesktopInput.pressed(event,"interact") and not _any_modal_open() and not daily_report_pending:
			_use_target()
			get_viewport().set_input_as_handled()
			return
	if is_instance_valid(account_overlay):
		return
	if _any_modal_open():
		# Preserve existing drag-to-bag and trim controls, scrolling, and UI buttons.
		if plant_direct_panel.visible and plant_direct_scroll != null and plant_direct_scroll.handle_pointer(event):
			get_viewport().set_input_as_handled()
		elif _handle_station_list_pointer(event) or _handle_station_pointer(event):
			get_viewport().set_input_as_handled()
		elif phone_open and phone_scroll != null and phone_scroll.handle_pointer(event):
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		fp_player.look(event.relative)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()

func _go_to_view(view_name: String, animate: bool = true) -> void:
	if not fp_ready:
		super._go_to_view(view_name, animate)
		return
	_cancel_camera_view_tween()
	current_view = "fp_walk"
	_refresh_navigation_ui()

func _tick_status_notification(delta:float) -> void:
	if status_label.text!=fp_status_text:
		fp_status_text=status_label.text
		fp_status_remaining=4.0 if not fp_status_text.is_empty() else 0.0
	else:
		fp_status_remaining=maxf(0.0,fp_status_remaining-delta)
	if fp_status_remaining<=0.0:
		status_label.text=""
		fp_status_text=""
	status_label.visible=fp_status_remaining>0.0

func _refresh_navigation_ui() -> void:
	if not fp_ready:
		super._refresh_navigation_ui()
		return
	_hide_old_navigation()

func _hide_old_navigation() -> void:
	for control in [left_button, right_button, forward_button, back_button, contextual_button, door_quick_button, view_label, world_top_bar]:
		if is_instance_valid(control):
			control.visible = false

func _refresh_tutorial_coach() -> void:
	if not fp_ready:
		super._refresh_tutorial_coach()
		return
	if tutorial_world_coach != null:
		tutorial_world_coach.visible = false
	if tutorial_phone_coach != null:
		tutorial_phone_coach.visible = false
	_setup_desktop_panels()

func _quick_turn_to_door() -> void:
	status_label.text = "Walk to the front door and press R to answer."

func _capture_runtime_state() -> Dictionary:
	var data: Dictionary = super._capture_runtime_state()
	if fp_player != null:
		data["prototype_player"] = {"x": fp_player.position.x, "y": fp_player.position.y, "z": fp_player.position.z, "yaw": fp_player.yaw, "pitch": fp_player.pitch}
	return data

func _reset_beta_save() -> void:
	if not AFBCloud.session.is_empty():
		status_label.text = "Shared career resets are not supported here. Sign out to reset your local guest career."
		return
	super._reset_beta_save()

func _confirm_beta_reset() -> void:
	super._confirm_beta_reset()
	if reset_in_progress:
		AFBCloud.baseline = {}
		AFBCloud.pending = {}
		AFBCloud.write_json(AFBCloud.cache_path(), {})
		AFBCloud.write_json(AFBCloud.settings_path(), {})

func _save_game() -> void:
	if phone_remote_stock_change:return
	super._save_game()
	if not reset_in_progress and FileAccess.file_exists(SAVE_PATH):
		AFBCloud.queue_save(AFBCloud.read_json(SAVE_PATH))

func _phone_manual_save() -> void:
	_save_game()
	_show_save_notification("GAME SAVED", "Saved locally. Cloud sync is queued." if not AFBCloud.session.is_empty() else "Saved on this device — guest.")

func _phone_safe_quit() -> void:
	var menu:Node=inventory_system.session_menu
	if menu.quitting:return
	menu.quitting=true
	phone_open=false;phone_panel.hide()
	_pause_gameplay();_save_game()
	if not last_save_ok:
		menu.quit_failed("Could not save on this device. Please try again. The game is still open.")
		return
	await AFBCloud.flush()
	while AFBCloud.busy:await get_tree().process_frame
	if not AFBCloud.pending.is_empty() or AFBCloud.blocked:
		menu.quit_failed("Saved on this device, but cloud sync needs attention. Please retry before quitting.")
		return
	if not await AFBCloud.release_play():
		menu.quit_failed("Could not close the cloud session. Please retry.")
		return
	menu.quit_saved()

func _any_modal_open() -> bool:
	if neighborhood != null and neighborhood.property_opportunity != null and neighborhood.property_opportunity.is_open(): return true
	return fp_station_opening or is_instance_valid(account_overlay) or super._any_modal_open()

func _open_web_account_settings() -> void:
	_open_account_overlay(false)

func _open_web_leaderboard() -> void:
	_open_account_overlay(true)

func _open_account_overlay(rankings: bool) -> void:
	if is_instance_valid(account_overlay): return
	_pause_gameplay()
	account_overlay = load("res://account/account_panel.gd").new()
	account_overlay.game = self
	add_child(account_overlay)
	if rankings: account_overlay.show_leaderboard()
	else: account_overlay.show_account()

func _on_cloud_status(message: String) -> void:
	if is_instance_valid(status_label):
		if AFBCloud.sync_warning:
			status_label.text = message
			fp_sync_warning = message
		elif not fp_sync_warning.is_empty() and not message.begins_with("Saving "):
			if status_label.text == fp_sync_warning:status_label.text = ""
			fp_sync_warning = ""
	if AFBCloud.blocked and inventory_system!=null:
		inventory_system.session_menu.on_cloud_event("replaced" if AFBCloud.block_reason in ["session_replaced","session_invalid"] else "save_conflict")

func _close_active_panel() -> bool:
	if inventory_system.packing.is_open():inventory_system.packing.close();return true
	if inventory_system.furniture.is_open():inventory_system.furniture.close();return true
	if inventory_system!=null and inventory_system.is_open():
		inventory_system.close()
		return true
	if neighborhood.location_ops.is_open():
		neighborhood.location_ops.close()
		return true
	if neighborhood.property_opportunity.is_open():
		neighborhood.property_opportunity.end_tour()
		return true
	if is_instance_valid(account_overlay):
		account_overlay.close()
		return true
	if reset_confirmation_open:
		_cancel_beta_reset()
	elif phone_open:
		_toggle_phone()
	elif trim_panel.visible:
		_close_trim_minigame()
	elif bag_minigame_panel.visible:
		_close_bag_minigame()
	elif plant_direct_panel.visible:
		_close_direct_plant()
	elif bagging_panel.visible:
		_close_bagging_panel()
	elif dealer_storage_panel.visible:
		_close_dealer_storage_panel()
	elif storage_panel.visible:
		_close_storage_panel()
	elif supply_inventory_panel.visible:
		_close_supply_inventory_panel()
	elif system_control_panel.visible:
		_close_system_control_panel()
	elif peephole_panel.visible:
		_close_peephole()
	elif grow_panel.visible:
		_close_grow_panel()
	elif sale_panel.visible or daily_report_pending:
		return true # These require an explicit transaction/closeout choice.
	else:
		return false
	return true

func _add_physical_collisions(root: Node) -> void:
	for child in root.get_children():
		if child == fp_player or child == production_worker_node or child is Skeleton3D:
			continue
		if child is MeshInstance3D and child.mesh is BoxMesh and not child.get_meta("no_collision", false):
			var size_value: Vector3 = child.mesh.size
			if not child.has_node("PrototypeCollision") and size_value.y >= 0.12 and maxf(size_value.x, size_value.z) >= 0.3:
				var body := StaticBody3D.new()
				body.name = "PrototypeCollision"
				body.collision_layer = 3 if str(child.name) in WALL_NAMES or child.get_meta("structural", false) else 1
				body.collision_mask = 4
				var shape := CollisionShape3D.new()
				var box := BoxShape3D.new()
				box.size = size_value
				shape.shape = box
				body.add_child(shape)
				child.add_child(body)
				fp_collisions.append({"mesh": child, "shape": shape})
		_add_physical_collisions(child)

func _add_neighborhood_ground_collision() -> void:
	if has_node("PrototypeNeighborhoodGround"):
		return
	var body:=StaticBody3D.new()
	body.name="PrototypeNeighborhoodGround"
	body.collision_layer=1
	body.collision_mask=4
	var shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	var map_rect:Rect2=neighborhood.MAP_RECT
	box.size=Vector3(map_rect.size.x,.10,map_rect.size.y)
	shape.shape=box
	shape.position=Vector3(map_rect.get_center().x,-.05,map_rect.get_center().y)
	body.add_child(shape)
	add_child(body)

func _add_prop_collisions() -> void:
	var couch := get_node_or_null("AFBLoveseat")
	if couch != null and not couch.has_node("CouchCollision"):
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 4
		var box := BoxShape3D.new()
		box.size = Vector3(2.68, 0.95, 0.98)
		var shape := CollisionShape3D.new()
		shape.shape = box
		shape.position.y = 0.475
		body.add_child(shape)
		couch.add_child(body)
	for plant in plant_visuals:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 4
		var cylinder := CylinderShape3D.new()
		cylinder.radius = 0.33
		cylinder.height = 0.45
		var shape := CollisionShape3D.new()
		shape.shape = cylinder
		shape.position.y = 0.23
		body.add_child(shape)
		plant.add_child(body)

func _sync_physical_collisions() -> void:
	for entry in fp_collisions:
		var mesh: MeshInstance3D = entry.mesh
		var shape: CollisionShape3D = entry.shape
		if is_instance_valid(mesh) and is_instance_valid(shape):
			if shape.shape is BoxShape3D and mesh.mesh is BoxMesh:shape.shape.size=mesh.mesh.size
			shape.set_deferred("disabled", not mesh.is_visible_in_tree())

func _add_station_targets() -> void:
	_add_interaction_area("FP_ApartmentComputer",Vector3(3.70,1.35,4.35),Vector3(.30,1.3,1.5),"operation_apartment_computer")
	_add_interaction_area("FP_HouseComputer",Vector3(25.90,1.35,1.65),Vector3(.30,1.3,1.5),"operation_house_computer")
	_add_interaction_area("FP_Checkout",Vector3(14,1.35,3),Vector3(1.6,1.0,.35),"operation_market_checkout")
	_add_interaction_area("FP_Couch",Vector3(-2.28,.9,2.8),Vector3(2.5,1.1,.4),"sit_couch")
	# Target fronts sit just ahead of the relevant surfaces, not at fixed-view anchors.
	_add_interaction_area("FP_Locker", Vector3(3.95, 1.3, -2.20), Vector3(0.25, 2.0, 1.5), "station_locker")
	_add_interaction_area("FP_Bench", Vector3(3.25, 1.35, 0.78), Vector3(0.3, 0.8, 2.25), "station_workbench")
	_add_interaction_area("FP_Storage", Vector3(-3.95, 1.3, -0.30 if storage_level >= 4 else -0.06), Vector3(0.3, 1.8, 2.4), "station_storage")
	_add_interaction_area("FP_Door", Vector3(0, 1.4, 5.84), Vector3(1.85, 2.6, 0.6), "station_door")
	_add_interaction_area("FP_House", Vector3(40, 1.4, 8.3), Vector3(1.8, 2.6, 0.4), "inspect_house")
	_add_interaction_area("FP_System", Vector3(4.45, 1.8, -6.65), Vector3(0.25, 1.0, 1.2), "station_system", "grow")
	_add_interaction_area("FP_Supply", Vector3(-4.05, 1.25, -6.45), Vector3(0.25, 1.8, 1.3), "station_supply", "grow")

func _target_from_ray(origin: Vector3, direction: Vector3) -> Area3D:
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction.normalized() * REACH, 8 | 16)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	var area := hit.collider as Area3D
	if area == null or not area.is_visible_in_tree():
		return null
	# Walls occlude interaction targets even when they are close enough to reach.
	var wall_query := PhysicsRayQueryParameters3D.create(origin, hit.position, 2)
	if not get_world_3d().direct_space_state.intersect_ray(wall_query).is_empty():
		return null
	if area.has_meta("plant_slot"):
		return area
	var id := str(area.get_meta("interaction_id", ""))
	if id in ["room_enter_grow", "room_enter_main"]:
		return null
	return area if not id.is_empty() else null

func _update_target() -> void:
	if inventory_system.furniture.is_placing():fp_target=null;return
	fp_target = _target_from_ray(camera.global_position, -camera.global_basis.z)
	fp_prompt.text = ""
	fp_container=inventory_system.near_container() if fp_target==null else ""
	fp_control = neighborhood.house_controls.nearby() if fp_target == null else ""
	if fp_target==null and fp_control.is_empty():fp_control=neighborhood.bench_seating.target()
	if not fp_control.is_empty():
		fp_prompt.text = "[ " + DesktopInput.label("interact") + " ]   " + (("Stand up" if neighborhood.bench_seating.seated>=0 else "Sit on bench") if fp_control.begins_with("bench_") else neighborhood.house_controls.title(fp_control))
	if fp_target != null:
		var label_text := ""
		if fp_target.has_meta("plant_slot"):
			var i := int(fp_target.get_meta("plant_slot"))
			var slot: Dictionary = plant_slots[i]
			label_text = "Pot %d · %s" % [i + 1, str(slot.get("strain", "")) if int(slot.get("stage", -1)) >= 0 else "Plant a seed"]
		else:
			var id := str(fp_target.get_meta("interaction_id"))
			label_text = {"station_locker": "Dealer Storage", "station_workbench": "Packaging bench", "station_storage": "Product storage", "storage_vault": "Storage vault", "station_door": ("Close front door" if neighborhood.door_open else "Open front door") + ("   [ " + DesktopInput.label("visitor") + " ] Answer visitor" if customer_waiting else "   [ " + DesktopInput.label("visitor") + " ] Peephole"), "interior_door": "Open / close door", "inspect_house": "Inspect house", "station_system": "Grow-room controls", "station_supply": "Seeds & fertilizer", "main_light_switch": "Main lights", "floor_lamp": "Floor lamp", "grow_room_light_switch": "Grow-room light"}.get(id, id.replace("_", " ").capitalize())
			if id=="equipment_container":
				var container:String=fp_target.get_meta("equipment_container")
				label_text="Sit down" if container=="seat" else ("Toggle lamp" if container=="lamp" else inventory_system.title(container))
			if id=="station_door" and not _can_use_apartment_peephole():label_text="Close front door" if neighborhood.door_open else "Open front door"
			if id == "interior_door" and fp_target.get_meta("door_controller").name == "HouseEntrance" and not neighborhood.get_node("HouseEntrance").opened and not neighborhood.property_opportunity.touring and not bool(property_opportunity_state.get("relocated",false)) and neighborhood.get_node("HouseEntrance").to_local(fp_player.position).z >= 0.0:
				label_text = "View house details" if property_offer_unlocked else "House not available yet"
		fp_prompt.text = "[ " + DesktopInput.label("interact") + " ]   " + label_text
	if not fp_container.is_empty() and fp_control.is_empty():
		fp_prompt.text="[ " + DesktopInput.label("interact") + " ]   " + inventory_system.title(fp_container)
	fp_crosshair.modulate = Color("b6f38a") if fp_target != null or not fp_control.is_empty() or not fp_container.is_empty() else Color(1, 1, 1, 0.7)

func _use_target() -> void:
	_update_target() # Revalidate reach and line of sight at the actual key press.
	if not fp_control.is_empty():
		if fp_control.begins_with("bench_"):neighborhood.bench_seating.use(fp_control)
		else:neighborhood.house_controls.use(fp_control)
		return
	if fp_target == null:
		if not fp_container.is_empty():inventory_system.open_container(fp_container)
		return
	if fp_target.has_meta("plant_slot"):
		_open_direct_plant(int(fp_target.get_meta("plant_slot")))
	else:
		var id := str(fp_target.get_meta("interaction_id"))
		if id=="equipment_container":
			var container:String=fp_target.get_meta("equipment_container")
			if container=="seat":neighborhood._toggle_couch()
			elif container=="lamp":inventory_system.furniture.equipment_world.toggle_lamp()
			elif container.ends_with(":computer"):neighborhood.location_ops.computer(container.get_slice(":",0))
			else:inventory_system.open_container(container)
			return
		if id.begins_with("operation_"):
			neighborhood.location_ops.use(id.trim_prefix("operation_"))
			return
		match id:
			"sit_couch": neighborhood._toggle_couch()
			"station_locker": _open_fp_locker()
			"station_workbench": _open_bagging_panel()
			"station_storage", "storage_vault": _open_storage_panel()
			"station_supply": _open_supply_inventory_panel()
			"station_system": _open_system_control_panel()
			"station_door": neighborhood.toggle_door()
			"inspect_house": neighborhood._interact()
			"interior_door": neighborhood.use_interior_door(fp_target.get_meta("door_controller"))
			_: _activate_room_interaction(id)
	if _any_modal_open():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		fp_player.enabled = false

func _setup_desktop_panels() -> void:
	for panel in [grow_panel, plant_direct_panel, bagging_panel, dealer_storage_panel, storage_panel, supply_inventory_panel, system_control_panel, trim_panel, bag_minigame_panel]:
		panel.set_anchors_preset(Control.PRESET_CENTER)
		panel.offset_left = -345
		panel.offset_right = 345
		panel.offset_top = -320
		panel.offset_bottom = 330
	PhoneVisuals.fit(self)
	phone_title.add_theme_font_size_override("font_size", 24)
	phone_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	phone_title.clip_text = true
	status_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	status_label.offset_left = -280
	status_label.offset_right = 280
	status_label.offset_top = 90
	status_label.offset_bottom = 150
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	status_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_stylebox_override("normal",_style_box(Color("17251fee"),Color("689c50"),12,1))
	# Prototype-only wording; the original account UI cannot access a live backend.
	# Account and cloud wording now reflects the native integration.

func _build_advancements_app() -> void:
	super._build_advancements_app()
	# The base Rewards view was designed for the wider/mobile shell. In the
	# portrait desktop phone, long labels can otherwise increase the minimum
	# width of the PanelContainer and make the whole phone stretch sideways.
	_constrain_portrait_phone_content(phone_list)
	phone_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	phone_list.custom_minimum_size.x = 0.0
	phone_scroll.custom_minimum_size.x = 0.0
	phone_list.queue_sort()
	phone_scroll.queue_sort()
	call_deferred("_setup_desktop_panels")

func _constrain_portrait_phone_content(node: Node) -> void:
	if node.has_meta("phone_visual"):return
	for child: Node in node.get_children():
		if child is Control:
			var control := child as Control
			control.custom_minimum_size.x = 0.0
			control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if control is Label:
				var label := control as Label
				label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				label.clip_text = false
				label.add_theme_font_size_override("font_size",mini(18,label.get_theme_font_size("font_size")))
			elif control is Button:
				var button := control as Button
				button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				if button.has_meta("phone_app"):button.add_theme_font_size_override("font_size",16)
		_constrain_portrait_phone_content(child)

func _build_fp_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	fp_hud = Control.new()
	fp_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fp_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fp_hud)
	fp_info = _fp_label(Vector2(28, 16), 16)
	fp_info.add_theme_color_override("font_color", Color("d2efc9"))
	fp_crosshair = _fp_label(Vector2.ZERO, 24)
	fp_crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	fp_crosshair.offset_left = -10
	fp_crosshair.offset_top = -16
	fp_crosshair.text = "+"
	fp_prompt = _fp_label(Vector2.ZERO, 20)
	fp_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	fp_prompt.offset_left = -180
	fp_prompt.offset_right = 180
	fp_prompt.offset_top = -145
	fp_prompt.offset_bottom = -95
	fp_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fp_prompt.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	fp_prompt.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	fp_prompt.add_theme_font_size_override("font_size",16)
	fp_prompt.add_theme_stylebox_override("normal",_style_box(Color("438d31"),Color("69aa4f"),9,1))
	fp_hint = _fp_label(Vector2.ZERO, 16)
	fp_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	fp_hint.offset_left = 28
	fp_hint.offset_right = -28
	fp_hint.offset_top = -35
	fp_hint.offset_bottom = -12
	fp_stamina_bar = ProgressBar.new()
	fp_stamina_bar.name = "SprintStamina"
	fp_stamina_bar.min_value = 0
	fp_stamina_bar.max_value = 100
	fp_stamina_bar.value = 100
	fp_stamina_bar.show_percentage = false
	fp_stamina_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fp_stamina_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	fp_stamina_bar.offset_left = -120
	fp_stamina_bar.offset_right = 120
	fp_stamina_bar.offset_top = -78
	fp_stamina_bar.offset_bottom = -58
	var stamina_bg := StyleBoxFlat.new()
	stamina_bg.bg_color = Color("102019")
	stamina_bg.border_color = Color("4c7257")
	stamina_bg.set_border_width_all(2)
	stamina_bg.set_corner_radius_all(8)
	var stamina_fill := StyleBoxFlat.new()
	stamina_fill.bg_color = Color("7fcf88")
	stamina_fill.set_corner_radius_all(6)
	fp_stamina_bar.add_theme_stylebox_override("background", stamina_bg)
	fp_stamina_bar.add_theme_stylebox_override("fill", stamina_fill)
	fp_hud.add_child(fp_stamina_bar)
	fp_stamina_label = _fp_label(Vector2.ZERO, 13)
	fp_stamina_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	fp_stamina_label.offset_left = -120
	fp_stamina_label.offset_right = 120
	fp_stamina_label.offset_top = -103
	fp_stamina_label.offset_bottom = -80
	fp_stamina_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fp_stamina_bar.hide()
	fp_stamina_label.hide()

func _update_fp_stamina_hud() -> void:
	if fp_stamina_bar == null or fp_stamina_label == null or fp_player == null:
		return
	fp_stamina_bar.value = fp_player.stamina
	var show_bar: bool = fp_player.is_sprinting or fp_player.stamina < fp_player.STAMINA_MAX - .1
	fp_stamina_bar.visible = show_bar
	fp_stamina_label.visible = show_bar
	if show_bar:
		fp_stamina_label.text = "SPRINTING" if fp_player.is_sprinting else ("EXHAUSTED" if fp_player.exhausted else "STAMINA")

func _fp_label(pos: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = pos
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	fp_hud.add_child(label)
	return label

func _apply_visual_upgrades() -> void:
	super._apply_visual_upgrades()
	if fp_ready:
		_add_physical_collisions(self)
		_sync_physical_collisions()

func _sync_dealer_locker_visual() -> void:
	super._sync_dealer_locker_visual()
	if fp_ready:
		_sync_physical_collisions()

func _open_fp_locker() -> void:
	if dealer_locker_level >= 3:
		fp_station_opening = true
		fp_player.enabled = false
		fp_open_epoch += 1
		var epoch := fp_open_epoch
		_set_premium_dealer_locker_open(true)
		await get_tree().create_timer(0.32).timeout
		if epoch != fp_open_epoch:
			return
		fp_station_opening = false
		if session_paused:
			return
	_open_dealer_storage_panel()

func _pause_gameplay(message: String = "Paused. Resume whenever you are ready.", start_unix: float = 0.0) -> void:
	if fp_station_opening:
		fp_open_epoch += 1
		fp_station_opening = false
		_set_premium_dealer_locker_open(false)
		_set_hidden_stash_open(false)
	super._pause_gameplay(message, start_unix)

func _resume_gameplay() -> void:
	var reopen := dealer_storage_reopen_after_pause
	super._resume_gameplay()
	if reopen and not session_paused and fp_ready:
		_open_dealer_storage_panel()
		if dealer_locker_level >= 3:
			_set_premium_dealer_locker_open(true)

func _sync_storage_furniture() -> void:
	super._sync_storage_furniture()
	if fp_ready:
		var target := get_node_or_null("FP_Storage") as Node3D
		if target != null:
			target.position.z = -0.30 if storage_level >= 4 else -0.06

func _open_storage_panel() -> void:
	if storage_level < 5:
		super._open_storage_panel()
		return
	fp_station_opening = true
	fp_player.enabled = false
	fp_open_epoch += 1
	var epoch := fp_open_epoch
	_set_hidden_stash_open(true)
	await get_tree().create_timer(0.28).timeout
	if epoch != fp_open_epoch:
		return
	fp_station_opening = false
	if session_paused:
		return
	inventory_system.open_container("storage")

func _build_door_alert() -> void:
	super._build_door_alert()
	# A compact, fixed alert rail above the portrait phone.
	knock_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	knock_banner.offset_left = -170
	knock_banner.offset_right = 170
	knock_banner.offset_top = 12
	knock_banner.offset_bottom = 64
	var style := knock_banner.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	style.content_margin_left = 12
	style.content_margin_right = 12
	knock_banner.add_theme_stylebox_override("panel", style)
	knock_text.add_theme_font_size_override("font_size", 14)
	door_alert_detail.add_theme_font_size_override("font_size", 12)
	door_alert_dot.add_theme_font_size_override("font_size", 16)
	door_alert_button.custom_minimum_size = Vector2(100, 48)
	door_alert_button.add_theme_font_size_override("font_size", 12)

func _refresh_door_alert() -> void:
	super._refresh_door_alert()
	if knock_banner != null:
		if fp_player!=null and not neighborhood.indoors(fp_player.position):knock_banner.hide()
		# Base mobile layout otherwise moves the alert down to Y=194 while walking.
		knock_banner.offset_top = 12
		knock_banner.offset_bottom = 64

func _build_pause_overlay() -> void:
	super._build_pause_overlay()
	var box: VBoxContainer = pause_overlay.get_child(0).get_child(0)
	box.add_theme_constant_override("separation",10)
	var settings_button:=Button.new()
	settings_button.text="CONTROLS & DISPLAY SETTINGS"
	settings_button.custom_minimum_size.y=48
	settings_button.pressed.connect(DesktopInput.show_settings)
	box.add_child(settings_button)

func _refresh_phone() -> void:
	super._refresh_phone()
	if phone_list!=null:
		_constrain_portrait_phone_content(phone_list)
		call_deferred("_setup_desktop_panels")

func _build_phone_panel() -> void:
	super._build_phone_panel()
	var root: VBoxContainer=phone_panel.get_child(0)
	root.add_theme_constant_override("separation",6)
	var dock: HBoxContainer=root.get_child(root.get_child_count()-1)
	dock.add_theme_constant_override("separation",3)
	for child in dock.get_children():
		if child is Button:
			child.add_theme_font_size_override("font_size",11)
			child.text=child.text.replace("BUSINESSES","SHOP")
	phone_back_button.custom_minimum_size.x=32
	var header: HBoxContainer=phone_title.get_parent()
	header.get_child(header.get_child_count()-1).custom_minimum_size.x=32
	phone_status_label.add_theme_font_size_override("font_size",11)

func _controller_grab(pressed:bool) -> bool:
	var trimming:bool=trim_panel.visible and trim_harvest_amount>0
	var bagging:bool=bag_minigame_panel.visible and bag_current_units<bag_target_units
	if not trimming and not bagging and not controller_work_held:return false
	if pressed:
		controller_work_held=true
	else:
		if controller_work_held and bagging:
			_finish_bud_drag()
			if bag_current_units>=bag_target_units:bag_seal_button.grab_focus()
		controller_work_held=false
	return true

func _controller_work_tick(delta:float,axis:Vector2) -> void:
	if not DesktopInput.controller_active or not (trim_panel.visible or bag_minigame_panel.visible):
		controller_work_held=false;return
	if not controller_work_held:return
	if trim_panel.visible and trim_harvest_amount>0:
		trim_scissors.position+=axis*400.0*delta
		_clamp_control_to_parent(trim_scissors,trim_play_area)
		_check_trim_collisions()
		if trim_harvest_amount<=0:trim_continue_button.grab_focus()
	elif bag_minigame_panel.visible and bag_current_units<bag_target_units:
		bag_bud_token.position+=axis*400.0*delta
		_clamp_control_to_parent(bag_bud_token,bag_play_area)

# Art-lab house system uses the apartment UI with an explicit property context.
var house_system_context:bool=false
func open_house_system()->void:
	house_system_context=true
	_set_system_copy()
	super._open_system_control_panel()
func _open_system_control_panel()->void:
	house_system_context=false
	_set_system_copy()
	super._open_system_control_panel()
func _close_system_control_panel()->void:
	super._close_system_control_panel()
	house_system_context=false
func _activate_room_interaction(action_id:String)->bool:
	if not house_system_context or not system_control_panel.visible:return super._activate_room_interaction(action_id)
	if session_paused or daily_report_pending or tutorial_active:return false
	var controls=neighborhood.house_controls
	match action_id:
		"grow_room_light_switch":
			var basement=get_node("BasementExpansion")
			basement.set_room_lights(not basement.room_lights_on)
			_save_game()
		"grow_light_switch":controls.toggle_house_grow_lights()
		"ventilation_switch":controls.toggle_house_ventilation()
		_:return false
	_refresh_system_control_panel()
	return true
func _refresh_system_control_panel()->void:
	if not house_system_context:
		super._refresh_system_control_panel()
		return
	if system_control_status==null:return
	var controls=neighborhood.house_controls
	var state:Dictionary=controls.grow_snapshot()
	var basement=get_node_or_null("BasementExpansion")
	system_control_status.text="HOUSE · BASEMENT CONTROL PANEL\n%d tents · %d/%d plants · %d ready · %d need water · %d dead\nRoom light: %s · Grow lights: %s · Air: %s\nHouse equipment only · Upstairs and basement tents." % [state.tents,state.active,state.capacity,state.ready,state.dry,state.dead,"ON" if basement!=null and basement.room_lights_on else "OFF","ON" if controls.states.get("grow_lights",false) else "OFF",("ON" if state.ventilation_on else "OFF") if state.ventilation else "NOT INSTALLED"]
	_refresh_utility_controls()
func _refresh_utility_controls()->void:
	super._refresh_utility_controls()
	if not house_system_context or system_control_panel==null:return
	var controls=neighborhood.house_controls
	var state:Dictionary=controls.grow_snapshot()
	for button in system_control_panel.find_children("System_*","Button",true,false):
		var action:String=str(button.get_meta("utility_id",""))
		var on:bool=false
		var installed:bool=true
		match action:
			"grow_room_light_switch":on=get_node("BasementExpansion").room_lights_on
			"grow_light_switch":
				on=bool(controls.states.get("grow_lights",false));installed=state.tents>0
			"ventilation_switch":
				on=state.ventilation_on;installed=state.ventilation
		button.text=("NO TENTS PLACED" if action=="grow_light_switch" else "NOT INSTALLED") if not installed else ("ON   |   TAP OFF" if on else "OFF   |   TAP ON")
		button.disabled=not installed or session_paused or daily_report_pending or tutorial_active
		button.add_theme_stylebox_override("normal",_style_box(Color("294636") if on else Color("242c33"),Color("9ac8a6") if on else Color("9aa7b1"),12,2))

func _set_system_copy()->void:
	for label in system_control_panel.find_children("*","Label",true,false):
		if label==system_control_status:continue
		if not label.has_meta("apartment_copy"):label.set_meta("apartment_copy",label.text)
		var original:String=str(label.get_meta("apartment_copy"))
		label.text=original
		if house_system_context:
			if original=="GROW ROOM SYSTEM":label.text="HOUSE GROW SYSTEM"
			elif original=="General grow-room lighting.":label.text="Basement ceiling lights. Also controlled with B."
			elif original=="Plant lighting. OFF greatly slows crop growth.":label.text="Placed house tents. Separate from apartment lighting."
			elif original=="Air system. Requires the ventilation upgrade.":label.text="Requires a ventilation unit placed at the house."
