extends Node
## Headless smoke test of the core loop:
##   godot --headless --path . res://tests/smoke_test.tscn
## Runs main.tscn offline, accepts a job, signs an artist, records, releases, renders audio + cover.

var _failures := 0


func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	main.get_node("UI/LoginScreen").hide()
	Game.save_slot = "smoketest"
	Game.new_game()
	Game.running = true
	Game._emit_all()

	_check(Game.staff.size() == 2, "starter staff")
	_check(Game.offers.size() == 3, "starter offers")
	_check(main.get_node("Office").workers.size() == 2, "office spawned worker squares")

	# Balance: the starter duo must comfortably finish a starter job before its deadline.
	for offer in Game.offers:
		_check(int(offer["deadline"]) >= 6, "starter offer deadline %d weeks" % offer["deadline"])
	var duo_days := Game.estimate_days(Game.staff, Game.offers[0]["mix"])
	_check(duo_days <= 12, "starter duo estimate %d days" % duo_days)

	var easy: Dictionary = Game.offers[0]
	Game.accept_offer(easy)
	var duo_ids := []
	for a in Game.staff:
		duo_ids.append(a["id"])
	_check(Game.start_project(easy["id"], duo_ids, easy["mix"], "Starter Song") == "", "starter project")
	var days := 0
	while not Game.project.is_empty() and not Game.project["done"]:
		Game._advance_day()
		days += 1
	_check(not Game.project.is_empty() and Game.project["done"], "starter song done in %d days, before deadline" % days)
	_check(int(Game.project["eval"]["total"]) >= 20, "starter song (perfect mix) scores %d/40" % Game.project["eval"]["total"])
	Game.release_project(0)

	var job: Dictionary = Game.offers[0]
	var money_before := Game.money
	var pct := Game.accept_offer(job)
	_check(pct == 25 or pct == 50, "deposit is 25% or 50%")
	_check(Game.money == money_before + int(job["upfront"]), "deposit paid")

	var artist := Game.generate_artist(0.8)
	_check(Game.sign_artist(artist, 8) == "", "sign artist")

	var ids := []
	for a in Game.staff:
		ids.append(a["id"])
	_check(Game.start_project(job["id"], ids, job["mix"], "Smoke Test Song") == "", "start project")

	var guard := 0
	while not Game.project["done"] and guard < 200:
		Game._advance_day()
		guard += 1
	_check(Game.project["done"], "project completes (%d days)" % guard)
	var ev: Dictionary = Game.project["eval"]
	_check(int(ev["total"]) >= 4 and int(ev["total"]) <= 40, "critic total in range: %d" % ev["total"])

	var song := Game.release_project(1)
	_check(not song.is_empty(), "release song")
	_check(Game.project.is_empty(), "project cleared")

	var t0 := Time.get_ticks_msec()
	await MusicGen.produce(song)
	print("produce() took %d ms -> %s" % [Time.get_ticks_msec() - t0, song["status"]])
	_check(FileAccess.file_exists(song["local_audio"]), "wav written")
	_check(FileAccess.file_exists(song["local_cover"]), "cover written")
	var wav := AudioStreamWAV.load_from_file(song["local_audio"])
	_check(wav != null and wav.get_length() > 10.0, "wav loads (%.1fs)" % (wav.get_length() if wav else 0.0))

	var params := {"timestamp": "1315060510", "public_id": "sample_image"}
	_check(Cloudinary.sign_params(params, "abcd") == "b4ad47fb4e25c7bf5f92a20089f9db59bc302313", "cloudinary signature matches docs example")

	Game.save_game()
	var songs_before := Game.songs.size()
	Game.songs = []
	_check(Game.load_game() and Game.songs.size() == songs_before, "save/load roundtrip")

	Game.reset_game()
	_check(Game.songs.is_empty() and Game.money == Game.START_MONEY and Game.staff.size() == 2, "reset_game starts fresh")
	await get_tree().process_frame
	_check(main.get_node("Office").workers.size() == 2, "office respawned after reset")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save_smoketest.dat"))

	print("SMOKE TEST %s (%d failures)" % ["PASSED" if _failures == 0 else "FAILED", _failures])
	await Audio.shutdown()
	get_tree().quit(_failures)


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		_failures += 1
