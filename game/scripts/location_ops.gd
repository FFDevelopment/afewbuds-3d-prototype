extends RefCounted
var world: Node3D
var host: Node3D
var ui: RefCounted
var crew: RefCounted
var installing := false
var computer_context := ""
var management_app := ""
var rendering_management := false
var grow_panel_poll_seconds:float=0.0
var last_notice := -1
var apartment_release_confirm := false
var portfolio_property: String = "" # UI-only focus, not physical location.
var portfolio_page: String = "overview"
var portfolio_employee: String = ""
var portfolio_fire_confirm: String = ""
const APT_PC := Vector3(4.15,1.35,4.35)
const HOUSE_PC := Vector3(26.35,1.35,1.65)
const CHECKOUT := Vector3(14,1.3,3)
const APARTMENT_REACQUIRE_COST:=600
func setup(owner: Node3D) -> void:
	world=owner;host=owner.host
	ui=load("res://prototype/property_opportunity.gd").new()
	ui.setup(world)
	for key in ["carried_seeds","pickup_seeds","deliveries","house"]:
		if not host.location_state.get(key,{}) is Dictionary:host.location_state[key]={}
		if not host.location_state.has(key):host.location_state[key]={}
	host.location_state["pickup_fertilizer"]=maxi(0,int(host.location_state.get("pickup_fertilizer",0)))
	host.location_state["carried_fertilizer"]=maxi(0,int(host.location_state.get("carried_fertilizer",0)))
	if not host.location_state.has("active_property"):host.location_state["active_property"]="apartment"
	if not host.location_state.get("property_storage",[]) is Array:host.location_state["property_storage"]=[]
	if not host.location_state.get("asset_placements",{}) is Dictionary:host.location_state["asset_placements"]={}
	if not host.location_state.has("operation_assets_property"):host.location_state["operation_assets_property"]="apartment"
	if not host.location_state.has("operation_contents_property"):host.location_state["operation_contents_property"]="apartment"
	_ensure_property_utilities()
	_sync_legacy_utility_totals()
	if not host.apartment_rent_state.has("next_due"):
		host.apartment_rent_state={"next_due":host.game_day+14,"balance":0,"first_unpaid":0,"lease_active":true}
		host._save_game()
	elif not host.apartment_rent_state.has("lease_active"):
		host.apartment_rent_state["lease_active"]=true
		host._save_game()
	crew=load("res://scripts/crew_phone.gd").new();crew.setup(world)
	make_computer("Apartment",APT_PC,true)
	make_computer("House",HOUSE_PC,false)
func make_computer(id: String, at: Vector3, apartment: bool) -> void:
	var parts: Array[MeshInstance3D]=[]
	var origin := Vector3(at.x,0,at.z)
	# Local X is depth; front faces -X. Wood desktop and four steel legs.
	var box := func(label: String, pos: Vector3, size: Vector3, color: String, texture: String="", shine: float=0.65) -> MeshInstance3D:
		var node: MeshInstance3D=host._add_box(id+"Computer"+label,origin+pos,size,Color(color),shine,false,texture)
		parts.append(node)
		return node
	var desktop: MeshInstance3D=box.call("Desk",Vector3(0,0.86,0),Vector3(0.85,0.075,1.5),"a17b54","res://assets/textures/walnut.png")
	var grain := Image.create(512,256,false,Image.FORMAT_RGB8)
	for y in range(256):
		for x in range(512):
			var wave: float=sin(y*0.57+sin(x*0.015)*2.7)*0.045+sin(y*2.13+x*0.025)*0.018
			grain.set_pixel(x,y,Color(0.48+wave,0.31+wave*0.7,0.19+wave*0.5))
	desktop.mesh.material.albedo_color=Color.WHITE
	desktop.mesh.material.albedo_texture=ImageTexture.create_from_image(grain)
	for x in [-0.37,0.37]:
		for z in [-0.68,0.68]:
			box.call("Leg",Vector3(x,0.41,z),Vector3(0.055,0.82,0.055),"303638","res://assets/textures/brushed_metal.png",0.35)
			box.call("Foot",Vector3(x,0.025,z),Vector3(0.075,0.04,0.075),"171b1d")
	box.call("Drawer",Vector3(-0.02,0.73,0),Vector3(0.74,0.20,1.35),"32383a","res://assets/textures/matte_plastic.png")
	box.call("HandleInset",Vector3(-0.396,0.73,0),Vector3(0.012,0.075,0.24),"111719")
	for y in [0.692,0.768]:box.call("Handle",Vector3(-0.406,y,0),Vector3(0.018,0.012,0.25),"8c9292","res://assets/textures/brushed_metal.png",0.28)
	for z in [-0.12,0.12]:box.call("HandleSide",Vector3(-0.406,0.73,z),Vector3(0.018,0.075,0.012),"8c9292","res://assets/textures/brushed_metal.png",0.28)
	for z in [-0.68,0.68]:box.call("Rail",Vector3(0,0.14,z),Vector3(0.77,0.05,0.05),"303638")
	box.call("RearPanel",Vector3(0.34,0.47,0),Vector3(0.03,0.52,1.32),"313638","res://assets/textures/matte_plastic.png")
	box.call("TowerShelf",Vector3(0,0.17,0.49),Vector3(0.76,0.05,0.32),"876547","res://assets/textures/walnut.png")
	box.call("Tower",Vector3(0.05,0.43,0.49),Vector3(0.49,0.48,0.25),"1e2628","res://assets/textures/matte_plastic.png")
	box.call("TowerFace",Vector3(-0.2,0.43,0.49),Vector3(0.018,0.43,0.21),"11191b")
	for row in range(12):box.call("Vent",Vector3(-0.212,0.245+row*0.018,0.46),Vector3(0.008,0.007,0.10),"41484a")
	var led: MeshInstance3D=box.call("PowerLED",Vector3(-0.215,0.57,0.55),Vector3(0.009,0.08,0.009),"66c89a")
	led.mesh.material.emission_enabled=true;led.mesh.material.emission=Color("66c89a")
	box.call("MonitorBase",Vector3(0.18,0.918,-0.09),Vector3(0.29,0.025,0.42),"252e30","res://assets/textures/matte_plastic.png",0.4)
	box.call("Stand",Vector3(0.22,1.04,-0.09),Vector3(0.055,0.24,0.075),"2c3436")
	box.call("Monitor",Vector3(0.23,1.36,-0.09),Vector3(0.045,0.54,1.02),"1f282b","res://assets/textures/matte_plastic.png",0.38)
	var screen: MeshInstance3D=box.call("Screen",Vector3(0.204,1.365,-0.09),Vector3(0.006,0.48,0.955),"142d26")
	var screen_mat := StandardMaterial3D.new()
	screen_mat.albedo_color=Color.WHITE;screen_mat.albedo_texture=dashboard_texture()
	screen_mat.emission_enabled=true;screen_mat.emission=Color.WHITE;screen_mat.emission_texture=screen_mat.albedo_texture;screen_mat.emission_energy_multiplier=0.32
	var display_quad := QuadMesh.new()
	display_quad.size=Vector2(0.955,0.48)
	screen.mesh=display_quad;screen.rotation.y=-PI/2.0
	screen_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	screen.material_override=screen_mat
	box.call("Keyboard",Vector3(-0.21,0.924,-0.15),Vector3(0.20,0.028,0.65),"1f282b","res://assets/textures/matte_plastic.png")
	for row in range(5):
		for col in range(17):box.call("Key",Vector3(-0.29+row*0.035,0.946,-0.44+col*0.035),Vector3(0.025,0.008,0.027),"41494b")
	var mouse: MeshInstance3D=host._add_sphere(id+"ComputerMouse",origin+Vector3(-0.2,0.946,0.36),Vector3(0.09,0.035,0.055),Color("2c3436"),0.4)
	parts.append(mouse)
	box.call("MouseSeam",Vector3(-0.22,0.981,0.36),Vector3(0.045,0.003,0.003),"111619")
	var strip: MeshInstance3D=box.call("RearLED",Vector3(0.37,0.905,0),Vector3(0.012,0.008,1.29),"69ba91")
	strip.mesh.material.emission_enabled=true;strip.mesh.material.emission=Color("69ba91")
	for node in parts:
		node.set_meta("equipment_template_group","computer" if apartment else "house_computer")
		node.layers=1 if apartment else 2
		if not apartment:node.reparent(world,true)
func dashboard_texture() -> ImageTexture:
	var picture := Image.create(768,432,false,Image.FORMAT_RGB8)
	picture.fill(Color("0b211b"))
	picture.fill_rect(Rect2i(20,18,728,23),Color("245a45"))
	for panel in [Rect2i(24,57,450,214),Rect2i(490,57,254,214),Rect2i(24,289,218,118),Rect2i(260,289,214,118),Rect2i(490,289,254,118)]:
		picture.fill_rect(panel,Color("12352a"));picture.fill_rect(Rect2i(panel.position+Vector2i(10,10),Vector2i(panel.size.x-20,8)),Color("326e53"))
	for i in range(8):
		picture.fill_rect(Rect2i(278+i*22,380-i*8,13,15+i*8),Color("4d9c71"))
		picture.fill_rect(Rect2i(508,323+i*9,105+(i%3)*35,4),Color("397956"))
	for x in range(420):
		var y: int=240-int(x*0.29)-int(sin(x*0.045)*17)
		picture.fill_rect(Rect2i(39+x,y,2,2),Color("6ad69b"))
	for x in range(115):
		for y in range(115):
			var d:=Vector2(x-57,y-57).length()
			if d>32 and d<53:picture.set_pixel(555+x,109+y,Color("469775") if x>45 else Color("23563f"))
	return ImageTexture.create_from_image(picture)
func is_open() -> bool:return ui!=null and ui.is_open()
func near(point: Vector3, range_limit: float=2.4) -> bool:
	var offset: Vector3=point-host.camera.position
	return world._door_line_clear(point) and offset.length()<range_limit and (-host.camera.global_basis.z).dot(offset.normalized())>0.3
func target() -> String:
	if host.inventory_system!=null and host.inventory_system.furniture!=null:
		for e in host.inventory_system.furniture.model.state.items.values():
			if e.sku=="floor_lamp" and e.get("property","") in ["apartment","house"] and e.has("position") and near(Vector3(e.position[0],1.3,e.position[2]),2.0):return "equipment_lamp"
			if e.sku=="computer" and e.get("property","") in ["apartment","house"] and e.has("position") and near(Vector3(e.position[0],1.3,e.position[2]),3.1):return e.property+"_computer"
		if near(CHECKOUT,2.7):return "market_checkout"
		return ""
	if world._indoors(host.camera.position) and near(APT_PC):
		return "apartment_computer" if apartment_lease_active() else ""
	var room: String=world.house_controls._inside_room(host.camera.position)
	if room=="living" and near(HOUSE_PC):return "house_computer"
	if room=="market_front" and near(CHECKOUT,2.7):return "market_checkout"
	return ""
func use(id: String) -> void:
	if id=="equipment_lamp":host.inventory_system.furniture.equipment_world.toggle_lamp();return
	match id:
		"apartment_computer":computer("apartment")
		"house_computer":computer("house")
		"market_checkout":market()
func clear(title: String) -> void:
	ui.scroll_actions=true
	ui.scroll.scroll_vertical=0
	for container in [ui.body,ui.footer]:
		for child in container.get_children():container.remove_child(child);child.queue_free()
	ui.label(title,26)
	if host.inventory_system!=null and (title.begins_with("CENTRAL MARKET") or not computer_context.is_empty()):
		ui.panel.add_theme_stylebox_override("panel",host.inventory_system.ui_style("111713","566052",18))
	ui.overlay.show();ui.resize()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;host.fp_player.enabled=false
