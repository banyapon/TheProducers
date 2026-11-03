extends Node
var checks := 0
var failures := 0
var visual := false
var main: Node

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
	else: print("ok: ", label)

func capture(label: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if visual:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("D:/EP45/ndlp/Producers/City-Life/qa-" + label + ".png")

func _ready() -> void:
	var original_relationship_mode = Locale.relationship_mode
	Locale.relationship_mode = "all_genders"
	seed(20261030)
	visual = "--visual" in OS.get_cmdline_user_args()
	Game.save_slot = "city_qa"
	Game.new_game()
	Game.speed = 0
	Game.running = true
	Game.money = 100000
	var a: Dictionary = Game.staff[0]
	var b: Dictionary = Game.staff[1]
	var c: Dictionary = Game.clients.values()[0]
	check(Game.life.has("city") and c.has("completed_jobs"), "new game migrates city and client state")
	check(not StudioCity.interact(a["id"], "date")["ok"], "new staff cannot immediately date")
	var cash = Game.money
	check(StudioCity.interact(a["id"], "walk")["ok"] and Game.money == cash, "walk is free and available before dating")
	check(not StudioCity.interact(b["id"], "talk")["ok"], "global daily activity limit prevents multi-person farming")
	Game.day += 1
	var trust = a["social"]["trust"]
	StudioCity.interact(a["id"], "walk")
	check(a["social"]["trust"] - trust == 4, "repeated walks use rounded 70 percent gains")
	Game.day = 114
	a["social"]["trust"] = 60
	a["social"]["comfort"] = 60
	a["social"]["interested"] = true
	a["social"]["attraction"] = 0
	for n in 7:
		Game.day += 1
		check(StudioCity.interact(a["id"], "date")["ok"], "valid date " + str(n))
	check(a["social"]["partner"] == "producer", "dates create a partner after attraction threshold")
	check(StudioCity.weekly_fee(a) == 0 and Game.renewal_cost(a, 4) == 0, "partner salary and renewal fee waived")
	var weeks = a["weeks_left"]
	cash = Game.money
	Game._advance_week()
	check(Game.money == cash - int(b["fee_week"]) and a["weeks_left"] == weeks, "actual payroll skips partner and freezes contract countdown")
	b["social"]["trust"] = 70; b["social"]["comfort"] = 70; b["social"]["interested"] = true
	Game.day += 1
	check(not StudioCity.interact(b["id"], "date")["ok"], "exclusive relationship blocks second partner")
	Game.day = int(a["social"]["care_day"]) + 10
	StudioCity.tick_day()
	check(a["social"]["warning"] and a["social"]["partner"] == "producer", "warning gives time to repair neglected relationship")
	StudioCity.interact(a["id"], "walk")
	check(not a["social"]["warning"] and a["social"]["care_day"] == Game.day, "free visit resets neglect")
	Game.day += 21
	StudioCity.tick_day()
	check(a["social"]["partner"] == "" and StudioCity.weekly_fee(a) == int(a["fee_week"]), "neglect breakup restores normal pay")
	check(StudioCity.date_reason(a, false) == Locale.text("city_cooling"), "breakup has a 28-day cooldown")
	a["social"]["partner"] = "producer"
	a["social"]["care_day"] = Game.day
	a["social"]["strain"] = 0
	Game.money = -100
	for n in 14:
		Game.day += 1
		a["social"]["care_day"] = Game.day
		StudioCity.tick_day()
	check(a["social"]["partner"] == "", "14 debt days can end a cared-for relationship")
	Game.money = 100000
	c["social"]["interested"] = true; c["contact_opt_in"] = true
	c["social"]["trust"] = 60; c["social"]["comfort"] = 60
	c["rel"] = 60
	check(StudioCity.date_reason(c, true) == Locale.text("city_client_gate"), "client requires completed commissions")
	c["completed_jobs"] = 2
	c["met_day"] = Game.day - 28
	check(StudioCity.date_reason(c, true) == "", "adult willing contact with history and rapport may date")
	c["contact_opt_in"] = false
	check(StudioCity.date_reason(c, true) != "", "client opt-out is honored")
	c["contact_opt_in"] = true
	c["rel"] = 100
	var rescued = false
	var saved_job: Dictionary
	for n in 30:
		var job = {"id": "grace-test", "client": c["name"], "title": "Late song", "due_day": Game.day}
		if StudioCity.rescue_deadline(job): saved_job = job; rescued = true; break
	check(rescued and saved_job["due_day"] == Game.day + 4, "high rapport can grant four days of grace")
	check(not StudioCity.rescue_deadline(saved_job), "grace can never be retried for the same job")
	# Fire is a four-day emergency; all production pauses, burned room must be rebuilt.
	Game.floors[1][2] = "studio"
	Game.jobs.clear()
	Game.production_queue.clear()
	var job1 = Game.generate_job(true); var job2 = Game.generate_job(true)
	Game.offers.append(job1); Game.offers.append(job2)
	Game.accept_offer(job1); Game.accept_offer(job2)
	check(Game.start_project(job1["id"], [a["id"]], job1["mix"], "Fire test", 0) == "", "start first studio")
	check(Game.start_project(job2["id"], [b["id"]], job2["mix"], "Safe test", 1) == "", "start second studio")
	var damaged = Game.all_projects().filter(func(p: Dictionary): return int(p["room"]) == 0)[0]
	var safe = Game.all_projects().filter(func(p: Dictionary): return int(p["room"]) == 1)[0]
	check(StudioCity.ignite(0), "fire targets a studio")
	check(not StudioCity.ignite(1), "no overlapping fires")
	var start = Game.day
	for n in 4:
		Game.day = start + n
		Game._tick_all_projects()
	check(damaged["progress"] == 0.0 and safe["progress"] == 0.0, "emergency suspends production in all rooms")
	check(Game._booking_conflicts([], 0, start, start + 2), "damaged studio rejects bookings")
	Game.save_game()
	Game.life = {}
	check(Game.load_game() and not StudioCity.room_damage(0).is_empty(), "damage and social state survive save reload")
	Game.day = start + 4
	StudioCity.emergency_day()
	Game._tick_all_projects()
	check(not StudioCity.fire_active() and Game.floors[1][0] == "empty", "firefighters leave an empty lot after four days")
	check(Game.all_projects().size() == 1 and Game.all_projects()[0]["job_id"] == job2["id"] and Game.all_projects()[0]["progress"] > 0, "only surviving recording resumes")
	check(Game.build_room(1, 0, "studio") == "" and int(Game.all_projects()[0]["room"]) == 1, "paid rebuild restores studio and remaps surviving room")
	var restart_job = Game.get_job(job1["id"])
	check(Game.start_project(job1["id"], [a["id"]], restart_job["mix"], "Restart", 0) == "", "burned recording can restart in rebuilt lot")
	var repaired = Game.project
	Game.project = repaired
	var recording_job = Game.get_job(repaired["job_id"])
	var recording_artist = Game.get_artist(repaired["team"][0])
	repaired["points"] = {"Melody": 30, "Lyrics": 30, "Groove": 30, "Sound": 30}
	var original_pay = recording_job["pay"]
	seed(57)
	var before_eval = Game.evaluate_project()
	recording_job["pay"] = original_pay * 3
	seed(57)
	check(Game.evaluate_project()["total"] == before_eval["total"], "urgent price does not penalize craft or rating")
	recording_job["pay"] = original_pay
	for tag in recording_job["mix"]: recording_artist["skills"][tag] = 0
	recording_artist["experience"] = 0
	seed(57)
	var low_eval = Game.evaluate_project()
	for tag in recording_job["mix"]: recording_artist["skills"][tag] = 100
	recording_artist["experience"] = 100
	seed(57)
	var high_eval = Game.evaluate_project()
	check(high_eval["total"] > low_eval["total"], "genre skill and experience improve real production ratings")
	check(high_eval["total"] <= 40 and low_eval["total"] >= 4, "production stats respect rating bounds")
	Game.songs = [{"id": "test-song", "title": "City Lights", "rating": 40}]
	var count = Game.trophies.size()
	Game._run_contest()
	check(Game.trophies.size() == count and not Game.songs[0].get("contest_entered", false), "contest never auto-enters a song")
	StudioCity.submit(Game.songs[0])
	Game.save_game()
	Game.life = {}
	Game.load_game()
	check(Game.life["city"]["contest_song"] == "test-song", "chosen submission survives save reload")
	Game._run_contest()
	check(Game.songs[0]["contest_entered"] and Game.life["city"]["results"].size() == 1, "submitted song is judged and result persisted")
	Game._run_contest()
	check(Game.life["city"]["results"].size() == 1, "song cannot compete twice")
	check(StudioCity.contest_chance(40, 1) > StudioCity.contest_chance(25, 1) and StudioCity.contest_chance(40, 1) <= 0.92, "better stats improve odds without guaranteeing victory")
	var wins_low = 0
	var wins_high = 0
	seed(106)
	for n in 10000:
		var roll = randf()
		if roll < StudioCity.contest_chance(16, 12): wins_low += 1
		if roll < StudioCity.contest_chance(36, 12): wins_high += 1
	check(wins_high > 6500 and wins_high < 8000 and wins_low < 1200, "10000 judging draws distinguish strong and weak songs")
	# Full UI integration and bilingual rendering.
	main = load("res://scenes/main.tscn").instantiate()
	main._booting = true
	add_child(main)
	main.login.hide()
	Game.tutorial_step = -1
	Game._emit_all()
	Game.project = {}
	Game.parallel_projects = []
	Game.day += 1
	main.hud.action_buttons["city"].pressed.emit()
	check(main.city_panel.visible, "HUD City button opens the activity panel")
	main.city_panel.find_child("CityCompanion_" + str(Game.staff[0]["id"]), true, false).pressed.emit()
	var before_comfort = int(Game.staff[0]["social"]["comfort"])
	main.city_panel.find_child("CityAction_walk", true, false).pressed.emit()
	check(main.city_panel.location == "park" and Game.staff[0]["social"]["comfort"] >= before_comfort and Game.life["city"]["last_action_day"] == Game.day, "real walk button updates relationship and park backdrop")
	main.city_panel.close()
	for lang in ["en", "th"]:
		Locale.language = lang
		check(not Locale.text("city_title").contains("?"), "localized city title intact: " + lang)
		main.city_panel.visit(Game.staff[0]["id"])
		main.city_panel.find_child("CityCompanion_" + str(Game.staff[0]["id"]), true, false).pressed.emit()
		check(Game.is_paused(), "city panel pauses simulation")
		await capture("city-" + lang)
		main.city_panel.location = "park"; main.city_panel.refresh()
		await capture("park-" + lang)
		main.city_panel.location = "restaurant"; main.city_panel.refresh()
		await capture("restaurant-" + lang)
		main.city_panel.announce(Game.life["city"]["results"][0])
		await capture("hall-" + lang)
		check(main.city_panel.find_child("CityBackdrop", true, false) != null, "award ceremony displays its hall illustration")
		main.city_panel.close()
	main._queue.clear()
	main._booting = false
	Game.contest_announced.emit(Game.life["city"]["results"][0])
	await capture("ceremony")
	check(main.city_panel.visible and main.city_panel.location == "hall", "contest result signal opens staged award ceremony")
	main.city_panel.close()
	await get_tree().process_frame
	check(not main._queue_running, "closing ceremony releases the flow queue")
	main._booting = true
	StudioCity.ignite(0)
	await capture("fire")
	print("CITY TEST: %d checks, %d failures" % [checks, failures])
	Game.running = false
	Locale.relationship_mode = original_relationship_mode
	main._queue.clear()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game._save_path()))
	await Audio.shutdown()
	get_tree().quit(1 if failures else 0)
