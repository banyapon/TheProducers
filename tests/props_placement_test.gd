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
 var before=[]
 for prop in main.office.decoration.get_children():
  before.append([prop.prop_id, prop.position])
  check(not prop.prop_id.contains("cat"), "no pets spawned")
 check(before.size()==13,"six plants, arcade, bar, five outdoor props")
 main.office._refresh_props()
 var after=[]
 for prop in main.office.decoration.get_children(): after.append([prop.prop_id,prop.position])
 check(before==after,"refresh preserves random arrangement without duplicates")
 Game.floors[0][0]="empty"
 main.office._refresh_props()
 check(main.office.decoration.get_child_count()==11,"empty room loses its plant and arcade")
 Game.floors[0][0]="lounge"
 main.office._refresh_props()
 main.office.camera.zoom=Vector2(0.55,0.55)
 await get_tree().process_frame
 await get_tree().process_frame
 if "--visual" in OS.get_cmdline_user_args():
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_webp("D:/EP45/ndlp/Producers/Props/random-placement.webp", true)
 print("RANDOM PROPS: ", failures, " failures")
 Game.running = false
 await Audio.shutdown()
 get_tree().quit(failures)
