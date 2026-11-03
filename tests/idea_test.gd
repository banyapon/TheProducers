extends Node
var main: Node
var checks := 0
var failures := 0
var visual := false
var original_language := ""

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
	else: print("  ok  ",message)

func frame(label: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if visual:
		await RenderingServer.frame_post_draw
		var qa_dir = OS.get_environment("PRODUCERS_QA_DIR")
		if qa_dir == "": qa_dir = ProjectSettings.globalize_path("user://qa")
		DirAccess.make_dir_recursive_absolute(qa_dir)
		get_viewport().get_texture().get_image().save_webp(qa_dir.path_join("idea-" + label + ".webp"),true)

func drag(from: Vector2, to: Vector2) -> void:
	var motion = InputEventMouseMotion.new()
	motion.position = from
	get_viewport().push_input(motion,true)
	var down = InputEventMouseButton.new()
	down.position = from
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	get_viewport().push_input(down,true)
	await get_tree().process_frame
	for pos in [from+Vector2(25,0),to]:
		motion = InputEventMouseMotion.new()
		motion.position = pos
		motion.relative = pos-from
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		get_viewport().push_input(motion,true)
		await get_tree().process_frame
	var up = InputEventMouseButton.new()
	up.position = to
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	get_viewport().push_input(up,true)
	await get_tree().process_frame

func _ready() -> void:
	original_language = Locale.language
	Locale.set_language("en")
	visual = "--visual" in OS.get_cmdline_user_args()
	if visual:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1600,900))
		DisplayServer.window_set_title("The Producers · Idea Maker QA")
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	main.login.hide()
	main._booting = true
	Game.save_slot = "idea_qa"
	Game.new_game()
	Game.running = true
	Game.intro_seen = true
	Game.identity_initialized = true
	Game.money = 150000
	Game.speed = 0
	Game._emit_all()
	await frame("tutorial")
	check(main.coach.visible and Game.tutorial_gate, "first-song Alice coach appears and holds the setup calendar")
	Locale.set_language("th")
	await frame("tutorial-th")
	Locale.set_language("en")
	check(Game.offers[0]["mix"] == {"Pop":100}, "first tutorial commission has an explicit Pop brief")
	for value in [1,2,4]:
		check(main.hud.speed_buttons[value].text == "x%d" % value, "speed text uses clear ASCII x%d" % value)
		main.hud.speed_buttons[value].pressed.emit()
		check(Game.speed == value, "speed button selects its actual multiplier")
	for key in main.hud.action_buttons:
		if key != "alice": check(main.hud.action_buttons[key].icon != null,"menu icon exists: "+key)
	Game.speed = 0
	main.coach.finish()
	var job: Dictionary = Game.offers[0]
	Game.accept_offer(job)
	var before_day = Game.day
	check(Game.begin_idea_meeting(job) == "", "idea meeting starts in the existing Lounge")
	check(main.jam.visible and Game.idea_meeting["participants"].size() == Game.staff.size()+2, "Producer, Alice and every musician are included")
	check(not main.jam.body_root.visible, "composer leaves the office unobscured while participants gather")
	check(Game.is_researching(Game.staff[0]["id"]) and Game.is_researching("producer"), "all meeting participants are reserved")
	check(Game.start_project(job["id"],[Game.staff[0]["id"]],job["mix"],"Blocked") == Locale.text("jam_busy"), "recording cannot interrupt a meeting")
	await frame("gathering")
	for i in 240:
		for actor in main.office.workers.values()+main.office.principals.values(): actor._process(0.1)
		if main.office.meeting_ready(): break
	main.jam._process(0.1)
	check(main.office.meeting_ready() and Game.idea_meeting["phase"] == "ready", "everyone actually walks to the Lounge before puzzle readiness")
	check(main.jam.body_root.visible, "composer opens only after every participant arrives")
	check(Game.day == before_day,"gathering does not advance the calendar")
	await frame("ready")
	check(Game.idea_meeting.get("freeform", false), "manual uses freeform composition")
	var source = main.jam.find_child("IdeaBlock0", true, false)
	var target = main.jam.find_child("Lane2Step0", true, false)
	await drag(source.get_global_rect().get_center(), target.get_global_rect().get_center())
	check(Game.idea_meeting["placed"].size() == 1, "real pointer drag accepts any instrument lane")
	source = main.jam.find_child("IdeaBlock0", true, false)
	target = main.jam.find_child("Lane0Step1", true, false)
	await drag(source.get_global_rect().get_center(), target.get_global_rect().get_center())
	check(Game.idea_meeting["placed"].size() == 2, "palette clips can be reused")
	source = main.jam.find_child("Lane2Step0", true, false)
	target = main.jam.find_child("Lane3Step7", true, false)
	await drag(source.get_global_rect().get_center(), target.get_global_rect().get_center())
	check(Game.idea_meeting["placed"].size() == 2 and Game.idea_meeting["placed"].back()["col"] == 7, "dragging a placed clip moves it across lanes without duplication")
	check(Game.place_idea(1, 3, 7) and Game.idea_meeting["placed"].size() == 2, "replacement keeps one clip per cell")
	var saved_arrangement = Game.idea_meeting.duplicate(true)
	for entry in ["studio", "alice"]:
		main.jam.close()
		main._on_hud_panel_requested(entry)
		check(main.jam.visible and Game.idea_meeting == saved_arrangement, "closed composer resumes unchanged via " + entry)
		check(Game._pause_requests == 1, "resuming keeps one modal pause owner")
	main.jam.close()
	main._on_office_room_clicked(0, 0, "lounge")
	check(main.jam.visible and Game.idea_meeting == saved_arrangement, "clicking Lounge resumes existing arrangement")
	main.jam.close()
	check(Game.begin_idea_meeting(job) == "" and main.jam.visible and Game.idea_meeting == saved_arrangement, "Manual action resumes same job without resetting clips or phase")
	var other_job: Dictionary = Game.offers[0]
	Game.accept_offer(other_job)
	check(Game.begin_idea_meeting(other_job) == Locale.text("jam_busy") and Game.idea_meeting == saved_arrangement, "another job cannot replace the unfinished arrangement")
	check(not Game.place_idea(0, 4, 0) and not Game.place_idea(0, 0, 8), "out of bounds placement rejected")
	main.jam._process(200.0)
	check(not Game.idea_meeting.is_empty() and Game.day == before_day, "no countdown or calendar cost while composing")
	Game.idea_meeting["placed"] = []
	for lane in 4:
		for col in 4: Game.place_idea(0, lane, col)
	check(IdeaRules.score(Game.idea_meeting)["score"] < 100, "filling the grid alone does not guarantee perfect suitability")
	main.jam.refresh()
	main.jam.find_child("ComposerTempo", true, false).value = 90
	main.jam.preview()
	check(main.jam.player.stream is AudioStreamWAV and main.jam.player.stream.get_length() > 20, "eight-bar preview follows tempo")
	await frame("arrangement")
	Locale.set_language("th")
	await frame("arrangement-th")
	Game.save_game()
	check(Game.load_game() and Game.idea_meeting["placed"].size() == 16 and Game.idea_meeting["bpm"] == 90, "arrangement and tempo survive save/load")
	var result = Game.finish_idea_meeting()
	job = Game.get_job(job["id"])
	check(result["score"] <= 100 and job["idea"] == result["idea"] and job["idea_bpm"] == 90, "saved composition supplies earned gameplay bonus and tempo")
	check(not job["idea_notes"].is_empty() and job["arrangement"]["placed"].size() == 16, "musical output and editable arrangement persisted")
	var midi = FileAccess.get_file_as_bytes(job["idea_midi"])
	check(midi.slice(0, 4).get_string_from_ascii() == "MThd", "valid MIDI exported")
	check(Game.begin_idea_meeting(job) == Locale.text("jam_once"), "idea farming blocked")
	Game.running = false
	main._queue.clear()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game._save_path()))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(job["idea_midi"]))
	Locale.set_language(original_language)
	print("IDEA TESTS: %d checks, %d failures" % [checks, failures])
	await Audio.shutdown()
	get_tree().quit(1 if failures else 0)
