extends RefCounted
var world: Node3D
var host: Node3D
var ops: RefCounted:
	get:return world.location_ops
var thread := ""
var actions := false
var release_confirmation: String = ""
var character_scenes: Dictionary = {}
var malik_visitor: Node3D
var malik_worker: Node3D
var tick := 0.0
var applying := false
var manager_attempted := false
var manager_node: Node3D
func setup(owner: Node3D) -> void:
	world=owner;host=world.host
	if not host.location_state.get("staff_assignments",{}) is Dictionary:host.location_state["staff_assignments"]={}
	if not host.location_state.has("staff_assignments"):host.location_state["staff_assignments"]={}
	if not host.location_state.has("crew_alerts"):host.location_state["crew_alerts"]={}
func label(parent: Node, text: String) -> void:
	var node:=Label.new();node.text=text;node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;parent.add_child(node)
func button(parent: Node,text: String,action: Callable,disabled: bool=false) -> void:
	var node:=Button.new();node.text=text;node.custom_minimum_size.y=54;node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;node.disabled=disabled;node.pressed.connect(action);parent.add_child(node)
func role(name: String) -> String:
	if host.packing_employee_hired and name==host._critical_production_sender():return "production"
	if host._friend_staff_role(name)=="dealer" or (name.begins_with("Hired Dealer ") and int(name.trim_prefix("Hired Dealer "))>0 and int(name.trim_prefix("Hired Dealer "))<=host.dealer_count) or (name=="Dealer Team" and host._total_dealer_count()>0):return "dealer"
	return host._friend_staff_role(name)
func roster() -> Array[String]:
	var names: Array[String]=host._friend_staff_names("dealer")
	for idx in range(host.dealer_count):names.append("Hired Dealer %d" % (idx+1))
	if host.packing_employee_hired and not names.has(host._critical_production_sender()):names.append(host._critical_production_sender())
	return names
func assignment(name: String) -> String:return str(host.location_state.staff_assignments.get(name,"apartment"))
func reeves_available() -> bool:
	return host.reeves_met or host.reeves_arrangement_active or host.reeves_arrangement_ended

func contacts() -> void:
	host.phone_title.text="Contacts"
	label(host.phone_list,"Known clients and your crew. Open a contact for messages, appointments, recruiting and property assignment.")
	button(host.phone_list,"EMPLOYEES · DUTY / DEALER SALES / COMMISSION",host._open_phone_app.bind("employees"))
	var names: Array[String]=roster()
	for client in host.customers:
		if host._customer_is_known(client) and not names.has(str(client.name)):names.append(str(client.name))
	if reeves_available() and not names.has("Agent Reeves"):names.append("Agent Reeves")
	names.sort()
	for name in names:
		var job:=role(name)
		var description:String="Reeves · Private contact" if name=="Agent Reeves" else (job.capitalize()+" · "+assignment(name).capitalize() if not job.is_empty() else "Client")
		button(host.phone_list,name+"\n"+description,open_thread.bind(name))
	if names.is_empty():label(host.phone_list,"Contacts appear as you get to know clients or hire staff.")
func open_thread(name: String) -> void:
	thread=name;actions=false;release_confirmation="";host.phone_current_app="texts";host.phone_open=true;host.phone_panel.show();host._refresh_phone();jump_latest.call_deferred()
func jump_latest() -> void:
	host.phone_scroll.scroll_vertical=0
func back() -> void:
	release_confirmation=""
	if actions:actions=false
	else:thread=""
	host._refresh_phone()
func show_actions() -> void:actions=true;host._refresh_phone()
func peer(message: Dictionary) -> String:return str(message.get("contact",message.get("sender","Unknown")))
func unread(name: String) -> int:
	var count:=0
	for msg in host.phone_text_messages:
		if peer(msg)==name and not bool(msg.get("read",false)):count+=1
	return count
func recount() -> void:
	host.phone_text_unread=0
	for msg in host.phone_text_messages:
		if not bool(msg.get("read",false)):host.phone_text_unread+=1
func threads() -> void:
	if thread.is_empty():
		host.phone_title.text="Messages"
		var names: Array[String]=[]
		for i in range(host.phone_text_messages.size()-1,-1,-1):
			var name:=peer(host.phone_text_messages[i])
			if not names.has(name):names.append(name)
		if reeves_available() and not names.has("Agent Reeves"):names.append("Agent Reeves")
		for name in names:
			var preview:=""
			for i in range(host.phone_text_messages.size()-1,-1,-1):
				if peer(host.phone_text_messages[i])==name:preview=str(host.phone_text_messages[i].get("body",""));break
			button(host.phone_list,name+(" · %d unread" % unread(name) if unread(name)>0 else "")+"\n"+preview.left(90),open_thread.bind(name))
		if names.is_empty():label(host.phone_list,"No messages yet. Start from Contacts.")
		button(host.phone_list,"CONTACTS",host._open_phone_app.bind("clients"))
		return
	host.phone_title.text=thread
	button(host.phone_list,"BACK TO MESSAGES",back)
	if actions:
		render_actions()
		return
	button(host.phone_list,"CONTACT DETAILS & ACTIONS",show_actions)
	for i in range(host.phone_text_messages.size()-1,-1,-1):
		var msg: Dictionary=host.phone_text_messages[i]
		if peer(msg)!=thread:continue
		var card:=PanelContainer.new();card.add_theme_stylebox_override("panel",host._style_box(Color("183126") if bool(msg.get("outgoing",false)) else Color("171d24"),Color("33434f"),16,1));host.phone_list.add_child(card)
		var box:=VBoxContainer.new();card.add_child(box)
		label(box,("YOU" if bool(msg.get("outgoing",false)) else thread)+" · DAY %d %s" % [int(msg.get("day",host.game_day)),str(msg.get("time",""))])
		label(box,str(msg.get("body","")))
		world.client_visits.append_replies(box,msg,i)
		msg["read"]=true
	recount();host._save_game()
