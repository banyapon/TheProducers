class_name StudioLife
extends RefCounted
## Persistent state lives in Game.life / staff dictionaries. This class owns its rules.
const ROMANCE_DAYS := 112
const TRAIN_COST := 1800
const TRAIN_DAYS := 7

static func ensure_artist(a: Dictionary) -> void:
	if not a.has("joined_day"): a["joined_day"] = 0
	if not a.has("social"):
		a["social"] = {"trust": 20, "comfort": 15, "attraction": 0, "partner": "", "last_day": -99, "last_action": "", "interested": randf() < 0.75}
	if not a.has("met"): a["met"] = false
	if not a.has("auto_renew"): a["auto_renew"] = false

static func migrate() -> void:
	if not Game.life.has("training"): Game.life["training"] = []
	if not Game.life.has("feedback"): Game.life["feedback"] = []
	if not Game.life.has("resolved_month"): Game.life["resolved_month"] = 0
	for a in Game.staff: ensure_artist(a)
	StudioCity.migrate()
	StudioStage.migrate()

static func training(id: String) -> Dictionary:
	for task in Game.life.get("training", []):
		if task["artist_id"] == id: return task
	return {}

static func available(a: Dictionary) -> bool:
	return not a.is_empty() and not Game.is_in_project(a["id"]) and not Game.is_researching(a["id"]) and training(a["id"]).is_empty() and a["id"] not in Game.idea_meeting.get("participants", []) and not StudioStage.performing(str(a["id"]))

static func train(a: Dictionary, genre: String) -> String:
	if not Game.staff.has(a) or genre not in Data.GENRES: return Locale.text("staff_missing")
	if not available(a): return Locale.text("artist_busy")
	for booking in Game.production_queue:
		if a["id"] in booking["team"] and int(booking["start_day"]) < Game.day + TRAIN_DAYS: return Locale.text("schedule_conflict")
	if Game.money < TRAIN_COST: return Locale.text("life_no_money")
	Game.add_money(-TRAIN_COST)
	migrate()
	Game.life["training"].append({"artist_id": a["id"], "genre": genre, "finish_day": Game.day + TRAIN_DAYS})
	Game.staff_changed.emit()
	Game.save_game()
	return Locale.text("training_sent", [a["name"], genre, TRAIN_DAYS])

static func socialize(id: String, action: String) -> String:
	var mapped = {"party": "meal", "flirt": "date"}.get(action, action)
	return StudioCity.interact(id, mapped)["text"]


static func pair_staff(a: Dictionary, b: Dictionary) -> bool:
	if a == b or not Game.staff.has(a) or not Game.staff.has(b): return false
	if not RelationshipOptions.allows_pair(a, b): return false
	for person in [a, b]:
		ensure_artist(person)
		if Game.day - int(person["joined_day"]) <= ROMANCE_DAYS or not person["social"]["interested"] or person["social"]["partner"] != "": return false
	# Adult staff follow the player's relationship preference; Alice is outside this pool.
	a["social"]["partner"] = b["id"]
	b["social"]["partner"] = a["id"]
	StudioStage.on_couple(a, b)
	Game.alice_notice.emit(Locale.text("staff_couple", [a["name"], b["name"]]))
	Game.staff_changed.emit()
	return true

static func tick_day() -> void:
	migrate()
	if StudioCity.fire_active(): return
	for task in Game.life["training"].duplicate():
		if Game.day < int(task["finish_day"]): continue
		Game.life["training"].erase(task)
		var a = Game.get_artist(task["artist_id"])
		if not a.is_empty():
			a["skills"][task["genre"]] = mini(100, int(a["skills"].get(task["genre"], 0)) + 8)
			a["experience"] = mini(100, int(a.get("experience", 0)) + 5)
			Game.alice_notice.emit(Locale.text("training_done", [a["name"], task["genre"]]))
			Game.staff_changed.emit()
	if Game.day % 28 == 0:
		queue_feedback(int(Game.day / 28))
	if Game.day % 7 == 0 and Game.day > ROMANCE_DAYS:
		var eligible = Game.staff.filter(func(a: Dictionary): return available(a))
		eligible.shuffle()
		if eligible.size() >= 2 and randf() < 0.35: pair_staff(eligible[0], eligible[1])
	StudioStage.tick_day()

static func queue_feedback(month: int) -> void:
	if month > int(Game.life["resolved_month"]) and not Game.life["feedback"].has(month):
		Game.life["feedback"].append(month)
		Game.monthly_feedback.emit(month)

static func feedback(month: int) -> Dictionary:
	var events = Locale.values("monthly_events")
	return events[(month - 1) % events.size()] if not events.is_empty() else {}

static func resolve_feedback(month: int, option: int) -> String:
	migrate()
	if not Game.life["feedback"].has(month): return Locale.text("feedback_resolved")
	var event = feedback(month)
	if option < 0 or option >= event.get("choices", []).size(): return Locale.text("back")
	var choice: Dictionary = event["choices"][option]
	if Game.money < int(choice.get("cost", 0)): return Locale.text("life_no_money")
	Game.add_money(-int(choice.get("cost", 0)))
	Game.fame = maxi(0, Game.fame + int(choice["fame"]))
	Game.reputation = clampi(Game.reputation + int(choice["reputation"]), 0, 100)
	Game.life["feedback"].erase(month)
	Game.life["resolved_month"] = maxi(month, int(Game.life["resolved_month"]))
	Game.fans_changed.emit(Game.fans)
	Game.save_game()
	return Locale.text("feedback_result", [choice["fame"], choice["reputation"]])

static func auto_arrange(job: Dictionary) -> void:
	if int(job.get("idea_rounds", 0)) > 0: return
	var meeting = IdeaRules.create(job)
	for lane in range(4):
		var step = 0
		for i in meeting["deck"].size():
			var block: Dictionary = meeting["deck"][i]
			if int(block["lane"]) != lane: continue
			if IdeaRules.can_place(meeting, i, lane, step):
				meeting["placed"].append({"block": i, "row": lane, "col": step})
				step += int(block["width"])
	var score = IdeaRules.score(meeting)
	job["idea"] = mini(30, int(job.get("idea", 0)) + int(score["idea"]) / 2)
	job["idea_notes"] = IdeaMusic.events(meeting["deck"], meeting["placed"])
	job["idea_bpm"] = meeting["bpm"]
	job["idea_rounds"] = 1
	job["idea_score"] = score["score"]
