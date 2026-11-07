extends Node2D
var failures := 0
func check(ok: bool, message: String) -> void:
 if not ok: failures += 1; push_error(message)
func _ready() -> void:
 var bg=ColorRect.new();bg.color=Color("303a48");bg.z_index=-10;bg.size=Vector2(1920,1080);add_child(bg)
 for id in SceneProp.catalogue():
  var p=SceneProp.new();add_child(p);check(p.configure(id),id)
  var spec: Dictionary=SceneProp.catalogue()[id]
  check(p.sprite_frames.get_frame_count("default")==int(spec.frames),id+" frames")
  check(p.offset==-Vector2(spec.anchor[0],spec.anchor[1]),id+" floor anchor")
  p.hide()
 var i=0
 for id in ["plant-monstera","arcade-fighter","wood-bar-front","thai-taxi-green-yellow","8-12-convenience-store"]:
  var p=SceneProp.new();add_child(p);p.configure(id);p.position=Vector2(140+i*320,400);i+=1
  var actor=ModularCharacter.new();add_child(actor);actor.configure("alice");actor.position=p.position+Vector2(10,0)
  if id=="wood-bar-front":check(p.z_index>actor.z_index,"bar covers cast")
 await get_tree().process_frame
 if "--visual" in OS.get_cmdline_user_args():
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_webp("D:/EP45/ndlp/Producers/Props/props-ingame.webp",true)
 print("PROPS: ",failures," failures")
 await Audio.shutdown()
 get_tree().quit(failures)