func render_actions() -> void:
	if thread=="Agent Reeves":
		render_reeves_actions()
		return
	var job:=role(thread)
	if not job.is_empty():
		label(host.phone_list,job.to_upper()+" · Assigned to "+assignment(thread).capitalize())
		if job=="dealer":
			var stats:Dictionary=host.friend_dealer_stats.get(thread,{})
			label(host.phone_list,"THIS DEALER · TODAY: %d deals · %dg · $%d gross · $%d commission" % [int(stats.get("today_sales",0)),int(stats.get("today_grams",0)),int(stats.get("today_gross",0)),int(stats.get("today_commission",0))])
			label(host.phone_list,"CAREER: %d deals · %dg · $%d gross · $%d commission earned" % [int(stats.get("sales",0)),int(stats.get("grams",0)),int(stats.get("gross",0)),int(stats.get("commission_earned",0))])
			label(host.phone_list,"DEALER TEAM: %s · %d deals today · $%d cash held · $%d commission pending · $%d balance due" % ["ON DUTY" if host.dealers_active else "OFF DUTY",host.dealer_sales_today,host.dealer_cash_held,host.dealer_commission_held,host.dealer_balance_due])
			var dealer_reason:String=host._staff_duty_blocker("dealer")
			if not host.dealers_active and not dealer_reason.is_empty():label(host.phone_list,"WHY OFF DUTY: "+dealer_reason)
			button(host.phone_list,("SEND ALL DEALERS HOME" if host.dealers_active else "PUT ALL DEALERS ON DUTY")+" (TEAM-WIDE)",toggle_crew_duty.bind("dealer"),not host.dealers_active and not dealer_reason.is_empty())
		elif job=="production":
			label(host.phone_list,"PRODUCTION: %s · Today: %d tasks · Current: %s" % ["ON DUTY" if host.packing_employee_active else "OFF DUTY",host.production_worker_tasks_today,host.production_worker_last_action])
			var production_reason:String=host._staff_duty_blocker("production")
			if not host.packing_employee_active and not production_reason.is_empty():label(host.phone_list,"WHY OFF DUTY: "+production_reason)
			button(host.phone_list,"SEND PRODUCTION WORKER HOME" if host.packing_employee_active else "PUT PRODUCTION WORKER ON DUTY",toggle_crew_duty.bind("production"),not host.packing_employee_active and not production_reason.is_empty())
		if thread!="Dealer Team":
			var alternate:String="house" if assignment(thread)=="apartment" else "apartment"
			if ops._property_controlled(alternate):
				button(host.phone_list,"TEXT: TRANSFER "+thread.to_upper()+" TO "+alternate.to_upper(),transfer_from_contact.bind(thread,alternate))
			else:
				label(host.phone_list,"Other operation locked — manage property access in Real Estate.")
		button(host.phone_list,"ALL EMPLOYEES · FULL DUTY & PERFORMANCE",host._open_phone_app.bind("employees"))
		if not host.lay_low_active:button(host.phone_list,"CLOSE SHOP" if host.business_open else "OPEN SHOP",command.bind(thread,"close" if host.business_open else "open"))
		button(host.phone_list,"SET UP SHOP" if host.lay_low_active else "SHUT DOWN SHOP & LAY LOW",command.bind(thread,"reopen" if host.lay_low_active else "shutdown"))
		button(host.phone_list,"TEXT: APARTMENT STATUS",command.bind(thread,"status"))
		if job=="dealer":button(host.phone_list,"GO BACK TO STREET DEALS" if manager()==thread else "HANDLE APARTMENT DOOR",return_to_street.bind(thread) if manager()==thread else assign_manager.bind(thread))
		if job=="dealer" and host.dealer_arrested:button(host.phone_list,"SEND DEALER BAIL · $%d" % host.dealer_bail_due,host._pay_dealer_bail,host.cash<host.dealer_bail_due)
		if job=="production" and host.production_worker_arrested:button(host.phone_list,"SEND WORKER BAIL · $%d" % host.production_worker_bail_due,host._pay_production_bail,host.cash<host.production_worker_bail_due)
	else:
		var client: Dictionary=host._customer_by_name(thread)
		if not client.is_empty() and host._customer_is_known(client):
			button(host.phone_list,"TEXT: STOP BY / I'M OPEN",invite.bind(thread),not host.business_open)
			if host._friend_is_recruitable(client):
				button(host.phone_list,"OFFER DEALER WORK · APARTMENT",recruit.bind(thread,"dealer"),host._total_dealer_count()>=host._dealer_capacity())
				button(host.phone_list,"OFFER PRODUCTION WORK · APARTMENT",recruit.bind(thread,"production"),host.grower_level<5 or host.packing_employee_hired)
			elif str(client.get("tier",""))=="Friend":label(host.phone_list,"Recruiting requires %d loyalty and %d personal sales." % [host.FRIEND_RECRUIT_LOYALTY,host.FRIEND_RECRUIT_PLAYER_SALES])
	if not host._friend_staff_role(thread).is_empty():
		if release_confirmation==thread:
			label(host.phone_list,"Confirm ending "+thread+"'s employment. They will no longer work at either property. Completed dealer sales and earned commission history remain recorded.")
			button(host.phone_list,"CONFIRM FIRE "+thread.to_upper(),confirm_staff_release.bind(thread),host.dealer_arrested if job=="dealer" else host.production_worker_arrested)
			button(host.phone_list,"CANCEL FIRING",cancel_staff_release)
		else:
			button(host.phone_list,"FIRE "+thread.to_upper()+" · END "+job.to_upper()+" ROLE",request_staff_release.bind(thread))
	button(host.phone_list,"BACK TO CONVERSATION",back)

