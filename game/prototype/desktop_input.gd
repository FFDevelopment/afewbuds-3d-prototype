extends Node
## Device preferences are never included in the shared career save.
const PATH := "user://desktop_preferences.json"
const DEFAULTS := {"forward":KEY_W,"backward":KEY_S,"left":KEY_A,"right":KEY_D,"sprint":KEY_SHIFT,"interact":KEY_E,"phone":KEY_P,"backpack":KEY_I,"visitor":KEY_R,"tour":KEY_T,"save":KEY_F5}
const PAD_DEFAULTS := {"interact":JOY_BUTTON_A,"phone":JOY_BUTTON_DPAD_UP,"backpack":JOY_BUTTON_DPAD_RIGHT,"visitor":JOY_BUTTON_X,"tour":JOY_BUTTON_RIGHT_SHOULDER,"sprint":JOY_BUTTON_LEFT_STICK,"save":JOY_BUTTON_BACK}
var pad_bindings:Dictionary=PAD_DEFAULTS.duplicate()
var rebind_device:="keyboard"
var focus_key:=""
var bindings: Dictionary = DEFAULTS.duplicate()
var mouse_sensitivity := 1.0
var controller_sensitivity := 1.0
var invert_y := false
var controller_active := false
var rebinding := ""
var rebind_button: Button
var settings: CanvasLayer
var cursor := Vector2.ZERO
var dragging := false
var scroll_timer := 0.0
var window_size := Vector2i(1280,800)
var fullscreen := false

func _ready() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else {}
	if data is Dictionary:
		mouse_sensitivity=clampf(float(data.get("mouse",1)),.1,3)
		controller_sensitivity=clampf(float(data.get("controller",1)),.1,3)
		invert_y=bool(data.get("invert_y",false))
		fullscreen=bool(data.get("fullscreen",false))
		window_size=Vector2i(clampi(int(data.get("width",1280)),960,3840),clampi(int(data.get("height",800)),600,2160))
		for action in DEFAULTS:
			var key:=int(data.get("bindings",{}).get(action,DEFAULTS[action]))
			if key>0 and key!=KEY_ESCAPE:bindings[action]=key
		var previous_pad:Dictionary=data.get("pad_bindings",{})
		if int(previous_pad.get("phone",-1))==JOY_BUTTON_Y and int(previous_pad.get("backpack",-1))==JOY_BUTTON_DPAD_UP:
			previous_pad["phone"]=JOY_BUTTON_DPAD_UP;previous_pad["backpack"]=JOY_BUTTON_DPAD_RIGHT
			data["pad_bindings"]=previous_pad
		for action in PAD_DEFAULTS:
			var button:int=int(data.get("pad_bindings",{}).get(action,PAD_DEFAULTS[action]))
			if button>=0 and button<JOY_BUTTON_MAX and button not in [JOY_BUTTON_B,JOY_BUTTON_START]:pad_bindings[action]=button
	install_actions()
	Input.joy_connection_changed.connect(func(_device,connected):
		if not connected and dragging:dragging=false;mouse_button(MOUSE_BUTTON_LEFT,false)
	)
	apply_display()

func install_actions() -> void:
	for action in DEFAULTS:
		var id: String="fp_"+action
		if not InputMap.has_action(id):InputMap.add_action(id,.2)
		InputMap.action_erase_events(id)
		var key:=InputEventKey.new();key.physical_keycode=int(bindings[action]);InputMap.action_add_event(id,key)
	for action in pad_bindings:
		var button:=InputEventJoypadButton.new();button.button_index=int(pad_bindings[action]);InputMap.action_add_event("fp_"+action,button)
	for spec in [["left",JOY_AXIS_LEFT_X,-1],["right",JOY_AXIS_LEFT_X,1],["forward",JOY_AXIS_LEFT_Y,-1],["backward",JOY_AXIS_LEFT_Y,1]]:
		var axis:=InputEventJoypadMotion.new();axis.axis=spec[1];axis.axis_value=spec[2];InputMap.action_add_event("fp_"+spec[0],axis)

func save_preferences() -> void:
	var file:=FileAccess.open(PATH,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"bindings":bindings,"pad_bindings":pad_bindings,"mouse":mouse_sensitivity,"controller":controller_sensitivity,"invert_y":invert_y,"width":window_size.x,"height":window_size.y,"fullscreen":fullscreen}))

func apply_display() -> void:
	if DisplayServer.get_name()=="headless":return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	if not fullscreen:
		var available:=DisplayServer.screen_get_usable_rect().size
		DisplayServer.window_set_size(Vector2i(mini(window_size.x,available.x),mini(window_size.y,available.y)))
		DisplayServer.window_set_position(DisplayServer.screen_get_usable_rect().position+(available-DisplayServer.window_get_size())/2)

