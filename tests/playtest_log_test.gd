extends Node
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if ok: print("ok: ",message)
	else: failures += 1; push_error(message)
func _ready() -> void:
	Game.save_slot = "playtest_qa_normal"
	Game.new_game(); Game.running = true; Game.speed = 0
	var prior = PlaytestLog.data()["runs"].size()
	Game.accept_offer(Game.offers[0], "manual")
	PlaytestLog.start_session()
	check(PlaytestLog.current().is_empty() and PlaytestLog.data()["runs"].size() == prior, "normal play never opts in automatically")
	var id = PlaytestLog.create_run()
	Game.start(id); Game.speed = 0
	check(DemoCareer.active() and PlaytestLog.current()["sessions"] == 1, "opt-in creates a separate guided demo")
	var job = Game.offers[0]
	Game.accept_offer(job, "manual")
	Game.begin_idea_meeting(job); Game.idea_meeting["phase"] = "ready"
	var panel = IdeaJamPanel.new(); add_child(panel); panel.open()
	panel.preview(); panel.preview()
	var row = PlaytestLog.job_row(job)
	check(row["accepted"] and row["versions_heard"].size() == 1, "repeated preview counts one distinct arrangement")
	panel._set_tempo(100); panel.preview()
	check(row["versions_heard"].size() == 2, "changed tempo creates another preview variant")
	panel.find_child("SubmitIdea",true,false).pressed.emit()
	panel.review_open = false; panel.refresh()
	panel._set_tempo(105)
	check(row["reviews"] == 1 and row["edits_after_review"] == 1, "revision after review is recorded separately")
	panel.listen_comparison(true)
	check(row["comparisons"] == 1, "comparison action is recorded")
	panel.close(); panel.queue_free()
	PlaytestLog.ending(0)
	check(PlaytestLog.current()["return_visits"] == 0, "continue choice does not count as later return")
	PlaytestLog.released({"demo_index":2,"play_mode":"manual"})
	PlaytestLog.start_session()
	check(PlaytestLog.current()["return_visits"] == 1 and not PlaytestLog.current()["later_launch_return"], "same-launch revisit is distinct from a new app launch")
	PlaytestLog.boot_id = "simulated-next-app-launch"
	PlaytestLog.start_session()
	check(PlaytestLog.current()["later_launch_return"], "later app launch return is detected")
	PlaytestLog.answer("explore", 0); PlaytestLog.answer("next", 4); PlaytestLog.answer("return",5)
	check(PlaytestLog.current()["survey"]["explore"] == 0 and PlaytestLog.current()["survey"]["return"] == 5, "skipped answer is distinct from a low rating")
	PlaytestLog.cache = {}; PlaytestLog.loaded = false
	check(PlaytestLog.current()["survey"]["next"] == 4, "observations persist independently of game saves")
	PlaytestLog.current()["survey"] = {}
	var main = load("res://scenes/main.tscn").instantiate()
	main._booting = true
	add_child(main)
	main.login.hide()
	main._flow_demo_end()
	await get_tree().process_frame
	main.dialog.choice_selected.emit(0)
	await get_tree().process_frame
	check(main.dialog._options.size() == 6 and main.dialog.visible, "ending presents optional ratings with a skip choice")
	for choice in [5,3,4]:
		main.dialog.choice_selected.emit(choice)
		await get_tree().process_frame
	check(PlaytestLog.current()["survey"] == {"explore":0,"next":4,"return":5}, "ending stores skipped and rated answers through the real dialog")
	check(not main.dialog.visible, "survey closes and lets the player continue")
	main._queue.clear()
	main.queue_free()
	await get_tree().process_frame
	var exported = PlaytestLog.export_run(id)
	var output = FileAccess.get_file_as_string(exported)
	check(not output.contains(Game.studio_name) and not output.contains("idea_notes") and not output.contains("local_audio"), "export excludes identity and song content")
	var report = PlaytestPanel.new(); report.selected_id = id; report.can_launch = true; add_child(report); report.open()
	await get_tree().process_frame
	await get_tree().process_frame
	if "--visual" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_webp("D:/EP45/ndlp/Producers/playtest-report.webp", true)
	report.close(); report.queue_free()
	PlaytestLog.erase(id)
	check(PlaytestLog.current().is_empty() and not FileAccess.file_exists(exported), "deletion removes observations and generated export")
	PlaytestLog.answer("next", 1)
	check(not PlaytestLog.data()["runs"].has(id), "deleted run cannot silently resume logging")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game._save_path()))
	Game.running = false
	print("PLAYTEST LOG: %d checks, %d failures" % [checks,failures])
	await Audio.shutdown()
	get_tree().quit(failures)
