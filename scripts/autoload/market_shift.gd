class_name MarketShift
extends RefCounted

static func state() -> Dictionary:
	if not Game.life.has("market_shift"):
		Game.life["market_shift"] = {"seed": randi_range(0, 11), "history": []}
	return Game.life["market_shift"]

static func genre(offset: int = 0) -> String:
	return Data.GENRES[posmod(int(state()["seed"]) + (int(Game.day / 28) + offset) * 5, Data.GENRES.size())]

static func identity(artist: Dictionary) -> Dictionary:
	if not artist.has("identity"):
		artist["identity"] = {"genre": Data.sorted_tags(artist["skills"])[0], "loyalty": 70, "trust": 70}
	return artist["identity"]

static func plan(job: Dictionary) -> Dictionary:
	if not job.has("shift_plan"):
		for artist in Game.staff:
			if artist.get("role", "") != "Vocal": continue
			var home: String = identity(artist)["genre"]
			job["shift_plan"] = {"artist_id": artist["id"], "artist": artist["name"], "home": home, "target": genre() if genre() != home else genre(1), "strategy": "hold"}
			break
	return job.get("shift_plan", {})

static func choose(job: Dictionary, strategy: String) -> bool:
	if strategy not in ["hold", "blend", "pivot"] or int(job.get("idea_rounds", 0)) > 0: return false
	var p = plan(job)
	if p.is_empty(): return false
	p["strategy"] = strategy
	Game.save_game()
	return true

static func outlook(job: Dictionary) -> String:
	var p = plan(job)
	if p.is_empty(): return Locale.text("shift_no_vocal")
	var artist = Game.get_artist(p["artist_id"])
	if artist.is_empty(): return Locale.text("shift_no_vocal")
	var a = identity(artist)
	return Locale.text("shift_outlook", [genre(), genre(1), p["artist"], p["home"], a["loyalty"], a["trust"], p["target"]])

static func release(job: Dictionary, song: Dictionary, ids: Array) -> void:
	if song.has("shift_result"): return
	var p: Dictionary = job.get("shift_plan", {})
	if p.is_empty() or not p["artist_id"] in ids: return
	var artist = Game.get_artist(p["artist_id"])
	if artist.is_empty(): return
	var a = identity(artist)
	var mix: Dictionary = song["mix"]
	var arrangement: Dictionary = job.get("arrangement", {})
	if not arrangement.get("placed", []).is_empty():
		mix = {}
		for placed in arrangement["placed"]:
			var g: String = arrangement["deck"][placed["block"]]["genre"]
			mix[g] = float(mix.get(g,0)) + 100.0 / arrangement["placed"].size()
	var home_share = float(mix.get(p["home"], 0)) / 100.0
	var target_share = float(mix.get(p["target"], 0)) / 100.0
	var strategy: String = p["strategy"]
	var followed = home_share >= 0.6 if strategy == "hold" else (home_share >= 0.25 and target_share >= 0.25 if strategy == "blend" else target_share >= 0.6)
	var loyalty = 0
	var trust = 0
	var multiplier = 1.0
	if followed:
		match strategy:
			"hold": loyalty = 6; trust = 3; multiplier = 1.05
			"blend": loyalty = -3; trust = 2; multiplier = 1.12
			"pivot":
				loyalty = -12; trust = -6; multiplier = 1.25
				if int(song["rating"]) >= 24: a["genre"] = p["target"]
	else: loyalty = -5; trust = -4; multiplier = 0.95
	# Audience reach is earned by the released sound, and limited by song quality.
	var market_share = float(mix.get(genre(), 0)) / 100.0
	multiplier = 1.0 + (multiplier - 1.0) * clampf(float(song["rating"]) / 40.0, 0, 1) + market_share * 0.10
	multiplier *= 0.85 + int(a["loyalty"]) * 0.003
	a["loyalty"] = clampi(int(a["loyalty"]) + loyalty,0,100)
	a["trust"] = clampi(int(a["trust"]) + trust,0,100)
	var profile = StudioStars.profile(artist)
	if not profile.is_empty(): profile["trust"] = clampi(int(profile["trust"]) + trust,0,100)
	song["weekly_sales"] = roundi(int(song["weekly_sales"]) * multiplier)
	song["shift_result"] = {"strategy":strategy, "artist":p["artist"], "market":genre(), "followed":followed, "loyalty":loyalty, "trust":trust, "sales_pct":roundi((multiplier - 1) * 100)}
	state()["history"].append(song["shift_result"].duplicate(true))
	if state()["history"].size() > 30: state()["history"].pop_front()
	Game.alice_notice.emit(Locale.text("shift_result", [p["artist"], Locale.text("shift_" + strategy), song["shift_result"]["sales_pct"], loyalty, trust]))
	Game.staff_changed.emit()