func transfer_from_contact(name:String,property:String) -> void:
	# Text commands and property-computer transfers share one assignment route.
	# Neither changes a crew member's role or historical dealer performance.
	if role(name).is_empty() or not ops._property_controlled(property):return
	if name=="Dealer Team" or assignment(name)==property:return
	assign(name,property)
	host._refresh_phone()

func request_staff_release(name:String) -> void:
	if host._friend_staff_role(name).is_empty():return
	release_confirmation=name
	host._refresh_phone()

func cancel_staff_release() -> void:
	release_confirmation=""
	host._refresh_phone()

func confirm_staff_release(name:String) -> void:
	if release_confirmation!=name or host._friend_staff_role(name).is_empty():return
	release_confirmation=""
	host._release_friend_staff(name)
	actions=false
	host._refresh_phone()

func toggle_crew_duty(job:String) -> void:
	if job=="dealer" and host._total_dealer_count()>0:host._toggle_dealers()
	elif job=="production" and host.packing_employee_hired:host._toggle_packing_employee()
	host._refresh_phone()

func render_reeves_actions() -> void:
	if not reeves_available():
		label(host.phone_list,"You haven't met Reeves yet.")
		return
	var remaining:int=host._reeves_remaining_balance()
	label(host.phone_list,"PRIVATE · AGENT REEVES")
	label(host.phone_list,"Heat: %d · Relationship: %d / 100 · Enforcement risk: %d%%" % [int(round(host.heat)),host.reeves_relationship,int(round(host.enforcement_risk))])
	if host.reeves_arrangement_active:
		label(host.phone_list,"Protection balance: $%d · Next payment: Day %d" % [remaining,host.reeves_next_payment_day])
	elif host.reeves_arrangement_ended:
		label(host.phone_list,"The protection arrangement is settled. Optional paid favors and private visits are available." if host._reeves_is_friendly() else "The protection arrangement is settled.")
	else:
		label(host.phone_list,"No recurring agreement. Reeves will discuss a formal arrangement in person.")
	button(host.phone_list,"TEXT: HOW ARE THINGS LOOKING?",reeves_message.bind("status"))
	var can_help:bool=host.reeves_met and not host.reeves_arrangement_active and (not host.reeves_arrangement_ended or host._reeves_is_friendly()) and (host.corrupt_contact_unlocked or host._reeves_is_friendly() or host.heat_peak>=50.0) and (host.heat>=host.HEAT_CONTACT_MINIMUM or (host._reeves_is_friendly() and host.heat>0.0)) and host.cash>=host._heat_contact_cost()
	button(host.phone_list,"ASK REEVES TO REDUCE HEAT · $%d" % host._heat_contact_cost(),reeves_message.bind("help"),not can_help)
	if host.heat<=0.0:
		label(host.phone_list,"Heat is 0. Reeves stays available, but there is no attention to reduce. You can still request a private visit.")
	elif not can_help and host.cash<host._heat_contact_cost():
		label(host.phone_list,"Not enough cash for this favor.")
	if host.reeves_arrangement_active and remaining>0:
		var paid_today:bool=host.reeves_last_payment_day==host.game_day
		var half:int=host._reeves_half_payment_amount()
		button(host.phone_list,"TEXT: PAY HALF NOW · $%d" % half,reeves_message.bind("half"),paid_today or half<=0)
		button(host.phone_list,"TEXT: SETTLE REMAINING $%d" % remaining,reeves_message.bind("full"),paid_today or host.cash<remaining)
		var quiet_ready:bool=not host.business_open and host.heat<=10.0 and host.reeves_quiet_days>=host.REEVES_QUIET_EXIT_DAYS
		button(host.phone_list,"REQUEST QUIET EXIT · %d/%d DAYS" % [host.reeves_quiet_days,host.REEVES_QUIET_EXIT_DAYS],reeves_message.bind("quiet"),not quiet_ready)
	button(host.phone_list,"TEXT: CAN WE TALK?",reeves_message.bind("meeting"))
	button(host.phone_list,"BACK TO CONVERSATION",back)

