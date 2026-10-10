extends Node3D
# Shared procedural animation study, in the AFB skeleton's local metres.
var sk:Skeleton3D
var ap:AnimationPlayer
var action:="idle"
var clock:=0.0
var stopping:=false
var stop_clock:=0.0
var frozen:=false
var phase:="Idle"
var left:=Vector3(.24,.90,-.03)
var right:=Vector3(-.24,.90,-.03)
var stop_left:Vector3
var stop_right:Vector3
var bench:Node3D
var blunt:Node3D
var lighter:Node3D
var flame:Node3D
var scissors:Node3D
var blade:Node3D
var bud:Node3D
var bag:Node3D
var finished_bag:Node3D
var smoke:Array[MeshInstance3D]=[]
var max_reach_error:=0.0
var mouth_point:=Vector3(0,1.563,-.097)
var lip_error:=0.0
var finger_gap:=0.0
var at_mouth:=false
var wrist_bend:=0.0
var max_joint_error:=0.0
var pass_roll:=0.0
var lighter_press:=0.0
func setup(model:Node3D):
 sk=model.find_children("*","Skeleton3D",true,false)[0]
 ap=model.find_children("*","AnimationPlayer",true,false)[0]
 var who:=str(model.name).trim_prefix("AFB_")
 var face_scale:Vector2={"Mike":Vector2(1.03,1.04),"Tyler":Vector2(.99,1.03),"Kobi":Vector2(.91,1.13),"Rod":Vector2(.91,1.07),"Malik":Vector2(.86,1.06)}.get(who,Vector2(.96,1.09))
 mouth_point=Vector3(0,1.637+(1.560-1.637)*face_scale.x,-.088*face_scale.y)
 sk.add_child(self)
 bench=Node3D.new();add_child(bench);bench.scale.z=.70
 cube(bench,Vector3(0,1.00,-.56),Vector3(1.05,.055,.62),Color("684830"))
 for x in [-.45,.45]:
  for z in [-.31,-.80]:cube(bench,Vector3(x,.49,z),Vector3(.055,.98,.055),Color("263332"))
 cube(bench,Vector3(.25,1.04,-.60),Vector3(.28,.025,.25),Color("92a6a1"))
 cube(bench,Vector3(-.26,1.055,-.65),Vector3(.22,.07,.18),Color("39464b"))
 cube(bench,Vector3(-.26,1.096,-.65),Vector3(.17,.012,.14),Color("b9c1c0"))
 cube(bench,Vector3(-.26,1.07,-.55),Vector3(.08,.018,.004),Color("6ded9d"))
 for i in 7:sphere(bench,Vector3(.20+.04*(i%3),1.065,-.65+.043*(i/3)),Vector3(.024,.022,.018),Color("648142"))
 blunt=Node3D.new();add_child(blunt)
 rod(blunt,Vector3.ZERO,Vector3(0,0,-.085),.005,Color("765039"))
 sphere(blunt,Vector3(0,0,-.086),Vector3(.005,.005,.003),Color("ec773b"))
 lighter=Node3D.new();add_child(lighter)
 cube(lighter,Vector3.ZERO,Vector3(.021,.043,.012),Color("bc4049"));cube(lighter,Vector3(0,.025,0),Vector3(.021,.012,.014),Color("9ba4aa"))
 cube(lighter,Vector3(-.005,.032,0),Vector3(.01,.005,.009),Color("25272b"))
 sphere(lighter,Vector3(.006,.032,0),Vector3(.006,.006,.006),Color("657078"))
 flame=sphere(lighter,Vector3(0,.047,0),Vector3(.006,.015,.005),Color("ffb946"));flame.hide()
 scissors=Node3D.new();add_child(scissors)
 rod(scissors,Vector3(-.015,0,.014),Vector3(.014,0,-.072),.0028,Color("c6d1d4"))
 blade=Node3D.new();scissors.add_child(blade);rod(blade,Vector3(.015,0,.014),Vector3(-.014,0,-.072),.0028,Color("c6d1d4"))
 for x in [-.014,.014]:
  var ring:=MeshInstance3D.new();var torus:=TorusMesh.new();torus.inner_radius=.007;torus.outer_radius=.011;torus.rings=12;torus.ring_segments=6;ring.mesh=torus;ring.position=Vector3(x,0,.018);ring.material_override=material(Color("333b3d"));scissors.add_child(ring)
 bud=Node3D.new();add_child(bud)
 for i in 5:sphere(bud,Vector3(.009*sin(i*2.4),i*.008-.016,.008*cos(i*2.4)),Vector3(.012,.014,.01),Color("78914d"))
 bag=Node3D.new();add_child(bag);cube(bag,Vector3.ZERO,Vector3(.073,.095,.013),Color("b8c5b6"));cube(bag,Vector3(0,.028,-.008),Vector3(.058,.004,.002),Color("728471"));cube(bag,Vector3(0,-.009,-.009),Vector3(.044,.028,.002),Color("577943"))
 finished_bag=Node3D.new();bench.add_child(finished_bag);cube(finished_bag,Vector3(.37,1.051,-.37),Vector3(.08,.017,.11),Color("b8c5b6"))
 for i in 10:
  var puff:=sphere(self,Vector3.ZERO,Vector3.ONE*.015,Color(.72,.76,.74,.25));smoke.append(puff)
 reset_props()
