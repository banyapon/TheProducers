class_name CreativeJourney
extends RefCounted

static func session(id: String) -> Dictionary:
	for p in Game.all_projects():
		if p["job_id"] == id: return p
	return {}

static func tick(p: Dictionary) -> bool:
	var job = Game.get_job(p["job_id"])
	if Game.day < int(p.get("retake_until", -1)): return true
	if job.get("creative_choice", "") != "" or not job.has("arrangement") or job.get("tutorial_brief", false) or int(job.get("demo_index", -1)) == 0: return false
	if float(p["progress"]) < 40: return false
	if not p.get("creative_pending", false):
		p["creative_pending"] = true
		Game.creative_decision_requested.emit(p["job_id"])
	return true

static func preview_notes(job: Dictionary, reduced: bool) -> Array:
	var m: Dictionary = job.get("arrangement", {}).duplicate(true)
	if m.is_empty(): return []
	if reduced: m["placed"] = m["placed"].filter(func(p: Dictionary): return not (int(p["row"]) == 1 and int(p["col"]) < 5))
	return IdeaMusic.events(m["deck"], m["placed"])

static func can_simplify(job: Dictionary) -> bool:
	return job.get("arrangement", {}).get("placed", []).any(func(p): return int(p["row"]) == 1 and int(p["col"]) < 5)

static func trust(ids: Array, amount: int) -> void:
	for id in ids:
		var artist = Game.get_artist(id)
		if artist.get("role", "") != "Vocal": continue
		var p = StudioStars.profile(artist)
		p["trust"] = clampi(int(p["trust"]) + amount,0,100)
		var identity = MarketShift.identity(artist)
		identity["trust"] = clampi(int(identity["trust"]) + amount,0,100)
	Game.staff_changed.emit()

static func resolve(id: String, choice: int) -> String:
	var p = session(id)
	var job = Game.get_job(id)
	if StudioCity.fire_active() or p.is_empty() or job.is_empty() or not p.get("creative_pending", false) or job.has("creative_choice") or choice not in [0,1,2]: return Locale.text("journey_unavailable")
	if choice == 1 and Game.money < 600: return Locale.text("life_no_money")
	if choice == 2 and not can_simplify(job): return Locale.text("journey_unavailable")
	job["creative_choice"] = ["keep", "retake", "simplify"][choice]
	job["creative_score"] = [-0.02,0.06,-0.01][choice]
	p["creative_pending"] = false
	if choice == 1:
		Game.add_money(-600)
		p["retake_until"] = Game.day + 3
	if choice == 2:
		var m: Dictionary = job["arrangement"]
		m["placed"] = m["placed"].filter(func(cell: Dictionary): return not (int(cell["row"]) == 1 and int(cell["col"]) < 5))
		job["idea_notes"] = IdeaMusic.events(m["deck"], m["placed"])
		job["idea_score"] = IdeaRules.score(m)["score"]
		IdeaMusic.write_midi(job["idea_notes"], job["idea_bpm"], job["idea_midi"])
		p["mix"] = ComposerFlow.arrangement_mix(job)
		p["progress"] = minf(95, float(p["progress"]) + 15)
	trust(p["team"], [4,-2,0][choice])
	Game.save_game()
	return Locale.text("journey_done_" + job["creative_choice"])

static func on_release(job: Dictionary, song: Dictionary) -> void:
	song["signature"] = job.get("arrangement", {}).get("signature", {}).duplicate(true)
	song["creative_choice"] = job.get("creative_choice", "")
	if job.has("demo_index") and int(job["demo_index"]) < 2: return
	if int(song["rating"]) >= 24 and song["team"].any(func(id): return Game.get_artist(id).get("role", "") == "Vocal"):
		song["rights_offer_until"] = Game.day + 14
		Game.notify.emit(Locale.text("rights_available"))

static func locked(song: Dictionary) -> bool:
	return Game.day < int(song.get("exclusive_until", -1))

static func available(song: Dictionary) -> bool:
	if song.get("archived",false) or song.has("rights_choice") or Game.day >= int(song.get("rights_offer_until", -1)): return false
	for c in StudioStars.data()["collections"]:
		if c["type"] == "Album" and song["id"] in c["songs"]: return false
	for r in StudioStars.data()["royalties"]:
		if r["song_id"] == song["id"]: return false
	return true

static func rights(song: Dictionary, choice: int) -> String:
	if StudioCity.fire_active() or not song in Game.songs or not available(song) or choice not in [0,1,2]: return Locale.text("journey_unavailable")
	song["rights_choice"] = ["exclusive","limited","keep"][choice]
	var fee = 6000 + int(song["rating"]) * 100 if choice == 0 else (2500 + int(song["rating"]) * 50 if choice == 1 else 0)
	Game.add_money(fee)
	song["rights_income"] = fee
	if choice == 0: song["exclusive_until"] = Game.day + 56
	if choice == 1: StudioStars.data()["royalties"].append({"id":Game._id("rights"),"song_id":song["id"],"weekly":300,"remaining":8,"next":Game.day+7})
	trust(song["team"], [-8,1,5][choice])
	StudioStars.data()["offers"] = StudioStars.data()["offers"].filter(func(o): return o["kind"] != "license" or o["song_id"] != song["id"])
	Game.save_game()
	Game.song_updated.emit(song)
	return Locale.text("rights_done_" + song["rights_choice"])

static func history(song: Dictionary) -> String:
	var result = SongIdentity.label(song.get("signature", {}))
	if song.get("creative_choice", "") != "": result += "\n" + Locale.text("journey_done_" + song["creative_choice"])
	if song.has("rights_choice"): result += "\n" + Locale.text("rights_done_" + song["rights_choice"])
	if locked(song): result += "\n" + Locale.text("rights_locked", [int(song["exclusive_until"]) - Game.day])
	return result
