extends Node
var failures := 0
func check(ok: bool, message: String) -> void:
 if not ok: failures += 1; push_error(message)
func _ready() -> void:
 Game.running = false
 var bg = ColorRect.new(); bg.color=Color("303a48"); bg.size=Vector2(1600,900); add_child(bg)
 for row in 2:
  for i in Art.INSTRUMENTS.size():
   var id = Art.INSTRUMENTS[i]
   var actor = load("res://scenes/office/worker.tscn").instantiate()
   add_child(actor); actor.set_process(false)
   actor.configure_art("npc-16-female-sidesweep" if row == 0 else "alice")
   actor.position=Vector2(120+i*220,360+row*360); actor.scale=Vector2(2,2)
   actor._instrument=id; actor._instrument_data=Art.instrument_info(id)
   actor.state=Worker.State.WORK; actor._update_visual(0.0); actor.body.pause()
   for frame in 9:
    actor.body.frame=frame; actor._update_visual(0.0)
    check(actor._instrument_front.visible, id+" shown while playing")
    check(actor._instrument_back.visible == (id=="organ"), id+" rear layer")
    var atlas = actor._instrument_front.texture as AtlasTexture
    check(atlas.region.end.x<=960 and atlas.region.end.y<=160, id+" frame within sheet")
   for state in [Worker.State.IDLE,Worker.State.WALK,Worker.State.CHAT]:
    actor.state=state; actor._update_visual(0.0)
    check(not actor._instrument_front.visible and not actor._instrument_back.visible,id+" hidden outside play")
   actor.state=Worker.State.WORK;actor._update_visual(0.0);actor.body.pause();actor.body.frame=4;actor._update_visual(0.0)
   var label=Label.new();label.text=id;label.position=Vector2(70+i*220,380+row*360);add_child(label)
 await get_tree().process_frame
 if "--visual" in OS.get_cmdline_user_args():
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_webp("D:/EP45/ndlp/Producers/Native-lots/npc-playing-instruments.webp",true)
 print("INSTRUMENT OVERLAYS: ",failures," failures")
 await Audio.shutdown()
 get_tree().quit(failures)