func material(c:Color)->StandardMaterial3D:
 var m:=StandardMaterial3D.new();m.albedo_color=c;m.roughness=.85
 if c.a<1:m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 return m
func cube(parent:Node3D,pos:Vector3,size:Vector3,c:Color):
 var n:=MeshInstance3D.new();var m:=BoxMesh.new();m.size=size;n.mesh=m;n.position=pos;n.material_override=material(c);parent.add_child(n)
func sphere(parent:Node3D,pos:Vector3,size:Vector3,c:Color)->MeshInstance3D:
 var n:=MeshInstance3D.new();var m:=SphereMesh.new();m.radius=1;m.height=2;m.radial_segments=12;m.rings=6;n.mesh=m;n.position=pos;n.scale=size;n.material_override=material(c);parent.add_child(n);return n
func rod(parent:Node3D,a:Vector3,b:Vector3,r:float,c:Color):
 var n:=MeshInstance3D.new();var m:=CylinderMesh.new();m.top_radius=r;m.bottom_radius=r;m.height=a.distance_to(b);m.radial_segments=8;n.mesh=m;n.position=(a+b)*.5;n.quaternion=Quaternion(Vector3.UP,(b-a).normalized());n.material_override=material(c);parent.add_child(n)
func reset_props():
 for p in [bench,blunt,lighter,scissors,bud,bag]:p.hide()
 flame.hide();finished_bag.hide()
 for p in smoke:p.hide()
func begin(which:String):
 sk.clear_bones_global_pose_override();action=which;clock=0;stopping=false;stop_clock=0;max_reach_error=0
 ap.play("idle",0);ap.advance(0);ap.seek(0,true);ap.pause();reset_props()
 bench.visible=which in ["pack","trim"]
func finish():
 if action=="idle" or stopping:return
 stopping=true;stop_clock=0;stop_left=left;stop_right=right;phase="Finish / put tools away"
func blend_position(a:Vector3,b:Vector3,t:float)->Vector3:return a.lerp(b,smoothstep(0,1,clampf(t,0,1)))
func _process(delta):
 if frozen or action=="idle":return
 advance(delta)
func advance(delta:float):
 # Finish the first draw, stow the lighter, then lower the same gripping hand.
 if action=="light" and not stopping and clock+delta>=4.1:
  var overflow:=clock+delta-4.1
  action="smoke"
  sample(3.3+overflow,delta)
 else:sample(clock+delta,delta)
