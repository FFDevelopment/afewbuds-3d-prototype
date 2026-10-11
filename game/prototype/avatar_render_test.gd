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
 print("AVATAR_RENDER_STAGE: opening")
 editor.open(host,menu)
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
 var examples:Array=[]
 for item in meshes:
  var mesh:MeshInstance3D=item as MeshInstance3D
  if not mesh.is_visible_in_tree() or mesh.mesh==null:continue
  visible_count+=1
  var local_center:Vector3=mesh.get_aabb().get_center()
  var center:Vector3=mesh.to_global(local_center)
  var projected:Vector2=camera.unproject_position(center)
  if not camera.is_position_behind(center) and projected.x>=0 and projected.y>=0 and projected.x<preview.size.x and projected.y<preview.size.y:
   in_frustum+=1
  if examples.size()<4:examples.append({"part":mesh.name,"pos":center,"projected":projected,"layer":mesh.layers})
 var image:Image=preview.get_texture().get_image()
 var ui:Image=root.get_texture().get_image()
 if ui!=null and not ui.is_empty():ui.save_png("/tmp/afb-avatar-ui.png")
 var meaningful_pixels:int=0
 var central_pixels:int=0
 var total_pixels:int=0
 if image!=null and not image.is_empty():
  image.save_png("/tmp/afb-avatar-preview.png")
  for y in range(55,image.get_height()-70,3):
   for x in range(50,image.get_width()-50,3):
    var pixel:Color=image.get_pixel(x,y)
    var difference:float=absf(pixel.r-.09)+absf(pixel.g-.14)+absf(pixel.b-.12)
    if difference>.12:meaningful_pixels+=1
    if difference>.05:central_pixels+=1
    total_pixels+=1
 print("AVATAR_RENDER_DIAGNOSTIC ",JSON.stringify({"preview_size":preview.size,"preview_visible":editor.preview_image.is_visible_in_tree(),"camera_current":camera.current,"camera_pos":camera.global_position,"camera_basis":camera.global_transform.basis,"world":render_world!=null,"visible_meshes":visible_count,"in_frustum":in_frustum,"example_centers":examples,"pixels_colorful":meaningful_pixels,"pixels_changed":central_pixels,"samples":total_pixels,"image_size":image.get_size() if image!=null else Vector2i.ZERO,"container_size":editor.preview_image.size,"ui_size":ui.get_size() if ui!=null else Vector2i.ZERO}))
 var ok:bool=visible_count>=15 and in_frustum>=12 and meaningful_pixels>=150
 print("AVATAR_RENDER_RESULT: "+("PASS" if ok else "FAIL"))
 editor._cancel()
 host.queue_free()
 for i in 5:await process_frame
 quit(0 if ok else 1)
