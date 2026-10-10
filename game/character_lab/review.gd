extends Node3D
const NAMES=["Mike","Tyler","Jeremias","Mahto","Marcuss","Diddy","Kobi","Rod","Malik"]
var session:Node3D
var partner:=1
var activities:Array[Node3D]=[]
var models:Array[Node3D]=[]
var players:Array[AnimationPlayer]=[]
var labels:Array[Label3D]=[]
var seats:Array[Node3D]=[]
var camera:Camera3D
var selected:=0
var count:=1
var target:=Vector3(0,1.24,0)
var distance:=4.9
var yaw:=0.0
var pitch:=.06
var dragging:=false
var turning:=false
var paused:=false
var current_clip:="idle"
var title:Label
var reference:TextureRect
var phase:Label
func _ready():
 for i in NAMES.size():
  var model=load("res://assets/characters/"+NAMES[i]+".glb").instantiate();add_child(model);models.append(model)
  var player:AnimationPlayer=model.find_children("*","AnimationPlayer",true,false)[0];players.append(player)
  for clip in ["idle","walk","bend_test","sit"]:player.get_animation(clip).loop_mode=Animation.LOOP_LINEAR
  player.play("idle")
  var activity=load("res://character_lab/activity.gd").new();activity.setup(model);activities.append(activity)
  var label:=Label3D.new();label.text=NAMES[i];label.position=Vector3(0,2.65,0);label.font_size=38;label.pixel_size=.005;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;model.add_child(label);labels.append(label)
  var seat:=Node3D.new();add_child(seat);seats.append(seat)
  box(seat,Vector3(0,.4049319 if i==5 else .408,.02),Vector3(.9,.12,.65),Color("394c47"))
  box(seat,Vector3(0,.76,.37),Vector3(.9,.7,.08),Color("394c47"))
  for x in [-.36,.36]:
   for z in [-.23,.29]:box(seat,Vector3(x,.19,z),Vector3(.045,.38,.045),Color("182423"))
 camera=Camera3D.new();camera.fov=38;add_child(camera);camera.current=true
 var sun:=DirectionalLight3D.new();add_child(sun);sun.rotation_degrees=Vector3(-32,155,0);sun.light_energy=.85;sun.shadow_enabled=true
 var fill:=DirectionalLight3D.new();add_child(fill);fill.rotation_degrees=Vector3(-22,-35,0);fill.light_energy=.35
 var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("142221");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("d3ddd8");env.environment.ambient_light_energy=.55;add_child(env)
 var floor:=MeshInstance3D.new();floor.mesh=PlaneMesh.new();floor.mesh.size=Vector2(100,100);add_child(floor)
 var mat:=StandardMaterial3D.new();mat.albedo_color=Color("34413f");floor.material_override=mat
 var layer:=CanvasLayer.new();add_child(layer)
 var panel:=PanelContainer.new();panel.position=Vector2(16,16);panel.size=Vector2(254,818);layer.add_child(panel)
 var style:=StyleBoxFlat.new();style.bg_color=Color("101b19");style.content_margin_left=14;style.content_margin_right=14;style.content_margin_top=16;style.content_margin_bottom=14;style.corner_radius_top_left=12;style.corner_radius_bottom_right=12;panel.add_theme_stylebox_override("panel",style)
 var scroll:=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;panel.add_child(scroll)
 var column:=VBoxContainer.new();column.add_theme_constant_override("separation",8);scroll.add_child(column)
 title=Label.new();title.add_theme_font_size_override("font_size",24);column.add_child(title)
 var note:=Label.new();note.text="ANIMATION LAB / REVIEW 07\nProps + shared actions";note.modulate=Color("9ac1b0");column.add_child(note)
 var grid:=GridContainer.new();grid.columns=2;column.add_child(grid)
 for i in NAMES.size():
  var idx:=i;button(grid,NAMES[i],func():set_clip("idle");selected=idx;count=1;full_view();arrange())
 button(grid,"All nine",func():set_clip("idle");count=9;full_view();arrange())
 button(column,"Compare new friends",func():set_clip("idle");count=2;full_view();arrange())
 var animations:=GridContainer.new();animations.columns=2;column.add_child(animations)
 for clip in ["idle","walk","bend_test","sit"]:
  var clip_value:String=clip;button(animations,clip.replace("_"," ").capitalize(),func():set_clip(clip_value))
 for action in ["light","smoke","pack","trim"]:
  var value:String=action;button(animations,{"light":"Light & smoke","smoke":"Smoke","pack":"Pack bags","trim":"Trim"}[action],func():count=1;full_view();set_clip(value))
 var partner_label:=Label.new();partner_label.text="Session partner";column.add_child(partner_label)
 var partner_select:=OptionButton.new()
 for person in NAMES:partner_select.add_item(person)
 partner_select.selected=1;partner_select.item_selected.connect(func(idx):partner=idx)
 column.add_child(partner_select)
 button(column,"Smoke together",start_session)
 button(column,"Finish current action",func():
  if is_instance_valid(session):session.stop()
  else:activities[selected].finish())
 button(column,"Restart action",func():
  if is_instance_valid(session):start_session()
  else:set_clip(current_clip))
 button(column,"Pause / Play [Space]",func():paused=not paused;set_speed())
 var views:=GridContainer.new();views.columns=2;column.add_child(views)
 button(views,"Full body",full_view)
 button(views,"Face",func():count=1;target=Vector3(0,2.17,0);distance=1.65;pitch=0;yaw=0;arrange())
 button(views,"Turntable",func():turning=not turning)
 button(views,"Reference",func():reference.visible=not reference.visible)
 phase=Label.new();phase.modulate=Color("99b9aa");column.add_child(phase)
 reference=TextureRect.new();reference.custom_minimum_size=Vector2(220,130);reference.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;reference.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;column.add_child(reference);reference.hide()
 var help:=Label.new();help.text="Drag empty space to orbit.\nWheel to zoom. R to reset.\nFinish lowers hands and tools.\n\nAnimation studies; no live save.";help.modulate=Color("b7c5be");column.add_child(help)
 arrange()
 if "--session-capture" in OS.get_cmdline_user_args():capture_session.call_deferred()
 if "--capture" in OS.get_cmdline_user_args():capture.call_deferred()