func sample(time:float,delta:float=0):
 clock=time
 pass_roll=0.0
 lighter_press=0.0
 var l0:=Vector3(.24,.90,-.03);var r0:=Vector3(-.24,.90,-.03)
 var t:=maxf(0,clock-1.0);var cycle:=fmod(t,6.0)
 at_mouth=not stopping and clock>=1 and (action=="light" or (action=="smoke" and cycle>=1.2 and cycle<=2.3))
 lip_error=0;max_joint_error=0;wrist_bend=0
 phase="Start / reach" if clock<1 else "Loop / "+action
 var l:=Vector3(.19,1.12,-.35);var r:=Vector3(-.16,1.13,-.36)
 reset_props();bench.visible=action in ["pack","trim"]
 if action=="light":
  var hold:=Vector3(-.09,1.55,-.115);var ignite:=Vector3(.034,1.50,-.157)
  r=hold;l=blend_position(Vector3(.24,.92,-.07),ignite,cycle/.8) if cycle<.8 else (ignite if cycle<2.3 else blend_position(ignite,Vector3(.24,.92,-.07),(cycle-2.3)/.8))
  blunt.show();lighter.show();flame.visible=clock>=1 and cycle>=.8 and cycle<2.3
  lighter_press=smoothstep(.55,.8,cycle)*(1-smoothstep(2.3,2.5,cycle)) if clock>=1 else 0.0
  phase="Thumb strike / ignite" if flame.visible else phase
 elif action=="smoke":
  var low:=Vector3(-.24,1.03,-.17);var mouth:=Vector3(-.09,1.55,-.115)
  r=blend_position(low,mouth,cycle/1.2) if cycle<1.2 else (mouth if cycle<2.3 else blend_position(mouth,low,(cycle-2.3)/1.1));l=Vector3(.24,.92,-.07);blunt.show()
  if cycle>3.0 and cycle<5.3 and clock>1:
   phase="Exhale"
   for i in smoke.size():
    var a:=fmod(cycle-3.0+i*.13,1.4);smoke[i].show();smoke[i].position=Vector3(.016*sin(i+a*3),1.56+a*.11,-.12-a*.16);smoke[i].scale=Vector3.ONE*(.008+a*.026)
 elif action=="pack":
  bag.show();bud.visible=cycle<3.4;l=Vector3(.08,1.13,-.42)
  if cycle<1.7:r=blend_position(Vector3(-.26,1.13,-.58),Vector3(-.06,1.21,-.43),cycle/1.7);phase="Weigh / fill"
  elif cycle<3.4:r=Vector3(-.06+.012*sin(cycle*9),1.19,-.43);phase="Fill bag"
  elif cycle<4.5:r=blend_position(Vector3(-.05,1.17,-.43),Vector3(.055,1.17,-.43),(cycle-3.4)/1.1);phase="Seal"
  else:l=blend_position(l,Vector3(.28,1.09,-.36),(cycle-4.5)/.8);r=Vector3(-.2,1.13,-.32);finished_bag.visible=cycle>5.4;phase="Set aside"
 elif action=="trim":
  l=Vector3(.035,1.17,-.40);r=Vector3(-.11,1.17,-.35);bud.show();scissors.show()
  if cycle<4.6:r+=Vector3(.014*sin(cycle*2),.009*sin(cycle*5),.008*cos(cycle*3));blade.rotation.y=.38*(.5+.5*sin(cycle*17));phase="Trim / snip"
  else:l=blend_position(l,Vector3(.22,1.09,-.58),(cycle-4.6)/1.0);phase="Place in tray"
 if cycle>5.5 and action in ["pack","trim"]:
  l=blend_position(l,Vector3(.08,1.13,-.42) if action=="pack" else Vector3(.035,1.17,-.40),(cycle-5.5)/.5)
  r=blend_position(r,Vector3(-.26,1.13,-.58) if action=="pack" else Vector3(-.11,1.17,-.35),(cycle-5.5)/.5)
 if action in ["pack","trim"]:l.z*=.70;r.z*=.70
 left=blend_position(l0,l,clock);right=blend_position(r0,r,clock)
 var amount:=smoothstep(0,1,minf(clock,1))
 if stopping:
  stop_clock+=delta;amount=1-smoothstep(0,1,stop_clock/.85);left=blend_position(stop_left,l0,stop_clock/.85);right=blend_position(stop_right,r0,stop_clock/.85);phase="Finish / lower hands";flame.hide()
  if stop_clock>=.85:
   action="idle";phase="Idle";reset_props();sk.clear_bones_global_pose_override();ap.play("idle");return
 arm("L",left,Vector3(-1,0,0) if action in ["pack","trim"] else Vector3(-.6,.4,-.2).normalized(),amount)
 var smoking:=action in ["light","smoke"]
 var finger_direction:=Vector3(1,.25,-.08).normalized() if smoking else Vector3(1,0,0)
 arm("R",right,finger_direction,amount)
 if smoking:
  # Calibrate the wrist from the actual posed finger contact, not a hand offset.
  var blend_to_lips:=1.0 if action=="light" else (smoothstep(0,1,cycle/1.2) if cycle<1.2 else (1.0 if cycle<2.3 else 1-smoothstep(0,1,(cycle-2.3)/1.1)))
  blend_to_lips*=smoothstep(0,1,minf(clock,1))
  if stopping:blend_to_lips=0
  for iteration in 14:
   sk.force_update_all_bone_transforms()
   var contact:=cigarette_frame()
   var mouth_end:=contact.origin+contact.basis.z*.018
   var correction:=(mouth_point-mouth_end)*blend_to_lips
   if not at_mouth and iteration>0:break
   right+=correction
   arm("R",right,finger_direction,amount)
 sk.force_update_all_bone_transforms()
 var lh:=grip("L");var rh:=grip("R")
 if smoking:
  var contact:=cigarette_frame()
  blunt.transform=Transform3D(contact.basis,contact.origin+contact.basis.z*.018)
  lip_error=blunt.position.distance_to(mouth_point) if at_mouth else 0
 else:blunt.position=rh+Vector3(0,.006,0)
 update_lighter_frame()
 if action=="light" and cycle>=.55 and cycle<2.5 and clock>=1:
  var ember:=blunt.transform*Vector3(0,0,-.085)
  var approach:=smoothstep(.55,.8,cycle)*(1-smoothstep(2.3,2.5,cycle))
  for iteration in 10:
   var flame_tip:=lighter.transform*Vector3(0,.047,0)
   left+=(ember-flame_tip)*approach
   arm("L",left,Vector3(-.6,.4,-.2).normalized(),amount)
   sk.force_update_all_bone_transforms()
   update_lighter_frame()
 scissors.position=rh;bud.position=rh if action=="pack" else lh;bag.position=lh-Vector3(0,.035,0)
 bag.visible=bag.visible and not finished_bag.visible
 if clock<.35:
  for p in [blunt,lighter,scissors,bud,bag]:p.hide()
