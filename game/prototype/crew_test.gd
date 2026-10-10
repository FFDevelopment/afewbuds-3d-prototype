extends SceneTree
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures+=1;push_error(message)
func labels(node: Node) -> String:
	var result:=""
	for button in node.find_children("*","Button",true,false):result+=button.text+"\n"
	return result
func visit(game: Node3D,client: Dictionary,product: String,qty: int) -> void:
	game.current_customer=client.duplicate(true);game.active_request={"product":product,"qty":qty};game.customer_waiting=true;game.customer_answered=false;game.customer_departing=false
func run() -> void:
	var game: Node3D=load("res://prototype/apartment.tscn").instantiate();root.add_child(game);game.fp_player.set_physics_process(false);await process_frame
	game.set_process(false);game.neighborhood.set_process(false);game.gameplay_ready=true;game.session_paused=false;game.tutorial_active=false;game.daily_report_pending=false;game.tutorial_panel.hide();game.pause_overlay.hide();game.daily_report_panel.hide();game.visit_timer.stop();game.dealer_count=1;game.dealers_active=true;game.business_open=true;game.dealer_balance_due=0;game.dealer_arrested=false;game.lay_low_active=false
	var crew: RefCounted=game.neighborhood.location_ops.crew
	# A fallback dealer must never inherit a production worker's custom GLB.
	var old_friend:String=game.production_worker_friend_name
	game.production_worker_friend_name="Malik"
	crew.update_malik()
	var tyler:Node3D=crew.generic_manager_instance("Tyler")
	check(tyler.find_children("*","Skeleton3D",true,false).is_empty(),"Tyler fallback has no attached Malik skeleton or imported character scene")
	check(tyler.find_children("*","AnimationPlayer",true,false).is_empty(),"Tyler fallback does not inherit Malik animations")
	var face:MeshInstance3D=tyler.get_node_or_null("FriendFaceWrap") as MeshInstance3D
	check(face!=null and face.visible and face.material_override!=null,"Tyler receives only his own default body and face wrap")
	check(tyler.get_node_or_null("Torso")!=null and (tyler.get_node("Torso") as MeshInstance3D).visible,"Tyler fallback body remains visible even when Malik hides the production rig")
	tyler.free()
	game.friend_staff_roles["Tyler"]="dealer"
	game.location_state["staff_assignments"]["Tyler"]="apartment"
	game.location_state["apartment_manager"]="Tyler"
	crew.update(0.01)
	check(crew.manager_node!=null and str(crew.manager_node.get_meta("contact",""))=="Tyler","Real apartment manager creates the Tyler avatar")
	if crew.manager_node!=null:
		check(crew.manager_node.get_meta("character","")=="Tyler" and crew.manager_node.find_children("*","Skeleton3D",true,false).size()==1,"Real Tyler manager loads his own approved skeleton")
		check(crew.manager_node!=crew.malik_worker,"Tyler manager and Malik worker have independent character instances")
		crew.manager_node.queue_free()
		crew.manager_node=null
	game.location_state["apartment_manager"]=""
	game.location_state["staff_assignments"].erase("Tyler")
	game.friend_staff_roles.erase("Tyler")
	game.production_worker_friend_name="Tyler"
	crew.update_malik()
	check(crew.malik_worker!=null and crew.malik_worker.get_meta("character","")=="Tyler","Switching production identity from Malik to Tyler loads Tyler appearance")
	game.production_worker_friend_name=old_friend
	crew.update_malik()
	var dealer: String="Hired Dealer 1";crew.assign_manager(dealer)
	var client: Dictionary=game.customers[0].duplicate(true)
	var product: String=str(client.favorite)
	game.products[product]={"stock":5,"reserved":2,"listed":true,"price":20,"grade":"B"};game.locker_weed={};game.bagged_inventory={};game.dealer_locker_level=0;game.dealer_customers_served_today={};game.customer_relationships[str(client.name)]={"visits":1,"player_sales":0}
	var text_count:int=game.phone_text_messages.size()
	visit(game,client,product,2);var gross: int=game.lifetime_revenue
	check(crew.serve_visit(client,game.active_request),"Door serves stored stock without locker or prior player sale")
	check(game.products[product].stock==3 and game.lifetime_revenue==gross+40 and not game.customer_waiting,"Actual order consumes storage and settles original dealer accounting")
	check(game.phone_text_messages.size()==text_count,"Routine dealer sale sends no phone text")
	var history:Array=game.location_state.get("dealer_sale_history",{}).get(dealer,[])
	check(history.size()==1 and int(history[0].grams)==2 and int(history[0].gross)==40 and history[0].client==client.name,"Dealer details retain real sale quantity, client and earnings")
	check(not crew.serve_visit(client,{"product":product,"qty":2}),"Released visit cannot sell twice")
	game.bagged_inventory[product]=2;game.locker_weed[product]=1
	visit(game,client,product,3);check(crew.serve_visit(client,game.active_request),"Later legitimate repeat visit combines packaged sources")
	check(game.products[product].stock==2 and game.bagged_inventory[product]==1 and not game.locker_weed.has(product),"Locker then unreserved storage then packaged bench; reserves preserved")
	visit(game,client,product,5);var before: int=game.lifetime_revenue
	check(not crew.serve_visit(client,game.active_request) and game.lifetime_revenue==before and game.bagged_inventory[product]==1,"Short stock cannot partially charge or consume")
	game.customer_waiting=false;game.current_customer={};game.locker_weed[product]=20
	game.products[product].stock=0;game.products[product].listed=false;game.bagged_inventory={}
	check(game._has_listed_stock(),"Door visitor scheduling sees locker-only packaged stock")
	check(not game._dealer_sell_one(false,dealer),"Door-assigned dealer cannot also make street sales")
	crew.thread=dealer;crew.actions=true;game.phone_current_app="texts";game._refresh_phone()
	check("GO BACK TO STREET DEALS" in labels(game.phone_list) and not "HANDLE APARTMENT DOOR" in labels(game.phone_list),"Door role replaces assignment action")
	crew.command(dealer,"close");check(not game.business_open and "OPEN SHOP" in labels(game.phone_list) and not "CLOSE SHOP" in labels(game.phone_list),"Close flips to Open on same screen")
	crew.command(dealer,"open");check(game.business_open and "CLOSE SHOP" in labels(game.phone_list),"Open flips to Close")
	crew.command(dealer,"shutdown");check(game.lay_low_active and "SET UP SHOP" in labels(game.phone_list) and not "SHUT DOWN SHOP & LAY LOW" in labels(game.phone_list),"Lay Low flips to Set Up Shop")
	game.heat=0;crew.command(dealer,"reopen");check(not game.lay_low_active and game.business_open,"Setup restores storefront and prior crew duty")
	crew.return_to_street(dealer);check(crew.manager().is_empty() and "HANDLE APARTMENT DOOR" in labels(game.phone_list),"Return restores street role and inverse button")
	# Existing waiting visitor is completed after manager reaches the door, even at home.
	crew.assign_manager(dealer);game.camera.position=Vector3(0,1.7,3);game.products[product].stock=12;game.customer_waiting=false;crew.update(0.01)
	visit(game,client,product,2);crew.manager_node.position=Vector3(1.45,0,4.45);crew.update(0.01)
	check(not game.customer_waiting,"Manager handles waiting visitor while player watches at home")
	game.camera.position=Vector3(-25,1.7,20);visit(game,client,product,2)
	check(not game.neighborhood.client_visits.route_arrival() and game.customer_waiting,"Assigned manager retains away visitor for door service")
	crew.manager_attempted=false;crew.manager_node.position=Vector3(1.45,0,4.45);crew.update(0.01)
	check(not game.customer_waiting,"Manager completes away visitor")
	visit(game,client,product,2);game.session_paused=true;crew.manager_attempted=false;crew.manager_node.position=Vector3(1.45,0,4.45);crew.update(0.01)
	check(game.customer_waiting and not crew.manager_attempted,"Paused play cannot sell or consume the pending manager attempt")
	game.session_paused=false;crew.update(0.01);check(not game.customer_waiting,"Resuming lets manager complete pending visit")

	for player in game.find_children("*","AudioStreamPlayer",true,false):player.stop();player.stream=null
	await create_timer(.15).timeout
	await process_frame
	await process_frame
	game.queue_free()
	await process_frame
	await process_frame
	print("CREW_TEST_RESULT: PASS" if failures==0 else "CREW_TEST_RESULT: FAIL")
	quit(1 if failures else 0)
