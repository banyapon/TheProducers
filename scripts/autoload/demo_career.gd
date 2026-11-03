class_name DemoCareer
extends RefCounted

static func active() -> bool:
	return Game.life.has("demo") and not Game.life["demo"].get("finished", false)

static func next_step() -> Dictionary:
	if not active(): return {}
	var index = Game.life["demo"]["completed"].size()
	for job in Game.jobs:
		if int(job.get("demo_index", -1)) != index or job.get("status", "") != "active": continue
		for session in Game.all_projects():
			if session["job_id"] == job["id"]:
				return {"index":index, "job":job, "action":"release" if session["done"] else "recording"}
		return {"index":index, "job":job, "action":"compose" if Game.needs_manual_composition(job) else "record"}
	for job in Game.offers:
		if int(job.get("demo_index", -1)) == index: return {"index":index, "job":job, "action":"brief"}
	return {}

static func setup() -> void:
	Game.life["demo"] = {"completed": [], "finished": false}
	Game.tutorial_step = -1
	Game.tutorial_gate = false
	Game.identity_initialized = true
	Game.intro_seen = true
	Game.money = 45000
	MarketShift.state()["seed"] = Data.GENRES.find("Rock")
	for artist in Game.staff:
		artist["weeks_left"] = 52
		for genre in ["Lofi", "Rock", "Pop"]: artist["skills"][genre] = 60
		if artist["role"] == "Vocal": artist["identity"] = {"genre":"Lofi", "loyalty":70, "trust":70}
	Game.offers.clear()
	next_brief(0)

static func next_brief(index: int) -> void:
	var job = Game.generate_job(true)
	job["demo_index"] = index
	job["brief_kind"] = ["cafe", "sport", "debut"][index]
	job["title"] = ["Morning Coffee", "Final Sprint", "First Spotlight"][index]
	job["mix"] = [{"Lofi":100}, {"Rock":100}, {"Pop":100}][index]
	job["artist_genre"] = ["Lofi", "Rock", "Pop"][index]
	job["roles"] = ["Vocal", "Producer"]
	job["revealed"] = job["mix"].keys()
	job["deadline"] = 12
	job["expires"] = 999
	Game.offers.push_front(job)
	Game.jobs_changed.emit()
	Game.alice_notice.emit(Locale.text("demo_next", [index + 1]))

static func released(job: Dictionary, song: Dictionary) -> void:
	if not job.has("demo_index") or not Game.life.has("demo"): return
	var d: Dictionary = Game.life["demo"]
	if d["finished"]: return
	d["completed"].append({"title": song["title"], "rating": song["rating"], "arrangement": job.get("idea_score",0), "shift": song.get("shift_result", {}).duplicate(true)})
	if d["completed"].size() < 3: next_brief(d["completed"].size())
	else:
		d["finished"] = true
		Game.demo_completed.emit()

static func summary() -> String:
	var lines = PackedStringArray()
	for song in Game.life.get("demo", {}).get("completed", []):
		lines.append("%s | %d/40 | Arrangement %d/100" % [song["title"],song["rating"],song["arrangement"]])
		if not song.get("shift", {}).is_empty():
			var shift: Dictionary = song["shift"]
			lines.append(Locale.text("shift_result", [shift["artist"], Locale.text("shift_" + shift["strategy"]), shift["sales_pct"], shift["loyalty"], shift["trust"]]))
	return Locale.text("demo_end", ["\n".join(lines)])
