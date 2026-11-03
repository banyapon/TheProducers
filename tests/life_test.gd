extends Node
var checks := 0
var failures := 0
var main: Node
var visual := false
var server := TCPServer.new()
var peer: StreamPeerTCP
var served := false
var old_language: String
var old_levels: Dictionary

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok: print("  ok  ", message)
	else: failures += 1; push_error(message)

func frame(label: String = "") -> void:
	if visual and label != "" and main != null and main.dialog.visible:
		if main.dialog._tween: main.dialog._tween.kill()
		main.dialog.text_label.visible_ratio = 1
	await get_tree().process_frame
	await get_tree().process_frame
	if visual and label != "":
		await RenderingServer.frame_post_draw
		var dir = OS.get_environment("PRODUCERS_QA_DIR")
		if dir == "": dir = ProjectSettings.globalize_path("user://qa")
		DirAccess.make_dir_recursive_absolute(dir)
		get_viewport().get_texture().get_image().save_webp(dir.path_join("life-" + label + ".webp"), true)

func _process(_delta: float) -> void:
	if server.is_listening() and server.is_connection_available(): peer = server.take_connection()
	if peer:
		peer.poll()
		if not served and peer.get_available_bytes() > 0:
			var request = peer.get_utf8_string(peer.get_available_bytes())
			check(request.contains("GET /song.mp3"), "cloud playback requests converted MP3 URL")
			var bytes = FileAccess.get_file_as_bytes("res://assets/sfx/reward.mp3")
			peer.put_data(("HTTP/1.1 200 OK\r\nContent-Type: audio/mpeg\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % bytes.size()).to_utf8_buffer())
			peer.put_data(bytes)
			served = true

func _ready() -> void:
	check(Locale.display_game_text("Alice \u00b7 Guide") == "Alice | Guide", "middle-dot separator renders as pipe")
	check(Locale.display_game_text("A \u00c2\u00b7 B") == "A | B", "legacy corrupted separator is normalized")
	check(Locale.display_game_text("ท ทานอาหาร ทำงาน") == "ท ทานอาหาร ทำงาน", "real Thai letters remain unchanged")
	var original_relationship_mode = Locale.relationship_mode
	Locale.relationship_mode = "all_genders"
	seed(40267)
	old_language = Locale.language
	old_levels = Audio.levels.duplicate()
	Locale.set_language("en")
	visual = "--visual" in OS.get_cmdline_user_args()
	if visual:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1600,900))
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	main._booting = true
	await frame()
	Game.save_slot = "life_qa"
	Game.new_game()
	Game.running = true
	Game.speed = 0
	Game.tutorial_step = -1
	Game.intro_seen = true
	Game.money = 200000
	Game._emit_all()
	main.login.hide()
	await frame("compact-toolbar")
	check(main.hud.get_node("TopToolbar").size.y < 140, "top toolbar is shorter with larger left-side labels")
	check(main.hud.get_node("BottomToolbar").size.y <= 80, "bottom toolbar uses a compact 80-pixel height")
	check(main.hud.action_buttons.has("staff"), "HUD exposes a dedicated Staff button")
	main.hud.action_buttons["staff"].pressed.emit()
	await frame("staff-en")
	check(main.staff_panel.visible and main.staff_panel.find_child("Call_alice",true,false) != null, "Staff grid includes Alice and individual call controls")
	check(main.staff_panel.get_minimum_size().y <= 1080, "Staff grid fits without vertical scrolling")
	main._booting = false
	main.staff_panel.find_child("Call_alice",true,false).pressed.emit()
	await frame()
	check(main.dialog.visible and main.dialog._options.size() == 3, "calling Alice opens her own conversation")
	main.dialog.choices_box.get_node("DialogChoice1").pressed.emit()
	await frame()
	check(main.dialog.text_label.text == StudioCity.alice_status(), "Alice explains the award requirement through the Staff dialog")
	main.dialog.text_label.visible_ratio = 1
	main.dialog._advance()
	await frame()
	main._booting = true
	main.staff_panel.close()
	var ui_offer: Dictionary = Game.offers[0]
	main._flow_offer(ui_offer, false, "")
	main.dialog.text_label.visible_ratio = 1; main.dialog._advance()
	await frame()
	main.dialog.choices_box.get_node("DialogChoice0").pressed.emit()
	await frame("mode-selection")
	check(main.dialog._options == [Locale.text("play_manual"),Locale.text("play_auto"),Locale.text("back")], "real offer acceptance presents Manual and Auto")
	check(main.dialog.alice_portrait.visible, "Alice is visible beside the client while explaining the workflow")
	main.dialog.choices_box.get_node("DialogChoice1").pressed.emit()
	await frame()
	for n in 2:
		main.dialog.text_label.visible_ratio = 1; main.dialog._advance()
		await frame()
	check(ui_offer["play_mode"] == "auto" and not main.jam.visible, "selecting Auto in the dialog accepts without opening the puzzle")
	var job: Dictionary = Game.offers[0]
	Game.accept_offer(job, "auto")
	check(job["play_mode"] == "auto" and job["idea_rounds"] == 1 and not job["idea_notes"].is_empty(), "Auto accepts the brief and produces an actual music arrangement")
	check(job["idea"] <= 15 and Game.idea_meeting.is_empty(), "Auto has a reduced idea bonus and never opens a timed puzzle")
	var manual: Dictionary = Game.offers[0]
	Game.accept_offer(manual, "manual")
	check(manual["play_mode"] == "manual" and not manual.has("idea_rounds"), "Manual preserves the interactive idea round")
	check(Game.begin_idea_meeting(manual) == "", "Manual launches the Lounge gathering")
	Game.cancel_idea_meeting()
	var a: Dictionary = Game.staff[0]
	var b: Dictionary = Game.staff[1]
	check(StudioLife.socialize("alice", "flirt") == StudioCity.alice_status(), "Alice romance requires award achievement")
	check(Game.get_artist("alice").is_empty(), "Alice cannot enter the staff dating pool")
	check(StudioLife.socialize(a["id"], "flirt") == Locale.text("romance_locked"), "romance is locked during the first four months")
	var trust = a["social"]["trust"]
	StudioLife.socialize(a["id"], "talk")
	check(a["social"]["trust"] > trust, "conversation increases trust")
	check(StudioLife.socialize(a["id"], "party") == Locale.text("city_daily_limit"), "repeated same-day interactions are blocked")
	Game.day += 1
	var cash = Game.money
	StudioLife.socialize(a["id"], "party")
	check(Game.money == cash - 350 and a["social"]["comfort"] > 15, "party costs cash and improves comfort")
	var before = int(a["skills"].get("Pop",0))
	check(StudioLife.train(a,"Pop") == Locale.text("training_sent",[a["name"],"Pop",7]), "training enrollment succeeds")
	check(not main.office.workers[a["id"]].visible, "artist leaves the studio during training")
	Game.save_game()
	Game.life = {}
	check(Game.load_game() and not StudioLife.training(a["id"]).is_empty(), "ongoing training survives a save/load")
	a = Game.get_artist(a["id"]); b = Game.get_artist(b["id"])
	manual = Game.get_job(manual["id"])
	# Isolate staff availability from the newer Manual-composition prerequisite.
	manual["idea_rounds"] = 1
	check(Game.start_project(manual["id"],[a["id"]],manual["mix"],"Unavailable") == Locale.text("artist_busy"), "training artist cannot record")
	check(Game.schedule_project(manual["id"],[a["id"]],manual["mix"],"Overlap",Game.day+1) == Locale.text("artist_busy"), "training artist cannot be booked before returning")
	Game.day += 7
	StudioLife.tick_day()
	check(StudioLife.training(a["id"]).is_empty() and a["skills"]["Pop"] == mini(100,before+8), "training completes once and increases the selected genre")
	check(main.office.workers[a["id"]].visible, "trained artist returns to the studio")
	Game.day = 112
	check(not StudioLife.pair_staff(a,b), "staff cannot date before more than four months")
	Game.day = 113
	for person in [a,b]: person["social"]["interested"] = true
	b["gender"] = a["gender"]
	check(StudioLife.pair_staff(a,b), "same-gender staff can choose to date after month four")
	check(a["social"]["partner"] == b["id"] and b["social"]["partner"] == a["id"], "staff partnership is reciprocal")
	for person in [a,b]: person["social"]["partner"] = ""
	b["gender"] = "female" if a["gender"] == "male" else "male"
	check(StudioLife.pair_staff(a,b), "different-gender staff can also date")
	Game.release_artist(b)
	check(a["social"]["partner"] == "", "departing staff clear their partner's relationship")
	a["social"]["trust"] = 60; a["social"]["comfort"] = 60; a["social"]["last_day"] = -99
	for n in 7:
		Game.day += 1
		StudioLife.socialize(a["id"], "flirt")
	check(a["social"]["partner"] == "producer", "player romance requires trust, comfort, compatibility and several visits")
	a["met"] = true; a["auto_renew"] = true; a["weeks_left"] = 1
	Game._advance_week()
	check(a["weeks_left"] == 1, "partner contract countdown is frozen without renewal charges")
	a["social"]["partner"] = ""
	Game.money = 0; a["weeks_left"] = 1
	var expired: Array = []
	Game.contract_expired.connect(func(person: Dictionary): expired.append(person["id"]))
	Game._advance_week()
	check(expired.has(a["id"]) and a["weeks_left"] == 0, "insufficient renewal funds route back to the player's decision")
	Game.money = 20000
	Game.day = 140
	StudioLife.tick_day()
	check(Game.life["feedback"].has(5), "monthly feedback is queued at the start of the next month")
	var fame = Game.fame; var reputation = Game.reputation
	var feedback = StudioLife.feedback(5)
	StudioLife.resolve_feedback(5,1)
	check(Game.fame == fame + feedback["choices"][1]["fame"] and Game.reputation == reputation + feedback["choices"][1]["reputation"], "feedback choices change Fame and Reputation independently")
	check(StudioLife.resolve_feedback(5,1) == Locale.text("feedback_resolved"), "monthly feedback cannot be claimed twice")
	Game.save_game()
	Game.life = {}
	check(Game.load_game() and Game.life["resolved_month"] == 5 and Game.staff[0]["auto_renew"], "relationships, monthly reports and renewal preference survive save/load")
	main._queue.clear()
	for lang in ["en","th"]:
		while Game.staff.size() < 6:
			var recruit = Game.generate_artist(0.5)
			recruit["weeks_left"] = 12
			Game.staff.append(recruit)
		StudioLife.migrate()
		Locale.set_language(lang)
		main.staff_panel.open()
		await frame("staff-"+lang)
		main.staff_panel.close()
		main.shell.open()
		await frame("options-"+lang)
		check(main.shell.find_child("VolumeBGM",true,false) is HSlider, "Options exposes BGM slider: "+lang)
		main.shell.find_child("OpenCredits",true,false).pressed.emit()
		await frame("credits-game-"+lang)
		check(main.shell.page == "credits" and Game.is_paused(), "in-game credits retain modal pause: "+lang)
		main.shell.find_child("CreditsBack",true,false).pressed.emit()
		main.shell.close()
		main.login._page = "options"; main.login.show(); main.login._render()
		await frame("title-options-"+lang)
		check(main.login.find_child("VolumeSFX",true,false) is HSlider, "title Options exposes SFX slider: "+lang)
		main.login.find_child("OpenCredits",true,false).pressed.emit()
		await frame("credits-title-"+lang)
		check(main.login._page == "credits" and Locale.values("credits_audio_entries").size() == 4, "title credits contain four credited sound works: "+lang)
		main.login.escape()
		check(main.login._page == "options", "ESC returns credits to title Options: "+lang)
		main.login.hide()
	Game.life["feedback"].append(6)
	main._flow_monthly_feedback(6)
	main.dialog.text_label.visible_ratio = 1
	await frame("monthly-feedback")
	check(main.dialog._options.size() == 3, "Alice's monthly conversation offers three decisions")
	main.dialog.choices_box.get_node("DialogChoice0").pressed.emit()
	await frame()
	main.dialog.text_label.visible_ratio = 1
	main.dialog._advance()
	await frame()
	check(not main.dialog.visible and not Game.life["feedback"].has(6), "monthly decision closes and is consumed through real dialog buttons")
	Audio.set_level("BGM",0.27)
	var cfg = ConfigFile.new(); cfg.load("user://audio.cfg")
	check(is_equal_approx(cfg.get_value("audio","BGM"),0.27), "volume changes persist independently of game saves")
	Audio.set_level("SFX",0)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), "zero SFX volume mutes effects and ambience")
	check(Audio.playlist.size() == 2 and not Audio.playlist.any(func(path: String): return path.ends_with("title.mp3")), "game playlist excludes the title song")
	Audio._next_bgm(); var last = Audio._last_track; Audio._next_bgm()
	check(Audio._last_track != last, "random playlist avoids repeating the previous song")
	Game.idea_meeting = {"phase":"playing"}
	Audio._process(0.1)
	check(Audio.workshop_quiet and (not Audio.bgm.playing or Audio.bgm.stream_paused) and (not Audio.ambient.playing or Audio.ambient.stream_paused), "timed workshop silences background music and meeting ambience")
	Game.idea_meeting = {}
	Audio._process(0.1)
	for effect in ["click","success","reward","fail"]:
		Audio.sfx(effect)
		check((Audio.clicks if effect == "click" else Audio.effects).playing, "one-shot sound starts: "+effect)
	check(server.listen(18764,"127.0.0.1") == OK, "local cloud-audio fixture starts")
	var song = {"id":"cloud_fixture","title":"Cloud Fixture","audio_url":"http://127.0.0.1:18764/song.wav","rating":40}
	Game.songs.append(song)
	Game.trophies.append({"edition":1,"song_id":song["id"],"song":song["title"],"rating":40})
	main.planner.tab = 3; main.planner.open()
	await frame("trophy-cloud")
	var cloud_button = main.planner.find_child("TrophyCloudPlay",true,false)
	check(cloud_button != null and not cloud_button.disabled, "Trophy card exposes enabled cloud playback for its own song")
	cloud_button.pressed.emit()
	var timeout = Time.get_ticks_msec()+4000
	while not Audio.preview.playing and Time.get_ticks_msec()<timeout: await get_tree().process_frame
	check(served and Audio.preview.playing and Audio.preview.stream is AudioStreamMP3, "Trophy click downloads and plays real MP3 bytes through cloud playback")
	check(Audio.bgm.volume_db == -24, "song preview ducks the background music")
	main.planner.close()
	check(not Audio.preview.playing and Audio.bgm.volume_db == 0, "closing Trophy stops preview and restores BGM")
	if peer: peer.disconnect_from_host()
	server.stop()
	if visual:
		Locale.set_language("th")
		main.dialog.open(main.PLAYER, main._alice_portrait())
		main.dialog._show_line("right", "กำลังทำงาน — คำแนะนำ — ทำเพลงสำเร็จ\nน้ำ กำ จำ ดำ ต่ำ ย้ำ ช้ำ")
		await frame("font-thai-sara-am")
		main.dialog.close()
	Game.running = false
	main._queue.clear()
	for bus in old_levels: Audio.set_level(bus,old_levels[bus])
	Locale.set_language(old_language)
	Locale.relationship_mode = original_relationship_mode
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game._save_path()))
	print("LIFE/AUDIO TESTS: %d checks, %d failures" % [checks,failures])
	await Audio.shutdown()
	get_tree().quit(1 if failures else 0)
