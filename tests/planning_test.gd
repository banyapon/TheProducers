extends Node
var failures := 0
var checks := 0
var main: Node
var visual := false
var original_language := ""

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
	else: print("  ok  ", message)

func frame(label: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if visual:
		await RenderingServer.frame_post_draw
		var qa_dir = OS.get_environment("PRODUCERS_QA_DIR")
		if qa_dir == "": qa_dir = ProjectSettings.globalize_path("user://qa")
		DirAccess.make_dir_recursive_absolute(qa_dir)
		get_viewport().get_texture().get_image().save_webp(qa_dir.path_join("planning-" + label + ".webp"),true)

func _ready() -> void:
	original_language = Locale.language
	Locale.set_language("en")
	visual = "--visual" in OS.get_cmdline_user_args()
	if visual:
		DisplayServer.window_set_title("The Producers Planning QA")
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1600, 900))
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	main._booting = true # Record notices without consuming test input or writing the player's save.
	await frame("title")
	check(main.login.has_node("TitleWallpaper") and main.login.get_node("TitleMenu").anchor_left >= 0.7, "duo title reserves the right thirty percent for login")
	main.login.hide()
	Game.save_slot = "planning_qa"
	Game.new_game()
	Game.running = true
	Game.speed = 0
	Game.money = 150000
	Game.identity_initialized = true
	Game.intro_seen = true
	Game._emit_all()
	check(Art.portrait("producer") != null and Art.portrait("alice") != null, "both main portraits exist")
	main.dialog.open(main.PLAYER, main._artist_portrait(Game.staff[0]))
	main.dialog._show_line("alice", Locale.text("alice_contract", [Game.staff[0]["name"]]))
	main.dialog._tween.kill()
	main.dialog.text_label.visible_ratio = 1
	await frame("contract")
	check(main.dialog.left_portrait.texture != null and main.dialog.left_portrait.visible, "Producer is visible at the left of dialogue")
	check(main.dialog.alice_portrait.visible and main.dialog.right_portrait.texture != null, "Alice and musician appear together at right")
	check(main.dialog.alice_portrait.flip_h and main.dialog.right_portrait.flip_h, "both right-side portraits face left")
	check(main.dialog.left_portrait.size == Vector2(192, 192) and main.dialog.right_portrait.size == Vector2(192, 192), "dialogue portraits share a three-times integer pixel scale")
	check(main.dialog.speaker_label.text == "Alice", "adviser's dialogue is attributed to Alice")
	main.dialog.close()
	check(Game.commission_pay(12000, 2) > Game.commission_pay(12000, 4) and Game.commission_pay(12000, 4) > Game.commission_pay(12000, 8), "same scope pays more for shorter deadlines")
	var job: Dictionary = Game.offers[0]
	Game.accept_offer(job)
	var original_due = int(job["due_day"])
	Game.clients[job["client"]]["rel"] = 80
	Game.request_extension(job)
	check(int(job["due_day"]) == original_due + 7 and job["extension_fee"] == 0, "high-relationship client extends for free")
	Game.request_extension(job)
	check(job["due_day"] == original_due + 7, "extension cannot be repeated")
	var second: Dictionary = Game.offers[0]
	Game.accept_offer(second)
	Game.clients[second["client"]]["rel"] = 50
	Game.request_extension(second)
	check(second["extension_fee"] == int(second["pay"] * 0.1), "middle-relationship extension withholds ten percent")
	var third: Dictionary = Game.offers[0]
	Game.accept_offer(third)
	Game.clients[third["client"]]["rel"] = 10
	var third_due = third["due_day"]
	Game.request_extension(third)
	check(third["due_day"] == third_due and Game.clients[third["client"]]["rel"] == 7, "low-relationship client refuses extension")
	Game.floors[0][2] = "empty"
	check(Game.start_research(job) == Locale.text("research_room"), "research requires a Lounge")
	Game.build_room(0,2,"lounge")
	check(Game.build_room(1, 2, "meeting") == "", "meeting room can be built")
	var research_stock = Game.items["research"]
	Game.start_research(job)
	check(Game.research_tasks.size() == 1 and Game.items["research"] == research_stock - 1, "research consumes one brief and starts a three-day task")
	check(Game.is_researching("alice") and Game.is_researching(Game.staff[0]["id"]), "Alice and one musician are reserved for research")
	check(main.office.principals["alice"].researching and main.office.workers[Game.staff[0]["id"]].researching, "world actors walk to meeting room for research")
	var ids = [Game.staff[0]["id"]]
	check(Game.start_project(job["id"], ids, job["mix"], "Blocked") == Locale.text("artist_busy"), "researching musician cannot double-book a recording")
	Game.save_game()
	check(Game.load_game() and Game.research_tasks.size() == 1, "in-progress research survives a save")
	job = Game.get_job(job["id"])
	second = Game.get_job(second["id"])
	third = Game.get_job(third["id"])
	Game.day += 2
	Game._tick_research()
	check(not job.has("research_hint"), "research does not finish early")
	Game.day += 1
	Game._tick_research()
	check(job.has("research_hint") and job["research_hint"] in Data.GENRES and job["idea"] == 8, "research finishes on canonical saved job with genre recommendation and Idea")
	check(Game.research_tasks.is_empty() and not Game.is_researching("alice"), "research releases its participants")
	Game.use_item("energy", job)
	check(job["idea"] == 14 and Game.items["energy"] == 0, "energy drink gives six Idea")
	Game.use_item("pizza", job)
	check(job["idea"] == 26, "pizza gives twelve Idea")
	Game.items["pizza"] = 2
	Game.use_item("pizza", job)
	Game.use_item("pizza", job)
	check(job["idea"] == 30 and Game.items["pizza"] == 1, "Idea caps at thirty without wasting another item")
	Game.add_column()
	Game.build_room(1, 3, "studio")
	check(Game.count_rooms("studio") == 2, "second studio provides a second room")
	main.production._setup_mode = true
	main.production.open()
	await frame("musician-grid")
	main.production.close()
	var first_id = Game.staff[0]["id"]
	var second_id = Game.staff[1]["id"]
	job["planned_day"] = Game.day + 3
	check(Game.start_project(job["id"], [first_id], job["mix"], "Too early") == Locale.text("not_planned_yet"), "timeline reservation prevents premature start")
	job["planned_day"] = Game.day
	check(Game.start_project(job["id"], [first_id], job["mix"], "Parallel A") == "", "first room recording starts")
	check(Game.project["points"]["Melody"] == 30, "planned Idea becomes production points")
	check(Game.start_project(second["id"], [first_id], second["mix"], "Conflict") == Locale.text("artist_busy"), "musician cannot occupy two recording rooms")
	check(Game.start_project(second["id"], [second_id], second["mix"], "Parallel B") == "", "second disjoint team records in parallel")
	check(Game.all_projects().size() == 2 and Game.artist_project(first_id)["room"] != Game.artist_project(second_id)["room"], "sessions occupy distinct physical rooms")
	check(main.office.workers[first_id].assigned_room != main.office.workers[second_id].assigned_room, "musicians are routed to distinct studios in the world")
	Game._tick_all_projects()
	check(Game.artist_project(first_id)["progress"] > 0 and Game.artist_project(second_id)["progress"] > 0, "both sessions advance on the same day")
	main.production.open()
	await frame("parallel")
	check(main.production.team_grid.columns == 2, "musician selection is a two-column portrait grid")
	main.production.close()
	Game.save_game()
	Game.parallel_projects = []
	check(Game.load_game() and Game.all_projects().size() == 2, "both room bookings survive save/load")
	job = Game.get_job(job["id"])
	second = Game.get_job(second["id"])
	for session in Game.all_projects():
		Game.focus_project(session["job_id"])
		Game.project["progress"] = 100
		Game.project["done"] = true
		Game.project["eval"] = Game.evaluate_project()
	Game.focus_project(job["id"])
	var money_before = Game.money
	var song = Game.release_project(0)
	check(not song.is_empty() and Game.invoices.size() == 1, "release creates a final invoice")
	check(Game.money == money_before - Data.MARKETING[0]["cost"], "final invoice does not pay cash immediately")
	check(Game.all_projects().size() == 1 and Game.project["job_id"] == second["id"], "releasing one session preserves the other room")
	Game._tick_invoices()
	check(not Game.invoices[0]["paid"], "invoice is not paid before its due day")
	Game.day += 7
	Game._tick_invoices()
	check(Game.invoices[0]["paid"] and Game.money == money_before - Data.MARKETING[0]["cost"] + song["payout"], "invoice pays seven days after release")
	var after_payment = Game.money
	Game._tick_invoices()
	check(Game.money == after_payment, "invoice pays only once")
	song["rating"] = 40
	StudioCity.submit(song)
	seed(1) # Deterministic winning draw; statistical odds are checked by city_test.
	Game._run_contest()
	check(Game.trophies.size() == 1 and Game.trophies[0]["edition"] == 1, "Best Track awards a first-place trophy")
	Game._run_contest()
	check(Game.trophies.size() == 1 and Game.contest_edition == 3, "numbered contests continue and do not reuse an entered song")
	for i in 4:
		main.planner.tab = i
		main.planner.open()
		await frame(["timeline", "research", "invoices", "trophies"][i])
		check(main.planner.get_minimum_size().y <= 1080, "Alice desk tab fits screen: " + str(i))
		main.planner.close()
	Locale.set_language("th")
	main.planner.tab = 0
	main.planner.open()
	await frame("timeline-th")
	main.planner.close()
	for artist in Game.staff:
		check(artist["gender"] == Art.gender(artist["art_id"]), "musician name pool follows portrait gender")
	for id in Art.vip_ids:
		check(Game.client_contact({"art_id": id, "name": "Studio"}).begins_with("Ms." if Art.gender(id) == "female" else "Mr."), "VIP contact uses explicit gender: " + id)
	Game.save_game()
	Game.invoices = []
	Game.trophies = []
	check(Game.load_game() and Game.invoices.size() == 1 and Game.trophies.size() == 1, "invoices and trophy collection survive save/load")
	# A notice queued while planning must wait rather than disappear behind the modal.
	main._queue.clear()
	main._booting = false
	main.planner.open()
	Game.alice_notice.emit("Invoice regression report")
	await frame("notice-wait")
	check(main.planner.visible and not main.dialog.visible, "Alice notice waits behind the open planning desk")
	main.planner.close()
	await frame("notice")
	check(main.dialog.visible and main.dialog.text_label.text == "Invoice regression report", "Alice report appears after the planning desk closes")
	main.dialog.text_label.visible_ratio = 1
	main.dialog._advance()
	await get_tree().process_frame
	check(not main.dialog.visible and not main._queue_running, "Alice report releases its dialog and queue")
	main._booting = true
	main._flow_shop()
	main.dialog.text_label.visible_ratio = 1
	main.dialog._advance()
	await frame("shop")
	check(main.dialog._options.size() == Data.ITEMS.size() + 1 and main.dialog.choices_box.get_child_count() == main.dialog._options.size() and not main.dialog.choice_pager.visible, "item shop shows every consumable and back action without choice pages")
	var shop_bottom = main.dialog.choices_box.get_global_rect().end.y
	check(shop_bottom <= get_viewport().get_visible_rect().size.y, "all shop buttons fit without scrolling")
	main.dialog.choice_selected.emit(Data.ITEMS.size())
	await get_tree().process_frame
	# Both room-completion events must be retained even on the same simulation tick.
	Game.project = {}
	Game.parallel_projects = []
	var a = Game.generate_job(true)
	var b = Game.generate_job(true)
	Game.accept_offer(a)
	Game.accept_offer(b)
	Game.start_project(a["id"], [first_id], a["mix"], "Finish A")
	Game.start_project(b["id"], [second_id], b["mix"], "Finish B")
	for session in Game.all_projects(): session["progress"] = 99
	var completed: Array = []
	Game.project_completed.connect(func(session: Dictionary): completed.append(session["job_id"]))
	Game._tick_all_projects()
	check(completed.size() == 2 and completed.has(a["id"]) and completed.has(b["id"]), "two rooms completing on the same tick both report completion")
	Game.focus_project(a["id"])
	Game.get_client(b["client"])["rel"] = 0 # No goodwill grace for this cancellation fixture.
	Game._fail_job(b)
	check(Game.all_projects().size() == 1 and Game.project["job_id"] == a["id"], "a missed deadline cancels only its own room")
	Game.running = false
	main._queue.clear()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game._save_path()))
	Locale.set_language(original_language)
	print("PLANNING TESTS: %d checks, %d failures" % [checks, failures])
	await Audio.shutdown()
	get_tree().quit(1 if failures else 0)