func close() -> void:
	ui.overlay.hide();management_app=""
	if not host._any_modal_open():Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
func b(text: String, callback: Callable, disabled: bool=false) -> void:
	var item := Button.new()
	item.text=text;item.custom_minimum_size.y=54
	item.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	item.add_theme_font_size_override("font_size",22)
	if host.inventory_system!=null:host.inventory_system.style_button(item)
	item.disabled=disabled;item.pressed.connect(callback);ui.body.add_child(item)
func total(inventory: Dictionary) -> int:
	var amount:=0
	for key in inventory:amount+=maxi(0,int(inventory[key]))
	return amount
func order_seed(name: String) -> void:
	if host.tutorial_active or not host.seed_catalog.has(name):return
	var info: Dictionary=host.seed_catalog[name]
	if bool(info.get("recipe_only",false)) or host.grower_level<int(info.get("unlock",1)):return
	var price: int=int(info.get("cost",10))
	if host.cash<price or total(host.location_state.pickup_seeds)>=50:return
	host.cash-=price
	host._record_daily_expense("Seed orders",price)
	host.location_state.pickup_seeds[name]=int(host.location_state.pickup_seeds.get(name,0))+1
	host._increment_advancement_stat("seeds_bought")
	if host.inventory_system.guide!=null:host.inventory_system.guide.record("order_seed")
	host._update_cash_ui();host._save_game();host._refresh_phone()
	host.status_label.text="Seed order ready at Central Market. Pick it up at the checkout."
func pickup() -> void:
	if target()!="market_checkout":return
	close()
	host.inventory_system.open_container("market:orders")
func fertilizer() -> void:
	if target()!="market_checkout" or host.cash<45 or host.inventory_system.free_space("backpack","fertilizer")<5:return
	host.cash-=45;host.location_state.carried_fertilizer+=5
	host._record_daily_expense("Supplies",45);host._increment_advancement_stat("supplies_bought")
	host._update_cash_ui();host._save_game();market()
func eligible(name: String) -> bool:
	if rent_overdue():return false
	if not host.supply_catalog.has(name) or host._supply_is_purchased(name) or host.location_state.deliveries.has(name):return false
	if host.grower_level<int(host.supply_catalog[name].get("unlock",1)):return false
	if name=="Grow Supply Shelf III" and host.supply_shelf_level<2:return false
	if name==host.VAULT_SUPPLY and host.storage_level<3:return false
	if name==host.HIDDEN_STASH_SUPPLY and host.storage_level<4:return false
	if name=="Bagging Bench III" and host.bagging_level<2:return false
	return true
func order_equipment(name: String) -> void:
	if host.inventory_system!=null and host.inventory_system.furniture!=null:equipment();return
	if target()!="market_checkout" or not eligible(name):return
	var price: int=int(host.supply_catalog[name].get("cost",10))
	if host.cash<price:return
	host.cash-=price;host._record_daily_expense("Equipment orders",price)
	host.location_state.deliveries[name]={"property":active_property(),"paid":price,"collected":false}
	host._update_cash_ui();host._save_game();equipment()
func install(name: String) -> void:
	if computer_context not in ["apartment","house"] or not _property_controlled(computer_context) or not host.location_state.deliveries.has(name):return
	if not host.inventory_system.delivery_carried(name):
		host.status_label.text="Collect this paid equipment into your backpack before installing it."
		return
	var delivery: Dictionary=host.location_state.deliveries[name]
	if str(delivery.get("property",""))!=computer_context:return
	if host._supply_is_purchased(name):return
	if str(delivery.get("kind",""))=="dealer":
		installing=true;host._buy_dealer_locker_upgrade();installing=false
		if host.dealer_locker_level>=int(delivery.level):host.location_state.deliveries.erase(name)
		host._save_game()
		if host.phone_open:host._refresh_phone()
		else:manage("property")
		return
	var price: int=int(host.supply_catalog[name].cost)
	host.supply_catalog[name].cost=0;installing=true
	host._buy_supply(name)
	installing=false;host.supply_catalog[name].cost=price
	if host._supply_is_purchased(name):host.location_state.deliveries.erase(name)
	host._save_game()
	if host.phone_open:host._refresh_phone()
	else:manage("property")
func deposit() -> void:
	# Compatibility for old callers: inventory transfers only happen at containers.
	host.status_label.text="Open the grow shelf and choose Add Stock to store supplies."
func market() -> void:
	clear("CENTRAL MARKET")
	market_navigation()
	ui.label("Order supplies, then collect everything that fits in your backpack. Paid items stay here until you take them.",18)
	b("ORDER PICKUP",pickup,host.inventory_system.contents("market:orders").is_empty())
	market_card("seed|Street Green","Seeds","Parent strains for planting and breeding.",seeds)
	market_card("fertilizer","Supplies","Fertilizer and everyday growing supplies.",supplies)
	market_card("equipment|Grow Tent upgrade","Upgrades","Grow tents, equipment and larger backpacks.",equipment)
	market_card("equipment|Storage Shelving II","Furniture","Furnish your properties. Delivered to Property Storage.",market_furniture)
	ui.button("CLOSE",close)
func market_furniture() -> void:
	host.inventory_system.furniture.shop("furniture")
func market_grow_tents() -> void:
	host.inventory_system.furniture.shop("grow")
func market_navigation() -> void:
	host.inventory_system.furniture.cart.toolbar(ui.body)
	ui.label("Cash: $%d  |  %s" % [host.cash,host.inventory_system.backpack_summary()],16)
	var row:=GridContainer.new();row.columns=2;row.add_theme_constant_override("h_separation",6);row.add_theme_constant_override("v_separation",6);ui.body.add_child(row)
	for category_name in ["Seeds","Supplies","Upgrades","Furniture"]:
		var callback:Callable={"Seeds":seeds,"Supplies":supplies,"Upgrades":equipment,"Furniture":market_furniture}[category_name]
		var tab:Button=host.inventory_system.button(category_name,callback,row)
		tab.size_flags_horizontal=Control.SIZE_EXPAND_FILL;tab.add_theme_font_size_override("font_size",16)
func market_card(item:String,title:String,detail:String,callback:Callable,disabled:bool=false) -> void:
	var card:=Button.new();card.custom_minimum_size.y=128;card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	host.inventory_system.style_button(card);card.disabled=disabled;card.pressed.connect(callback);ui.body.add_child(card)
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",12);card.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);row.offset_left=12;row.offset_right=-12;row.offset_top=10;row.offset_bottom=-10
	host.inventory_system.art_rect(item,row,Vector2(88,88))
	var text_box:=VBoxContainer.new();text_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(text_box)
	host.inventory_system.label(title,text_box,20)
	host.inventory_system.label(detail,text_box,16).modulate=Color("bdcbb4")
	host.inventory_system.ignore_pointer(row)
	if disabled:row.modulate=Color(1,1,1,.5)
func supplies() -> void:
	clear("CENTRAL MARKET - SUPPLIES");market_navigation()
	host.inventory_system.furniture.cart.supplies(ui.body)
	ui.button("BACK TO CHECKOUT",market)
	ui.button("CLOSE",close)

func seeds() -> void:
	clear("CENTRAL MARKET - SEEDS");market_navigation()
	host.inventory_system.furniture.cart.seeds(ui.body)
	ui.button("BACK TO CHECKOUT",market)

func equipment() -> void:
	clear("CENTRAL MARKET - EQUIPMENT");market_navigation()
	market_card("equipment|Grow Tent","Grow tents · 1 / 2 / 3 / 4 plants","Purchase packed tents and choose where to place them.",market_grow_tents)
	market_card("equipment|Packing Bench","Stations & equipment","Buy basic or upgraded equipment; retain your old items.",func():host.inventory_system.furniture.shop("equipment"))
	b("Furniture",market_furniture)
	b("Sell packed equipment",func():host.inventory_system.furniture.sell_menu())

func computer(property: String) -> void:
	if not _property_controlled(property):
		host.status_label.text="You do not currently control this property."
		return
	computer_context=property
	clear(property.to_upper()+" — COMPUTER")
	ui.label("MANAGEMENT MOVED TO THE PHONE",22)
	ui.label(portfolio_name(property)+"\nWorkers, property bills, stock, and furniture are now organized in Phone > Properties.")
	ui.label("This desk remains your owned furniture. You can move or remove it through Arrange Furniture while at this property.")
	ui.button("OPEN "+portfolio_name(property).to_upper()+" IN PROPERTIES",func():close();computer_context="";host._open_phone_app("realestate");portfolio_select(property);host._refresh_phone();host.phone_open=true;host.phone_panel.show())
	ui.button("CLOSE COMPUTER",func():close();computer_context="")

const MANAGEMENT_TABS := ["business","employees","production","inventory","upgrades","bills"]
const MANAGEMENT_TITLES := {"business":"OVERVIEW","employees":"EMPLOYEES","production":"PRODUCTION","inventory":"INVENTORY","upgrades":"EQUIPMENT","bills":"BILLS"}
func _management_navigation(section:String) -> void:
	var property:String=computer_context
	var banner:=PanelContainer.new()
	banner.add_theme_stylebox_override("panel",host.inventory_system.ui_style("10251d","5a9a74",15))
	ui.body.add_child(banner)
	var banner_box:=VBoxContainer.new()
	banner_box.add_theme_constant_override("separation",4)
	banner.add_child(banner_box)
	var heading:=Label.new()
	heading.text=property.to_upper()+"  /  "+str(MANAGEMENT_TITLES.get(section,section.to_upper()))
	heading.add_theme_font_size_override("font_size",24)
	heading.add_theme_color_override("font_color",Color("b6efc4"))
	banner_box.add_child(heading)
	var detail:=Label.new()
	detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	detail.text="PROPERTY-LOCAL CONTROLS  ·  $%d outstanding  ·  %d assigned staff" % [computer_due(property),computer_staff_names(property).size()]
	detail.add_theme_font_size_override("font_size",15)
	detail.add_theme_color_override("font_color",Color("b1c8b6"))
	banner_box.add_child(detail)
	var tabs:=GridContainer.new()
	tabs.columns=2 if ui.panel.size.x<590 else 3
	tabs.add_theme_constant_override("h_separation",8)
	tabs.add_theme_constant_override("v_separation",8)
	ui.body.add_child(tabs)
	for key in MANAGEMENT_TABS:
		var tab:=Button.new()
		tab.text=str(MANAGEMENT_TITLES[key])
		tab.custom_minimum_size.y=48
		tab.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		tab.add_theme_font_size_override("font_size",16)
		tab.disabled=key==section
		host.inventory_system.style_button(tab)
		tab.pressed.connect(manage.bind(key))
		tabs.add_child(tab)

func manage(app: String) -> void:
	# Everything displayed on this computer belongs to its original property.
	if computer_context not in ["apartment","house"] or not _property_controlled(computer_context):return
	management_app=app
	rendering_management=true
	clear(computer_context.to_upper()+" — BUSINESS COMPUTER")
	var previous_list:VBoxContainer=host.phone_list
	host.phone_list=ui.body
	if app!="production":
		_management_navigation(app)
	match app:
		"business":business_home()
		"operations":operations_home()
		"inventory":inventory_home()
		"property":property_home()
		"employees":computer_employees()
		"production":production()
		"products":host._build_products_app()
		"genetics":host._build_genetics_app()
		"upgrades":computer_upgrades()
		"bills":computer_bills()
	host.phone_list=previous_list
	if is_open():
		if app!="business":ui.button("BACK TO OVERVIEW",manage.bind("business"))
		ui.button("CLOSE COMPUTER",close)
		format_management()
	rendering_management=false