func pad_label(index:int) -> String:
	return {JOY_BUTTON_A:"A / Cross",JOY_BUTTON_B:"B / Circle",JOY_BUTTON_X:"X / Square",JOY_BUTTON_Y:"Y / Triangle",JOY_BUTTON_LEFT_SHOULDER:"LB / L1",JOY_BUTTON_RIGHT_SHOULDER:"RB / R1",JOY_BUTTON_LEFT_STICK:"L3",JOY_BUTTON_RIGHT_STICK:"R3",JOY_BUTTON_BACK:"Back / Select",JOY_BUTTON_START:"Start",JOY_BUTTON_DPAD_UP:"D-pad Up",JOY_BUTTON_DPAD_DOWN:"D-pad Down",JOY_BUTTON_DPAD_LEFT:"D-pad Left",JOY_BUTTON_DPAD_RIGHT:"D-pad Right"}.get(index,"Button %d" % index)
func label(action:String) -> String:
	if controller_active and pad_bindings.has(action):return pad_label(int(pad_bindings[action]))
	return OS.get_keycode_string(int(bindings.get(action,0)))
func binding_label(action:String,device:String) -> String:
	return pad_label(int(pad_bindings[action])) if device=="controller" else OS.get_keycode_string(int(bindings[action]))
func assign_binding(action:String,device:String,value:int) -> bool:
	var table:Dictionary=pad_bindings if device=="controller" else bindings
	if device=="controller" and (value<0 or value>=JOY_BUTTON_MAX or value in [JOY_BUTTON_B,JOY_BUTTON_START]):return false
	if device=="keyboard" and (value<=0 or value==KEY_ESCAPE):return false
	for other in table:
		if other!=action and int(table[other])==value:return false
	table[action]=value;install_actions();save_preferences();return true
func begin_rebind(action:String,device:String,button:Button) -> void:
	if not rebinding.is_empty() and is_instance_valid(rebind_button):rebind_button.text=binding_label(rebinding,rebind_device)
	rebinding=action;rebind_device=device;rebind_button=button
	button.text="Press a controller button · B cancels" if device=="controller" else "Press a key · Escape cancels"

func stick(right: bool) -> Vector2:
	var devices:=Input.get_connected_joypads()
	if devices.is_empty():return Vector2.ZERO
	var device:int=devices[0]
	var value:=Vector2(Input.get_joy_axis(device,JOY_AXIS_RIGHT_X if right else JOY_AXIS_LEFT_X),Input.get_joy_axis(device,JOY_AXIS_RIGHT_Y if right else JOY_AXIS_LEFT_Y))
	var length:=value.length()
	return value.normalized()*clampf((length-.2)/.8,0,1)

func is_back(event: InputEvent) -> bool:
	return (event is InputEventKey and event.keycode==KEY_ESCAPE and event.pressed and not event.echo) or (event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_START,JOY_BUTTON_B])

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value)>.25):controller_active=true
	elif event is InputEventKey or event is InputEventMouseButton or (event is InputEventMouseMotion and event.device!=-9):controller_active=false
	if not rebinding.is_empty():
		var cancel:bool=(event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE) or (rebind_device=="controller" and event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_B)
		var candidate:bool=(rebind_device=="keyboard" and event is InputEventKey and event.pressed and not event.echo) or (rebind_device=="controller" and event is InputEventJoypadButton and event.pressed)
		if cancel:
			rebind_button.text=binding_label(rebinding,rebind_device);rebinding=""
		elif candidate:
			var value:int=int(event.button_index) if rebind_device=="controller" else int(event.physical_keycode if event.physical_keycode else event.keycode)
			if assign_binding(rebinding,rebind_device,value):rebind_button.text=binding_label(rebinding,rebind_device);rebinding=""
			else:rebind_button.text="Already assigned or reserved — try another"
		get_viewport().set_input_as_handled();return
	if is_instance_valid(settings) and is_back(event):
		close_settings();get_viewport().set_input_as_handled();return
	if event is InputEventJoypadButton and event.button_index==JOY_BUTTON_A and not is_instance_valid(settings):
		for game in get_tree().root.get_children():
			if game.has_method("_controller_grab") and game._controller_grab(event.pressed):
				get_viewport().set_input_as_handled();return
	if event is InputEventJoypadButton and menu_root()!=null and event.button_index in [JOY_BUTTON_A,JOY_BUTTON_DPAD_UP,JOY_BUTTON_DPAD_DOWN,JOY_BUTTON_DPAD_LEFT,JOY_BUTTON_DPAD_RIGHT]:
		if event.pressed:
			ensure_focus()
			if event.button_index==JOY_BUTTON_A:activate_focus()
			else:move_focus({JOY_BUTTON_DPAD_UP:Vector2.UP,JOY_BUTTON_DPAD_DOWN:Vector2.DOWN,JOY_BUTTON_DPAD_LEFT:Vector2.LEFT,JOY_BUTTON_DPAD_RIGHT:Vector2.RIGHT}[event.button_index])
		get_viewport().set_input_as_handled()