func box(parent:Node3D,at:Vector3,size:Vector3,color:Color):
 var ob:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=size;ob.mesh=mesh;ob.position=at;var mat:=StandardMaterial3D.new();mat.albedo_color=color;ob.material_override=mat;parent.add_child(ob)
func button(row:Control,text:String,action:Callable):
 var b:=Button.new();b.text=text;b.custom_minimum_size=Vector2(108,34);b.pressed.connect(action);row.add_child(b)
func full_view():
 target=Vector3(0,1.24,0);distance=4.9 if count==1 else (6.4 if count==2 else 22.0);yaw=.18 if count==1 else 0.0;pitch=.06
func arrange():
 if is_instance_valid(session):return
 for i in models.size():
  models[i].rotation.y=0
  models[i].visible=(i==selected if count==1 else i<count)
  models[i].position.x=((count-1)*.5-i)*1.7 if count>1 else 0.0
  labels[i].visible=count>1;seats[i].position=models[i].position;seats[i].visible=models[i].visible and current_clip=="sit"
 title.text=NAMES[selected] if count==1 else ("New friends" if count==2 else "Full lineup")
 var ref_path="res://assets/characters/"+NAMES[selected].to_lower()+"_door.png"
 reference.texture=load(ref_path) if ResourceLoader.exists(ref_path) else null
func set_clip(clip:String):
 if is_instance_valid(session):
  session.queue_free();session=null
 current_clip=clip
 for i in players.size():
  activities[i].begin(clip if clip in ["light","smoke","pack","trim"] else "idle")
  if clip not in ["light","smoke","pack","trim"]:players[i].play(clip,.15)
 set_speed();arrange()
func set_speed():
 for p in players:p.speed_scale=0 if paused else 1
 for a in activities:a.frozen=paused or is_instance_valid(session)
 if is_instance_valid(session):session.paused=paused
func _process(delta):
 if is_instance_valid(session):session.advance(delta)
 if turning:yaw+=delta*.3
 camera.position=target+Vector3(sin(yaw)*cos(pitch),sin(pitch),-cos(yaw)*cos(pitch))*distance;camera.look_at(target);camera.h_offset=-distance*.115
 phase.text=(session.phase if is_instance_valid(session) else (activities[selected].phase if current_clip in ["light","smoke","pack","trim"] else current_clip.capitalize()))+" · "+("Paused" if paused else "Playing")
func _input(event):
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:dragging=false
func _unhandled_input(event):
 if event is InputEventMouseButton:
  if event.button_index==MOUSE_BUTTON_LEFT:dragging=event.pressed
  if event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_UP:distance=maxf(.6,distance*.9)
  if event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_DOWN:distance=minf(24,distance*1.1)
 if event is InputEventMouseMotion and dragging:yaw-=event.relative.x*.007;pitch=clampf(pitch+event.relative.y*.005,-.5,1.2)
 if event is InputEventKey and event.pressed:
  if event.keycode==KEY_R:full_view()
  if event.keycode==KEY_SPACE:paused=not paused;set_speed()
func shot(name:String):
 for i in 6:await get_tree().process_frame
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://../preview/"+name+".png")
func capture():
 paused=true;set_speed();selected=0;count=1;target=Vector3(0,1.95,-.1);distance=2.1;yaw=.45;pitch=.04;arrange()
 for action in ["light","smoke"]:
  set_clip(action)
  activities[selected].sample(2.7)
  await shot("Grip_"+action)
  if action=="smoke":
   yaw=1.15;await shot("Grip_smoke_side");yaw=.45
   activities[selected].sample(5.0);await shot("Grip_lowered")
 set_clip("light");activities[selected].sample(4.1);activities[selected].advance(0)
 await shot("Sequence_transition")
 activities[selected].advance(.8);await shot("Sequence_exhale")
 full_view();yaw=.38
 for action in ["pack","trim"]:
  set_clip(action);activities[selected].sample(3.5);await shot("Action_"+action)
 selected=6;target=Vector3(0,2.15,0);distance=1.65;yaw=.1;set_clip("idle");arrange();await shot("Kobi_beard_eyes")
 selected=1;arrange();await shot("Tyler_sleeves_eyes")
 print("GRIP_CAPTURE_COMPLETE");get_tree().quit()

func start_session():
 if partner==selected:partner=(selected+1)%NAMES.size()
 set_clip("idle")
 session=load("res://character_lab/smoke_session.gd").new();add_child(session)
 for i in models.size():
  models[i].visible=i in [selected,partner];seats[i].hide();labels[i].visible=models[i].visible
 models[selected].position=Vector3(-.53,0,0);models[selected].rotation.y=-PI/2
 models[partner].position=Vector3(.53,0,0);models[partner].rotation.y=PI/2
 session.setup(activities[selected],activities[partner]);session.paused=paused
 current_clip="session";title.text=NAMES[selected]+" + "+NAMES[partner]
 target=Vector3(0,1.5,0);distance=5.6;yaw=.2;pitch=.08
func capture_session():
 paused=true;start_session()
 for t in [2.7,8.8,9.3,10.0,12.5,18.3]:
  session.sample(t);await shot("Session_"+str(t).replace(".","_"))
 print("SESSION_CAPTURE_COMPLETE");get_tree().quit()