func reeves_message(action:String) -> void:
	if not reeves_available():return
	var who:String="Agent Reeves"
	match action:
		"status":
			outgoing(who,"How are things looking around me?")
			send(who,"Heat %d. Risk %d%%. %s" % [int(round(host.heat)),int(round(host.enforcement_risk)),("Your next payment is Day %d."%host.reeves_next_payment_day) if host.reeves_arrangement_active else "Stay quiet if you want less attention."])
		"meeting":
			outgoing(who,"Can we talk?")
			if host._reeves_is_friendly():
				if host.customer_waiting or host.reeves_visit_pending:
					send(who,"Someone's already at your door or I have a visit lined up. Text again later.")
				else:
					host.reeves_visit_pending=true
					host.reeves_visit_reason="friendly_checkin"
					send(who,"We are square. I can stop by your place for a private chat. No new protection bill.")
					host._save_game()
			else:
				send(who,"We can talk when I'm at your door. A message won't start or erase a protection agreement.")
		"help":
			if not host.reeves_met or host.reeves_arrangement_active or (host.reeves_arrangement_ended and not host._reeves_is_friendly()) or not (host.corrupt_contact_unlocked or host._reeves_is_friendly() or host.heat_peak>=50.0) or (host.heat<host.HEAT_CONTACT_MINIMUM and not (host._reeves_is_friendly() and host.heat>0.0)) or host.cash<host._heat_contact_cost():return
			var cost:int=host._heat_contact_cost()
			var prior:int=host.corrupt_contact_calls
			outgoing(who,"Can you make a few calls? I can pay $%d."%cost)
			host.corrupt_contact_unlocked=true
			host._use_heat_contact()
			if host.corrupt_contact_calls>prior:send(who,"I made some calls. Attention should be lower. Don't make this a habit.")
		"half","full":
			if not host.reeves_arrangement_active or host.reeves_last_payment_day==host.game_day:return
			var before:int=host.reeves_total_paid
			if action=="half":host._reeves_pay_half(true)
			else:host._reeves_pay_full(true)
			if host.reeves_total_paid>before:
				outgoing(who,"Sent you $%d."%(host.reeves_total_paid-before))
				send(who,"Got the payment. $%d left."%host._reeves_remaining_balance())
		"quiet":
			if not host.reeves_arrangement_active or host.business_open or host.heat>10.0 or host.reeves_quiet_days<host.REEVES_QUIET_EXIT_DAYS:return
			host._reeves_quiet_exit()
			outgoing(who,"I've kept the shop shut. The arrangement is over.")
			send(who,"We are square. Keep it that way.")
	host._refresh_phone()

func outgoing(name: String,body: String) -> void:
	host.phone_text_messages.append({"sender":"You","contact":name,"body":body,"outgoing":true,"read":true,"day":host.game_day,"time":host._format_game_clock()})
	while host.phone_text_messages.size()>120:host.phone_text_messages.pop_front()
func send(name: String,body: String) -> void:
	host._push_phone_text(name,body);host._save_game()
func assign(name: String,property: String) -> void:
	if role(name).is_empty() or property not in ["apartment","house"]:return
	if property=="house" and not ops._property_controlled("house"):return
	# The anonymous Dealer Team is part of apartment street-sales accounting.
	# Named recruits may be reassigned; this does not duplicate anyone.
	if name=="Dealer Team" and property=="house":return
	var previous:String=assignment(name)
	if previous==property:return
	host.location_state.staff_assignments[name]=property
	if str(host.location_state.get("apartment_manager",""))==name and property!="apartment":
		host.location_state["apartment_manager"]=""
		manager_attempted=false
	if role(name)=="production":
		host.production_worker_pending_action=""
		host.production_worker_pending_slot=-1
		host.production_worker_task="Transferring to "+property.capitalize()
		host.production_worker_last_action=host.production_worker_task
		host._reset_production_worker_navigation()
		if host.production_worker_node!=null:
			host.production_worker_node.set_meta("seated",false)
			host.production_worker_node.position=host._production_worker_station_position("entry")
		host.production_worker_target_position=host._production_worker_station_position("idle")
	outgoing(name,"Report to the "+property+".")
	send(name,"Assigned to "+property.capitalize()+". I will use that property's own stock and equipment.")
	host._refresh_phone();host._save_game()
func recruit(name: String,job: String) -> void:
	actions=false
	host._recruit_friend_staff(name,job)
	if role(name)==job:assign(name,"apartment")
func invite(name: String) -> void:
	if not host.business_open:return
	outgoing(name,"I'm available at the apartment. Stop by when you can.");host._text_known_customer(name);host._refresh_phone();host._save_game()
func assign_manager(name: String) -> void:
	if role(name)!="dealer" or assignment(name)!="apartment":return
	host.location_state["apartment_manager"]=name
	if can_handle():host._schedule_next_customer(true)
	outgoing(name,"Run the apartment and answer clients at the door.")
	send(name,"I'll answer clients at the apartment using packaged stock in its locker, storage or packing bench. I'm off street deals while assigned here. Cash and commission settle at nightly closeout.")
	host._refresh_phone()
func manager() -> String:
	var name:=str(host.location_state.get("apartment_manager",""))
	return name if role(name)=="dealer" and assignment(name)=="apartment" else ""
func shutdown() -> void:
	if applying:return
	applying=true
	if not host.lay_low_active:
		host.location_state["shutdown_duty"]={"production":host.packing_employee_active,"dealers":host.dealers_active}
	host._start_lay_low()
	host.ventilation_on=false;host.packing_employee_active=false;host.dealers_active=false
	host.production_worker_pending_action="";host.production_worker_task="Hanging out · Apartment lay low";host.production_worker_last_action=host.production_worker_task
	host._reset_production_worker_navigation()
	host.location_state["crew_idle"]=true
	var controls: RefCounted=world.house_controls
	if controls.shades.has("ApartmentBlind"):
		var shade: Dictionary=controls.shades.ApartmentBlind
		shade.closed=true;shade.node.scale.y=1.0;controls.states["ApartmentBlind"]=true
		host.house_control_state=controls.states.duplicate(true)
	host._refresh_light_interaction_visuals();host._save_game();applying=false
