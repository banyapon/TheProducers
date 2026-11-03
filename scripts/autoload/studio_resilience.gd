class_name StudioResilience
extends RefCounted

static func data() -> Dictionary:
	if not Game.life.has("resilience"): Game.life["resilience"] = {"insurance_until": -1, "inspection_until": -1, "recoveries": []}
	return Game.life["resilience"]

static func purchase(kind: String) -> String:
	if kind not in ["insurance", "inspection"] or StudioCity.fire_active(): return Locale.text("city_fire_wait")
	var price = 800 if kind == "insurance" else 1200
	if int(data()[kind + "_until"]) > Game.day: return Locale.text("risk_active")
	if Game.money < price: return Locale.text("life_no_money")
	Game.add_money(-price)
	data()[kind + "_until"] = Game.day + 28
	Game.save_game()
	return Locale.text("risk_bought")

static func fire_chance() -> float:
	return 0.006 if int(data()["inspection_until"]) > Game.day else 0.012

static func after_fire(damage: Dictionary) -> void:
	var payout = int(Data.ROOM_TYPES["studio"]["cost"] * 0.6) if damage.get("insured", false) else 0
	if payout > 0: Game.add_money(payout)
	var event = {"id": Game._id("recovery"), "payout":payout, "floor":damage["floor"], "column":damage["column"], "jobs":Game.jobs.map(func(j: Dictionary): return j["id"])}
	data()["recoveries"].append(event)
	Game.recovery_requested.emit(event)

static func resolve(id: String, choice: int) -> String:
	if StudioCity.fire_active() or choice not in [0,1]: return Locale.text("city_fire_wait")
	for event in data()["recoveries"]:
		if event["id"] != id: continue
		if choice == 1:
			if Game.money < 1200: return Locale.text("life_no_money")
			Game.add_money(-1200)
			for job in Game.jobs:
				if job["id"] in event["jobs"] and not job.get("fire_extension", false):
					job["due_day"] = int(job.get("due_day", Game.day)) + 3
					job["fire_extension"] = true
			Game.reputation = maxi(0, Game.reputation - 2)
		data()["recoveries"].erase(event)
		Game.jobs_changed.emit()
		Game.save_game()
		return Locale.text("risk_done")
	return Locale.text("risk_done")
