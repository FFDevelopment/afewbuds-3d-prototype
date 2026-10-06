extends SceneTree
var failures := 0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures+=1;push_error(message)
func run() -> void:
	var game: Node3D=load("res://prototype/apartment.tscn").instantiate();root.add_child(game);game.fp_player.set_physics_process(false);game.set_process(false);game.neighborhood.set_process(false)
	await process_frame
	game.session_paused=false;game.tutorial_active=false;game.daily_report_pending=false;game.customer_waiting=false
	for name in ["tutorial_panel","daily_report_panel","pause_overlay","sale_panel","grow_panel","plant_direct_panel","bagging_panel","storage_panel","dealer_storage_panel","supply_inventory_panel","system_control_panel","trim_panel","bag_minigame_panel","peephole_panel"]:
		var panel=game.get(name)
		if panel!=null:panel.hide()
	game.visit_timer.stop();game.cash=10000;game.grower_level=10
	var n: Node3D=game.neighborhood;var ops: RefCounted=n.location_ops
	game.camera.position=Vector3(-25,2.16,20)
	check(int(game.apartment_rent_state.next_due)==game.game_day+14 and ops.balance()==0,"Existing/new career starts with fourteen-day rent grace")
	var due: int=int(game.apartment_rent_state.next_due)
	game.game_day=due-1;ops.update(0);check(ops.balance()==0,"No early rent charge")
	game.game_day=due;ops.update(0);ops.update(0);check(ops.balance()==600 and int(game.apartment_rent_state.next_due)==due+14,"Rent accrues exactly once per due date")
	var cash: int=game.cash;ops.pay_rent();ops.pay_rent();check(game.cash==cash-600 and ops.balance()==0,"Rent payment cannot double-charge")
	game.game_day=due+14;ops.update(0);check(ops.balance()==600,"Second fourteen-day cycle")
	var seed: String=game.SEED_ORDER[0];var owned: int=int(game.seed_inventory.get(seed,0));cash=game.cash
	game._buy_seed(seed)
	check(int(game.seed_inventory.get(seed,0))==owned and int(game.location_state.pickup_seeds.get(seed,0))==1,"Phone seed order waits at market")
	check(game.cash==cash-int(game.seed_catalog[seed].cost),"Seed order charges once")
	ops.pickup();check(int(game.location_state.pickup_seeds.get(seed,0))==1,"Remote pickup rejected")
	game.camera.position=Vector3(14,1.64,5);game.camera.look_at(ops.CHECKOUT)
	check(ops.target()=="market_checkout","Checkout reachable")
	ops.pickup();check(int(game.location_state.carried_seeds.get(seed,0))==1 and int(game.seed_inventory.get(seed,0))==owned,"Pickup goes to carried inventory")
	var fert: int=game.fertilizer_units;cash=game.cash;ops.fertilizer()
	check(game.fertilizer_units==fert and int(game.location_state.carried_fertilizer)==5 and game.cash==cash-45,"Market fertilizer carried, not auto-delivered")
	cash=game.cash;ops.order_fertilizer();check(game.cash==cash-45 and game.fertilizer_units==fert and game.location_state.pickup_fertilizer==5,"Phone fertilizer waits at market after one charge")
	var upgrade := "Grow Supply Shelf II";cash=game.cash;ops.order_equipment(upgrade)
	check(game.supply_shelf_level==1 and game.location_state.deliveries.has(upgrade),"Paid equipment waits for installation")
	check(game.cash==cash-int(game.supply_catalog[upgrade].cost),"Equipment charged once")
	ops.order_equipment(upgrade);check(game.cash==cash-int(game.supply_catalog[upgrade].cost),"Duplicate equipment order rejected")
	var dealer_level: int=game.dealer_locker_level
	ops.order_dealer()
	var dealer_name: String="Dealer Storage "+game._roman(dealer_level+1)
	check(game.dealer_locker_level==dealer_level and game.location_state.deliveries.has(dealer_name),"Dealer storage waits for installation")
	game.camera.position=Vector3(3,1.64,4.35);game.camera.look_at(ops.APT_PC)
	check(ops.target()=="apartment_computer","Apartment computer reachable")
	cash=game.cash;ops.install(upgrade)
	check(game.supply_shelf_level==2 and not game.location_state.deliveries.has(upgrade) and game.cash==cash,"Computer installs paid equipment without second charge")
	cash=game.cash;ops.install(dealer_name)
	check(game.dealer_locker_level==dealer_level+1 and game.cash==cash,"Dealer storage installs without double charge")
	ops.deposit();check(int(game.seed_inventory.get(seed,0))==owned+1 and game.fertilizer_units==fert+5,"Supplies deposited at active apartment")
	ops.deposit();check(int(game.seed_inventory.get(seed,0))==owned+1,"Deposit cannot duplicate seeds")
	game.location_state.carried_seeds[seed]=2
	game.seed_inventory[seed]=game._supply_seed_capacity()
	ops.deposit();check(int(game.location_state.carried_seeds[seed])==2,"Full shelf leaves carried seeds intact")
	game.cash=0;ops.pay_rent();check(ops.balance()==600,"Insufficient cash does not erase rent")
	ops.close();game._save_game()
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_PATH))
	check(data.has("location_state") and data.has("apartment_rent_state"),"Commerce and rent saved with career")
	game.location_state={};game.apartment_rent_state={};game._load_game()
	check(ops.balance()==600 and game.location_state.has("carried_seeds"),"Commerce and rent reload")
	game.game_day+=4;ops.update(0)
	check(ops.rent_overdue() and not ops.eligible("Grow Supply Shelf III"),"Overdue rent holds new equipment orders")
	game.game_day-=4
	# Both the visible phone tile and stale direct navigation must be removed.
	ops.close();game.phone_current_app="business";game._refresh_phone()
	check(game.phone_current_app=="budshop","Illegal Businesses phone category remains accessible")
	game._open_phone_app("bills");check(game.phone_current_app=="bills" and game._phone_parent_app("bills")=="budshop","Bills opens and returns to Business")
	var business_tiles: Array[String]=[]
	game.phone_current_app="business";game._refresh_phone()
	for node in game.phone_list.find_children("*","Button",true,false):business_tiles.append(node.text)
	check(business_tiles.any(func(t):return "BILLS" in t),"Business includes Bills")
	check(not business_tiles.any(func(t):return "EMPLOYEES" in t or "UPGRADES" in t),"Business does not duplicate computer management")
	game.phone_open=false;game.phone_panel.hide()
	var desk: MeshInstance3D=game.get_node("ApartmentComputerDesk")
	var bench: MeshInstance3D=game.get_node("BenchTop")
	check(not (desk.global_transform*desk.get_aabb()).intersects(bench.global_transform*bench.get_aabb()),"Computer desk clears packaging bench")
	check(desk.position.z-0.55>bench.position.z+1.76+1.0,"Clear gap between desk and packaging bench")
	var original_list: VBoxContainer=game.phone_list
	for app in ["business","employees","products","genetics","upgrades","bills"]:
		ops.manage(app)
		check(ops.is_open() and not game.phone_open and game.phone_list==original_list,"Management stays in computer panel: "+app)
		ops.close()
	ops.computer("apartment")
	check(ops.management_app=="business","Computer opens complete original Business interface")
	var buttons: String=""
	for button in ops.ui.body.find_children("*","Button",true,false):buttons+=button.text
	for category in ["OPERATIONS","INVENTORY","PROPERTY & BILLS"]:check(category in buttons,"Computer category: "+category)
	ops.manage("employees")
	check(ops.management_app=="employees" and not game.phone_open,"Staff management stays in computer")
	ops.close()
	game.camera.position=Vector3(27.7,1.64,1.65);game.camera.look_at(ops.HOUSE_PC)
	check(ops.target()=="house_computer","House computer reachable")
	ops.computer("house");check(ops.is_open() and not game.location_state.house.has("equipment"),"House computer preview does not activate production")
	ops.close()

	ops.close();game.phone_open=false;game.phone_panel.hide();game.session_paused=false
	for spec in [[Vector3(2.7,.08,4.35),Vector3(3.70,1.35,4.35),"apartment"],[Vector3(14,.08,4.6),Vector3(14,1.35,3),"market"],[Vector3(27.8,.08,1.65),Vector3(25.90,1.35,1.65),"house"]]:
		game.fp_player.position=spec[0];game.camera.position=spec[0]+Vector3.UP*2.16;game.camera.look_at(spec[1])
		await physics_frame
		game._use_target()
		check(ops.is_open(),"Native E opens "+spec[2]+" panel")
		check(game._close_active_panel() and not ops.is_open(),"Escape closes "+spec[2]+" panel")
	game.fp_player.position=Vector3(72,.08,17)
	check(game.fp_player.move_and_collide(Vector3(32,0,0))==null,"Native capsule crosses former east fence and reaches new junction")
	game.fp_player.position=Vector3(115,.08,17)
	check(game.fp_player.move_and_collide(Vector3(19,0,0))==null,"Main street continues through new district")
	game.fp_player.position=Vector3(135,.08,17)
	check(game.fp_player.move_and_collide(Vector3(5,0,0))!=null,"Relocated east fence contains the native capsule")
	for at in [Vector3(82,.1,8),Vector3(125.5,.1,-1.6),Vector3(131,.1,24)]:
		game.fp_player.position=at
		check(game.fp_player.move_and_collide(Vector3(0,-1,0))!=null,"New district has physical ground")
	game.fp_player.position=Vector3(-1.78,.08,1.8);n._toggle_couch()
	check(n.couch_seated and is_equal_approx(game.camera.position.y,1.18),"Desktop couch uses seated eye height")
	n._toggle_couch();check(not n.couch_seated and game.fp_player.position.distance_to(Vector3(-1.78,.08,1.8))<.001,"Standing restores safe approach position")
	for player in game.find_children("*","AudioStreamPlayer",true,false):player.stop();player.stream=null
	await create_timer(.15).timeout
	await process_frame
	await process_frame
	game.queue_free()
	await process_frame
	await process_frame
	print("COMMERCE_TEST_RESULT: PASS" if failures==0 else "COMMERCE_TEST_RESULT: FAIL")
	quit(1 if failures else 0)