func command(name: String,action: String) -> void:
	actions=true
	if role(name).is_empty() or assignment(name)!="apartment":return
	outgoing(name,{"shutdown":"Shut down shop and lay low.","reopen":"Set up shop again.","close":"Close shop for clients.","open":"Open shop again.","status":"How is the apartment doing?"}[action])
	if (role(name)=="dealer" and host.dealer_arrested) or (role(name)=="production" and host.production_worker_arrested):send(name,"I'm being held. I can't act on that until bail is resolved.");return
	if action=="close":
		host._set_business_away();send(name,"Shop closed to clients. Production and the current lights stay as they are.")
	elif action=="open":
		if host.lay_low_active:send(name,"We are laying low. Use Set Up Shop to resume.");return
		if host._staff_heat_locked() or host.game_day<host.raid_lockdown_until_day:send(name,"We cannot open while heat or raid restrictions are active.");return
		host._reopen_business();send(name,"Shop is open again." if host.business_open else "Shop could not reopen yet.")
	elif action=="shutdown":
		shutdown();send(name,"Apartment shut down: blinds closed, lights and ventilation off, sales and work stopped. We're staying inside and hanging out.")
	elif action=="reopen":
		if host._staff_heat_locked() or host.game_day<host.raid_lockdown_until_day:send(name,"We can't reopen while the heat or raid restriction is still active.");return
		host._stop_lay_low_and_reopen()
		if host.business_open:
			host.location_state["crew_idle"]=false
			var saved: Dictionary=host.location_state.get("shutdown_duty",{})
			host.packing_employee_active=bool(saved.get("production",false)) and host.packing_employee_hired and not host.production_worker_arrested
			host.dealers_active=bool(saved.get("dealers",false)) and host._total_dealer_count()>0 and not host.dealer_arrested
			send(name,"Apartment reopened. Previous on-duty crew can work again. Lights and blinds stay as you left them; use the computer's production controls to choose what to turn on.")
	else:send(name,"Apartment: %s. Dealer stock %dg; shelf %d seeds / %d fertilizer uses. %s" % ["LAY LOW" if host.lay_low_active else ("OPEN" if host.business_open else "AWAY"),host._dealer_locker_total(),host._total_seed_inventory(),host.fertilizer_units,"Dealer answering the door: "+manager() if not manager().is_empty() else "No door manager assigned."])
	host._refresh_phone();host._save_game()
func return_to_street(name: String) -> void:
	if manager()!=name:return
	host.location_state["apartment_manager"]="";manager_attempted=false
	host._schedule_next_customer(true)
	outgoing(name,"Go back to street deals.");send(name,"Back on street deals. I'll use the Dealer Locker again. You'll need to answer the apartment door.");host._refresh_phone()
func can_handle() -> bool:
	return not host._simulation_blocked() and not manager().is_empty() and host.dealers_active and host.business_open and not host.lay_low_active and not host.dealer_arrested and host.dealer_balance_due<=0
func serve_visit(client: Dictionary,request: Dictionary) -> bool:
	var name:=manager()
	if not host.customer_waiting or host.customer_answered or host.customer_departing or str(host.current_customer.get("name",""))!=str(client.get("name","")):return false
	if not can_handle() or not str(client.get("special","")).is_empty():return false
	if not host._dealer_sell_one(false,name,client,request):return false
	host.customer_answered=true;host._record_customer_encounter(false)
	var summary: String="Served %s · %dg %s. Proceeds settle at closeout." % [str(client.get("name","client")),int(request.get("qty",0)),str(request.get("product",""))]
	world.client_visits._release_visit()
	host.status_label.text=name+": "+summary
	send(name,summary)
	return true
func computer_controls() -> void:
	label(ops.ui.body,"APARTMENT STOREFRONT · "+("LAY LOW" if host.lay_low_active else ("OPEN" if host.business_open else "AWAY")))
	button(ops.ui.body,"REOPEN APARTMENT" if not host.business_open else "APARTMENT AWAY · TEXT CLIENTS",host._reopen_business if not host.business_open else host._set_business_away)
	button(ops.ui.body,"APARTMENT LAY LOW · SHUT DOWN",shutdown)
	button(ops.ui.body,"CONTACTS & CREW TEXTS",func():ops.close();host._open_phone_app("clients");host.phone_open=true;host.phone_panel.show())
	label(ops.ui.body,"Door manager: "+(manager() if not manager().is_empty() else "Not assigned. Assign a dealer from Contacts."))
func alert(name: String,key: String,empty: bool,body: String) -> void:
	var alerts: Dictionary=host.location_state.crew_alerts
	if not empty:alerts.erase(key);return
	if alerts.has(key):return
	alerts[key]=true;send(name,"Apartment: "+body)