func grip(side:String)->Vector3:
 var b:=sk.get_bone_global_pose(sk.find_bone("Hand_"+side));return b*Vector3(.068 if side=="L" else -.068,0,0)
func cigarette_frame()->Transform3D:
 var index:=sk.get_bone_global_pose(sk.find_bone("Index1_R"))
 var thumb:=sk.get_bone_global_pose(sk.find_bone("Thumb3_R"))
 # Index proximal pad and thumb distal pad, rather than a floating palm socket.
 var a:Vector3=index*Vector3(-.018,0,0)
 var b:Vector3=thumb*Vector3(-.010,0,0)
 var along:Vector3=-index.basis.x.normalized()
 var spread:Vector3=(a-b).normalized()
 var axis:Vector3=along.cross(spread).normalized()
 var hand:Transform3D=sk.get_bone_global_pose(sk.find_bone("Hand_R"))
 if axis.dot(Vector3.BACK)<0:axis=-axis
 var x:Vector3=(along-axis*along.dot(axis)).normalized()
 var y:Vector3=axis.cross(x).normalized()
 finger_gap=a.distance_to(b)
 return Transform3D(Basis(x,y,axis),(a+b)*.5)
func oriented_basis(axis:Vector3,palm:Vector3)->Basis:
 var y:Vector3=(palm-axis*axis.dot(palm)).normalized()
 if y.length()<.01:y=(Vector3.FORWARD-axis*axis.dot(Vector3.FORWARD)).normalized()
 return Basis(axis,y,axis.cross(y).normalized())
