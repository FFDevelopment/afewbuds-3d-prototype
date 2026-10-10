extends Node3D
# One prop and one holder; handoff is committed only at the shared contact pose.
var people:Array=[]
var shared:Node3D
var elapsed:=0.0
var holder:=0
var transfers:=0
var phase:="Lighting"
var paused:=false
var active:=false
var ending:=false
var from_pose:Transform3D
var to_pose:Transform3D
var exchange:Transform3D
var last_pass:=-1
func setup(first,second):
 people=[first,second]
 shared=first.blunt.duplicate();add_child(shared)
 for a in people:a.frozen=true;a.begin("smoke");a.sample(7.0);a.reset_props()
 active=true;sample(0)
func quiet(a):
 a.rest_wait()
func held_pose(a)->Transform3D:
 a.action="smoke"
 a.sample(7.0)
 return a.blunt.global_transform
func stop():
 ending=true
 for a in people:a.finish()
func advance(delta:float):
 if not active or paused:return
 if ending:
  for a in people:a.sample(a.clock+delta,delta);a.blunt.hide()
  shared.global_transform=people[holder].blunt.global_transform
  phase="Finishing session"
  if people[holder].action=="idle":active=false;shared.hide();phase="Session finished"
 else:sample(elapsed+delta)
func sample(time:float):
 elapsed=time
 if time<7.8:
  holder=0;quiet(people[1])
  var a=people[0]
  if time<4.1:a.action="light";a.sample(time);phase="Lighting together"
  else:a.action="smoke";a.sample(time-.8);phase="First puff / exhale"
  shared.global_transform=a.blunt.global_transform;shared.visible=time>=.35;a.blunt.hide()
  return
 var round_index:=int((time-7.8)/9.0)
 var t:=fmod(time-7.8,9.0)
 var donor:=round_index%2;var receiver:=1-donor
 if t<3.0:
  people[donor].action="smoke";people[donor].sample(7.0)
  quiet(people[receiver])
  if last_pass!=round_index:
   from_pose=held_pose(people[donor]);to_pose=held_pose(people[receiver])
   exchange=from_pose.interpolate_with(to_pose,.5)
   exchange.origin=Vector3(0,1.65,0)
   last_pass=round_index
   quiet(people[receiver])
  var prop:Transform3D
  if t<1.5:prop=from_pose.interpolate_with(exchange,smoothstep(0,1,t/1.5))
  else:prop=exchange.interpolate_with(to_pose,smoothstep(0,1,(t-1.5)/1.5))
  shared.global_transform=prop;shared.show()
  holder=donor if t<1.5 else receiver
  # Receiver approaches a different point along the shaft; fingers don't overlap.
  var reach_weight:=smoothstep(0,1,(t-.65)/.85)
  var return_weight:=smoothstep(0,1,(t-1.5)/1.5)
  if t<1.5:
   people[donor].pose_shared(prop,.018,smoothstep(0,1,t/1.5))
   if t>.65:
    var waiting=people[receiver]
    var rest:Transform3D=waiting.global_transform*waiting.cigarette_frame()
    rest.origin+=rest.basis.z*.048
    waiting.pose_shared(rest.interpolate_with(exchange,reach_weight),.048,reach_weight)
  else:
   people[receiver].action="smoke";people[receiver].sample(7.0)
   people[receiver].pose_shared(prop,lerpf(.048,.018,return_weight),1-return_weight)
   quiet(people[donor])
   if t<2.8:
    var waiting=people[donor]
    var rest:Transform3D=waiting.global_transform*waiting.cigarette_frame()
    rest.origin+=rest.basis.z*.018
    waiting.pose_shared(exchange.interpolate_with(rest,smoothstep(0,1,(t-1.5)/1.3)),.018,1.0)
  transfers=round_index+(1 if t>=1.5 else 0)
  phase="Offering / reaching" if t<1.5 else "Received / drawing back"
 else:
  holder=receiver;quiet(people[donor])
  var a=people[receiver];a.action="smoke";a.sample(1.0+t-3.0)
  shared.global_transform=a.blunt.global_transform;shared.show()
  phase="Partner puff / exhale"
 for a in people:a.blunt.hide();a.lighter.hide();a.flame.hide()