func computer_staff_names(property:String) -> Array[String]:
	var names:Array[String]=[]
	for name in crew.roster():
		if crew.role(name)!="" and crew.assignment(name)==property and not names.has(name):names.append(name)
	names.sort()
	return names
func computer_staff_payroll(property:String) -> int:
	var total:int=0
	for name in computer_staff_names(property):
		if crew.role(name)=="production" and host.packing_employee_active:total+=host.PACKER_DAILY_WAGE
	return total
func computer_stock_total(property:String,kind:String,prefix:String) -> int:
	if host.inventory_system==null:return 0
	var amount:int=0
	for key in host.inventory_system.contents(property+":"+kind):
		if str(key).begins_with(prefix):amount+=maxi(0,int(host.inventory_system.contents(property+":"+kind)[key]))
	return amount
func computer_due(property:String) -> int:
	var state:Dictionary=utility_state(property)
	return int(state.get("power_due",0))+int(state.get("water_due",0))+(house_balance() if property=="house" else apartment_balance())
func _management_metric(title:String,value:String,description:String) -> void:
	var card:=PanelContainer.new()
	card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel",host.inventory_system.ui_style("182c25","3d6c55",12))
	ui.body.add_child(card)
	var column:=VBoxContainer.new()
	column.add_theme_constant_override("separation",4)
	card.add_child(column)
	for entry in [[title,15,"b6d6bf"],[value,23,"e6f8e3"],[description,14,"a2b9aa"]]:
		var label_node:=Label.new()
		label_node.text=str(entry[0])
		label_node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		label_node.add_theme_font_size_override("font_size",int(entry[1]))
		label_node.add_theme_color_override("font_color",Color(str(entry[2])))
		column.add_child(label_node)

func business_home() -> void:
	var property:String=computer_context
	var staff:Array[String]=computer_staff_names(property)
	ui.label("YOUR "+property.to_upper()+" AT A GLANCE",21)
	_management_metric("CREW",str(staff.size())+" assigned","On duty: "+str(host.packing_employee_active if staff.has(host._critical_production_sender()) else false)+" · Dealer team: "+("WORKING" if host.dealers_active else "HOME"))
	_management_metric("PRODUCTION","%dg packed" % computer_stock_total(property,"packing","product|"),"%dg raw · %dg trimmed" % [computer_stock_total(property,"packing","raw|"),computer_stock_total(property,"packing","trimmed|")])
	_management_metric("STORAGE","%dg products" % computer_stock_total(property,"storage","product|"),"Dealer locker: %dg" % computer_stock_total(property,"dealer","product|"))
	_management_metric("BILLS","$%d due" % computer_due(property),"Power, water and property payments")
	ui.label("Choose a section above to manage this property's workers, production, inventory, equipment or bills.",17)
	if property=="house":ui.label("House equipment, utilities, stock and worker assignments are separate from the apartment. Dealer duty is currently a team-wide switch.",16)
	else:ui.label("Apartment storefront: "+("LAYING LOW" if host.lay_low_active else ("OPEN" if host.business_open else "AWAY")),16)
	if host.location_state.deliveries.size()>0:ui.label("%d paid orders · Collect into backpack at Central Market before placement." % host.location_state.deliveries.size(),16)
func operations_home() -> void:
	var property:String=computer_context
	ui.label(property.to_upper()+" CREW · %d assigned" % computer_staff_names(property).size())
	if property=="apartment":ui.label("Apartment door manager: "+(crew.manager() if not crew.manager().is_empty() else "None assigned"))
	else:ui.label("The apartment door manager does not operate the house. Assign staff to the house separately.")
	b("EMPLOYEES · Hiring, duty & assignments",manage.bind("employees"))
	b("PRODUCTION & POWER · Lights, ventilation & equipment",production)
	b("CONTACTS · Crew messages & commands",func():close();host._open_phone_app("clients");host.phone_open=true;host.phone_panel.show())
func computer_employees() -> void:
	var property:String=computer_context
	var local:Array[String]=computer_staff_names(property)
	ui.label(property.to_upper()+" STAFF · "+str(local.size())+" assigned",22)
	ui.label("Crew positions are shared until transferred. Hired staff and pay remain in your career, but assignments and work stock are tied to one property.")
	for name in local:
		var role_name:String=crew.role(name)
		ui.label(name+" · "+role_name.capitalize()+" · "+("ON DUTY" if host.packing_employee_active else "OFF DUTY") if role_name=="production" else name+" · "+role_name.capitalize())
		if role_name=="dealer":
			var performance:Dictionary=host.friend_dealer_stats.get(name,{})
			ui.label("  Today: %d deals · %dg · $%d earned · $%d commission" % [int(performance.get("today_sales",0)),int(performance.get("today_grams",0)),int(performance.get("today_gross",0)),int(performance.get("today_commission",0))])
			ui.label("  Career: %d deals · %dg · $%d gross · $%d commission earned" % [int(performance.get("sales",0)),int(performance.get("grams",0)),int(performance.get("gross",0)),int(performance.get("commission_earned",0))])
		b("MOVE "+name.to_upper()+" TO "+("HOUSE" if property=="apartment" else "APARTMENT"),move_computer_staff.bind(name,"house" if property=="apartment" else "apartment"))
	if local.is_empty():ui.label("No workers are assigned to this property. Apartment staff are not shown here.")
	var local_dealer_count:int=0
	for staff_name in local:
		if crew.role(staff_name)=="dealer":local_dealer_count+=1
	if local_dealer_count>0:
		ui.label("ALL DEALERS · %s · %d deals today · $%d cash held · $%d commission held · $%d balance due" % ["ON DUTY" if host.dealers_active else "OFF DUTY",host.dealer_sales_today,host.dealer_cash_held,host.dealer_commission_held,host.dealer_balance_due])
		ui.label("Dealer duty is a team-wide setting across properties; each dealer's assignment remains unchanged.")
		var duty_reason:String=host._staff_duty_blocker("dealer")
		if not host.dealers_active and not duty_reason.is_empty():ui.label("WHY OFF DUTY: "+duty_reason)
		b("SEND ALL DEALERS HOME" if host.dealers_active else "PUT ALL DEALERS ON DUTY",toggle_computer_dealers,not host.dealers_active and not duty_reason.is_empty())
	var other:String="house" if property=="apartment" else "apartment"
	for name in computer_staff_names(other):
		b("ASSIGN "+name.to_upper()+" TO "+property.to_upper(),move_computer_staff.bind(name,property))
	if not host.packing_employee_hired:
		b("HIRE PRODUCTION WORKER FOR "+property.to_upper(),hire_computer_worker.bind(property),host.grower_level<5 or host.cash<host.PACKER_HIRE_COST)
	elif computer_staff_names(property).has(host._critical_production_sender()):
		var worker_reason:String=host._staff_duty_blocker("production")
		if not host.packing_employee_active and not worker_reason.is_empty():ui.label("WHY OFF DUTY: "+worker_reason)
		b("SEND PRODUCTION WORKER HOME" if host.packing_employee_active else "PUT PRODUCTION WORKER ON DUTY",toggle_computer_worker,not host.packing_employee_active and not worker_reason.is_empty())
	if property=="apartment":
		ui.label("Apartment storefront sales and door coverage are managed here.")
		b("APARTMENT DEALER / DOOR CONTROLS",crew.computer_controls)
	else:
		ui.label("House production work uses house supplies. Apartment-only door coverage cannot be controlled from here.")
func move_computer_staff(name:String,property:String) -> void:
	if not _property_controlled(property):return
	crew.assign(name,property)
	manage("employees")
func hire_computer_worker(property:String) -> void:
	if not _property_controlled(property):return
	host._hire_packing_employee()
	if host.packing_employee_hired:crew.assign(host._critical_production_sender(),property)
	manage("employees")
func toggle_computer_dealers() -> void:
	var local_staff:Array[String]=computer_staff_names(computer_context)
	var has_dealer:bool=false
	for staff_name in local_staff:
		if crew.role(staff_name)=="dealer":has_dealer=true
	if not has_dealer:return
	host._toggle_dealers()
	manage("employees")

func toggle_computer_worker() -> void:
	if crew.assignment(host._critical_production_sender())!=computer_context:return
	host._toggle_packing_employee()
	manage("employees")
func computer_upgrades() -> void:
	var property:String=computer_context
	ui.label(property.to_upper()+" OWNED EQUIPMENT",22)
	if host.inventory_system==null or host.inventory_system.furniture==null:return
	var model:RefCounted=host.inventory_system.furniture.model
	var count:int=0
	for id in model.state.items:
		var item:Dictionary=model.state.items[id]
		if str(item.get("property",""))!=property:continue
		count+=1
		ui.label(model.item_name(id)+" · "+("FIXED IN PLACE" if bool(item.get("locked",false)) else "READY TO MOVE"))
	if count==0:ui.label("No equipment or furniture is installed at this property. Apartment equipment stays at the apartment.")
	b("ARRANGE "+property.to_upper()+" FURNITURE & EQUIPMENT",func():close();host.inventory_system.furniture.open_property(property))
	ui.label("Buy additional equipment at Central Market. Purchases must be delivered or carried to this property.")
func computer_bills() -> void:
	var property:String=computer_context
	var due:Dictionary=utility_state(property)
	ui.label(property.to_upper()+" PROPERTY BILLS",22)
	ui.label("Power: $%d · Water: $%d" % [int(due.get("power_due",0)),int(due.get("water_due",0))])
	if property=="house":
		ui.label("House agreement balance: $%d" % house_balance())
		if house_balance()>0:b("PAY HOUSE AGREEMENT · $%d" % house_balance(),pay_house_payment,host.cash<house_balance())
	else:
		ui.label("Apartment rent balance: $%d" % apartment_balance())
		if apartment_balance()>0:b("PAY APARTMENT RENT · $%d" % apartment_balance(),pay_apartment_rent,host.cash<apartment_balance())
	b("MANAGE PROPERTY & UTILITIES ON PHONE",func():close();host._open_phone_app("realestate");host.phone_open=true;host.phone_panel.show())
func inventory_home() -> void:
	b("STORAGE · Stock, prices & listings",manage.bind("products"))
	b("GENETICS · Hybrid recipes & seeds",manage.bind("genetics"))
func property_home() -> void:
	b("BILLS & RENT · Payments and balances",manage.bind("bills"))
	b("EQUIPMENT · Upgrades & installation",manage.bind("upgrades"))
	if host.location_state.deliveries.size()>0:
		ui.label("PAID EQUIPMENT · Collect at market before installation")
		for name in host.location_state.deliveries:
			if str(host.location_state.deliveries[name].get("property",""))==computer_context:b("INSTALL "+str(name),install.bind(str(name)),not host.inventory_system.delivery_carried(str(name)))
	if computer_context=="apartment":crew.computer_controls()
func business_extras() -> void:
	if computer_context=="apartment":crew.computer_controls()
	for name in host.location_state.deliveries:
		if str(host.location_state.deliveries[name].get("property",""))==computer_context:b("INSTALL "+str(name),install.bind(str(name)),not host.inventory_system.delivery_carried(str(name)))
	var grid: GridContainer=host._phone_category_grid()
	for app in ["employees","upgrades","products","genetics"]:
		var title: String={"employees":"Employees","upgrades":"Upgrades","products":"Storage","genetics":"Genetics"}[app]
		host._add_phone_app_tile(grid,"",title,computer_context.capitalize()+" operation",app)
	b("PRODUCTION & UTILITIES",production)
