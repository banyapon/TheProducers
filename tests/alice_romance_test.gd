extends Node
var failures := 0
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok: print("ok: ", message)
	else: failures += 1; push_error(message)

func _ready() -> void:
	Game.save_slot = "alice_romance_qa"
	Game.new_game()
	Game.running = true
	Game.money = 100000
	Game.speed = 0
	check(not StudioCity.alice()["romance_unlocked"], "Alice starts locked")
	check(not StudioCity.interact("alice", "date")["ok"], "dating requires awards")
	Game.songs = [{"id": "unawarded", "rating": 40}]
	check(StudioCity.alice_award_count() == 0, "high score alone is not an award")
	for n in 4: Game.trophies.append({"song_id": "winner%d" % n, "rating": 30})
	Game.trophies.append({"song_id": "winner0", "rating": 40})
	Game.trophies.append({"song_id": "low", "rating": 29})
	Game.trophies.append({"song_id": "loser", "rating": 40, "win": false})
	check(StudioCity.alice_award_count() == 4, "count unique winners at 30 or higher only")
	check(not StudioCity.alice()["romance_unlocked"], "four awards stay locked")
	Game.songs = [{"id": "fifth", "title": "Fifth Award", "rating": 40}]
	StudioCity.submit(Game.songs[0])
	seed(1)
	Game._run_contest()
	check(StudioCity.alice_award_count() == 5, "real contest adds fifth award")
	var alice = StudioCity.alice()
	check(alice["romance_unlocked"] and StudioCity.date_reason(alice, false) == "", "immediately ready before 112 days")
	check(Game.get_artist("alice").is_empty(), "secretary stays outside production roster")
	check(StudioCity.interact("alice", "date")["ok"], "date succeeds on unlock day")
	check(alice["social"]["attraction"] == 12 and alice["social"]["partner"] == "", "unlock starts courtship, not automatic partnership")
	check(not StudioCity.interact("alice", "date")["ok"], "daily limit still applies")
	for n in 6:
		Game.day += 1
		StudioCity.interact("alice", "date")
	check(StudioCity.partner_id() == "alice", "Alice becomes partner after dates")
	var artist: Dictionary = Game.staff[0]
	artist["joined_day"] = -200
	artist["social"]["interested"] = true
	artist["social"]["trust"] = 80; artist["social"]["comfort"] = 80
	check(StudioCity.date_reason(artist, false) == Locale.text("city_unavailable"), "Alice shares exclusivity rules")
	Game.save_game()
	Game.life = {}
	check(Game.load_game() and StudioCity.partner_id() == "alice", "relationship survives reload")
	alice = StudioCity.alice()
	Game.day = int(alice["social"]["care_day"]) + 21
	StudioCity.tick_day()
	check(alice["social"]["partner"] == "" and alice["romance_unlocked"], "neglect breaks up without relocking achievement")
	check(StudioCity.date_reason(alice, false) == Locale.text("city_cooling"), "breakup cooldown applies")
	Game.life.erase("alice")
	StudioCity.migrate()
	check(StudioCity.alice()["romance_unlocked"], "old saves migrate from qualifying trophies")
	Game.trophies.clear()
	check(StudioCity.alice()["romance_unlocked"], "unlock is permanent")
	var panel = CityPanel.new()
	add_child(panel)
	panel.visit("alice")
	check(panel.contact == "alice" and not panel.find_child("CityAction_date", true, false).disabled, "City UI selects Alice and enables dating")
	panel.close()
	Game.life.clear(); Game.trophies.clear()
	StudioCity.migrate()
	panel.visit("alice")
	check(panel.find_child("CityAction_date", true, false).disabled, "locked Alice disables UI date button")
	panel.close()
	for lang in ["en", "th"]:
		Locale.language = lang
		check(StudioCity.alice_status() == Locale.text("alice_romance_locked") and not StudioCity.alice_status().contains("30/40") and not StudioCity.alice_status().contains("0/5"), "localized refusal hides achievement requirements: " + lang)
	Game.running = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game._save_path()))
	print("ALICE ROMANCE: %d checks, %d failures" % [checks, failures])
	await Audio.shutdown()
	get_tree().quit(1 if failures else 0)
