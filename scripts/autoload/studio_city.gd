class_name StudioCity
extends RefCounted
## All persistent city state is inside Game.life, clients and staff (existing save keys).
const ACTIONS := {
	"talk": {"cost": 0, "trust": 6, "comfort": 3, "attraction": 0, "scene": "city"},
	"walk": {"cost": 0, "trust": 5, "comfort": 7, "attraction": 2, "scene": "park"},
	"meal": {"cost": 350, "trust": 4, "comfort": 10, "attraction": 4, "scene": "restaurant"},
	"date": {"cost": 600, "trust": 6, "comfort": 8, "attraction": 12, "scene": "restaurant"},
}
const FIRE_DAYS := 4
const ALICE_AWARD_GOAL := 5
const ALICE_MIN_RATING := 30

static func alice_award_count() -> int:
	var qualifying: Dictionary = {}
	for trophy in Game.trophies:
		var song_id = str(trophy.get("song_id", ""))
		if song_id.is_empty() or not trophy.get("win", true): continue
		if int(trophy.get("rating", 0)) >= ALICE_MIN_RATING: qualifying[song_id] = true
	return qualifying.size()

static func alice() -> Dictionary:
	if not Game.life.has("alice"):
		Game.life["alice"] = {"id": "alice", "name": "Alice", "art_id": "alice", "romance_unlocked": false,
			"social": {"trust": 20, "comfort": 15, "attraction": 0, "partner": "", "last_day": -99, "last_action": "", "interested": true}}
	var person: Dictionary = Game.life["alice"]
	person.merge(Game.assistant_portrait(), true)
	ensure_person(person)
	if not person.get("romance_unlocked", false) and alice_award_count() >= ALICE_AWARD_GOAL:
		person["romance_unlocked"] = true
		person["social"]["interested"] = true
		person["social"]["trust"] = maxi(40, int(person["social"]["trust"]))
		person["social"]["comfort"] = maxi(35, int(person["social"]["comfort"]))
	return person

static func person_for(id: String, client: bool = false) -> Dictionary:
	if client: return Game.get_client(id)
	return alice() if id == "alice" else Game.get_artist(id)

static func alice_status() -> String:
	return Locale.text("alice_romance_ready") if alice()["romance_unlocked"] else Locale.text("alice_romance_locked")

static func ensure_person(person: Dictionary, client: bool = false) -> void:
	StudioLife.ensure_artist(person)
	var s: Dictionary = person["social"]
	var defaults = {"trust": 20, "comfort": 15, "attraction": 0, "partner": "", "last_day": -99, "last_action": "", "interested": true, "strain": 0, "warning": false, "break_until": -1, "care_day": Game.day, "tick_day": Game.day}
	for key in defaults:
		if not s.has(key): s[key] = defaults[key]
	if client:
		# Romance is with an adult contact, never with the client organization itself.
		if not person.has("contact_adult"): person["contact_adult"] = true
		if not person.has("contact_opt_in"): person["contact_opt_in"] = bool(s["interested"])
		if not person.has("met_day"): person["met_day"] = Game.day
		if not person.has("completed_jobs"): person["completed_jobs"] = 0

static func migrate() -> void:
	if not Game.life.has("city"): Game.life["city"] = {"last_action_day": -1, "last_fire_day": -99, "damage": [], "contest_song": "", "results": []}
	for a in Game.staff: ensure_person(a)
	for c in Game.clients.values(): ensure_person(c, true)
	alice()

static func partner_id() -> String:
	if alice()["social"]["partner"] == "producer": return "alice"
	for a in Game.staff:
		if a.get("social", {}).get("partner", "") == "producer": return str(a["id"])
	for c in Game.clients.values():
		if c.get("social", {}).get("partner", "") == "producer": return "client:" + str(c["name"])
	return ""

static func date_reason(person: Dictionary, client: bool) -> String:
	ensure_person(person, client)
	var s: Dictionary = person["social"]
	var id = "client:" + str(person["name"]) if client else str(person["id"])
	if id == "alice" and not alice()["romance_unlocked"]: return alice_status()
	if not s["interested"] or s["partner"] not in ["", "producer"] or partner_id() not in ["", id]: return Locale.text("city_unavailable")
	if Game.day < int(s["break_until"]): return Locale.text("city_cooling")
	# Changing the preference affects new romances; existing partners are preserved.
	if s["partner"] != "producer" and not RelationshipOptions.allows_pair(Game.player_portrait(), person): return Locale.text("relationship_mode_unavailable")
	if client:
		if not person["contact_adult"] or not person["contact_opt_in"]: return Locale.text("city_unavailable")
		if Game.day - int(person["met_day"]) < 28 or int(person["completed_jobs"]) < 2 or int(person.get("rel", 0)) < 40: return Locale.text("city_client_gate")
	elif id != "alice" and Game.day - int(person["joined_day"]) <= StudioLife.ROMANCE_DAYS: return Locale.text("romance_locked")
	if int(s["trust"]) < 40 or int(s["comfort"]) < 35: return Locale.text("city_trust_gate")
	return ""