func management_allowed() -> bool:
	return is_open() and computer_context in ["apartment","house"] and _property_controlled(computer_context)
func supply_intercept(name: String) -> bool:
	if installing:return false
	# The guided starter purchase stays with the tutorial; regular restocking moves to the market.
	if host.tutorial_active and name=="Fertilizer Pack":return false
	host.status_label.text="Buy fertilizer and order equipment at the Central Market checkout."
	return true
func redirect(app: String) -> bool:
	if rendering_management:return false
	if is_open() and computer_context in ["apartment","house"] and app in ["business","bills","employees","products","genetics","upgrades"]:
		manage(app)
		return true
	if host.tutorial_active:return false
	# Mobile/desktop phone must offer remote staff and inventory information too.
	# These apps use the same loaded career, while physical interactions stay
	# restricted to the property computer and nearby stations.
	if app in ["employees","products","genetics","upgrades"]:
		return false
	return false
func _utility_template() -> Dictionary:
	return {"today_power":0.0,"power_due":0,"last_power":0,"today_water":0.0,"water_uses":0,"water_due":0,"last_water":0}

func _ensure_property_utilities() -> void:
	var ledger:Variant=host.location_state.get("property_utilities",{})
	if not ledger is Dictionary:
		ledger={}
	var data:Dictionary=ledger as Dictionary
	if not data.has("apartment") or not data["apartment"] is Dictionary:
		data["apartment"]=_utility_template()
	if not data.has("house") or not data["house"] is Dictionary:
		data["house"]=_utility_template()
	if not bool(data.get("_migrated_legacy",false)):
		var apartment:Dictionary=data["apartment"]
		apartment["today_power"]=maxf(float(apartment.get("today_power",0.0)),host.current_day_power_cost)
		apartment["power_due"]=maxi(int(apartment.get("power_due",0)),host.power_bill_due)
		apartment["last_power"]=maxi(int(apartment.get("last_power",0)),host.last_power_bill)
		apartment["today_water"]=maxf(float(apartment.get("today_water",0.0)),host.current_day_water_cost)
		apartment["water_uses"]=maxi(int(apartment.get("water_uses",0)),host.current_day_water_uses)
		apartment["water_due"]=maxi(int(apartment.get("water_due",0)),host.water_bill_due)
		apartment["last_water"]=maxi(int(apartment.get("last_water",0)),host.last_water_bill)
		data["apartment"]=apartment
		data["_migrated_legacy"]=true
	host.location_state["property_utilities"]=data

func utility_state(property:String) -> Dictionary:
	_ensure_property_utilities()
	var ledger:Dictionary=host.location_state.get("property_utilities",{})
	if not ledger.has(property) or not ledger[property] is Dictionary:
		ledger[property]=_utility_template()
		host.location_state["property_utilities"]=ledger
	return ledger[property]

func _property_controlled(property:String) -> bool:
	if property=="apartment":return apartment_lease_active()
	if property=="house":return bool(house_state().get("acquired",false)) and bool(house_state().get("relocated",false))
	return false

func _sync_legacy_utility_totals() -> void:
	_ensure_property_utilities()
	var apartment:Dictionary=utility_state("apartment")
	var house:Dictionary=utility_state("house")
	host.current_day_power_cost=float(apartment.get("today_power",0.0))+float(house.get("today_power",0.0))
	host.power_bill_due=int(apartment.get("power_due",0))+int(house.get("power_due",0))
	host.last_power_bill=int(apartment.get("last_power",0))+int(house.get("last_power",0))
	host.current_day_water_cost=float(apartment.get("today_water",0.0))+float(house.get("today_water",0.0))
	host.current_day_water_uses=int(apartment.get("water_uses",0))+int(house.get("water_uses",0))
	host.water_bill_due=int(apartment.get("water_due",0))+int(house.get("water_due",0))
	host.last_water_bill=int(apartment.get("last_water",0))+int(house.get("last_water",0))

func _apartment_power_rate() -> float:
	if not apartment_lease_active():return 0.0
	var rate:float=host.POWER_BASE_COST_PER_GAME_MINUTE if active_property()=="apartment" else 0.0
	if host.main_ceiling_light_on:rate+=host.POWER_MAIN_LIGHT_COST_PER_GAME_MINUTE
	if host.floor_lamp_on:rate+=host.POWER_LAMP_COST_PER_GAME_MINUTE
	if host.grow_room_light_on:rate+=host.POWER_GROW_ROOM_LIGHT_COST_PER_GAME_MINUTE
	if host.grow_lights_on:rate+=host.POWER_GROW_LIGHT_COST_PER_TENT_PER_GAME_MINUTE*float(host.inventory_system.furniture.model.powered_tent_count("apartment"))
	rate+=host.inventory_system.furniture.model.utility_power("apartment")
	return rate

func _house_power_rate() -> float:
	if not _property_controlled("house"):return 0.0
	var rate:float=host.POWER_BASE_COST_PER_GAME_MINUTE if active_property()=="house" else 0.0
	for room_id in ["living","packing","kitchen","bathroom","bedroom","cross_hall","grow"]:
		if bool(host.house_control_state.get(room_id,true)):rate+=host.POWER_MAIN_LIGHT_COST_PER_GAME_MINUTE
	if bool(host.house_control_state.get("grow_lights",false)):rate+=host.POWER_GROW_LIGHT_COST_PER_TENT_PER_GAME_MINUTE*float(host.inventory_system.furniture.model.powered_tent_count("house"))
	rate+=host.inventory_system.furniture.model.utility_power("house")
	return rate

func track_power_usage(elapsed_game_minutes:float) -> void:
	if elapsed_game_minutes<=0.0:return
	for property in ["apartment","house"]:
		var rate:float=_apartment_power_rate() if property=="apartment" else _house_power_rate()
		if rate<=0.0:continue
		var state:=utility_state(property)
		state["today_power"]=float(state.get("today_power",0.0))+rate*elapsed_game_minutes
	_sync_legacy_utility_totals()

func charge_water_use(count:int=1) -> void:
	if count<=0:return
	var property:=str(host.location_state.get("operation_assets_property",active_property()))
	if not _property_controlled(property):property=active_property()
	if not _property_controlled(property):return
	var state:=utility_state(property)
	state["water_uses"]=int(state.get("water_uses",0))+count
	state["today_water"]=float(state.get("today_water",0.0))+host.WATER_COST_PER_WATERING*float(count)
	_sync_legacy_utility_totals()

func finalize_power_bills(show_feedback:bool=false) -> void:
	var total_bill:int=0
	for property in ["apartment","house"]:
		var state:=utility_state(property)
		var bill:int=maxi(0,int(ceil(float(state.get("today_power",0.0)))))
		state["last_power"]=bill
		state["power_due"]=mini(host.POWER_BILL_MAX_BALANCE,int(state.get("power_due",0))+bill)
		state["today_power"]=0.0
		total_bill+=bill
	host.lifetime_power_cost+=total_bill
	_sync_legacy_utility_totals()
	if show_feedback and total_bill>0:host.status_label.text="Property electric bills posted: $%d total." % total_bill

func finalize_water_bills(show_feedback:bool=false) -> void:
	var total_bill:int=0
	for property in ["apartment","house"]:
		var state:=utility_state(property)
		var bill:int=maxi(0,int(ceil(float(state.get("today_water",0.0)))))
		state["last_water"]=bill
		state["water_due"]=mini(host.WATER_BILL_MAX_BALANCE,int(state.get("water_due",0))+bill)
		state["today_water"]=0.0
		state["water_uses"]=0
		total_bill+=bill
	host.lifetime_water_cost+=total_bill
	_sync_legacy_utility_totals()
	if show_feedback and total_bill>0:host.status_label.text="Property water bills posted: $%d total." % total_bill

func property_utility_due(property:String,kind:String) -> int:
	var state:=utility_state(property)
	return maxi(0,int(state.get("power_due" if kind=="power" else "water_due",0)))

func utility_total_due() -> int:
	return property_utility_due("apartment","power")+property_utility_due("apartment","water")+property_utility_due("house","power")+property_utility_due("house","water")

func pay_property_utility(property:String,kind:String) -> void:
	var state:=utility_state(property)
	var key:String="power_due" if kind=="power" else "water_due"
	var amount:int=maxi(0,int(state.get(key,0)))
	if amount<=0 or host.cash<amount:return
	host.cash-=amount
	state[key]=0
	if property=="house":host.location_state["house_bills_paid"]=int(host.location_state.get("house_bills_paid",0))+1
	host._increment_advancement_stat("power_bills_paid" if kind=="power" else "water_bills_paid")
	host._record_daily_expense(("%s electricity" if kind=="power" else "%s water") % property.capitalize(),amount)
	_sync_legacy_utility_totals()
	host._update_cash_ui();host._save_game();host._refresh_phone()
	host.status_label.text="%s %s bill paid: $%d." % [property.capitalize(),"electric" if kind=="power" else "water",amount]

func utility_bills_ui(parent:VBoxContainer) -> void:
	for property in ["apartment","house"]:
		if property=="apartment" and not apartment_lease_active() and property_utility_due(property,"power")==0 and property_utility_due(property,"water")==0:continue
		if property=="house" and not bool(house_state().get("acquired",false)) and property_utility_due(property,"power")==0 and property_utility_due(property,"water")==0:continue
		var state:=utility_state(property)
		_property_label(parent,"%s UTILITIES\nElectric due: $%d · Water due: $%d\nToday: $%d electric · $%d water (%d uses)" % [property.to_upper(),int(state.get("power_due",0)),int(state.get("water_due",0)),int(ceil(float(state.get("today_power",0.0)))),int(ceil(float(state.get("today_water",0.0)))),int(state.get("water_uses",0))],17)
		if int(state.get("power_due",0))>0:_property_button(parent,"PAY %s ELECTRIC · $%d" % [property.to_upper(),int(state.get("power_due",0))],pay_property_utility.bind(property,"power"),host.cash<int(state.get("power_due",0)))
		if int(state.get("water_due",0))>0:_property_button(parent,"PAY %s WATER · $%d" % [property.to_upper(),int(state.get("water_due",0))],pay_property_utility.bind(property,"water"),host.cash<int(state.get("water_due",0)))

func placement_room(property:String,world_point:Vector3) -> String:
	if property=="house":
		var room:String=world.house_controls._inside_room(world_point)
		return "" if room=="apartment" else room
	if property=="apartment":
		if not world._indoors(world_point):return ""
		return "grow" if world_point.z< -4.0 else "main"
	return ""

func asset_requires_grow_room(asset_name:String) -> bool:
	return asset_name.to_lower().contains("grow tent")

func can_place_owned_asset(asset_name:String,property:String,world_point:Vector3) -> bool:
	if not _property_controlled(property):return false
	var room:=placement_room(property,world_point)
	if room.is_empty():return false
	if asset_requires_grow_room(asset_name):return room=="grow"
	return true

func save_asset_placement(asset_id:String,asset_name:String,property:String,world_point:Vector3,yaw:float,locked:bool=true) -> bool:
	if asset_id.is_empty() or not can_place_owned_asset(asset_name,property,world_point):return false
	var placements:Dictionary=host.location_state.get("asset_placements",{})
	placements[asset_id]={
		"name":asset_name,
		"property":property,
		"position":[world_point.x,world_point.y,world_point.z],
		"yaw":yaw,
		"locked":locked,
		"room":placement_room(property,world_point)
	}
	host.location_state["asset_placements"]=placements
	host._save_game()
	return true

