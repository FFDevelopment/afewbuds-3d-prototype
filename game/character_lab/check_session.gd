extends SceneTree
func _initialize():call_deferred("run")
func run():
 var scene=load("res://character_lab/review.tscn").instantiate();root.add_child(scene);await process_frame
 scene.paused=true
 var errors:Array[String]=[];var pairs:Array=[]
 for idx in 9:
  scene.selected=idx;scene.partner=(idx+1)%9;scene.start_session()
  var s=scene.session;var max_contact:=0.0;var max_step:=0.0;var previous:=Vector3.ZERO;var max_wrist:=0.0;var minimum_thumb_direction:=1.0
  for frame in 1501:
   var t:=frame/60.0;s.sample(t)
   if frame>1 and s.shared.visible:
    var step:=previous.distance_to(s.shared.global_position)
    if idx==0 and step>.06:print("JUMP_TIME ",t," step ",step)
    max_step=maxf(max_step,step)
   previous=s.shared.global_position
   if t>=7.8 and fmod(t-7.8,9.0)<3.0:
    var a=s.people[s.holder]
    var contact:Vector3=a.to_global(a.cigarette_frame().origin)
    var distance:float=.018
    var pass_t:=fmod(t-7.8,9.0)
    if pass_t>=1.5:distance=lerpf(.048,.018,smoothstep(0,1,(pass_t-1.5)/1.5))
    max_contact=maxf(max_contact,contact.distance_to(s.shared.global_transform*Vector3(0,0,-distance)))
   if t>=7.8 and fmod(t-7.8,9.0)>=.9 and fmod(t-7.8,9.0)<=2.1:
    for actor in s.people:
     var thumb:Transform3D=actor.sk.get_bone_global_pose(actor.sk.find_bone("Thumb3_R"))
     minimum_thumb_direction=minf(minimum_thumb_direction,(-thumb.basis.x).y)
   if t>=7.8:
    for a in s.people:
     var hand:Transform3D=a.sk.get_bone_global_pose(a.sk.find_bone("Hand_R"))
     var forearm:Transform3D=a.sk.get_bone_global_pose(a.sk.find_bone("LowerArm_R"))
     max_wrist=maxf(max_wrist,hand.basis.x.angle_to(forearm.basis.x))
     if a.blunt.visible:errors.append("Duplicate blunt")
  if minimum_thumb_direction<-.02:errors.append("Right thumb points down during reach/pass "+str(minimum_thumb_direction))
  if max_wrist>.701:errors.append("Wrist bends too far")
  if max_contact>.012:errors.append(str(idx)+" missed grip "+str(max_contact))
  if max_step>.06:errors.append(str(idx)+" prop jump "+str(max_step))
  if s.transfers<2:errors.append("Missing return pass")
  s.stop();s.paused=false
  for f in 60:s.advance(1.0/60)
  if s.active or s.shared.visible:errors.append("Stop failed")
  pairs.append({"first":scene.NAMES[idx],"second":scene.NAMES[(idx+1)%9],"minimum_reach_thumb_up_dot":minimum_thumb_direction,"max_wrist_radians":max_wrist,"grip_error_metres":max_contact,"max_prop_step_metres":max_step})
 var result={"passed":errors.is_empty(),"errors":errors,"pairs":pairs}
 var f=FileAccess.open("user://character_session_validation.json",FileAccess.WRITE);f.store_string(JSON.stringify(result,"\t"));print(JSON.stringify(result));quit(0 if errors.is_empty() else 1)