static func interact(id: String, action: String, client: bool = false) -> Dictionary:
	migrate()
	var p = person_for(id, client)
	if p.is_empty() or not ACTIONS.has(action): return {"ok": false, "text": Locale.text("staff_missing")}
	ensure_person(p, client)
	if not client and not StudioLife.available(p): return {"ok": false, "text": Locale.text("artist_busy")}
	var s: Dictionary = p["social"]
	if int(Game.life["city"]["last_action_day"]) == Game.day or int(s["last_day"]) == Game.day: return {"ok": false, "text": Locale.text("city_daily_limit")}
	if action == "date":
		var reason = date_reason(p, client)
		if reason != "": return {"ok": false, "text": reason}
	var spec: Dictionary = ACTIONS[action]
	if Game.money < int(spec["cost"]): return {"ok": false, "text": Locale.text("life_no_money")}
	Game.add_money(-int(spec["cost"]))
	var repeat = 0.7 if s["last_action"] == action else 1.0
	for key in ["trust", "comfort", "attraction"]:
		# Friendly activities build rapport; attraction requires mutual availability.
		if key == "attraction" and date_reason(p, client) != "": continue
		s[key] = mini(100, int(s[key]) + int(round(int(spec[key]) * repeat)))
	s["last_day"] = Game.day
	s["care_day"] = Game.day
	s["last_action"] = action
	s["strain"] = maxi(0, int(s["strain"]) - 2)
	s["warning"] = false
	Game.life["city"]["last_action_day"] = Game.day
	if client: Game.add_relationship(id, 2 if action == "talk" else 4)
	else: StudioStage.on_outing(id)
	var key = "city_activity_done"
	if action == "date" and int(s["attraction"]) >= 60 and s["partner"] == "":
		s["partner"] = "producer"
		key = "city_partner"
	Game.staff_changed.emit()
	Game.save_game()
	return {"ok": true, "scene": spec["scene"], "text": Locale.text(key, [Game.client_contact(p) if client else p["name"]])}

static func weekly_fee(person: Dictionary) -> int:
	return 0 if person.get("social", {}).get("partner", "") == "producer" else int(person["fee_week"])

static func tick_day() -> void:
	migrate()
	if fire_active(): return
	for p in Game.staff + Game.clients.values() + [alice()]:
		var s: Dictionary = p["social"]
		if int(s["tick_day"]) >= Game.day: continue
		s["tick_day"] = Game.day
		if s["partner"] != "producer": continue
		var ignored = Game.day - int(s["care_day"])
		if ignored > 7:
			s["comfort"] = maxi(0, int(s["comfort"]) - 2)
			s["attraction"] = maxi(0, int(s["attraction"]) - 1)
		s["strain"] = int(s["strain"]) + 1 if Game.money < 0 else maxi(0, int(s["strain"]) - 1)
		if (ignored >= 10 or int(s["strain"]) >= 7) and not s["warning"]:
			s["warning"] = true
			Game.alice_notice.emit(Locale.text("city_warning", [p["name"]]))
		if ignored >= 21 or int(s["strain"]) >= 14:
			s["partner"] = ""
			s["attraction"] = 20
			s["break_until"] = Game.day + 28
			Game.alice_notice.emit(Locale.text("city_breakup", [p["name"]]))
			Game.staff_changed.emit()

static func fire_active() -> bool:
	return not Game.life.get("city", {}).get("damage", []).is_empty()

static func emergency_day() -> bool:
	migrate()
	for damage in Game.life["city"]["damage"].duplicate():
		if Game.day >= int(damage["until"]): extinguish(damage)
	if fire_active():
		defer_calendar()
		Game.save_game()
		return true
	return false

static func defer_calendar() -> void:
	var city: Dictionary = Game.life["city"]
	for period in [7, 28]:
		var key = "pending_weeks" if period == 7 else "pending_months"
		if not city.has(key): city[key] = []
		var index = int(Game.day / period)
		if Game.day % period == 0 and not city[key].has(index): city[key].append(index)

static func resume_calendar() -> void:
	var city: Dictionary = Game.life["city"]
	var weeks: Array = city.get("pending_weeks", []).duplicate()
	var months: Array = city.get("pending_months", []).duplicate()
	city["pending_weeks"] = []
	city["pending_months"] = []
	for week in weeks: Game._advance_week(int(week))
	for month in months:
		StudioLife.queue_feedback(int(month))
		Game._run_contest()