func set_asset_locked(asset_id:String,locked:bool) -> void:
	var placements:Dictionary=host.location_state.get("asset_placements",{})
	if not placements.has(asset_id):return
	var entry:Dictionary=placements[asset_id]
	entry["locked"]=locked
	placements[asset_id]=entry
	host.location_state["asset_placements"]=placements
	host._save_game()

func active_property() -> String:
	return str(host.location_state.get("active_property","apartment"))

func house_state() -> Dictionary:
	if not host.property_opportunity_state is Dictionary:host.property_opportunity_state={}
	return host.property_opportunity_state

func apartment_lease_active() -> bool:
	return bool(host.apartment_rent_state.get("lease_active",true))

func apartment_balance() -> int:
	return maxi(0,int(host.apartment_rent_state.get("balance",0)))

func house_balance() -> int:
	return maxi(0,int(house_state().get("balance",0)))

func balance() -> int:
	return apartment_balance()+house_balance()

func _update_apartment_rent() -> bool:
	if not apartment_lease_active():return false
	var due:int=int(host.apartment_rent_state.get("next_due",host.game_day+14))
	if due<=0:due=host.game_day+14
	var changed:=false
	while host.game_day>=due:
		if apartment_balance()==0:host.apartment_rent_state["first_unpaid"]=due
		host.apartment_rent_state["balance"]=apartment_balance()+600
		due+=14
		changed=true
	host.apartment_rent_state["next_due"]=due
	return changed

func _update_house_payment() -> bool:
	var state:=house_state()
	if not bool(state.get("relocated",false)):return false
	var agreement:=str(state.get("agreement",""))
	if bool(state.get("owned",false)) or agreement=="purchase":return false
	if agreement not in ["rent","lease"]:return false
	var due:=int(state.get("next_due",host.game_day+7))
	if due<=0:due=host.game_day+7
	var changed:=false
	while host.game_day>=due:
		if house_balance()==0:state["first_unpaid"]=due
		var amount:=600 if agreement=="rent" else 1000
		if agreement=="lease":
			var remaining:=maxi(0,int(state.get("ownership_total",18500))-int(state.get("equity_paid",0))-house_balance())
			amount=mini(amount,remaining)
		if amount>0:state["balance"]=house_balance()+amount
		due+=7
		changed=true
		if agreement=="lease" and amount<=0:break
	state["next_due"]=due
	return changed

func _apartment_overdue() -> bool:
	if apartment_balance()<=0:return false
	var first:int=int(host.apartment_rent_state.get("first_unpaid",host.game_day))
	return host.game_day>first+3

func _house_overdue() -> bool:
	if house_balance()<=0:return false
	var first:int=int(house_state().get("first_unpaid",host.game_day))
	return host.game_day>first+3

func update(_delta: float) -> void:
	crew.update(_delta)
	# Installed house tents and ventilation report changing plant conditions
	# even when the player isn't aiming at the panel or reopening a computer.
	grow_panel_poll_seconds+=_delta
	if grow_panel_poll_seconds>=0.5:
		grow_panel_poll_seconds=0.0
		if world!=null and world.house_controls!=null:world.house_controls.refresh_grow_panel()
	if not host.phone_open and not is_open():computer_context=""
	var changed:bool=_update_apartment_rent()
	changed=_update_house_payment() or changed
	if changed:host._save_game()
	if last_notice==host.game_day:return
	var apartment_due:int=apartment_balance()
	var house_due:int=house_balance()
	if apartment_due>0 or house_due>0:
		last_notice=host.game_day
		host.status_label.text="Property balances: Apartment $%d · House $%d. Manage them in Phone > Real Estate." % [apartment_due,house_due]
		return
	if apartment_lease_active():
		var apartment_next:int=int(host.apartment_rent_state.get("next_due",host.game_day+14))
		if apartment_next-host.game_day<=3:
			last_notice=host.game_day
			host.status_label.text="Apartment rent: $600 due on Day %d. Phone > Real Estate." % apartment_next
			return
	var state:=house_state()
	var house_next:int=int(state.get("next_due",0))
	if bool(state.get("relocated",false)) and house_next>0 and house_next-host.game_day<=2 and not bool(state.get("owned",false)):
		last_notice=host.game_day
		host.status_label.text="House payment due on Day %d. Phone > Real Estate." % house_next

func pay_apartment_rent() -> void:
	var amount:=apartment_balance()
	if amount<=0 or host.cash<amount:return
	host.cash-=amount
	host.apartment_rent_state["balance"]=0
	host.apartment_rent_state["first_unpaid"]=0
	host._record_daily_expense("Apartment rent",amount)
	host._update_cash_ui();host._save_game();host._refresh_phone()
	host.status_label.text="Apartment balance paid: $%d." % amount

func pay_house_payment() -> void:
	var amount:=house_balance()
	if amount<=0 or host.cash<amount:return
	var state:=house_state()
	host.cash-=amount
	state["balance"]=0
	state["first_unpaid"]=0
	if str(state.get("agreement",""))=="lease":
		state["equity_paid"]=mini(int(state.get("ownership_total",18500)),int(state.get("equity_paid",0))+amount)
		if int(state["equity_paid"])>=int(state.get("ownership_total",18500)):
			state["owned"]=true
			state["next_due"]=0
	host._record_daily_expense("House payment",amount)
	host._update_cash_ui();host._save_game();host._refresh_phone()
	host.status_label.text="House balance paid: $%d." % amount

func pay_rent() -> void:
	if active_property()=="house" and house_balance()>0:pay_house_payment()
	elif apartment_balance()>0:pay_apartment_rent()

func _has_alternate_property() -> bool:
	return bool(house_state().get("acquired",false)) and bool(house_state().get("relocated",false))

func _dict_total(values:Dictionary) -> int:
	var total_value:int=0
	for value in values.values():total_value+=maxi(0,int(value))
	return total_value

func _apartment_has_live_plants() -> bool:
	for slot_variant in host.plant_slots:
		if slot_variant is Dictionary and int((slot_variant as Dictionary).get("stage",-1))>=0:return true
	return false

func _apartment_paid_equipment_labels() -> Array[String]:
	if host.inventory_system!=null and host.inventory_system.furniture!=null:return []
	var items:Array[String]=[]
	if host.grow_tent_count>1:items.append("Grow Tent Slots II-III")
	if host.tent_level>1:items.append("Grow Tent upgrade")
	if host.bagging_level>1:items.append("Bagging Bench upgrades")
	if host.storage_level>1:items.append("Storage / Vault / Hidden Stash upgrades")
	if host.supply_shelf_level>1:items.append("Grow Supply Shelf upgrades")
	if host.dealer_locker_level>0:items.append("Dealer Storage")
	if host.ventilation_installed:items.append("Grow Room Ventilation")
	if host.auto_water_unlocked:items.append("Auto Water Kit")
	return items

func _apartment_contents_blockers() -> Array[String]:
	var blockers:Array[String]=[]
	if host.inventory_system!=null and host.inventory_system.property_has_items("apartment"):
		blockers.append("Empty the apartment containers before releasing its lease.")
	if str(host.location_state.get("operation_contents_property","apartment"))=="apartment":
		if _apartment_has_live_plants():blockers.append("Harvest or move all live plants.")
		var pipeline:int=_dict_total(host.untrimmed_inventory)+_dict_total(host.trimmed_inventory)+_dict_total(host.bagged_inventory)
		if pipeline>0:blockers.append("Move %dg of packing-bench product." % pipeline)
		var stored:int=host._total_stored_stock()
		if stored>0:blockers.append("Move %dg of sellable storage stock." % stored)
		var dealer_stock:int=host._dealer_locker_total()
		if dealer_stock>0:blockers.append("Move %dg from Dealer Storage." % dealer_stock)
		var seed_total:int=host._total_seed_inventory()
		if seed_total>0:blockers.append("Move %d stored seeds." % seed_total)
		if host.fertilizer_units>0:blockers.append("Move %d fertilizer." % host.fertilizer_units)
	var apartment_deliveries:int=0
	for delivery_variant in host.location_state.get("deliveries",{}).values():
		if delivery_variant is Dictionary and str((delivery_variant as Dictionary).get("property",""))=="apartment":apartment_deliveries+=1
	if apartment_deliveries>0:blockers.append("Install or redirect %d paid apartment deliver%s." % [apartment_deliveries,"y" if apartment_deliveries==1 else "ies"])
	return blockers

func apartment_release_blockers() -> Array[String]:
	var blockers:Array[String]=[]
	if host.inventory_system!=null and host.inventory_system.furniture!=null and host.inventory_system.furniture.model.property_has_furniture("apartment"):blockers.append("Pack your placed apartment furniture first.")
	if not _has_alternate_property():blockers.append("Acquire and move into another property first.")
	if not apartment_lease_active():return blockers
	if world._indoors(host.camera.position):blockers.append("Leave the apartment before releasing its lease.")
	blockers.append_array(_apartment_contents_blockers())
	var paid_assets:=_apartment_paid_equipment_labels()
	if not paid_assets.is_empty() and str(host.location_state.get("operation_assets_property","apartment"))=="apartment":
		blockers.append("Pack paid apartment equipment into Property Storage first.")
	return blockers

func pack_apartment_paid_assets() -> void:
	if host.inventory_system!=null and host.inventory_system.furniture!=null:host.inventory_system.furniture.open();return
	if not apartment_lease_active() or not _has_alternate_property():return
	var blockers:=_apartment_contents_blockers()
	if not blockers.is_empty():
		host.status_label.text="Paid equipment cannot be packed yet: "+str(blockers[0])
		host._refresh_phone()
		return
	var assets:=_apartment_paid_equipment_labels()
	var stored_assets:Array=host.location_state.get("property_storage",[])
	for asset in assets:
		if not stored_assets.has(asset):stored_assets.append(asset)
	host.location_state["property_storage"]=stored_assets
	host.location_state["operation_assets_property"]="storage"
	host._save_game()
	host._refresh_phone()
	host.status_label.text="Paid apartment equipment packed into Property Storage. Nothing you purchased was deleted."

func install_property_storage_at(property:String) -> void:
	if host.inventory_system!=null and host.inventory_system.furniture!=null:host.inventory_system.furniture.open();return
	if property=="house" and not _property_controlled("house"):return
	if property=="apartment" and not apartment_lease_active():return
	var stored_assets:Array=host.location_state.get("property_storage",[])
	if stored_assets.is_empty():return
	host.location_state["operation_assets_property"]=property
	host.location_state["property_storage"]=[]
	host._save_game()
	host._refresh_phone()
	host.status_label.text="Owned equipment installed at the %s. Placement can be refined in Furnishing mode." % property

func reacquire_apartment() -> void:
	if apartment_lease_active():return
	var old_debt:int=apartment_balance()+property_utility_due("apartment","power")+property_utility_due("apartment","water")
	if old_debt>0:
		host.status_label.text="Clear the apartment's old rent and utility balances before starting a new lease."
		return
	if host.cash<APARTMENT_REACQUIRE_COST:
		host.status_label.text="You need $%d to start a new apartment lease." % APARTMENT_REACQUIRE_COST
		return
	host.cash-=APARTMENT_REACQUIRE_COST
	host._record_daily_expense("Apartment lease restart",APARTMENT_REACQUIRE_COST)
	host.apartment_rent_state["lease_active"]=true
	host.apartment_rent_state["next_due"]=host.game_day+14
	host.apartment_rent_state["first_unpaid"]=0
	host.apartment_rent_state.erase("released_day")
	house_state()["keep_apartment"]=true
	host._update_cash_ui();host._save_game();host._refresh_phone()
	host.status_label.text="Apartment lease restored. Door and computer access are active again."

