extends Node
var failures := 0
func check(ok: bool, message: String) -> void:
 if not ok: failures += 1; push_error(message)
func _ready() -> void:
 await get_tree().process_frame
 Game.save_slot = "native_art_qa"
 Game.new_game()
 Game.floors = [["lounge", "office", "storage"], ["studio", "meeting", "cafeteria"]]
 Game.running = true
 Game.speed = 0
 Game.tutorial_step = -1
 Game.tutorial_gate = false
 var main = load("res://scenes/main.tscn").instantiate()
 get_tree().root.add_child(main)
 main._booting = true
 main.login.hide()
 Game._emit_all()
 for kind in ["lounge", "office", "storage", "studio", "meeting", "cafeteria"]:
  for front in [false, true]: check(Art.room(kind, front).get_size() == Vector2(640, 360), kind + " native room")
 for sprite in main.office.foreground.get_children(): check(sprite.scale == Vector2.ONE, "no room texture scaling")
 for id in Art.INSTRUMENTS:
  var info = Art.instrument_info(id)
  check(info.size == Vector2i(160,160) and info.anchor == Vector2(80,137), id + " actor coordinates")
  check(info.texture.get_size() == Vector2(960,160), id + " six complete frames")
 await get_tree().process_frame
 await get_tree().process_frame
 if "--visual" in OS.get_cmdline_user_args():
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_webp("D:/EP45/ndlp/Producers/Native-lots/game-all-rooms.webp", true)
 print("NATIVE LOTS AND INSTRUMENTS: ", failures, " failures")
 Game.running = false
 await Audio.shutdown()
 get_tree().quit(failures)