func arm(side:String,wrist:Vector3,finger_dir:Vector3,curl:float):
 var sg:=1.0 if side=="L" else -1.0
 var u:=sk.find_bone("UpperArm_"+side);var e:=sk.find_bone("LowerArm_"+side);var h:=sk.find_bone("Hand_"+side)
 var shoulder:=sk.get_bone_global_rest(u).origin
 var delta:=wrist-shoulder;var d:=clampf(delta.length(),.04,.529);var direction:=delta.normalized();var reach:=shoulder+direction*d
 max_reach_error=maxf(max_reach_error,wrist.distance_to(reach))
 var pole:=Vector3(sg*.20,-1.0,.05);var perpendicular:=(pole-direction*pole.dot(direction)).normalized()
 var along:=(.28*.28-.25*.25+d*d)/(2*d);var height:=sqrt(maxf(0,.28*.28-along*along));var elbow:=shoulder+direction*along+perpendicular*height
 var forearm:Vector3=(reach-elbow).normalized()
 var bend:=forearm.angle_to(finger_dir)
 if bend>.70:finger_dir=forearm.slerp(finger_dir,.70/bend).normalized()
 wrist_bend=maxf(wrist_bend,forearm.angle_to(finger_dir))
 var smoking:=action in ["light","smoke"] and side=="R"
 var palm:=Vector3.BACK if smoking else Vector3.UP
 var hand_basis:=oriented_basis(finger_dir*sg,palm)
 # Use one continuous neutral roll through lift, handoff and lowering.
 # Thumb goes forward as fingers hang down, avoiding a vertical-axis singularity.
 if action in ["idle","light","smoke"]:
  var thumb_direction:Vector3=(Vector3.UP+Vector3.FORWARD*.9*smoothstep(.55,.95,-finger_dir.y)).normalized()
  var neutral_palm:Vector3=(-thumb_direction).cross(finger_dir*sg).normalized()
  if neutral_palm.length()>.01:
   hand_basis=oriented_basis(finger_dir*sg,neutral_palm)
 var lower_basis:=oriented_basis(forearm*sg,hand_basis.y)
 var upper_basis:=Basis(Quaternion(Vector3(sg,0,0),(elbow-shoulder).normalized()))
 sk.set_bone_global_pose_override(u,Transform3D(upper_basis,shoulder),1,true)
 sk.set_bone_global_pose_override(e,Transform3D(lower_basis,elbow),1,true)
 sk.set_bone_global_pose_override(h,Transform3D(hand_basis,reach),1,true)
 max_joint_error=maxf(max_joint_error,(Transform3D(upper_basis,shoulder)*sk.get_bone_rest(e).origin).distance_to(elbow))
 max_joint_error=maxf(max_joint_error,(Transform3D(lower_basis,elbow)*sk.get_bone_rest(h).origin).distance_to(reach))
 for finger in ["Index","Middle","Ring","Pinky","Thumb"]:
  for joint in [1,2,3]:
   var b:=sk.find_bone(finger+str(joint)+"_"+side)
   var angle:float=.4 if finger=="Thumb" else .55
   if smoking:angle=([.12,.24,.18][joint-1] if finger=="Index" else ([.05,.12,.08][joint-1] if finger=="Thumb" else .55))
   var hold_weight:=1.0 if smoking and finger in ["Index","Thumb"] else curl
   var q:=Quaternion(Vector3(0,0,1),-sg*hold_weight*angle)
   # Slightly separate the holding fingers at their bases; keep all joint positions intact.
   if smoking and joint==1 and finger in ["Index","Thumb"]:
    q=Quaternion(Vector3.UP,(.12 if finger=="Index" else -.19)*hold_weight)*q
   if action=="light" and side=="L":
    var grip_q:Quaternion
    if finger=="Thumb":
     var thumb_angles:Array=[0.0,lerpf(.35,.65,lighter_press),lerpf(.4,.8,lighter_press)]
     grip_q=Quaternion(Vector3.FORWARD,float(thumb_angles[joint-1]))
     if joint==1:grip_q=Quaternion(Vector3.UP,.12*(1-lighter_press))*grip_q
    else:grip_q=Quaternion(Vector3.FORWARD,([1.0,.7,.55][joint-1])*curl)
    var hold:=1-smoothstep(2.5,3.1,fmod(maxf(0,clock-1),6.0))
    q=q.slerp(grip_q,hold)
   sk.set_bone_pose_rotation(b,q)

 # Keep the thumb itself lifted during an offer, not only the thumb edge of the palm.
 if smoking and pass_roll>0:
  sk.force_update_all_bone_transforms()
  var tip_id:=sk.find_bone("Thumb3_R")
  var tip:Transform3D=sk.get_bone_global_pose(tip_id)
  var current_direction:Vector3=-tip.basis.x.normalized()
  var lifted:=Vector3(current_direction.x,.55,current_direction.z).normalized()
  var correction:=Quaternion(current_direction,lifted)
  var limit:=minf(1.0,.85/maxf(.001,current_direction.angle_to(lifted)))
  correction=Quaternion.IDENTITY.slerp(correction,limit*smoothstep(0,.1,pass_roll))
  var parent_basis:Basis=sk.get_bone_global_pose(sk.get_bone_parent(tip_id)).basis
  var local_basis:Basis=sk.get_bone_rest(tip_id).basis.inverse()*parent_basis.inverse()*Basis(correction)*tip.basis
  sk.set_bone_pose_rotation(tip_id,local_basis.get_rotation_quaternion().normalized())

