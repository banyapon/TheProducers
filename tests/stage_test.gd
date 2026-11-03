extends Node

var checks := 0
var failures := 0
var main: Node

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
	else:
		print("ok: ", label)

func _ready() -> void:
	seed(20261031)
	Game.save_slot = "stage_qa"
	Game.new_game()
	Game.speed = 0
	Game.running = true
	Game.money = 80000
	Game.tutorial_step = -1
	var a: Dictionary = Game.staff[0]
	var b: Dictionary = Game.staff[1]
	a["skills"] = {"Pop": 50, "Rock": 50}
	b["skills"] = {"Pop": 48, "Rock": 44}
	check(StudioStage.chemistry(a["id"], b["id"]) == 44, "shared genres set the starting chemistry")
	check(Locale._catalogues["en"].has("stage_chart_title") and Locale._catalogues["th"].has("stage_chart_title"), "chart copy exists in both languages")
	for key in Locale._catalogues["en"]:
		if str(key).begins_with("stage_"):
			check(Locale._catalogues["th"].has(key) and str(Locale._catalogues["th"][key]) != str(key), "thai stage copy: " + str(key))

	StudioStage.set_chemistry(a["id"], b["id"], 80)
	check(is_equal_approx(StudioStage.craft_multiplier([a, b]), 1.25), "high chemistry speeds craft points")
	check(StudioStage.stage()["bands"].size() >= 1, "a duo at 70 chemistry becomes a band")
	var band: Dictionary = StudioStage.matching_band([a["id"], b["id"]])
	check(not band.is_empty(), "the band matches the two members")
	check(StudioStage.fan_gain(20, 1.0, [a["id"], b["id"]], {}) == 375, "a band adds a quarter of the fan gain")
	check(StudioStage.fan_gain(20, 1.0, [a["id"], b["id"]], {"requested_band": band["id"]}) == 420, "a requested band adds a further fan bonus")

	StudioStage.set_chemistry(a["id"], b["id"], 10)
	Game.day = 3
	check(StudioStage.friction_today([a["id"], b["id"]]), "chemistry under 30 causes friction every third day")
	Game.day = 4
	check(not StudioStage.friction_today([a["id"], b["id"]]), "other days keep the session calm")
	StudioStage.on_shared_room([a["id"], b["id"]])
	check(StudioStage.chemistry(a["id"], b["id"]) == 11, "a shared recording day raises chemistry by one")

	var plain = _song("plain", 36, 0, 1.0)
	Game.songs = [plain]
	Game.fans = 0
	Game.day = 70
	Game.life["stage"]["genre_fans"] = {}
	var cold = StudioStage.song_score(plain)
	Game.life["stage"]["genre_fans"] = {"Pop": 200}
	var warm = StudioStage.song_score(plain)
	check(warm > cold, "a genre the label's fans already follow drops off the chart more slowly")

	var hit = _song("hit", 40, 28, 2.4)
	var sleeper = _song("sleeper", 28, 0, 1.0)
	sleeper["client"] = Game.clients.keys()[0]
	hit["client"] = sleeper["client"]
	Game.songs = [hit, sleeper]
	Game.day = 28
	Game.fans = 0
	Game.life["stage"]["chart"] = []
	Game.life["stage"]["chart_week"] = 0
	check(not StudioStage.radio_target().is_empty(), "radio can find a strong song that is outside the top 3")
	var fans = Game.fans
	StudioStage.on_week()
	check(StudioStage.current_rank("hit") == 1, "a fresh high-rated single takes the top of the chart")
	check(int(sleeper["chart_boost"]) == 1 and Game.fans == fans + 40, "radio pushes the sleeper and the boost then fades by one")
	check(int(hit["weeks_on_chart"]) == 1 and int(hit["peak_rank"]) == 1, "chart weeks and peak rank are stored on the song")

	Game.day = 21
	sleeper["day"] = 0
	sleeper["rating"] = 30
	var offer = StudioStage.offer_remix(sleeper)
	check(str(offer.get("remix_of", "")) == "sleeper" and offer["revealed"].has("Pop"), "a remix brief reveals the original mix")
	Game.accept_offer(offer)
	var error = Game.start_project(offer["id"], [a["id"]], {"Pop": 100}, offer["title"])
	check(error == "" and Game.project.get("remix", false) and int(Game.project["points"]["Melody"]) >= 30, "remix recording starts from the original rating and a shorter session")
	Game.project = {}

	var show = _song("show", 8, Game.day - 10, 1.0)
	show["client"] = sleeper["client"]
	Game.songs.append(show)
	Game.life["stage"]["last_show_day"] = -99
	Game.life["stage"]["show"] = {}
	var before = Game.reputation
	var miss = StudioStage.book_show(show["id"], [a["id"]])
	check(miss["ok"] and not miss["hit"] and Game.reputation == before - 2, "a weak show still runs and costs reputation")
	check(StudioStage.book_show(show["id"], [a["id"]])["ok"] == false, "the hall cannot be booked twice in the same month")
	check(Game.start_project(offer["id"], [a["id"]], {"Pop": 100}, "Busy") == Locale.text("artist_busy"), "a performer cannot record on the show day")
	Game.day += 1
	StudioStage.tick_day()
	check(not StudioStage.performing(a["id"]), "the stage booking lasts one day")

	Game.life["stage"]["last_show_day"] = -99
	Game.life["stage"]["show"] = {}
	var strong = _song("strong", 40, Game.day - 10, 1.0)
	strong["client"] = sleeper["client"]
	Game.songs.append(strong)
	fans = Game.fans
	var night = StudioStage.book_show(strong["id"], [a["id"]])
	check(night["hit"] and Game.fans == fans + 400 and int(strong["chart_boost"]) == 3, "a strong show adds fans and chart push")
	Game.life["stage"]["show"] = {}
	Game.project = {}

	StudioStage.set_chemistry(a["id"], b["id"], 60)
	StudioStage.split_pair(a["id"], b["id"])
	check(StudioStage.chemistry(a["id"], b["id"]) == 15, "a breakup crashes chemistry")
	var banned = Game.start_project(offer["id"], [a["id"], b["id"]], {"Pop": 100}, "Banned")
	check(banned == Locale.text("stage_room_ban", [a["name"], b["name"], 14]), "a broken-up pair cannot share a room for 14 days")
	check(Game.start_project(offer["id"], [b["id"]], {"Pop": 100}, "Solo") == "", "either musician can still record alone")
	Game.project = {}

	Game.day += 1
	a["social"]["partner"] = b["id"]
	b["social"]["partner"] = a["id"]
	StudioStage.set_chemistry(a["id"], b["id"], 50)
	Game.life["stage"]["split_day"].erase(StudioStage.pair_key(a["id"], b["id"]))
	Game.life["stage"]["last_together"][StudioStage.pair_key(a["id"], b["id"])] = Game.day - 21
	StudioStage.tick_day()
	check(a["social"]["partner"] == "" and b["social"]["partner"] == "" and StudioStage.chemistry(a["id"], b["id"]) == 5, "21 days apart ends a staff couple and drops chemistry")

	var client_name = str(sleeper["client"])
	var before_rel = int(Game.get_client(client_name).get("rel", 0))
	Game.life["stage"]["show"] = {}
	Game.life["stage"]["last_show_day"] = -99
	var rapport = StudioStage.book_show(strong["id"], [b["id"]])
	check(rapport["hit"] and int(Game.get_client(client_name)["rel"]) == before_rel + 4, "a client in the hall gains rapport from a good show")

	Game.project = {}
	Game.save_game()
	var saved_rank = StudioStage.current_rank("hit")
	var saved_chem = StudioStage.chemistry(a["id"], b["id"])
	Game.life = {}
	Game.songs = []
	check(Game.load_game(), "stage save loads")
	check(StudioStage.current_rank("hit") == saved_rank and StudioStage.chemistry(Game.staff[0]["id"], Game.staff[1]["id"]) == saved_chem, "chart rank and chemistry survive reload")

	main = load("res://scenes/main.tscn").instantiate()
	main._booting = true
	add_child(main)
	main.login.hide()
	Game.tutorial_step = -1
	main.city_panel.show_song = "strong"
	main.city_panel.visit()
	main.city_panel.find_child("CityCompanion_alice", true, false).pressed.emit()
	main.city_panel.location = "hall"
	main.city_panel.refresh()
	check(main.city_panel.find_child("StageChart", true, false) != null, "Music Hall shows the weekly chart")
	check(main.city_panel.find_child("ChartLine1", true, false) != null, "the current number one is listed")
	check(main.city_panel.find_child("StageShowBook", true, false) != null, "the hall can book a show")
	check(main.city_panel.find_child("ShowSong_strong", true, false) != null, "released songs are offered for the show")
	main.city_panel.close()
	main.staff_panel.open()
	check(main.staff_panel.visible, "staff panel still opens with chemistry lines")
	main.staff_panel.close()

	print("STAGE TEST: %d checks, %d failures" % [checks, failures])
	Game.running = false
	main._queue.clear()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game._save_path()))
	await Audio.shutdown()
	get_tree().quit(1 if failures else 0)

func _song(id: String, rating: int, day: int, hype: float) -> Dictionary:
	return {
		"id": id,
		"title": id,
		"client": "",
		"mix": {"Pop": 100},
		"rating": rating,
		"day": day,
		"hype": hype,
		"chart_boost": 0,
		"peak_rank": 0,
		"weeks_on_chart": 0,
		"team": [],
		"remix_of": "",
		"cover_seed": 3,
		"marketing": "none",
		"weeks_left": 0,
		"earned": 0,
		"status": "",
		"audio_url": "",
		"local_audio": "",
		"local_cover": "",
		"idea_midi": "",
	}