# Cursor coordinates are already viewport-local. Applying window stretch again
# offsets clicks at non-default resolutions. Keep motion and clicks in this space.
func mouse_button(button: int, pressed: bool) -> void:
	var event:=InputEventMouseButton.new();event.device=-9;event.button_index=button;event.pressed=pressed;event.position=cursor;event.global_position=cursor
	get_viewport().push_input(event, true)

func menu_root() -> Node:
	if is_instance_valid(settings):return settings
	for game in get_tree().root.get_children():
		if not game.has_method("_any_modal_open"):continue
		if is_instance_valid(game.get("account_overlay")):return game.account_overlay
		if game.inventory_system!=null and game.inventory_system.is_open():return game.inventory_system.panel
		for name in ["pause_overlay","daily_report_panel","tutorial_panel","trim_panel","bag_minigame_panel","sale_panel","peephole_panel","plant_direct_panel","grow_panel","phone_panel","system_control_panel"]:
			var panel=game.get(name)
			if panel is Control and panel.is_visible_in_tree():return panel
		if game.neighborhood.location_ops.is_open():return game.neighborhood.location_ops.ui.overlay
		if game.neighborhood.property_opportunity.is_open():return game.neighborhood.property_opportunity.overlay
	var scene:Node=get_tree().current_scene
	if scene is Control and scene.is_visible_in_tree():return scene
	return null
func focusables(node:Node,result:Array[Control]) -> void:
	if node is Control and not node.is_visible_in_tree():return
	if node is ScrollContainer:node.follow_focus=true
	if (node is BaseButton and not node.disabled) or node is Range or (node is LineEdit and not node.get_parent() is SpinBox):
		node.focus_mode=Control.FOCUS_ALL;result.append(node)
	for child in node.get_children():focusables(child,result)
func menu_controls() -> Array[Control]:
	var result:Array[Control]=[];var menu:Node=menu_root()
	if menu!=null:focusables(menu,result)
	return result
func ensure_focus() -> void:
	var controls:=menu_controls()
	if controls.is_empty():return
	var current:Control=get_viewport().gui_get_focus_owner()
	if current in controls:
		focus_key=str(current.get_meta("navigation_key",""));return
	for control in controls:
		if not focus_key.is_empty() and str(control.get_meta("navigation_key",""))==focus_key:control.grab_focus();return
	for control in controls:
		if control.has_meta("navigation_key"):control.grab_focus();return
	controls[0].grab_focus()
func move_focus(direction:Vector2) -> void:
	var controls:=menu_controls();var current:Control=get_viewport().gui_get_focus_owner()
	if controls.is_empty():return
	if current==null:controls[0].grab_focus();return
	if current is Range and direction.x!=0:
		current.value+=direction.x*maxf(current.step,.1);return
	if current is OptionButton and direction.x!=0:
		var index:int=posmod(current.selected+int(direction.x),current.item_count)
		current.select(index);current.item_selected.emit(index);return
	var origin:Vector2=current.get_global_rect().get_center();var best:Control=null;var score:=INF
	for control in controls:
		if control==current:continue
		var offset:Vector2=control.get_global_rect().get_center()-origin
		var ahead:float=offset.dot(direction)
		if ahead<=1:continue
		var distance:float=ahead+absf(offset.cross(direction))*3
		if distance<score:score=distance;best=control
	if best==null:best=controls[0] if direction.x+direction.y>0 else controls[-1]
	best.grab_focus();focus_key=str(best.get_meta("navigation_key",""))
func activate_focus() -> void:
	var control:Control=get_viewport().gui_get_focus_owner()
	if control==null:return
	focus_key=str(control.get_meta("navigation_key",""))
	if control is OptionButton:
		move_focus(Vector2.RIGHT)
	elif control is BaseButton and not control.disabled:
		if control.toggle_mode:control.button_pressed=not control.button_pressed
		control.pressed.emit()
func _process(_delta:float) -> void:
	if controller_active and rebinding.is_empty() and menu_root()!=null:ensure_focus()

func close_settings() -> void:
	rebinding=""
	if is_instance_valid(settings):settings.queue_free()
	settings=null
	save_preferences()

