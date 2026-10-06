extends Node
## Device preferences are never included in the shared career save.
const PATH := "user://desktop_preferences.json"
const DEFAULTS := {"forward":KEY_W,"backward":KEY_S,"left":KEY_A,"right":KEY_D,"sprint":KEY_SHIFT,"interact":KEY_E,"phone":KEY_P,"visitor":KEY_R,"tour":KEY_T,"save":KEY_F5}
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
	for spec in [["interact",JOY_BUTTON_A],["phone",JOY_BUTTON_Y],["visitor",JOY_BUTTON_X],["tour",JOY_BUTTON_RIGHT_SHOULDER],["sprint",JOY_BUTTON_LEFT_STICK]]:
		var button:=InputEventJoypadButton.new();button.button_index=spec[1];InputMap.action_add_event("fp_"+spec[0],button)
	for spec in [["left",JOY_AXIS_LEFT_X,-1],["right",JOY_AXIS_LEFT_X,1],["forward",JOY_AXIS_LEFT_Y,-1],["backward",JOY_AXIS_LEFT_Y,1]]:
		var axis:=InputEventJoypadMotion.new();axis.axis=spec[1];axis.axis_value=spec[2];InputMap.action_add_event("fp_"+spec[0],axis)

func save_preferences() -> void:
	var file:=FileAccess.open(PATH,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"bindings":bindings,"mouse":mouse_sensitivity,"controller":controller_sensitivity,"invert_y":invert_y,"width":window_size.x,"height":window_size.y,"fullscreen":fullscreen}))

func apply_display() -> void:
	if DisplayServer.get_name()=="headless":return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	if not fullscreen:
		var available:=DisplayServer.screen_get_usable_rect().size
		DisplayServer.window_set_size(Vector2i(mini(window_size.x,available.x),mini(window_size.y,available.y)))
		DisplayServer.window_set_position(DisplayServer.screen_get_usable_rect().position+(available-DisplayServer.window_get_size())/2)

func label(action: String) -> String:
	if controller_active:
		return {"interact":"A / Cross","phone":"Y / Triangle","visitor":"X / Square","tour":"RB / R1","save":"F5"}.get(action,action.capitalize())
	return OS.get_keycode_string(int(bindings.get(action,0)))

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
	elif event is InputEventKey or (event is InputEventMouseMotion and event.device!=-9):controller_active=false
	if not rebinding.is_empty():
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode!=KEY_ESCAPE:
				var key:int=event.physical_keycode if event.physical_keycode else event.keycode
				for action in bindings:
					if action!=rebinding and bindings[action]==key:
						rebind_button.text="Already assigned — choose another key";get_viewport().set_input_as_handled();return
				bindings[rebinding]=key;install_actions();save_preferences()
			rebind_button.text=OS.get_keycode_string(int(bindings[rebinding]));rebinding=""
		get_viewport().set_input_as_handled();return
	if is_instance_valid(settings) and is_back(event):
		close_settings();get_viewport().set_input_as_handled();return
	if Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED and event is InputEventJoypadButton and event.button_index==JOY_BUTTON_A:
		if event.pressed:cursor=get_viewport().get_mouse_position()
		dragging=event.pressed
		mouse_button(MOUSE_BUTTON_LEFT,event.pressed)
		get_viewport().set_input_as_handled()

func mouse_button(button: int, pressed: bool) -> void:
	var event:=InputEventMouseButton.new();event.device=-9;event.button_index=button;event.pressed=pressed;event.position=cursor;event.global_position=cursor
	Input.parse_input_event(event)

func _process(delta: float) -> void:
	if Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		if dragging:dragging=false;mouse_button(MOUSE_BUTTON_LEFT,false)
		return
	var axis:=stick(false)
	if axis.length()>.01:
		cursor=get_viewport().get_mouse_position()
		var previous:=cursor
		cursor=(cursor+axis*650*delta).clamp(Vector2.ZERO,get_viewport().get_visible_rect().size-Vector2.ONE)
		get_viewport().warp_mouse(cursor)
		var event:=InputEventMouseMotion.new();event.device=-9;event.position=cursor;event.global_position=cursor;event.relative=cursor-previous;event.button_mask=MOUSE_BUTTON_MASK_LEFT if dragging else 0
		Input.parse_input_event(event)
	scroll_timer-=delta
	if absf(stick(true).y)>.35 and scroll_timer<=0:
		cursor=get_viewport().get_mouse_position();mouse_button(MOUSE_BUTTON_WHEEL_DOWN if stick(true).y>0 else MOUSE_BUTTON_WHEEL_UP,true);scroll_timer=.09

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
	var hint:=Label.new();hint.text="Controller: left stick moves the pointer in menus; A/Cross clicks or holds to drag.\nRight stick scrolls. B/Circle goes back; Start pauses. In the world: left stick walks,\nright stick looks, A interacts, Y opens phone, X checks visitors, L3 sprints.";hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(hint)
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
	for action in DEFAULTS:
		var row:=HBoxContainer.new();box.add_child(row)
		var name_label:=Label.new();name_label.text=action.capitalize();name_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(name_label)
		var button:=Button.new();button.text=OS.get_keycode_string(int(bindings[action]));button.custom_minimum_size=Vector2(360,36);row.add_child(button)
		button.pressed.connect(func():
			if not rebinding.is_empty():rebind_button.text=OS.get_keycode_string(int(bindings[rebinding]))
			rebinding=action;rebind_button=button;button.text="Press a key · Escape cancels"
		)
	var reset:=Button.new();reset.text="Reset controls and sensitivity";reset.pressed.connect(func():bindings=DEFAULTS.duplicate();mouse_sensitivity=1;controller_sensitivity=1;invert_y=false;install_actions();close_settings();show_settings());box.add_child(reset)
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
