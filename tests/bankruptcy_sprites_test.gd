extends Node
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
func capture(stem: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if "--visual" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_webp("D:/EP45/ndlp/Producers/" + stem + ".webp", true)
func _ready() -> void:
	await get_tree().process_frame
	Game.save_slot = "bankruptcy_sprites_qa"
	Game.new_game()
	Game.tutorial_step = -1
	Game.tutorial_gate = false
	Game.running = true
	Game.speed = 0
	var main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	main._booting = true
	main.login.hide()
	Game._emit_all()
	for id in ["producer", "alice"] + Art.npc_ids + Art.vip_ids:
		var frames = Art.office_frames(id)
		for pose in ["idle", "walk", "talk", "play"]:
			check(frames.has_animation(pose) and frames.get_frame_count(pose) == 9, id + " " + pose)
	check(Office.ROOM_W == 640 and Office.FLOOR_H == 360, "rooms match native bodies")
	for front in main.office.foreground.get_children():
		check(front.scale * front.texture.get_size() == Vector2(640, 360), "foreground furniture matches room scale")
	await capture("office-native-cast")
	main.dialog.open(Game.player_portrait(), Game.assistant_portrait())
	main.dialog._show_line("right", "Pending monthly report")
	Game.money = 0
	check(not Game.check_bankruptcy(), "zero balance is allowed")
	Game.add_money(-1)
	check(not Game.running and Game.life.get("bankrupt",false), "negative balance immediately stops simulation")
	check(main._queue.is_empty() and not main.get_node("UI").visible, "reports and choices immediately hidden")
	await get_tree().process_frame
	await capture("business-game-over")
	check(get_tree().current_scene.name == "GameOver", "pending dialog replaced by dedicated game over")
	var amount = Game.money
	Game.add_money(10000)
	check(Game.money == amount, "failed business cannot recover via later payouts")
	Game.load_game()
	check(Game.money < 0 and Game.life.get("bankrupt",false), "failure persists in save")
	Game.new_game()
	check(Game.money > 0 and not Game.life.get("bankrupt",false), "new business clears failure")
	Game.money = -50
	Game.save_game(true)
	Game.start(Game.save_slot)
	check(not Game.running and Game.life.get("bankrupt",false), "legacy negative save also ends")
	get_tree().current_scene._restart()
	print("restart requested")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	check(Game.money > 0 and not Game.life.get("bankrupt",false), "game over restart opens a solvent new business")
	print("restart verified")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game._save_path()))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.character_parts_path()))
	Game.running = false
	print("BANKRUPTCY + SPRITES: ", failures, " failures")
	await Audio.shutdown()
	get_tree().quit(failures)