func rest_wait():
 action="idle";pass_roll=0;reset_props()
 left=Vector3(.24,.90,-.03);right=Vector3(-.24,.90,-.03)
 arm("L",left,Vector3(0,-1,0),.3)
 arm("R",right,Vector3(0,-1,0),.3)
 sk.force_update_all_bone_transforms()

func pose_shared(prop_world:Transform3D, grip_distance:float, natural_weight:float=1.0):
 # Solve the contact point without overriding the wrist's anatomical bend limit.
 action="smoke"
 pass_roll=natural_weight
 var desired:Transform3D=global_transform.affine_inverse()*prop_world
 var target_point:Vector3=desired*Vector3(0,0,-grip_distance)
 var start_direction:Vector3=-sk.get_bone_global_pose(sk.find_bone("Hand_R")).basis.x.normalized()
 var shoulder:Vector3=sk.get_bone_global_rest(sk.find_bone("UpperArm_R")).origin
 var reach_direction:Vector3=target_point-shoulder
 # Offer with a level handshake-like hand instead of aiming down from the shoulder.
 reach_direction.y=.12
 reach_direction=reach_direction.normalized()
 var finger_direction:=start_direction.slerp(reach_direction,smoothstep(0,.25,natural_weight)).normalized()
 for iteration in 16:
  arm("R",right,finger_direction,1.0)
  sk.force_update_all_bone_transforms()
  right+=target_point-cigarette_frame().origin
 arm("R",right,finger_direction,1.0)
 sk.force_update_all_bone_transforms()

func update_lighter_frame():
 var hand:Transform3D=sk.get_bone_global_pose(sk.find_bone("Hand_L"))
 lighter.transform=hand*Transform3D(Basis(Vector3.RIGHT,Vector3.FORWARD,Vector3.UP),Vector3(.0757,-.039,-.003))
