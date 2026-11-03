extends Node
var checks := 0
var failures := 0
var main: Node
var events: Array = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok: print("ok: ", message)
	else: failures += 1; push_error(message)

func frame() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main._booting = true
	add_child(main)
	Game.save_slot = "fire_emergency_qa"
	Game.new_game()
	Game.running = true
	Game.speed = 0
	Game.money = 100000
	Game.day = 27
	Game.tutorial_step = -1
	main.login.hide()
	Game._emit_all()
	var job: Dictionary = Game.offers[0]
	# This test needs an active recording; Manual now requires an arrangement first.
	Game.accept_offer(job, "auto")
	check(Game.start_project(job["id"], [Game.staff[0]["id"]], job["mix"], "Burned recording") == "", "recording starts before emergency")
	Game.invoices.append({"title": "Late invoice", "amount": 100, "due_day": 28, "paid": false})
	var a: Dictionary = Game.staff[1]
	Game.life["training"].append({"artist_id": a["id"], "genre": "Pop", "finish_day": 28})
	Game.walk_in_client.connect(func(_j): events.append("walk_in"))
	Game.alice_notice.connect(func(_s): events.append("alice_notice"))
	Game.week_passed.connect(func(_w): events.append("week"))
	Game.monthly_feedback.connect(func(_m): events.append("month"))
	Game.job_failed.connect(func(_j): events.append("failed"))
	Game.project_completed.connect(func(_p): events.append("completed"))
	Game.contest_announced.connect(func(_r): events.append("contest"))
	main._queue.clear()
	main._booting = false
	check(StudioCity.ignite(0), "emergency starts")
	await frame()
	check(main.dialog.visible and main.dialog.text_label.text == Locale.text("city_fire"), "only Alice's fire department line opens")
	main.dialog.text_label.visible_ratio = 1
	main.dialog._advance()
	await frame()
	check(not main.dialog.visible, "Alice message closes normally")
	main._enqueue(main._flow_alice_notice.bind("Deferred ordinary event"))
	await frame()
	check(not main.dialog.visible, "ordinary queued dialog waits while fire burns")
	var cash = Game.money
	var offer_count = Game.offers.size()
	for n in 3: Game._advance_day()
	check(events.is_empty(), "no business, training, billing, weekly, monthly or contest events during fire")
	check(Game.offers.size() == offer_count and Game.money == cash and not Game.invoices[0]["paid"], "offers and finances stay quiet during response")
	check(Game.day == 30 and Game.project["progress"] == 0.0, "clock advances but production is suspended")
	check(Game.life["city"]["pending_weeks"] == [4] and Game.life["city"]["pending_months"] == [1], "calendar events are deferred instead of lost")
	check(Game.build_room(1, 2, "studio") == Locale.text("city_fire_wait"), "construction is blocked during emergency")
	Game.save_game()
	Game.life = {}
	check(Game.load_game() and StudioCity.fire_active() and Game.life["city"]["pending_months"] == [1], "mid-fire save restores emergency and pending events")
	Game._advance_day()
	check(not StudioCity.fire_active() and Game.floors[1][0] == "empty", "firefighters extinguish on day four and clear the burned lot")
	check(Game.all_projects().is_empty() and not Game.get_job(job["id"]).is_empty(), "burned session is removed but commission survives")
	check(events.has("week") and events.has("month") and Game.invoices[0]["paid"], "deferred events and invoices resume after extinguishing")
	check(Game.contest_edition == 2 and Game.life["feedback"].has(1), "deferred contest and monthly report are retained")
	await frame()
	check(main.dialog.visible and main.dialog.text_label.text == "Deferred ordinary event", "normal flow queue resumes after fire")
	main._booting = true
	main._queue.clear()
	main.dialog.text_label.visible_ratio = 1
	main.dialog._advance()
	await frame()
	var before_build = Game.money
	check(Game.build_room(1, 0, "studio") == "" and Game.money == before_build - int(Data.ROOM_TYPES["studio"]["cost"]), "player pays normal lot construction cost to rebuild")
	Game.save_game()
	Game.floors = []
	check(Game.load_game() and Game.floors[1][0] == "studio", "rebuilt lot survives save reload")
	Game.running = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game._save_path()))
	print("FIRE EMERGENCY: %d checks, %d failures" % [checks, failures])
	await Audio.shutdown()
	get_tree().quit(1 if failures else 0)
