extends SceneTree
## Unlike headless schema tests, this checks *actual pixels* with a real GL viewport.
class FakeHost:
 extends Node3D
 var location_state:Dictionary={}
class FakeMenu:
 extends Node
 var cloud_locked:=false
 var quitting:=false
 var avatar_editor:CanvasLayer
func _initialize()->void:
 call_deferred("run")
func run()->void:
 var host:=FakeHost.new()
 root.add_child(host)
 var menu:=FakeMenu.new()
 host.add_child(menu)
 var editor=load("res://scripts/avatar_editor.gd").new()
 host.add_child(editor)
 menu.avatar_editor=editor
 var native_test:bool="--native-preview" in OS.get_cmdline_user_args()
 editor.force_native_preview=native_test
 var alternate_fit:bool="--female-outfit" in OS.get_cmdline_user_args()
 print("AVATAR_RENDER_STAGE: opening "+("NATIVE" if native_test else "IMPORT"))
 editor.open(host,menu)
 if alternate_fit:
  var alternate:Dictionary=editor.draft.duplicate(true)
  alternate["body"]="feminine"
  alternate["hair"]="ponytail"
  alternate["top"]="tank"
  alternate["outerwear"]="denim_jacket"
  alternate["bottom"]="cargos"
  alternate["shoes"]="high_tops"
  alternate["headwear"]="none"
  editor.draft=alternate
  editor._refresh_preview()
 print("AVATAR_RENDER_STAGE: editor opened")
 if editor.preview_viewport==null:
  push_error("AVATAR_RENDER_TEST: Missing actual SubViewport")
  quit(1);return
 for i in 14:
  await process_frame
 await RenderingServer.frame_post_draw
 print("AVATAR_RENDER_STAGE: first frame drawn")
 var preview:SubViewport=editor.preview_viewport
 var camera:Camera3D=editor.camera
 var actor:Node3D=editor.preview_model
 var render_world:World3D=preview.world_3d
 var meshes:Array[Node]=actor.find_children("*","MeshInstance3D",true,false)
 var visible_count:int=0
 var in_frustum:int=0
 var low_y:float=INF
 var high_y:float=-INF
 var examples:Array=[]
 for item in meshes:
  var mesh:MeshInstance3D=item as MeshInstance3D
  if not mesh.is_visible_in_tree() or mesh.mesh==null:continue
  visible_count+=1
  var local_center:Vector3=mesh.get_aabb().get_center()
  var center:Vector3=mesh.to_global(local_center)
  low_y=minf(low_y,center.y)
  high_y=maxf(high_y,center.y)
  var projected:Vector2=camera.unproject_position(center)
  if not camera.is_position_behind(center) and projected.x>=0 and projected.y>=0 and projected.x<preview.size.x and projected.y<preview.size.y:
   in_frustum+=1
  if examples.size()<4:examples.append({"part":mesh.name,"pos":center,"projected":projected,"layer":mesh.layers})
 var image:Image=preview.get_texture().get_image()
 var name_prefix:String="/tmp/afb-avatar-feminine" if alternate_fit else ("/tmp/afb-avatar-native" if native_test else "/tmp/afb-avatar")
 var ui:Image=root.get_texture().get_image()
 if ui!=null and not ui.is_empty():ui.save_png(name_prefix+"-ui.png")
 var meaningful_pixels:int=0
 var central_pixels:int=0
 var total_pixels:int=0
 if image!=null and not image.is_empty():
  image.save_png(name_prefix+"-preview.png")
  for y in range(55,image.get_height()-70,3):
   for x in range(50,image.get_width()-50,3):
    var pixel:Color=image.get_pixel(x,y)
    var difference:float=absf(pixel.r-.09)+absf(pixel.g-.14)+absf(pixel.b-.12)
    if difference>.12:meaningful_pixels+=1
    if difference>.05:central_pixels+=1
    total_pixels+=1
 print("AVATAR_RENDER_DIAGNOSTIC ",JSON.stringify({"native_mode":native_test,"female_streetwear":alternate_fit,"preview_size":preview.size,"preview_visible":editor.preview_image.is_visible_in_tree(),"camera_current":camera.current,"camera_pos":camera.global_position,"camera_basis":camera.global_transform.basis,"world":render_world!=null,"visible_meshes":visible_count,"in_frustum":in_frustum,"avatar_height_span":high_y-low_y,"example_centers":examples,"pixels_colorful":meaningful_pixels,"pixels_changed":central_pixels,"samples":total_pixels,"image_size":image.get_size() if image!=null else Vector2i.ZERO,"container_size":editor.preview_image.size,"ui_size":ui.get_size() if ui!=null else Vector2i.ZERO}))
 var ok:bool=visible_count>=15 and in_frustum>=12 and meaningful_pixels>=150 and high_y-low_y>1.15
 print("AVATAR_RENDER_RESULT: "+("PASS" if ok else "FAIL"))
 editor._cancel()
 host.queue_free()
 for i in 5:await process_frame
 quit(0 if ok else 1)