func update(delta: float) -> void:
	if not host.customer_waiting:manager_attempted=false
	update_malik()
	update_seating(delta)
	if bool(host.location_state.get("crew_idle",false)) and not host.lay_low_active:host.location_state["crew_idle"]=false
	var name:=manager()
	if manager_node!=null and str(manager_node.get_meta("contact",""))!=name:manager_node.queue_free();manager_node=null
	if not name.is_empty() and host.production_worker_node!=null:
		if manager_node==null:
			manager_node=character_instance(name) if name in ["Malik","Rod","Kobi"] else generic_manager_instance(name)
			manager_node.name="ApartmentDoorManager";host.add_child(manager_node);manager_node.set_meta("contact",name)
			for tag in manager_node.find_children("*","Label3D",true,false):tag.text=name+" · APARTMENT DEALER"
		manager_node.visible=not host.dealer_arrested
		var couch: Dictionary=idle_couch()
		var relax: bool=not couch.is_empty() and not host.customer_waiting and not world.couch_seated
		var seat: Vector3=idle_spot(true,false)
		var before: Vector3=manager_node.position
		var already_seated: bool=bool(manager_node.get_meta("seated",false))
		var previous_seat: Vector3=manager_node.get_meta("idle_seat_position",Vector3.ZERO)
		var same_seat: bool=already_seated and str(manager_node.get_meta("idle_seat_id",""))==str(couch.get("id","")) and previous_seat.distance_to(seat)<0.03
		var seated: bool=relax and same_seat
		if not seated:
			# Movement is horizontal. Never chase the zero-height navigation
			# target after the sitting pose lowers a character's visual root.
			manager_node.position.y=0.0
			var destination: Vector3=seat if relax else (Vector3(1.45,0,4.45) if host.customer_waiting else idle_spot(true,true))
			manager_node.position=manager_node.position.move_toward(destination,delta*2.0)
			var arrived: bool=Vector2(manager_node.position.x-seat.x,manager_node.position.z-seat.z).length()<0.12
			seated=relax and arrived and (not already_seated or same_seat)
		if seated:
			manager_node.position.x=seat.x
			manager_node.position.z=seat.z
			manager_node.rotation.y=float(couch.get("yaw",0.0))
			manager_node.set_meta("idle_seat_id",str(couch.get("id","")))
			manager_node.set_meta("idle_seat_position",seat)
		else:
			manager_node.set_meta("idle_seat_id","")
		seated_pose(manager_node,seated)
		animate_manager(Vector3(manager_node.position.x-before.x,0,manager_node.position.z-before.z),seated,delta)
		if host.customer_waiting and not host.customer_answered and not host.customer_departing and can_handle() and not manager_attempted and manager_node.position.distance_to(Vector3(1.45,0,4.45))<0.2 and str(host.current_customer.get("special","")).is_empty():
			manager_attempted=true
			var client: Dictionary=host.current_customer.duplicate(true)
			var request: Dictionary=host.active_request.duplicate(true)
			if not serve_visit(client,request):
				send(name,"I cannot fill %s: %dg %s requested. Check packaged stock and reserved stock." % [str(client.get("name","client")),int(request.get("qty",0)),str(request.get("product",""))])
				if not world.client_visits.is_home():world.client_visits._release_visit();world.client_visits._send_missed(client,request,"Your dealer could not fill my order. Let me know when you have stock.")
	elif manager_node!=null:manager_node.hide()
	tick+=delta
	if tick<10 or host._simulation_blocked():return
	tick=0
	if host.business_open and host.dealers_active and host._total_dealer_count()>0:alert(name if not name.is_empty() else host._critical_dealer_sender(),"dealer_stock",packaged_stock()==0 if not name.is_empty() else property_supply_empty(assignment(host._critical_dealer_sender()),"product|", "dealer"),"Apartment packaged stock is empty. Restock it so I can serve the door." if not name.is_empty() else "Dealer Locker is empty. I cannot sell on the street until you restock it.")
	if host.packing_employee_hired and host.packing_employee_active:
		var worker: String=host._critical_production_sender()
		alert(worker,"seeds",property_supply_empty(assignment(worker),"seed|"),"We're out of seeds. Collect an order at Central Market and deposit it at the computer.")
		alert(worker,"fertilizer",property_supply_empty(assignment(worker),"fertilizer"),"Fertilizer is out. I'll keep watering existing plants, but you'll need to restock fertilizer at Central Market.")

func generic_manager_instance(name: String) -> Node3D:
	# Each generic character gets a fresh primitive visual hierarchy, independent
	# of the production worker's current skin, hidden state, and custom GLB avatar.
	var source: Node3D=host.production_worker_node
	var instance:=Node3D.new()
	instance.position=source.position
	instance.rotation=source.rotation
	for part_name in ["Torso","Head","ArmL","ArmR","LegL","LegR","ShoeL","ShoeR","FriendFaceWrap"]:
		var original:MeshInstance3D=source.get_node_or_null(part_name) as MeshInstance3D
		if original==null:continue
		var part:=MeshInstance3D.new()
		part.name=part_name
		part.mesh=original.mesh
		part.transform=original.transform
		part.material_override=original.material_override
		part.visible=true
		instance.add_child(part)
		if part_name=="Head":
			var skin:=StandardMaterial3D.new()
			skin.albedo_color=host._worker_skin_color(name)
			part.material_override=skin
		elif part_name=="FriendFaceWrap":
			part.visible=false
			var art:String=host._worker_face_texture_path(name)
			if not art.is_empty() and ResourceLoader.exists(art):
				var texture:Texture2D=load(art) as Texture2D
				if texture!=null:
					var face:=StandardMaterial3D.new()
					face.albedo_texture=texture
					face.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
					face.cull_mode=BaseMaterial3D.CULL_DISABLED
					face.roughness=0.74
					face.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
					part.material_override=face
					part.visible=true
	# Copy the label's appearance when possible, never a worker's model.
	for child in source.get_children():
		if child is Label3D:
			var label_node:Label3D=child.duplicate()
			instance.add_child(label_node)
	return instance