func request_apartment_release() -> void:
	if not apartment_lease_active():return
	var blockers:=apartment_release_blockers()
	if not blockers.is_empty():
		host.status_label.text="Apartment lease cannot be released yet: "+str(blockers[0])
		apartment_release_confirm=false
		host._refresh_phone()
		return
	apartment_release_confirm=true
	host._refresh_phone()

func cancel_apartment_release() -> void:
	apartment_release_confirm=false
	host._refresh_phone()

func confirm_apartment_release() -> void:
	if not apartment_lease_active():return
	var blockers:=apartment_release_blockers()
	if not blockers.is_empty():
		apartment_release_confirm=false
		host.status_label.text="Apartment lease cannot be released yet: "+str(blockers[0])
		host._refresh_phone()
		return
	if world.door_open:world.toggle_door()
	host.apartment_rent_state["lease_active"]=false
	host.apartment_rent_state["released_day"]=host.game_day
	host.apartment_rent_state["next_due"]=0
	house_state()["keep_apartment"]=false
	apartment_release_confirm=false
	host._save_game()
	host._refresh_phone()
	host.status_label.text="Apartment lease released. No new apartment rent will accrue; any existing apartment balance remains due."

func _property_label(parent:VBoxContainer,text_value:String,size:int=18) -> Label:
	var item:=Label.new()
	item.text=text_value
	item.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	item.add_theme_font_size_override("font_size",mini(size,16))
	parent.add_child(item)
	return item

func _property_button(parent:VBoxContainer,text_value:String,callback:Callable,disabled:bool=false) -> Button:
	return preload("res://scripts/phone_visuals.gd").row(parent,text_value,callback,disabled)

func property_activity(property_id:String) -> String:
	var inventory=host.inventory_system
	var model=inventory.furniture.model
	var furniture_count:=0
	var growing:=0
	for item in model.state.items.values():
		if item.get("property","")!=property_id:continue
		furniture_count+=1
		for slot in item.get("slots",[]):
			if int(slot)<host.plant_slots.size() and int(host.plant_slots[int(slot)].get("stage",-1))>=0:growing+=1
	var working:bool=host.packing_employee_hired and host.packing_employee_active and inventory.worker_property()==property_id
	return ("RUNNING" if working or growing>0 else "IDLE")+" · %d furniture items · %d planted pots\nProduction worker: %s" % [furniture_count,growing,"working here" if working else ("assigned here / paused" if host.packing_employee_hired and inventory.worker_property()==property_id else "none assigned")]

func real_estate_ui(parent:VBoxContainer) -> void:
	portfolio_ui(parent)
	return


# One property management hub, using existing worker, utility and inventory records.
# UI focus must never change the player's physical property or their save namespace.
func portfolio_reset() -> void:
	portfolio_property=""
	portfolio_page="overview"
	portfolio_employee=""
	portfolio_fire_confirm=""

func portfolio_select(property:String) -> void:
	if property not in ["apartment","house"] or not _property_controlled(property):return
	portfolio_property=property
	portfolio_page="overview"
	portfolio_employee=""
	portfolio_fire_confirm=""

func portfolio_phone_back(app:String) -> bool:
	if app=="employees" and portfolio_page=="dealer_stats":
		portfolio_page="overview"
		host._refresh_phone()
		return true
	if app=="employees" and not portfolio_property.is_empty() and not portfolio_employee.is_empty():
		portfolio_employee=""
		portfolio_fire_confirm=""
		host._refresh_phone()
		return true
	if app in ["employees","products"] and not portfolio_property.is_empty():
		host._open_phone_app("realestate")
		return true
	if app=="realestate" and (not portfolio_property.is_empty() or portfolio_page=="payments"):
		if portfolio_page!="overview":portfolio_page="overview"
		else:portfolio_reset()
		host._refresh_phone()
		return true
	return false

func portfolio_page_open(next_page:String) -> void:
	if portfolio_property.is_empty() or not _property_controlled(portfolio_property):return
	portfolio_page=next_page
	host._refresh_phone()

func portfolio_app_open(app:String) -> void:
	if portfolio_property.is_empty() or not _property_controlled(portfolio_property):return
	portfolio_employee=""
	portfolio_fire_confirm=""
	host._open_phone_app(app)

func portfolio_name(property:String) -> String:
	return "Starter Apartment" if property=="apartment" else "Maple Flats House"

func portfolio_on_site(property:String) -> bool:
	return property==active_property() and not placement_room(property,host.camera.global_position).is_empty()

func portfolio_furniture() -> void:
	if portfolio_property.is_empty() or not _property_controlled(portfolio_property):return
	if not portfolio_on_site(portfolio_property):
		host.status_label.text="Visit "+portfolio_name(portfolio_property)+" to arrange furniture."
		return
	host.inventory_system.furniture.open_property(portfolio_property)

func portfolio_ui(parent:VBoxContainer) -> void:
	if portfolio_property.is_empty() or not _property_controlled(portfolio_property):
		if portfolio_page=="payments":
			property_bills_ui(parent)
			if not apartment_lease_active():
				var old_debt:int=apartment_balance()+property_utility_due("apartment","power")+property_utility_due("apartment","water")
				_property_label(parent,"Released apartment: clear all old balances before renting it again. None of its former stock or furniture will be automatically restored.",16)
				_property_button(parent,"RENT STARTER APARTMENT AGAIN · $%d" % APARTMENT_REACQUIRE_COST,reacquire_apartment,old_debt>0 or host.cash<APARTMENT_REACQUIRE_COST)
			_property_button(parent,"BACK TO PROPERTIES",portfolio_back_pressed)
			return
		portfolio_reset()
		_property_label(parent,"Your people, stock and bills. Organized by property.",16)
		var utility_due:int=utility_total_due()
		_property_label(parent,"ALL PROPERTIES · ELECTRIC & WATER\nTotal utilities owed: $%d" % utility_due,19)
		if utility_due>0:
			_property_button(parent,"PAY ALL UTILITIES · $%d" % utility_due,pay_all_portfolio_utilities,host.cash<utility_due)
		for property in ["apartment","house"]:
			if not _property_controlled(property):
				continue
			var due:Dictionary=utility_state(property)
			var debt:int=int(due.get("power_due",0))+int(due.get("water_due",0))
			var staff:int=computer_staff_names(property).size()
			var summary:String="%s\n%d assigned crew · $%d utilities due" % [portfolio_name(property),staff,debt]
			_property_button(parent,summary,portfolio_open_property.bind(property))
		if not apartment_lease_active():
			_property_label(parent,"Starter Apartment lease released. Past-due balances and reacquisition remain available in Property Payments.",15)
		if not bool(house_state().get("acquired",false)):
			_property_label(parent,"More properties unlock as you progress.",15)
		_property_button(parent,"PROPERTY AGREEMENTS & RELEASED LEASES",portfolio_legacy_payments)
		return
	var property:String=portfolio_property
	var banner:=PanelContainer.new()
	banner.add_theme_stylebox_override("panel",preload("res://scripts/phone_visuals.gd").box(Color("20392b"),20))
	parent.add_child(banner)
	var overview:=VBoxContainer.new();overview.add_theme_constant_override("separation",8);banner.add_child(overview)
	_property_label(overview,portfolio_name(property),22)
	_property_label(overview,"%d assigned crew · $%d utilities due" % [computer_staff_names(property).size(),property_utility_due(property,"power")+property_utility_due(property,"water")],14)
	_property_label(overview,property_activity(property),12)
	if portfolio_page=="overview":
		_property_label(parent,"Shop: "+crew.shop.status(property),17)
		_property_button(parent,"SHOP OPERATIONS · Open, close & lay low",portfolio_page_open.bind("operations"))
		_property_button(parent,"EMPLOYEES · Assigned crew & dealer stats",portfolio_app_open.bind("employees"))
		_property_button(parent,"STOCK · Products, listings & inventory",portfolio_app_open.bind("products"))
		_property_button(parent,"ARRANGE FURNITURE"+("" if portfolio_on_site(property) else " · VISIT PROPERTY"),portfolio_furniture,not portfolio_on_site(property))
		_property_button(parent,"BILLS · Water, electricity & agreement",portfolio_page_open.bind("bills"))
		_property_button(parent,"CREW PAY · Wages & dealer balances",host._open_phone_app.bind("bills"))
		_property_button(parent,"PROPERTY AGREEMENT · Rent, ownership & access",portfolio_page_open.bind("agreement"))
		_property_label(parent,"Staff can be hired by texting Contacts. Furniture can only be rearranged while you are physically inside this property.",15)
	elif portfolio_page=="operations":
		crew.shop.render(parent,property)
	elif portfolio_page=="bills":
		var bill:Dictionary=utility_state(property)
		_property_label(parent,"ELECTRICITY  $%d\nWATER  $%d" % [int(bill.get("power_due",0)),int(bill.get("water_due",0))],19)
		if int(bill.get("power_due",0))>0:
			_property_button(parent,"PAY ELECTRIC · $%d" % int(bill.get("power_due",0)),pay_property_utility.bind(property,"power"),host.cash<int(bill.get("power_due",0)))
		if int(bill.get("water_due",0))>0:
			_property_button(parent,"PAY WATER · $%d" % int(bill.get("water_due",0)),pay_property_utility.bind(property,"water"),host.cash<int(bill.get("water_due",0)))
		_property_label(parent,"Today so far: $%d electric · $%d water. Charges are calculated using this property's own equipment and usage." % [int(ceil(float(bill.get("today_power",0.0)))),int(ceil(float(bill.get("today_water",0.0))))],15)
		var rent_due:int=apartment_balance() if property=="apartment" else house_balance()
		_property_label(parent,"Rent / Agreement owed: $%d" % rent_due,17)
		if rent_due>0:
			_property_button(parent,"PAY AGREEMENT · $%d" % rent_due,pay_apartment_rent if property=="apartment" else pay_house_payment,host.cash<rent_due)
	elif portfolio_page=="agreement":
		if property=="apartment":
			_property_label(parent,"APARTMENT · "+("LEASE ACTIVE" if apartment_lease_active() else "LEASE RELEASED"),19)
			_property_label(parent,"Rent: $600 every 14 game days · Next due Day %d\nExisting balance: $%d" % [int(host.apartment_rent_state.get("next_due",host.game_day+14)),apartment_balance()],16)
			if apartment_lease_active() and bool(house_state().get("relocated",false)):
				var blockers:Array[String]=apartment_release_blockers()
				if not blockers.is_empty():
					_property_label(parent,"CANNOT RELEASE LEASE\n" + "\n".join(PackedStringArray(blockers)),16)
				elif apartment_release_confirm:
					_property_label(parent,"Release the apartment? Future rent stops and apartment access locks. Unpaid balances remain.",16)
					_property_button(parent,"CONFIRM RELEASE LEASE",confirm_apartment_release)
					_property_button(parent,"CANCEL",cancel_apartment_release)
				else:
					_property_button(parent,"RELEASE APARTMENT LEASE",request_apartment_release)
		else:
			var h:Dictionary=house_state()
			var agreement:String=str(h.get("agreement",""))
			_property_label(parent,"HOUSE · "+({"rent":"RENT","lease":"LEASE TO OWN","purchase":"OWNED"}.get(agreement,"ACQUIRED")),19)
			_property_label(parent,"Outstanding: $%d · Next payment: Day %d" % [house_balance(),int(h.get("next_due",0))],16)
			if agreement=="lease":
				_property_label(parent,"Equity paid: $%d / $%d" % [int(h.get("equity_paid",0)),int(h.get("ownership_total",18500))],16)
	_property_button(parent,"BACK TO "+("PROPERTY LIST" if portfolio_page=="overview" else "PROPERTY OVERVIEW"),portfolio_back_pressed)

