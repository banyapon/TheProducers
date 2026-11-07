class_name VipOffice
extends RefCounted
## Appointments and relationship consequences persist in the normal save.
static func connection(client: Dictionary) -> float:
	if int(client.get("office_visits", 0)) == 0: return 0.0
	return clampf(float(client.get("rel", 0)) / 100.0, 0.0, 1.0)

static func offer_bonus() -> float:
	var total := 0.0
	for client in Game.clients.values(): total += connection(client) * 0.08
	return minf(0.2, total)

static func reason(id: String) -> String:
	if Game.get_client(id).is_empty(): return Locale.text("vip_missing")
	if not Game.life.get("vip_appointment", {}).is_empty(): return Locale.text("vip_pending")
	if StudioCity.fire_active() or Game.life.get("bankrupt", false): return Locale.text("vip_unavailable")
	if Game.count_rooms("meeting") + Game.count_rooms("office") == 0: return Locale.text("vip_room")
	if not Game.idea_meeting.is_empty() or Game.is_researching("producer"): return Locale.text("vip_busy")
	if int(Game.life.get("vip_last_day", -99)) == Game.day: return Locale.text("vip_daily")
	var wait = 7 - (Game.day - int(Game.get_client(id).get("office_last_day", -99)))
	if wait > 0: return Locale.text("vip_wait", [wait])
	return ""

static func invite(id: String) -> String:
	var error = reason(id)
	if error != "": return error
	Game.life["vip_appointment"] = {"client": id}
	Game.save_game()
	return ""

static func complete() -> bool:
	var pending: Dictionary = Game.life.get("vip_appointment", {})
	if pending.is_empty() or StudioCity.fire_active() or Game.life.get("bankrupt", false): return false
	var id = str(pending.get("client", ""))
	var client = Game.get_client(id)
	Game.life["vip_appointment"] = {}
	if client.is_empty(): return false
	StudioCity.ensure_person(client, true)
	client["office_visits"] = int(client.get("office_visits", 0)) + 1
	client["office_last_day"] = Game.day
	Game.life["vip_last_day"] = Game.day
	var social: Dictionary = client["social"]
	social["trust"] = mini(100, int(social["trust"]) + 6)
	social["comfort"] = mini(100, int(social["comfort"]) + 4)
	social["care_day"] = Game.day
	social["strain"] = maxi(0, int(social.get("strain", 0)) - 2)
	Game.add_relationship(id, 8)
	Game.alice_notice.emit(Locale.text("vip_done", [Game.client_contact(client)]))
	Game.save_game()
	return true

static func production_pressure(job: Dictionary, team: Array, roll: float = -1.0) -> int:
	if job.get("vip_pressure_applied", false): return 0
	job["vip_pressure_applied"] = true
	var strength = float(job.get("vip_connection", 0.0))
	if strength <= 0.0: return 0
	var chance = 0.45 + strength * 0.30
	if (randf() if roll < 0.0 else roll) >= chance: return 0
	var loss = 3 + roundi(strength * 3)
	var affected := 0
	for id in team:
		var artist = Game.get_artist(str(id))
		if artist.is_empty(): continue
		StudioLife.ensure_artist(artist)
		artist["social"]["trust"] = maxi(0, int(artist["social"]["trust"]) - loss)
		affected += 1
	if affected > 0:
		Game.staff_changed.emit()
		Game.alice_notice.emit(Locale.text("vip_pressure", [job.get("title", ""), loss]))
	return loss if affected > 0 else 0