func malik_instance() -> Node3D:return character_instance("Malik")
func _complete_sit_tracks(avatar: Node3D) -> void:
	for player in avatar.find_children("*","AnimationPlayer",true,false):
		var idle: Animation=player.get_animation("idle")
		var sit: Animation=player.get_animation("sit")
		if idle==null or sit==null:continue
		var lib: AnimationLibrary=player.get_animation_library("")
		if lib==null:continue
		var completed: Animation=sit.duplicate(true)
		var added:int=0
		for track in range(idle.get_track_count()):
			var track_type:int=idle.track_get_type(track)
			if track_type not in [Animation.TYPE_ROTATION_3D,Animation.TYPE_POSITION_3D,Animation.TYPE_SCALE_3D]:continue
			if idle.track_get_key_count(track)==0:continue
			var track_path:NodePath=idle.track_get_path(track)
			# Use the arms-down idle pose instead of the sit clip's T-pose arm keys.
			var arm_path:String=str(track_path).to_lower()
			if arm_path.contains("upperarm") or arm_path.contains("lowerarm") or arm_path.contains("hand_"):
				for existing in range(completed.get_track_count()-1,-1,-1):
					if completed.track_get_type(existing)==track_type and completed.track_get_path(existing)==track_path:
						completed.remove_track(existing)
			var already:bool=false
			for existing in range(completed.get_track_count()):
				if completed.track_get_type(existing)==track_type and completed.track_get_path(existing)==track_path:
					already=true
					break
			if already:continue
			var next:int=completed.add_track(track_type)
			completed.track_set_path(next,track_path)
			completed.track_insert_key(next,0.0,idle.track_get_key_value(track,0))
			added+=1
		if added>0:
			lib.remove_animation("sit")
			lib.add_animation("sit",completed)

func character_instance(name: String) -> Node3D:
	if name not in ["Malik","Rod","Kobi"]:return Node3D.new()
	var scene: PackedScene=character_scenes.get(name)
	if scene==null:
		# Native exports resolve Godot's imported scenes/textures, not raw file bytes.
		scene=load("res://assets/characters/"+name+".glb") as PackedScene
		if scene==null:push_error(name+" character scene unavailable");return Node3D.new()
		character_scenes[name]=scene
	var instance: Node3D=scene.instantiate()
	instance.set_meta("character",name)
	_complete_sit_tracks(instance)
	var material:=StandardMaterial3D.new()
	material.albedo_texture=load("res://assets/characters/"+name+"_BaseColor.png")
	material.roughness=.83;material.cull_mode=BaseMaterial3D.CULL_DISABLED
	for mesh in instance.find_children("*","MeshInstance3D",true,false):mesh.material_override=material
	for player in instance.find_children("*","AnimationPlayer",true,false):
		for clip in player.get_animation_list():
			if str(clip).ends_with("idle"):player.play(clip);break
	return instance
func production_worker_animation(worker: Node3D) -> String:
	if bool(worker.get_meta("seated",false)) and host.production_worker_pending_action.is_empty():return "sit"
	if not host.packing_employee_active:return "idle"
	# Do not keep walking in place at the packing bench, grow tents or storage.
	# Task-specific work animations may replace the standing idle later.
	var goal: Vector3=host.production_worker_target_position
	var horizontal_distance: float=Vector2(worker.position.x-goal.x,worker.position.z-goal.z).length()
	if horizontal_distance<=0.20:return "idle"
	var next_waypoint: Vector3=host._production_worker_navigation_target()
	var to_waypoint: float=Vector2(worker.position.x-next_waypoint.x,worker.position.z-next_waypoint.z).length()
	return "walk" if to_waypoint>0.10 else "idle"

func update_malik() -> void:
	var worker: Node3D=host.production_worker_node
	var name: String=host.production_worker_friend_name
	if name in ["Malik","Rod","Kobi"] and worker!=null:
		if malik_worker!=null and str(malik_worker.get_meta("character",""))!=name:malik_worker.queue_free();malik_worker=null
		if malik_worker==null:malik_worker=character_instance(name);worker.add_child(malik_worker)
		malik_worker.show()
		for child in worker.get_children():
			if child is MeshInstance3D:child.hide()
		for player in malik_worker.find_children("*","AnimationPlayer",true,false):
			var wanted: String=production_worker_animation(worker)
			for clip in player.get_animation_list():
				if str(clip).ends_with(wanted) and player.current_animation!=clip:player.play(clip)
	else:
		if malik_worker!=null:
			malik_worker.queue_free()
			malik_worker=null
		if worker!=null:
			for child in worker.get_children():
				if child is MeshInstance3D and child!=host.production_worker_face_shell:child.show()
	var visitor: String=str(host.current_customer.get("name",""))
	if host.customer_waiting and visitor in ["Malik","Rod","Kobi"]:
		if malik_visitor!=null and str(malik_visitor.get_meta("character",""))!=visitor:malik_visitor.queue_free();malik_visitor=null
		if malik_visitor==null:malik_visitor=character_instance(visitor);host.add_child(malik_visitor);malik_visitor.position=Vector3(0,0,7.1)
		malik_visitor.show()
	elif malik_visitor!=null:malik_visitor.hide()

func seated_pose(model: Node3D,seated: bool) -> void:
	if model==null:return
	if model.has_meta("character"):
		if not seated and bool(model.get_meta("seated",false)):
			for skeleton in model.find_children("*","Skeleton3D",true,false):skeleton.reset_bone_poses()
		for player in model.find_children("*","AnimationPlayer",true,false):
			for clip in player.get_animation_list():
				if str(clip).ends_with("sit" if seated else "idle") and (seated or bool(model.get_meta("seated",false))) and player.current_animation!=clip:player.play(clip)
		model.position.y=0.0
	else:
		model.position.y=-0.57 if seated else 0.0
	model.set_meta("seated",seated)