func portfolio_legacy_payments() -> void:
	portfolio_reset()
	portfolio_page="payments"
	host._refresh_phone()

func portfolio_back_pressed() -> void:
	if portfolio_page=="overview" or portfolio_page=="payments":portfolio_reset()
	else:portfolio_page="overview"
	host._refresh_phone()

func portfolio_open_property(property:String) -> void:
	portfolio_select(property)
	host._refresh_phone()

func pay_all_portfolio_utilities() -> void:
	var amount:int=utility_total_due()
	if amount<=0 or host.cash<amount:return
	# One deduction with separate per-property records. Past debts remain payable
	# after a property is released; payment is not an ownership transfer.
	host.cash-=amount
	for property in ["apartment","house"]:
		var ledger:Dictionary=utility_state(property)
		for kind in ["power","water"]:
			var key:String=kind+"_due"
			var paid:int=maxi(0,int(ledger.get(key,0)))
			if paid<=0:continue
			ledger[key]=0
			host._record_daily_expense(property.capitalize()+(" electricity" if kind=="power" else " water"),paid)
			host._increment_advancement_stat("power_bills_paid" if kind=="power" else "water_bills_paid")
			if property=="house":host.location_state["house_bills_paid"]=int(host.location_state.get("house_bills_paid",0))+1
	_sync_legacy_utility_totals()
	host._update_cash_ui()
	host._save_game()
	host.status_label.text="All property utility bills paid: $%d." % amount
	host._refresh_phone()

func portfolio_stock_ui(parent:VBoxContainer) -> void:
	if portfolio_property.is_empty() or not _property_controlled(portfolio_property):return
	_property_label(parent,portfolio_name(portfolio_property)+" · STOCK",20)
	_property_label(parent,"Only this property's inventory and listings are shown. Stock at other properties stays separate.",15)
	if host.inventory_system!=null:
		host.inventory_system.at_property(portfolio_property,host._build_products_local)
	else:
		_property_label(parent,"Stock unavailable.",16)

func portfolio_staff_duty(name:String) -> bool:
	var duty:Dictionary=host.location_state.get("staff_duty",{})
	return bool(duty.get(name,true))

func portfolio_set_duty(name:String) -> void:
	if portfolio_property.is_empty() or not computer_staff_names(portfolio_property).has(name):return
	var job:String=crew.role(name)
	if job=="production":
		host._toggle_packing_employee()
	elif job=="dealer":
		var was_on:bool=portfolio_staff_duty(name)
		if not was_on and not host.dealers_active:
			if not host._staff_duty_blocker("dealer").is_empty():return
			host._toggle_dealers()
		var duty:Dictionary=host.location_state.get("staff_duty",{})
		if not was_on and (host.dealer_arrested or host.heat>=75.0 or host.dealer_balance_due>0):return
		duty[name]=not was_on
		host.location_state["staff_duty"]=duty
		host._save_game()
	host._refresh_phone()

func portfolio_transfer(name:String,target:String) -> void:
	if portfolio_property.is_empty() or not computer_staff_names(portfolio_property).has(name):return
	if not _property_controlled(target) or name=="Dealer Team":return
	crew.assign(name,target)
	portfolio_employee=""
	host._refresh_phone()

func portfolio_fire(name:String) -> void:
	if portfolio_employee!=name or portfolio_fire_confirm!=name:return
	if crew.role(name)=="dealer" and host.dealer_arrested:return
	if crew.role(name)=="production" and host.production_worker_arrested:return
	portfolio_fire_confirm=""
	if name.begins_with("Hired Dealer "):
		var slot:int=int(name.trim_prefix("Hired Dealer "))-1
		if slot<0 or slot>=host.dealer_count:return
		var duty:Dictionary=host.location_state.get("staff_duty",{})
		var assignments:Dictionary=host.location_state.get("staff_assignments",{})
		var stats:Dictionary=host.location_state.get("hired_dealer_stats",{})
		for idx in range(slot+1,host.dealer_count):
			var old_name:String="Hired Dealer %d" % (idx+1)
			var new_name:String="Hired Dealer %d" % idx
			duty[new_name]=bool(duty.get(old_name,true))
			assignments[new_name]=str(assignments.get(old_name,"apartment"))
			stats[new_name]=stats.get(old_name,{}).duplicate(true)
		var last:String="Hired Dealer %d" % host.dealer_count
		duty.erase(last);assignments.erase(last);stats.erase(last)
		host.location_state["staff_duty"]=duty
		host.location_state["staff_assignments"]=assignments
		host.location_state["hired_dealer_stats"]=stats
		host._fire_generic_dealer()
	elif not host._friend_staff_role(name).is_empty():
		host._release_friend_staff(name)
	elif crew.role(name)=="production":
		host._fire_packing_employee()
	portfolio_employee=""
	host._save_game()
	host._refresh_phone()

func portfolio_employee_open(name:String) -> void:
	if not computer_staff_names(portfolio_property).has(name):return
	portfolio_employee=name
	portfolio_fire_confirm=""
	host._refresh_phone()

func portfolio_employees_ui(parent:VBoxContainer) -> void:
	if portfolio_property.is_empty() or not _property_controlled(portfolio_property):return
	if portfolio_page=="dealer_stats":
		portfolio_dealer_stats_ui(parent)
		return
	var prop:String=portfolio_property
	_property_label(parent,portfolio_name(prop)+" · EMPLOYEES",20)
	if portfolio_employee.is_empty():
		_property_label(parent,"Hire by texting a recruit in Contacts. Select a worker to see their duties, performance, transfer and firing options.",15)
		var staff:Array[String]=computer_staff_names(prop)
		for worker_name in staff:
			var job:String=crew.role(worker_name)
			var working:bool=(host.dealers_active and portfolio_staff_duty(worker_name)) if job=="dealer" else host.packing_employee_active
			_property_button(parent,worker_name+" · "+job.capitalize()+"\n"+("ON DUTY" if working else "HOME"),portfolio_employee_open.bind(worker_name))
		if staff.is_empty():_property_label(parent,"No workers assigned here yet.",16)
		_property_button(parent,"CONTACTS · HIRE BY TEXT",host._open_phone_app.bind("clients"))
		return
	var name:String=portfolio_employee
	if not computer_staff_names(prop).has(name):
		portfolio_employee=""
		portfolio_employees_ui(parent)
		return
	var job:String=crew.role(name)
	_property_label(parent,name+" · "+job.capitalize(),20)
	var working:bool=(host.dealers_active and portfolio_staff_duty(name)) if job=="dealer" else host.packing_employee_active
	_property_label(parent,"Assigned: "+portfolio_name(prop)+"\nStatus: "+("LAYING LOW" if working and crew.shop.laying_low(prop) else ("ON DUTY" if working else "HOME")),16)
	if job=="dealer":
		_property_button(parent,"DEALER STATS · VIEW DEALS & COMMISSION",portfolio_page_dealer_stats)
		if name!="Dealer Team":
			_property_button(parent,"HANDLE APARTMENT DOOR" if crew.manager()!=name else "RETURN TO STREET DEALS",crew.assign_manager.bind(name) if crew.manager()!=name else crew.return_to_street.bind(name),prop!="apartment")
	elif job=="production":
		_property_label(parent,"Tasks today: %d\nCurrent task: %s" % [host.production_worker_tasks_today,host.production_worker_last_action],16)
		_property_button(parent,"AUTO PLANT: "+("ON" if host.production_worker_auto_plant else "OFF"),host._toggle_production_worker_auto_plant)
	var reason:String=host._staff_duty_blocker(job)
	_property_button(parent,"SEND HOME" if working else "PUT ON DUTY",portfolio_set_duty.bind(name),not working and not reason.is_empty())
	if not working and not reason.is_empty():_property_label(parent,"Cannot start work: "+reason,15)
	var other:String="house" if prop=="apartment" else "apartment"
	if _property_controlled(other):
		_property_button(parent,"TRANSFER TO "+portfolio_name(other),portfolio_transfer.bind(name,other))
	if portfolio_fire_confirm==name:
		_property_label(parent,"Confirm firing "+name+"? Sales history stays recorded.",16)
		_property_button(parent,"CONFIRM FIRE",portfolio_fire.bind(name))
		_property_button(parent,"CANCEL",portfolio_cancel_fire)
	else:
		_property_button(parent,"FIRE "+name.to_upper(),portfolio_request_fire.bind(name))
	_property_button(parent,"BACK TO EMPLOYEES",portfolio_employee_back)

func portfolio_employee_back() -> void:
	portfolio_employee=""
	portfolio_fire_confirm=""
	host._refresh_phone()

func portfolio_request_fire(name:String) -> void:
	portfolio_fire_confirm=name
	host._refresh_phone()

func portfolio_cancel_fire() -> void:
	portfolio_fire_confirm=""
	host._refresh_phone()

func portfolio_page_dealer_stats() -> void:
	if portfolio_employee.is_empty() or crew.role(portfolio_employee)!="dealer":return
	portfolio_page="dealer_stats"
	host._refresh_phone()

func record_dealer_sale(name:String,client:String,product:String,grams:int,gross:int,commission:int) -> void:
	if not host.location_state.get("dealer_sale_history",{}) is Dictionary:host.location_state["dealer_sale_history"]={}
	if not host.location_state.has("dealer_sale_history"):host.location_state["dealer_sale_history"]={}
	var history:Dictionary=host.location_state.dealer_sale_history
	var rows:Array=history.get(name,[])
	rows.append({"day":host.game_day,"time":host._format_game_clock(),"property":crew.assignment(name),"client":client,"product":product,"grams":grams,"gross":gross,"commission":commission})
	while rows.size()>100:rows.pop_front()
	history[name]=rows

func portfolio_dealer_stats_ui(parent:VBoxContainer) -> void:
	var name:String=portfolio_employee
	var stats:Dictionary={}
	if name.begins_with("Hired Dealer "):stats=host.location_state.get("hired_dealer_stats",{}).get(name,{})
	else:stats=host.friend_dealer_stats.get(name,{})
	_property_label(parent,name+" · DEALER STATS",22)
	_property_label(parent,"TODAY\nDeals: %d · Grams: %dg\nGross sales: $%d · Commission: $%d" % [int(stats.get("today_sales",0)),int(stats.get("today_grams",0)),int(stats.get("today_gross",0)),int(stats.get("today_commission",0))],18)
	_property_label(parent,"LIFETIME\nDeals: %d · Grams: %dg\nGross sales: $%d · Commission earned: $%d" % [int(stats.get("sales",0)),int(stats.get("grams",0)),int(stats.get("gross",0)),int(stats.get("commission_earned",0))],18)
	_property_label(parent,"RECENT SALES · latest 100",20)
	var rows:Array=host.location_state.get("dealer_sale_history",{}).get(name,[])
	if rows.is_empty():_property_label(parent,"New sales will appear here. Your existing totals are preserved.",16)
	for index in range(rows.size()-1,-1,-1):
		var sale:Dictionary=rows[index]
		_property_label(parent,"Day %d · %s · %s\n%s · %dg %s\n$%d gross · $%d commission · $%d net" % [int(sale.day),str(sale.time),str(sale.property).capitalize(),str(sale.client),int(sale.grams),str(sale.product),int(sale.gross),int(sale.commission),int(sale.gross)-int(sale.commission)],16)
	_property_button(parent,"BACK TO "+name.to_upper(),portfolio_dealer_stats_back)