func show_settings() -> void:
	if is_instance_valid(settings):return
	settings=CanvasLayer.new();settings.layer=110;add_child(settings)
	var shade:=ColorRect.new();shade.color=Color("10191ff5");shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);settings.add_child(shade)
	var panel:=PanelContainer.new();panel.theme=settings_theme();panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);panel.offset_left=100;panel.offset_right=-100;panel.offset_top=30;panel.offset_bottom=-30;shade.add_child(panel)
	var scroll:=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;panel.add_child(scroll)
	var box:=VBoxContainer.new();box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;box.add_theme_constant_override("separation",12);scroll.add_child(box)
	var title:=Label.new();title.text="DESKTOP SETTINGS";title.add_theme_font_size_override("font_size",28);box.add_child(title)
	var hint:=Label.new();hint.text="Menus: D-pad moves focus, A/Cross selects, B/Circle goes back.
D-pad left/right changes sliders and choices. Start pauses.
Click L3 to toggle forward sprint; keyboard sprint is hold Shift.";hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(hint)
	add_slider(box,"Mouse sensitivity",mouse_sensitivity,func(v):mouse_sensitivity=v;save_preferences())
	add_slider(box,"Controller look sensitivity",controller_sensitivity,func(v):controller_sensitivity=v;save_preferences())
	var invert:=CheckBox.new();invert.text="Invert vertical camera";invert.button_pressed=invert_y;invert.toggled.connect(func(v):invert_y=v;save_preferences());box.add_child(invert)
	var full:=CheckBox.new();full.text="Fullscreen (uses display resolution)";full.button_pressed=fullscreen;full.toggled.connect(func(v):fullscreen=v;apply_display();save_preferences());box.add_child(full)
	var resolution:=OptionButton.new()
	var sizes:=[Vector2i(960,600),Vector2i(1280,720),Vector2i(1280,800),Vector2i(1600,900),Vector2i(1920,1080),Vector2i(2560,1440),Vector2i(3840,2160)]
	for size_value in sizes:
		resolution.add_item("Window: %d × %d" % [size_value.x,size_value.y])
		if size_value==window_size:resolution.select(resolution.item_count-1)
	resolution.item_selected.connect(func(i):window_size=sizes[i];fullscreen=false;full.set_pressed_no_signal(false);apply_display();save_preferences());box.add_child(resolution)
	for device in ["keyboard","controller"]:
		var heading:=Label.new();heading.text="KEYBOARD BINDINGS" if device=="keyboard" else "CONTROLLER BINDINGS";box.add_child(heading)
		var table:Dictionary=bindings if device=="keyboard" else pad_bindings
		for action in table:
			var row:=HBoxContainer.new();box.add_child(row)
			var name_label:=Label.new();name_label.text=action.capitalize();name_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(name_label)
			var button:=Button.new();button.text=binding_label(action,device);button.custom_minimum_size=Vector2(360,36);row.add_child(button)
			button.set_meta("binding_action",action);button.set_meta("binding_device",device)
			button.pressed.connect(begin_rebind.bind(action,device,button))

	var reset:=Button.new();reset.text="Reset controls and sensitivity";reset.pressed.connect(func():bindings=DEFAULTS.duplicate();pad_bindings=PAD_DEFAULTS.duplicate();mouse_sensitivity=1;controller_sensitivity=1;invert_y=false;install_actions();close_settings();show_settings());box.add_child(reset)
	var done:=Button.new();done.text="Back to pause menu";done.custom_minimum_size.y=46;done.pressed.connect(close_settings);box.add_child(done)

func add_slider(box: VBoxContainer, title: String, value: float, changed: Callable) -> void:
	var text:=Label.new();text.text="%s: %.2f" % [title,value];box.add_child(text)
	var slider:=HSlider.new();slider.min_value=.1;slider.max_value=3;slider.step=.05;slider.value=value;slider.custom_minimum_size.y=30
	slider.value_changed.connect(func(v):text.text="%s: %.2f" % [title,v];changed.call(v));box.add_child(slider)

func pressed(event: InputEvent, action: String) -> bool:
	if event is InputEventKey:
		var key:int=event.physical_keycode if event.physical_keycode else event.keycode
		return event.pressed and not event.echo and key==int(bindings[action])
	return event.is_action_pressed("fp_"+action)

func settings_theme() -> Theme:
	var theme:=Theme.new()
	theme.default_font_size=18
	var panel:=StyleBoxFlat.new();panel.bg_color=Color("11191f");panel.set_content_margin_all(18);panel.set_corner_radius_all(16)
	theme.set_stylebox("panel","PanelContainer",panel)
	for type in ["Button","OptionButton"]:
		for state in ["normal","hover","pressed","focus"]:
			var style:=StyleBoxFlat.new();style.bg_color=Color("22352d") if state!="normal" else Color("1b272d");style.border_color=Color("6ba779");style.set_border_width_all(1);style.set_corner_radius_all(6);style.set_content_margin_all(8)
			theme.set_stylebox(state,type,style)
	return theme
