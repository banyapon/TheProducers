extends Node
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if ok: print("ok: ",message)
	else: failures += 1; push_error(message)
func capture(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not "--visual" in OS.get_cmdline_user_args(): return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_webp("D:/EP45/ndlp/Producers/journey-" + name + ".webp",true)
func _ready() -> void:
	if "--thai" in OS.get_cmdline_user_args(): Locale.language = "th"
	Game.save_slot = "song_journey_qa"; Game.new_game()
	Game.running = true; Game.speed = 0; Game.tutorial_step = -1; Game.tutorial_gate = false; Game.money = 50000
	var job: Dictionary = Game.offers[0]
	job.erase("tutorial_brief")
	Game.accept_offer(job,"manual")
	Game.begin_idea_meeting(job); Game.idea_meeting["phase"] = "ready"
	var m = Game.idea_meeting
	for col in 8:
		for row in 4: Game.place_idea(0,row,col)
	SongIdentity.apply(m,"motif",0)
	var notes_a = IdeaMusic.events(m["deck"],m["placed"])
	SongIdentity.apply(m,"motif",1)
	var notes_b = IdeaMusic.events(m["deck"],m["placed"])
	check(notes_a != notes_b, "motifs produce distinct note sequences")
	SongIdentity.apply(m,"mood",2)
	check(IdeaMusic.events(m["deck"],m["placed"]) != notes_b, "mood changes pitches and harmony")
	SongIdentity.apply(m,"lead",0)
	var piano = IdeaMusic.pcm(IdeaMusic.events(m["deck"],m["placed"]),120,0.5)
	SongIdentity.apply(m,"lead",1)
	var guitar = IdeaMusic.pcm(IdeaMusic.events(m["deck"],m["placed"]),120,0.5)
	SongIdentity.apply(m,"lead",2)
	check(piano != guitar and guitar != IdeaMusic.pcm(IdeaMusic.events(m["deck"],m["placed"]),120,0.5), "lead instruments produce distinct audio")
	SongIdentity.apply(m,"transition",1)
	var dropped = IdeaMusic.events(m["deck"],m["placed"])
	check(not dropped.any(func(n): return n["drum"] and n["step"] >= 32 and n["step"] < 40), "drum drop creates space before hook")
	SongIdentity.apply(m,"transition",2)
	var filled = IdeaMusic.events(m["deck"],m["placed"])
	check(filled.filter(func(n): return n["drum"] and n["step"] >= 32 and n["step"] < 40).size() == 8, "fill produces eight drum hits before hook")
	var panel = IdeaJamPanel.new(); add_child(panel); panel.open()
	var thai_letters = RegEx.new(); thai_letters.compile("[ก-๙]")
	check(panel.find_children("*", "Button", true, false).all(func(b): return thai_letters.search(b.text) == null), "composer buttons and drop cells use English")
	check(panel.body_root.auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED, "Thai locale cannot automatically retranslate English editing controls")
	panel.remember(); SongIdentity.apply(m,"motif",2); panel.undo()
	check(m["signature"]["motif"] == 1, "undo restores signature and clip settings")
	await capture("composer")
	panel.identity_open = true; panel.refresh()
	await capture("signature")
	Game.save_game(); Game.load_game()
	m = Game.idea_meeting
	check(m["signature"]["lead"] == 2, "sound identity persists in draft save")
	panel.submit(); panel.close(); panel.queue_free()
	job = Game.get_job(job["id"])
	var ids = Game.staff.map(func(a): return a["id"])
	check(Game.start_project(job["id"],ids,job["mix"],"Our first signature") == "", "manual song starts recording")
	var p = Game.project
	p["progress"] = 45
	var requests = [0]
	Game.creative_decision_requested.connect(func(_id): requests[0] += 1)
	Game._tick_all_projects(); Game._tick_all_projects()
	check(p["creative_pending"] and requests[0] == 1 and p["progress"] == 45, "one decision pauses this recording without repeating the request")
	var old_cash = Game.money
	CreativeJourney.resolve(job["id"],1)
	check(Game.money == old_cash-600 and p["retake_until"] == Game.day+3, "retake has actual cost and time")
	Game.day += 1; Game._tick_all_projects()
	Game.day += 1; Game._tick_all_projects()
	check(p["progress"] == 45, "retake holds two full recording days")
	Game.day += 1; Game._tick_all_projects()
	check(p["progress"] > 45, "recording resumes after retake")
	CreativeJourney.resolve(job["id"],1)
	check(Game.money == old_cash-600, "decision cannot be charged or rewarded twice")
	# Reset only this fixture to exercise the alternative and actual dialog.
	job.erase("creative_choice"); job.erase("creative_score"); p.erase("retake_until"); p["creative_pending"] = true
	var original = CreativeJourney.preview_notes(job,false)
	check(CreativeJourney.preview_notes(job,true).size() < original.size(), "simplified preview removes accompaniment")
	var main = load("res://scenes/main.tscn").instantiate(); main._booting = true; add_child(main); main.login.hide()
	await get_tree().process_frame
	await get_tree().process_frame
	main._flow_creative_decision(job["id"])
	await get_tree().process_frame
	if main.dialog._tween: main.dialog._tween.kill()
	main.dialog.text_label.visible_ratio = 1
	await capture("decision")
	main.dialog.choice_selected.emit(4)
	await get_tree().process_frame
	main.dialog.text_label.visible_ratio = 1; main.dialog._advance()
	await get_tree().process_frame
	check(job["creative_choice"] == "simplify" and job["idea_notes"].size() < original.size(), "selected simplification persists into the release notes")
	main._queue.clear(); main.queue_free(); await get_tree().process_frame
	p["done"] = true; p["eval"] = {"total":32,"critics":[]}
	var song = Game.release_project(0)
	check(song["signature"]["motif"] == 1 and song["creative_choice"] == "simplify" and song["idea_notes"] == job["idea_notes"], "released song retains sound and production story")
	check(CreativeJourney.available(song), "strong vocalist release receives a rights offer")
	var story = SongStoryPanel.new(); story.song = song; add_child(story); story.open()
	await capture("rights")
	story.close(); story.queue_free()
	old_cash = Game.money
	CreativeJourney.rights(song,0)
	check(CreativeJourney.locked(song) and Game.money == old_cash+9200, "exclusive contract pays and locks rights")
	CreativeJourney.rights(song,0)
	check(Game.money == old_cash+9200, "exclusive contract cannot pay twice")
	var singer: Dictionary = Game.staff.filter(func(a): return a["role"] == "Vocal")[0]
	check(StudioStars.offer_for(singer,"license").is_empty(), "exclusive song cannot receive another license offer")
	for index in 2:
		var extra = song.duplicate(true); extra["id"] = "extra%d" % index; extra.erase("exclusive_until"); extra.erase("rights_choice")
		Game.songs.append(extra); StudioStars.on_release(extra,ids)
	check(StudioStars.make_album(singer["id"]) == Locale.text("rights_album_wait"), "album cannot consume an exclusive track")
	Game.day = song["exclusive_until"]
	check(not CreativeJourney.locked(song) and StudioStars.make_album(singer["id"]) == Locale.text("stars_album_done"), "album use reopens at contract expiry")
	Game.save_game(); Game.load_game()
	check(Game.songs[0]["rights_choice"] == "exclusive" and Game.songs[0]["signature"]["motif"] == 1, "song decisions survive save and reload")
	for option in [1,2]:
		var offer = Game.songs[0].duplicate(true)
		offer["id"] = "rights_option_%d" % option
		offer.erase("rights_choice"); offer.erase("exclusive_until")
		offer["rights_offer_until"] = Game.day+14
		Game.songs.append(offer)
		old_cash = Game.money
		CreativeJourney.rights(offer,option)
		check(Game.money == old_cash + (4100 if option == 1 else 0) and not CreativeJourney.locked(offer), "non-exclusive option pays correctly without blocking albums")
		if option == 1:
			var royalties = StudioStars.data()["royalties"].filter(func(r): return r["song_id"] == offer["id"])
			check(royalties.size() == 1 and royalties[0]["weekly"] == 300 and royalties[0]["remaining"] == 8, "limited deal schedules eight weekly royalties")
	Game.running = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game._save_path()))
	print("SONG JOURNEY: %d checks, %d failures" % [checks,failures])
	await Audio.shutdown(); get_tree().quit(failures)
