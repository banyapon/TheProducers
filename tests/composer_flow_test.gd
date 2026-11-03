extends Node
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("ok: ", label)
	else: failures += 1; push_error(label)
func capture(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not "--visual" in OS.get_cmdline_user_args(): return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_webp("D:/EP45/ndlp/Producers/flow-" + name + ".webp", true)
func _ready() -> void:
	Game.save_slot = "composer_flow_qa"
	Game.new_game(); DemoCareer.setup()
	Game.running = true; Game.speed = 0
	check(DemoCareer.next_step()["action"] == "brief", "demo starts with one actionable brief")
	var hud = Hud.new(); add_child(hud)
	await capture("objective")
	check(hud.demo_card.visible and not hud.action_buttons["city"].visible, "early demo shows next step and defers secondary menus")
	var job = Game.offers[0]
	Game.accept_offer(job, "manual")
	check(DemoCareer.next_step()["action"] == "compose", "accepted Manual points to composer")
	check(Game.begin_idea_meeting(job) == "", "demo can gather for composition")
	var m = Game.idea_meeting
	check(m["placed"].size() == 16 and m["bpm"] == 95, "first lesson supplies editable starter")
	check(m["placed"][0]["block"] != m["placed"][2]["block"], "starter cells are independently editable")
	var original = ComposerFlow.snapshot(m)
	ComposerFlow.prepare(m, job)
	check(ComposerFlow.snapshot(m) == original, "reopening never reseeds the draft")
	m["phase"] = "ready"
	var panel = IdeaJamPanel.new(); add_child(panel); panel.open()
	await capture("basic")
	check(not panel.pitch_button.visible and not panel.market_open, "first lesson hides technical tuning and market choices")
	var old_language = Locale.language
	Locale.set_language("th")
	panel.refresh()
	await capture("basic-th")
	Locale.set_language(old_language)
	var score_before = IdeaRules.score(m)["score"]
	var light = -1
	for clip in m["deck"]:
		if clip.get("palette", false) and clip["genre"] == "Lofi" and clip["style"] == 2: light = clip["id"]; break
	for col in 8: panel.place(light, 3, col)
	await get_tree().process_frame
	check(IdeaRules.score(m)["score"] > score_before, "softening drums improves cafe suitability")
	check(ComposerFlow.preview_state(m,true,-1,[]) == original, "comparison preserves original sound")
	var solo = ComposerFlow.preview_state(m,false,3,[])
	check(solo["placed"].size() == 8 and solo["placed"].all(func(p): return p["row"] == 3), "solo filters only playback")
	check(ComposerFlow.preview_state(m,false,-1,[3])["placed"].size() == 8 and m["placed"].size() == 16, "mute never changes arrangement or scoring")
	panel.listen_comparison(true)
	check(panel.player.playing and panel.compare_before, "before comparison plays")
	var before_pcm: PackedByteArray = panel.player.stream.data
	panel.listen_comparison(false)
	check(panel.player.playing and not panel.compare_before, "after comparison plays")
	check(panel.player.stream.data != before_pcm, "drum revision produces different audio, not just a different score")
	panel.place(light, 3, 7)
	check(panel.player.playing and panel._pending_audio, "editing during playback queues a beat-boundary update")
	panel.player.seek(panel._audio_boundary * 60.0 / panel._preview_bpm)
	panel._process(0.0)
	check(not panel._pending_audio, "queued audio edit is applied at the next beat")
	panel.stop_playback()
	panel.clear_song(); panel.undo()
	check(m["placed"].size() == 16, "starting empty can be undone")
	panel.save_reference()
	check(m["listening_reference"] == ComposerFlow.snapshot(m), "player can replace comparison reference explicitly")
	panel.advanced = true; panel.inspected = m["placed"][0]["block"]; panel.refresh()
	await capture("advanced")
	var submit_control = panel.find_child("SubmitIdea",true,false)
	check(submit_control.get_global_rect().end.y <= get_viewport().get_visible_rect().end.y, "advanced submit stays inside the viewport")
	panel.find_child("SubmitIdea",true,false).pressed.emit()
	await capture("review")
	check(panel.review_open and int(job.get("idea_rounds",0)) == 0, "draft review does not commit or grant rewards")
	panel.review_details = true; panel.refresh()
	await capture("review-details")
	Game.save_game(); Game.load_game()
	check(Game.idea_meeting.has("listening_reference"), "comparison survives save and reload")
	panel.submit()
	check(DemoCareer.next_step()["action"] == "record", "confirmed arrangement points to team selection")
	panel.close(); panel.queue_free()
	job = Game.get_job(job["id"])
	var production = load("res://scenes/ui/production_panel.tscn").instantiate()
	add_child(production); production.open(); production.select_job(job["id"])
	check(production.current_mix() == ComposerFlow.arrangement_mix(job), "recording carries actual arrangement mix without re-entry")
	check(not production.find_child("MixRow1",true,false).visible, "manual recording hides duplicate genre controls")
	check(not production.selected_team_ids().is_empty(), "demo suggests a recording team for review")
	await capture("recording")
	production.close(); production.queue_free()
	var ids = Game.staff.map(func(a): return a["id"])
	check(Game.start_project(job["id"], ids, job["mix"], "Demo flow") == "", "recording starts after confirmed arrangement")
	check(DemoCareer.next_step()["action"] == "recording", "objective follows active recording")
	var before_offers = Game.offers.size()
	for n in 30: Game._advance_day()
	check(Game.offers.size() == before_offers and not StudioCity.fire_active(), "guided demo avoids random walk-ins and fires")
	check(Game.life.get("feedback", []).is_empty() and StudioStars.data()["offers"].is_empty(), "guided demo defers monthly reports and brand offers")
	check(DemoCareer.next_step()["action"] == "release", "completed recording points to release")
	Game.release_project(0)
	check(DemoCareer.next_step()["index"] == 1 and DemoCareer.next_step()["action"] == "brief", "release advances objective to next lesson")
	hud.queue_free()
	Game.running = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game._save_path()))
	print("COMPOSER FLOW: %d checks, %d failures" % [checks,failures])
	await Audio.shutdown()
	get_tree().quit(failures)