func portfolio_dealer_stats_back() -> void:
	portfolio_page="overview"
	host._refresh_phone()

func _legacy_real_estate_ui(parent:VBoxContainer) -> void:
	_property_label(parent,"PROPERTY PORTFOLIO",24)
	utility_bills_ui(parent)

	var apartment_status:String="LEASE ACTIVE" if apartment_lease_active() else "LEASE RELEASED"
	var apartment_copy:String="APARTMENT · "+apartment_status
	if apartment_lease_active():
		apartment_copy+="\nRent: $600 every 14 game days · Next: Day %d" % int(host.apartment_rent_state.get("next_due",host.game_day+14))
	else:
		apartment_copy+="\nNo future apartment rent accrues."
	apartment_copy+="\nOutstanding balance: $%d" % apartment_balance()
	apartment_copy+="\n"+property_activity("apartment")
	_property_label(parent,apartment_copy,19)
	if apartment_lease_active():_property_button(parent,"APARTMENT · FURNITURE / PICK UP / PLACE",host.inventory_system.furniture.open_property.bind("apartment"))
	if apartment_balance()>0:
		_property_button(parent,"PAY APARTMENT BALANCE · $%d" % apartment_balance(),pay_apartment_rent,host.cash<apartment_balance())
	if apartment_lease_active() and bool(house_state().get("relocated",false)):
		var blockers:=apartment_release_blockers()
		if not blockers.is_empty():
			var blocker_text:=_property_label(parent,"LEASE RELEASE SAFETY\n"+"\n".join(PackedStringArray(blockers)),16)
			blocker_text.modulate=Color("c9a979")
			_property_button(parent,"RELEASE APARTMENT LEASE · BLOCKED",request_apartment_release,true)
		elif apartment_release_confirm:
			var warning:=_property_label(parent,"RELEASE APARTMENT LEASE?\nFuture $600/14-day rent stops immediately. Any balance already owed remains due. Apartment access will be locked.",17)
			warning.modulate=Color("e6b38a")
			_property_button(parent,"CONFIRM RELEASE APARTMENT LEASE",confirm_apartment_release)
			_property_button(parent,"KEEP APARTMENT",cancel_apartment_release)
		else:
			_property_button(parent,"RELEASE APARTMENT LEASE…",request_apartment_release)

	if not apartment_lease_active():
		var old_debt:int=apartment_balance()+property_utility_due("apartment","power")+property_utility_due("apartment","water")
		if old_debt>0:
			_property_label(parent,"Clear the old apartment rent/electric/water balance ($%d) before renting this property again." % old_debt,16)
			_property_button(parent,"RENT APARTMENT AGAIN · $%d" % APARTMENT_REACQUIRE_COST,reacquire_apartment,true)
		else:
			_property_button(parent,"RENT APARTMENT AGAIN · $%d" % APARTMENT_REACQUIRE_COST,reacquire_apartment,host.cash<APARTMENT_REACQUIRE_COST)

	var state:=house_state()
	if not bool(state.get("acquired",false)):
		_property_label(parent,"HOUSE · NOT ACQUIRED\nComplete the Chapter 4 expansion requirements to unlock the property opportunity.",19)
	else:
		var agreement:=str(state.get("agreement",""))
		var house_copy:String="HOUSE · "+({"rent":"RENT","lease":"LEASE TO OWN","purchase":"OWNED"}.get(agreement,"ACQUIRED"))
		house_copy+="\n"+property_activity("house")
		if agreement=="rent":
			house_copy+="\n$600 every 7 game days · Next: Day %d" % int(state.get("next_due",0))
		elif agreement=="lease":
			house_copy+="\n$1000 every 7 game days · Next: Day %d\nEquity: $%d / $%d" % [int(state.get("next_due",0)),int(state.get("equity_paid",0)),int(state.get("ownership_total",18500))]
		else:
			house_copy+="\nNo recurring house payment."
		house_copy+="\nOutstanding balance: $%d" % house_balance()
		_property_label(parent,house_copy,19)
		_property_button(parent,"HOUSE · FURNITURE / PICK UP / PLACE",host.inventory_system.furniture.open_property.bind("house"))
		if house_balance()>0:
			_property_button(parent,"PAY HOUSE BALANCE · $%d" % house_balance(),pay_house_payment,host.cash<house_balance())

func property_bills_ui(parent:VBoxContainer) -> void:
	_property_label(parent,"PROPERTY PAYMENTS",22)
	if apartment_lease_active() or apartment_balance()>0:
		var apartment_line:String="APARTMENT · "+("LEASE ACTIVE" if apartment_lease_active() else "LEASE RELEASED")
		if apartment_lease_active():apartment_line+="\nRent: $600 every 14 game days · Next: Day %d" % int(host.apartment_rent_state.get("next_due",host.game_day+14))
		apartment_line+="\nRent balance: $%d" % apartment_balance()
		_property_label(parent,apartment_line,17)
		if apartment_balance()>0:_property_button(parent,"PAY APARTMENT RENT · $%d" % apartment_balance(),pay_apartment_rent,host.cash<apartment_balance())
	var state:=house_state()
	if bool(state.get("acquired",false)):
		var agreement:=str(state.get("agreement",""))
		var house_line:String="HOUSE · "+({"rent":"RENT","lease":"LEASE TO OWN","purchase":"OWNED"}.get(agreement,"ACQUIRED"))
		if agreement=="rent":house_line+="\n$600 every 7 game days · Next: Day %d" % int(state.get("next_due",0))
		elif agreement=="lease":house_line+="\n$1000 every 7 game days · Next: Day %d · Equity $%d / $%d" % [int(state.get("next_due",0)),int(state.get("equity_paid",0)),int(state.get("ownership_total",18500))]
		else:house_line+="\nNo recurring house payment."
		house_line+="\nHouse balance: $%d" % house_balance()
		_property_label(parent,house_line,17)
		if house_balance()>0:_property_button(parent,"PAY HOUSE BALANCE · $%d" % house_balance(),pay_house_payment,host.cash<house_balance())
	utility_bills_ui(parent)

func rent_ui(parent: VBoxContainer) -> void:
	property_bills_ui(parent)


func equipment_ui(parent: VBoxContainer) -> void:
	_property_label(parent,"Equipment is available to buy when you can afford it. There is no story goal required. Upgrade an empty owned item to its next tier, or buy a replacement.")
	_property_label(parent,"Furniture locks keep items fixed in place; they are not progression locks.",15)
	host.inventory_system.furniture.cart.toolbar(parent)
	_property_label(parent,"Owned equipment stays with you when packed. Upgrade an empty item, or buy and place a better replacement.")
	_property_button(parent,"MANAGE OWNED EQUIPMENT",host.inventory_system.furniture.open)
	_property_button(parent,"ORDER EQUIPMENT",func():host.inventory_system.furniture.shop("equipment"))
	_property_button(parent,"ORDER GROW TENTS",market_grow_tents)

func production() -> void:
	if computer_context not in ["apartment","house"] or not _property_controlled(computer_context):return
	if computer_context=="house":
		clear("HOUSE — PRODUCTION & POWER")
		ui.label("House equipment and utilities are separate from apartment switches.")
		var house_grow=world.house_controls.grow_snapshot()
		ui.label(world.house_controls.grow_summary())
		if int(house_grow.tents)>0:
			b("TURN "+("OFF" if bool(host.house_control_state.get("grow_lights",false)) else "ON")+" HOUSE TENT LIGHTS",toggle_computer_house_grow_lights)
		else:
			ui.label("No grow tents placed in the house. Purchase and place a tent in its grow room first.")
		if bool(house_grow.ventilation):
			b("TURN "+("OFF" if bool(house_grow.ventilation_on) else "ON")+" HOUSE VENTILATION",toggle_computer_house_ventilation)
		else:
			ui.label("VENTILATION NOT INSTALLED · Purchase and place a ventilation unit in the house grow room.")
		var house_utility:Dictionary=utility_state("house")
		ui.label("Power due: $%d · Water due: $%d" % [int(house_utility.get("power_due",0)),int(house_utility.get("water_due",0))])
		for room in ["living","packing","kitchen","bathroom","bedroom","cross_hall","grow"]:
			var active:bool=bool(host.house_control_state.get(room,true))
			b("HOUSE "+room.to_upper()+" LIGHT · "+("ON" if active else "OFF"),toggle_house_room.bind(room))
		b("BACK TO HOUSE OPERATIONS",manage.bind("operations"))
		return
	close();world.in_station=true
	world.walk_position=host.camera.position;world.walk_rotation=host.camera.rotation
	host._open_system_control_panel()
func toggle_computer_house_ventilation() -> void:
	if computer_context!="house" or not _property_controlled("house"):return
	world.house_controls.toggle_house_ventilation()
	production()
func toggle_computer_house_grow_lights() -> void:
	if computer_context!="house" or not _property_controlled("house"):return
	world.house_controls.toggle_house_grow_lights()
	production()
func toggle_house_room(room:String) -> void:
	if computer_context!="house" or not _property_controlled("house"):return
	host.house_control_state[room]=not bool(host.house_control_state.get(room,true))
	if world.house_controls.switches.has(room):world.house_controls._set_light(room,bool(host.house_control_state[room]))
	host._save_game()
	production()
func order_summary(parent: VBoxContainer) -> void:
	var note := Label.new()
	note.text="CENTRAL MARKET: %d seed(s), %d fertilizer ready for pickup.\nCARRIED: %d seed(s), %d fertilizer. Store carried supplies at the grow shelf using Add Stock." % [total(host.location_state.pickup_seeds),int(host.location_state.pickup_fertilizer),total(host.location_state.carried_seeds),int(host.location_state.carried_fertilizer)]
	note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;parent.add_child(note)

func order_dealer() -> void:
	if host.inventory_system!=null and host.inventory_system.furniture!=null:host.inventory_system.furniture.shop("equipment");return
	if target()!="market_checkout" or host.dealer_locker_level>=4 or rent_overdue():return
	var level: int=host.dealer_locker_level+1
	var name: String="Dealer Storage "+host._roman(level)
	var cost: int=host.DEALER_LOCKER_COST_BY_LEVEL[level]
	if host.cash<cost or host.location_state.deliveries.has(name):return
	host.cash-=cost;host._record_daily_expense("Dealer storage order",cost)
	host.location_state.deliveries[name]={"property":active_property(),"kind":"dealer","level":level,"paid":cost,"collected":false}
	host._update_cash_ui();host._save_game();equipment()

func refresh_management() -> bool:
	if rendering_management:return true
	if is_open() and not management_app.is_empty():
		manage(management_app)
		return true
	return false

func rent_overdue() -> bool:
	return _apartment_overdue() or _house_overdue()

func order_fertilizer() -> void:
	if host.tutorial_active or host.cash<45 or int(host.location_state.pickup_fertilizer)>45:return
	host.cash-=45;host.location_state.pickup_fertilizer+=5
	if host.inventory_system.guide!=null:host.inventory_system.guide.record("order_fertilizer")
	host._record_daily_expense("Supply orders",45);host._increment_advancement_stat("supplies_bought")
	host._update_cash_ui();host._save_game();host._refresh_phone()
	host.status_label.text="Fertilizer ready for pickup at Central Market."
func phone_supplies() -> void:
	host.inventory_system.furniture.cart.supplies(host.phone_list)

func format_management() -> void:
	for item in ui.body.find_children("*","Control",true,false):
		if item is Label or item is Button:
			item.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			item.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			item.custom_minimum_size.x=0
		if item is GridContainer and ui.panel.size.x<520:item.columns=1