static func try_fire() -> void:
	var city: Dictionary = Game.life["city"]
	# One occupied studio only, protected first month and 28-day event cooldown.
	if Game.day >= 28 and Game.day - int(city["last_fire_day"]) >= 28 and city["damage"].is_empty() and randf() < StudioResilience.fire_chance():
		var active = Game.all_projects().filter(func(p: Dictionary): return not p["done"])
		if not active.is_empty(): ignite(int(active.pick_random().get("room", 0)))

static func extinguish(damage: Dictionary) -> void:
	if not damage in Game.life.get("city", {}).get("damage", []): return
	var room = int(damage["room"])
	# The lost recording must restart, but the commission remains active.
	for session in Game.all_projects():
		if int(session.get("room", 0)) == room: Game._remove_session(session)
		elif int(session.get("room", 0)) > room: session["room"] = int(session["room"]) - 1
	for booking in Game.production_queue.duplicate():
		if int(booking["room"]) == room:
			var job = Game.get_job(booking["job_id"])
			if not job.is_empty(): job["planned_day"] = Game.day
			Game.production_queue.erase(booking)
		elif int(booking["room"]) > room: booking["room"] = int(booking["room"]) - 1
	Game.floors[int(damage["floor"])][int(damage["column"])] = "empty"
	Game.life["city"]["damage"].erase(damage)
	StudioResilience.after_fire(damage)
	Game.building_changed.emit()
	Game.project_ended.emit()
	Game.jobs_changed.emit()
	Game.schedule_changed.emit()
	Game.notify.emit(Locale.text("city_repaired"))
	Game.save_game()

static func room_damage(room: int) -> Dictionary:
	for d in Game.life.get("city", {}).get("damage", []):
		if int(d["room"]) == room and Game.day < int(d["until"]): return d
	return {}

static func ignite(room: int) -> bool:
	migrate()
	if room < 0 or room >= Game.count_rooms("studio") or not Game.life["city"]["damage"].is_empty(): return false
	var index = 0
	for f in Game.floors.size():
		for c in Game.floors[f].size():
			if Game.floors[f][c] != "studio": continue
			if index == room:
				Game.life["city"]["damage"].append({"room": room, "floor": f, "column": c, "until": Game.day + FIRE_DAYS, "insured": int(StudioResilience.data()["insurance_until"]) > Game.day})
			index += 1
	Game.life["city"]["last_fire_day"] = Game.day
	Game.fire_started.emit()
	Game.building_changed.emit()
	Game.save_game()
	return true

static func rescue_deadline(job: Dictionary) -> bool:
	if job.get("grace_checked", false): return false
	job["grace_checked"] = true
	var c = Game.get_client(job["client"])
	var rel = int(c.get("rel", 0))
	if rel < 40: return false
	var chance = clampf(0.15 + (rel - 40) * 0.01 + (0.15 if c.get("social", {}).get("partner", "") == "producer" else 0.0), 0.0, 0.85)
	if randf() >= chance: return false
	job["due_day"] = Game.day + 4
	job["weeks_left"] = 1
	Game.add_relationship(job["client"], -5)
	Game.alice_notice.emit(Locale.text("city_grace", [job["title"]]))
	Game.jobs_changed.emit()
	return true

static func submit(song: Dictionary) -> String:
	migrate()
	if not Game.songs.has(song) or song.get("contest_entered", false): return Locale.text("city_contest_used")
	Game.life["city"]["contest_song"] = song["id"]
	Game.save_game()
	return Locale.text("city_submitted", [song["title"]])

static func contest_chance(rating: int, edition: int) -> float:
	var rival = minf(35.0, 25.0 + edition * 0.5)
	return clampf(0.5 + (clampi(rating, 4, 40) - rival) * 0.045, 0.08, 0.92)

static func contest() -> void:
	migrate()
	var city: Dictionary = Game.life["city"]
	for song in Game.songs:
		if song["id"] != city["contest_song"] or song.get("contest_entered", false): continue
		song["contest_entered"] = true
		var win = randf() < contest_chance(int(song["rating"]), Game.contest_edition)
		var result = {"edition": Game.contest_edition, "song": song["title"], "song_id": song["id"], "rating": song["rating"], "day": Game.day, "win": win}
		var rivals = ["Midnight Avenue", "Golden Hour", "Neon Rain", "Paper Moon", "Afterglow", "City of Stars"]
		result["winner"] = song["title"] if win else rivals[(Game.contest_edition - 1) % rivals.size()]
		city["results"].append(result)
		if city["results"].size() > 24: city["results"].pop_front()
		if win:
			Game.trophies.append(result.duplicate())
			alice() # Keep the hidden unlock current without announcing its trigger.
			Game.staff_changed.emit()
			Game.trophy_awarded.emit(Game.trophies.back())
			Game.fame += 500
			Game.reputation = mini(100, Game.reputation + 3)
			Game.fans_changed.emit(Game.fans)
		Game.contest_announced.emit(result)
		break
	city["contest_song"] = ""
	Game.contest_edition += 1
	Game.save_game()
