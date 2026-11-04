extends Node
var checks = 0
var failures = 0
func check(ok: bool, description: String) -> void:
	checks += 1
	if ok: print("ok: ", description)
	else: failures += 1; push_error(description)

func _ready() -> void:
	Game.save_slot = "fullbody_qa_a"; Game.new_game(); Game.running = true
	check(Game.character_appearance.size() == 32, "all main NPC VIP recipes initialized")
	check(Game.character_appearance["producer"]["pants_tint"] == "#657447" and Game.character_appearance["alice"]["cloth_tint"] == "#ffffff", "requested defaults")
	Game.character_appearance["producer"]["pants_tint"] = "#123456"
	Game.initiate_character_parts()
	check(Game.character_appearance["producer"]["pants_tint"] == "#123456", "initialize preserves existing saved recipe")
	Game.save_game()
	var saved = JSON.parse_string(FileAccess.get_file_as_string(Game.character_parts_path()))
	check(saved["characters"]["producer"]["pants_tint"] == "#123456", "per-save JSON contains actual appearance")
	Game.character_appearance.clear(); Game.load_game()
	check(Game.character_appearance["producer"]["pants_tint"] == "#123456", "appearance reloads")
	Game.save_slot = "fullbody_qa_b"; Game.new_game(); Game.save_game()
	check(Game.character_appearance["producer"]["pants_tint"] == "#657447", "new slot does not inherit another outfit")
	Game.save_slot = "fullbody_qa_a"; Game.load_game()
	check(Game.character_appearance["producer"]["pants_tint"] == "#123456", "switch back restores first slot")
	Game.character_appearance.erase("alice"); Game.initiate_character_parts()
	check(Game.character_appearance.has("alice"), "migration fills missing characters")
	Game.character_appearance["alice"]["body"] = "broken"
	Game.character_appearance["alice"]["cloth_tint"] = "bad color"
	Game.initiate_character_parts()
	check(Game.character_appearance["alice"]["body"] == "shirt" and Game.character_appearance["alice"]["cloth_tint"] == "#ffffff", "invalid recipe repaired")
	Game.character_appearance["npc-02-female-bob"] = {"body":"jacket", "cloth_tint":"#123456"}
	Game.initiate_character_parts()
	check(Game.character_appearance["npc-02-female-bob"]["body"] == "tee" and Game.character_appearance["npc-02-female-bob"]["cloth_tint"] == "#123456", "old artwork migrates to new garment and preserves saved color")
	var main = load("res://scenes/main.tscn").instantiate(); main._booting = true; add_child(main)
	main.login.hide(); Game.speed = 1
	var event = InputEventKey.new(); event.keycode = KEY_I; event.pressed = true
	main._input(event)
	check(not main.fullbody_debug.visible, "I alone does not open preview")
	event.ctrl_pressed = true; event.shift_pressed = true
	var pauses = Game._pause_requests
	main._input(event)
	check(main.fullbody_debug.visible and Game._pause_requests == pauses+1, "Ctrl+Shift+I opens paused popup")
	check(main.fullbody_debug.characters.item_count == 32 and main.fullbody_debug.previews.size() == 4, "list and four simultaneous previews")
	var preview = main.fullbody_debug.previews[0]
	preview.set_pose("idle",0); preview._process(0.4)
	check(preview.frame == 1 and preview.parts.values().all(func(p): return p.frame == 1), "preview animates all layers while simulation is paused")
	for group in ["Main","NPC","VIP"]:
		main.fullbody_debug.group = group; main.fullbody_debug.refresh()
		check(main.fullbody_debug.characters.item_count == {"Main":2,"NPC":24,"VIP":6}[group], "filter "+group)
		main.fullbody_debug.characters.item_selected.emit(1)
		check(main.fullbody_debug.selected_id == main.fullbody_debug.characters.get_item_metadata(1) and main.fullbody_debug.previews[0].parts["head"].texture.resource_path.contains(main.fullbody_debug.selected_id), "list selection updates layered preview " + group)
	main.fullbody_debug.group = "All"; main.fullbody_debug.selected_id = "producer"; main.fullbody_debug.refresh()
	await get_tree().process_frame; await get_tree().process_frame
	if "--visual" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_webp("D:/EP45/ndlp/Producers/fullbody-f8.webp",true)
	main._input(event)
	check(not main.fullbody_debug.visible and Game._pause_requests == pauses, "Ctrl+Shift+I closes and releases pause")
	main._input(event)
	var esc = InputEventKey.new(); esc.keycode = KEY_ESCAPE; esc.pressed = true
	main._input(esc)
	check(not main.fullbody_debug.visible, "Escape closes preview")
	var worker = load("res://scenes/office/worker.tscn").instantiate(); add_child(worker)
	for id in ["producer", "alice", Art.npc_ids[0], Art.vip_ids[0]]:
		worker.configure_art(id)
		check(worker.body.visible and worker.body.sprite_frames == Art.office_frames(id), "office uses native 3x3 sprite sheet " + id)
	check(worker.get_children().all(func(child): return not child is ModularCharacter), "office does not instantiate fullbody parts")
	worker.state = Worker.State.WALK; worker._update_visual(0.2)
	check(worker.body.animation == "walk", "world walking drives original pixel animation")
	worker.queue_free(); main.queue_free(); await get_tree().process_frame
	for slot in ["fullbody_qa_a","fullbody_qa_b"]:
		Game.save_slot = slot
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Game._save_path()))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.character_parts_path()))
	Game.running = false
	print("FULLBODY SAVE: %d checks, %d failures" % [checks,failures])
	await Audio.shutdown(); get_tree().quit(failures)
