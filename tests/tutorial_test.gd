extends Node
var main: Node
var checks := 0
var failures := 0
var old_language := ""
func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("  ok  ",label)
	else:
		failures += 1
		push_error(label)

func tick() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

func advance() -> void:
	main.dialog.text_label.visible_ratio = 1
	main.dialog._advance()
	await tick()

func _ready() -> void:
	seed(78623)
	old_language = Locale.language
	Locale.set_language("en")
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await tick()
	main.login.hide()
	Game.save_slot = "tutorial_qa"
	Game.new_game()
	Game.running = true
	Game.intro_seen = true
	Game.identity_initialized = true
	Game.speed = 1
	Game._emit_all()
	await tick()
	check(main.coach.visible and main.coach.target == main.hud.action_buttons["jobs"],"tutorial points to actual commission button")
	main.hud.action_buttons["jobs"].pressed.emit()
	await tick()
	var talk = main.coach._button(main.job_board,Locale.text("talk"))
	check(talk != null and main.coach.target == talk,"tutorial targets a real commission action")
	talk.pressed.emit()
	await tick()
	check(main.dialog.visible,"commission conversation opens through tutorial action")
	await advance()
	check(main.dialog._options.size() == 6,"contract choices are available through compact paged dialog")
	main.dialog.choices_box.get_node("DialogChoice0").pressed.emit()
	await tick()
	check(main.dialog._options.size() == 3, "acceptance asks Manual, Auto or Back")
	main.dialog.choices_box.get_node("DialogChoice0").pressed.emit()
	await tick()
	await advance()
	await advance()
	check(Game.jobs.size() == 1 and main.planner.visible,"Manual acceptance opens Alice Timeline directly")
	await tick()
	var job: Dictionary = Game.jobs[0]
	var jam = main.planner.find_child("Jam_"+job["id"],true,false)
	check(jam != null and main.coach.target == jam,"Alice highlights the idea meeting for the accepted brief")
	jam.pressed.emit()
	await tick()
	for i in 240:
		for actor in main.office.workers.values()+main.office.principals.values(): actor._process(0.1)
		if main.office.meeting_ready(): break
	main.jam._process(0.1)
	await tick()
	check(main.coach.target == main.jam.find_child("ComposerGenre", true, false), "coach points to freeform genre selector")
	for i in 4:
		for col in 4:
			Game.place_idea(0, i, col)
	main.jam.refresh()
	await tick()
	check(main.coach.target == main.jam.find_child("SubmitIdea",true,false),"coach highlights submission after arranging the four tutorial clips")
	main.jam.find_child("SubmitIdea",true,false).pressed.emit()
	await tick()
	if main.dialog.visible: await advance()
	check(job.get("idea_score",0) == 100 and Game.tutorial_step == 2,"first idea puzzle advances guide to production planning")
	main.hud.action_buttons["alice"].pressed.emit()
	await tick()
	main.planner.find_child("PlanDelay1",true,false).pressed.emit()
	await tick()
	main.coach._button(main.planner,Locale.text("close")).pressed.emit()
	main.hud.action_buttons["studio"].pressed.emit()
	await tick()
	for checkbox in main.production._checks.values(): checkbox.button_pressed = true
	await tick()
	check(main.coach.target == main.production.find_child("StartBtn",true,false),"guide points to booking after selecting the band")
	main.production.find_child("StartBtn",true,false).pressed.emit()
	await tick()
	check(Game.production_queue.size() == 1 and Game.tutorial_step == 3 and not Game.tutorial_gate,"booking releases the setup calendar gate")
	Game._advance_day()
	await tick()
	check(not Game.project.is_empty() and Game.tutorial_step == 4,"booked session starts and guide changes to recording")
	for i in 30:
		if Game.project.get("done",false): break
		Game._tick_all_projects()
	await tick()
	check(main.release_panel.visible and main.coach.target == main.release_panel.marketing_box.get_child(0),"guide highlights the free release plan")
	main.release_panel.marketing_box.get_child(0).pressed.emit()
	await tick()
	check(Game.songs.size() == 1 and Game.tutorial_step == 5,"release advances to congratulations, even during Alice's invoice report")
	main.coach.finish()
	check(Game.tutorial_step == -1 and not Game.tutorial_gate,"Done permanently finishes the first-song guide")
	var song: Dictionary = Game.songs[0]
	var timeout = Time.get_ticks_msec()+10000
	while song["local_audio"] == "" and Time.get_ticks_msec()<timeout: await get_tree().process_frame
	check(song["local_audio"] != "","tutorial release finishes local arrangement audio generation")
	Game.save_game()
	Game.tutorial_step = 0
	check(Game.load_game() and Game.tutorial_step == -1,"finished tutorial state persists")
	Game.running = false
	main._queue.clear()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game._save_path()))
	for key in ["idea_midi","local_audio","local_cover"]:
		if str(song.get(key,"")) != "": DirAccess.remove_absolute(ProjectSettings.globalize_path(song[key]))
	Locale.set_language(old_language)
	print("TUTORIAL TESTS: %d checks, %d failures" % [checks,failures])
	await Audio.shutdown()
	get_tree().quit(1 if failures else 0)