# Resolve idle furniture from the actual save. A packed couch or one moved
# to the house must never leave an invisible apartment seating target.
func idle_couch() -> Dictionary:
	if host.inventory_system == null or host.inventory_system.furniture == null:return {}
	var model: RefCounted=host.inventory_system.furniture.model
	var candidate: Dictionary={}
	for id in model.state.items:
		var e: Dictionary=model.state.items[id]
		if e.get("sku","")!="sofa" or e.get("property","")!="apartment" or not e.has("position"):continue
		var p: Array=e.position
		candidate={"id":id,"origin":Vector3(float(p[0]),0.0,float(p[2])),"yaw":deg_to_rad(float(e.get("yaw",0.0)))}
		if str(id)=="legacy_sofa":break
	return candidate

func idle_spot(manager: bool=false,approach: bool=false) -> Vector3:
	var couch: Dictionary=idle_couch()
	if couch.is_empty():
		# No apartment couch means crew stay standing in a clear idle area.
		return Vector3(0.75 if manager else -0.75,0.0,1.25)
	var second: bool=manager and host.packing_employee_hired
	var offset: Vector3=Vector3(0.615 if second else -0.375,0.0,-1.10 if approach else -0.165)
	return (couch["origin"] as Vector3)+offset.rotated(Vector3.UP,float(couch["yaw"]))

func update_seating(_delta: float) -> void:
	var worker: Node3D=host.production_worker_node
	if worker!=null and worker.visible:
		var idle: bool=host.production_worker_pending_action.is_empty() and (not host.packing_employee_active or host.production_worker_task=="Waiting for work" or host.lay_low_active)
		var couch: Dictionary=idle_couch()
		var seat: Vector3=idle_spot(false,false)
		var already_seated: bool=bool(worker.get_meta("seated",false))
		var previous_seat: Vector3=worker.get_meta("idle_seat_position",Vector3.ZERO)
		var same_seat: bool=already_seated and str(worker.get_meta("idle_seat_id",""))==str(couch.get("id","")) and previous_seat.distance_to(seat)<0.03
		var arrived: bool=Vector2(worker.position.x-seat.x,worker.position.z-seat.z).length()<0.15
		var seated: bool=idle and not couch.is_empty() and not world.couch_seated and arrived and (not already_seated or same_seat)
		if seated:
			# Hold the cushion position. Navigation must not pull us back
			# toward the table/front-of-couch approach point.
			worker.position.x=seat.x
			worker.position.z=seat.z
			worker.rotation.y=float(couch.get("yaw",0.0))
			worker.set_meta("idle_seat_id",str(couch.get("id","")))
			worker.set_meta("idle_seat_position",seat)
		else:
			worker.set_meta("idle_seat_id","")
		worker.set_meta("seated",seated)
		if malik_worker!=null:seated_pose(malik_worker,seated)
		else:
			for part in ["LegL","LegR"]:
				var leg: Node3D=worker.get_node_or_null(part)
				if leg!=null:leg.rotation.x=-PI/2 if seated else 0.0
			worker.position.y=-0.57 if seated else 0.0
func packaged_stock() -> int:
	if host.inventory_system!=null:return int(host.inventory_system.at_property("apartment",packaged_stock_local))
	return packaged_stock_local()

func packaged_stock_local() -> int:
	var amount: int=host._dealer_locker_total()
	for product in host.products:amount+=host._available_amount(product)
	for product in host.bagged_inventory:amount+=maxi(0,int(host.bagged_inventory[product]))
	return amount

func product_stock(product: String) -> int:
	if host.inventory_system!=null:return int(host.inventory_system.at_property("apartment",product_stock_local.bind(product)))
	return product_stock_local(product)

func product_stock_local(product: String) -> int:
	return maxi(0,int(host.locker_weed.get(product,0)))+host._available_amount(product)+maxi(0,int(host.bagged_inventory.get(product,0)))

func animate_manager(motion: Vector3,seated: bool,delta: float) -> void:
	if manager_node==null:return
	var moving: bool=motion.length()>0.001 and not seated
	if moving:manager_node.rotation.y=lerp_angle(manager_node.rotation.y,atan2(-motion.x,-motion.z),minf(1.0,delta*8.0))
	if manager_node.has_meta("character"):
		if seated:return
		for player in manager_node.find_children("*","AnimationPlayer",true,false):
			for clip in player.get_animation_list():
				if str(clip).ends_with("walk" if moving else "idle") and (player.current_animation!=clip or not player.is_playing()):player.play(clip)
	else:
		var phase: float=float(manager_node.get_meta("walk_phase",0.0))
		phase=phase+motion.length()*4.5 if moving else lerpf(phase,0.0,minf(1.0,delta*5.0))
		manager_node.set_meta("walk_phase",phase)
		var swing: float=sin(phase)*0.42 if moving else 0.0
		for spec in [["ArmL",swing],["ArmR",-swing],["LegL",-swing*0.75],["LegR",swing*0.75]]:
			var part: Node3D=manager_node.get_node_or_null(spec[0])
			if part!=null:part.rotation.x=spec[1]

func property_supply_empty(property:String,prefix:String,kind:String="supply") -> bool:
	if host.inventory_system==null:return false
	for item in host.inventory_system.contents(property+":"+kind):
		if str(item).begins_with(prefix) and int(host.inventory_system.contents(property+":"+kind)[item])>0:return false
	return true
