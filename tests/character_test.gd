extends Node
var failures := 0
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
	else: print("ok: ", message)

func _ready() -> void:
	var language = Locale.language
	Locale.language = "th"
	Game.save_slot = "character_qa"
	Game.new_game()
	Game.running = true
	Game.speed = 0
	check(Game.player_character == "producer", "new game defaults to Producer")
	var main = load("res://scenes/main.tscn").instantiate()
	main._booting = true
	add_child(main)
	main.login.hide()
	main.shell.open("identity")
	main.shell.find_child("ChooseAlice", true, false).pressed.emit()
	await get_tree().process_frame
	check(main.shell._character == "alice" and main.shell._producer == "Alice", "selection updates character and suggested name")
	if "--visual" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_webp("D:/EP45/ndlp/Producers/character-choice.webp")
	check(Game.set_identity("มิน", "QA Studio", "alice"), "Alice identity accepted with custom name")
	check(Game.player_portrait()["art_id"] == "alice" and Game.player_portrait()["gender"] == "female", "Alice is the player")
	check(StudioCity.alice()["art_id"] == "producer" and StudioCity.alice()["name"] == "Producer", "assistant identity is swapped in social systems")
	check(main.office.principals["producer"]._art_id == "alice" and main.office.principals["alice"]._art_id == "producer", "office actors swap roles")
	main.dialog.open(main.PLAYER, Game.assistant_portrait())
	main.dialog._show_line("right", Locale.line("intro_3", {"producer": Game.producer_name}))
	check(main.dialog.speaker_label.text == "Producer", "assistant speaker name")
	check(main.dialog.text_label.text.contains("พี่ Producer") and main.dialog.text_label.text.contains("มิน") and not main.dialog.text_label.text.contains("เธอ"), "Producer uses พี่ and custom player name")
	main.dialog._show_line("alice", "พี่คะ ฉันช่วยดูงานให้ค่ะ")
	check(main.dialog.text_label.text == "มินครับ พี่ช่วยดูงานให้ครับ", "adviser speech preserves requested first person")
	check(Locale.assistant_line(main.dialog.text_label.text) == main.dialog.text_label.text, "formatted dialogue is not rewritten twice")
	var original_mode = Locale.relationship_mode
	Locale.relationship_mode = "different_gender"
	check(RelationshipOptions.allows_city_companion(StudioCity.alice()), "male assistant available in default mode for Alice player")
	check(not StudioCity.alice()["romance_unlocked"], "assistant romance initially locked")
	for i in 4: Game.trophies.append({"song_id": "award%d" % i, "rating": 30, "win": true})
	Game.trophies.append({"song_id": "award0", "rating": 40, "win": true})
	Game.trophies.append({"song_id": "low", "rating": 29, "win": true})
	check(not StudioCity.alice()["romance_unlocked"], "four songs, duplicate awards and low score do not unlock romance")
	Game.trophies.append({"song_id": "award4", "rating": 30, "win": true})
	check(StudioCity.alice()["romance_unlocked"], "five distinct winning songs at 30/40 unlock male assistant")
	check(StudioCity.date_reason(StudioCity.alice(), false) == "", "male assistant can be dated after award unlock")
	Locale.relationship_mode = original_mode
	check(main.dialog.alice_portrait.art_id == "producer", "adviser portrait is Producer")
	check(Game.load_game() and Game.player_character == "alice", "choice survives save/load")
	var path = Game._save_path()
	var saved = FileAccess.open(path, FileAccess.READ).get_var()
	saved.erase("player_character")
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_var(saved)
	file.close()
	check(Game.load_game() and Game.player_character == "producer", "legacy saves default to Producer")
	check(StudioCity.alice()["name"] == "Alice", "legacy assistant remains Alice")
	check(not Game.set_identity("Valid", "Studio", "invalid"), "invalid role rejected")
	Game.running = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Locale.language = language
	print("CHARACTER TESTS: %d checks, %d failures" % [checks, failures])
	await Audio.shutdown()
	get_tree().quit(1 if failures else 0)
