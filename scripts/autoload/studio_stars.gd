class_name StudioStars
extends RefCounted
const JOBS := {"photo": {"days": 3, "base": 1400}, "meet": {"days": 2, "base": 1000}, "license": {"days": 0, "base": 2200}, "concert": {"days": 5, "base": 3600}}
const BRANDS := ["Aurora Audio", "Daylight Fashion", "Neon Mobile", "Mellow Cafe", "Skyline Live", "Pulse Sports"]
const RIVALS := ["Nova", "Luna", "Atlas", "Iris", "Sol", "Echo", "Ruby", "Kai"]

static func data() -> Dictionary:
	if not Game.life.has("stars"): Game.life["stars"] = {}
	var state: Dictionary = Game.life["stars"]
	for key in ["profiles"]:
		if not state.has(key): state[key] = {}
	for key in ["offers", "assignments", "collections", "news", "royalties"]:
		if not state.has(key): state[key] = []
	for key in ["last_week", "last_news_day"]:
		if not state.has(key): state[key] = -99
	return state

static func profile(artist: Dictionary) -> Dictionary:
	if artist.get("role", "") != "Vocal": return {}
	var profiles: Dictionary = data()["profiles"]
	var id = str(artist["id"])
	if not profiles.has(id): profiles[id] = {"id": id, "name": artist["name"], "art_id": Art.model_id(artist), "fame": 0, "trust": 70, "releases": [], "album_tracks": [], "last_news": -99}
	return profiles[id]

static func busy(id: String) -> bool:
	for task in Game.life.get("stars", {}).get("assignments", []):
		if task["artist_id"] == id: return true
	return false

static func conflicts(ids: Array, start: int, end: int) -> bool:
	for task in data()["assignments"]:
		if task["artist_id"] in ids and start < int(task["until"]) and end > int(task["start"]): return true
	return false

static func tier(fame: int) -> String:
	if fame >= 5000: return "Superstar"
	if fame >= 2000: return "Star"
	if fame >= 600: return "Rising Star"
	return "Rookie"

static func rankings() -> Array:
	var rows: Array = []
	for i in RIVALS.size(): rows.append({"name": RIVALS[i], "id": "rival%d" % i, "fame": 6500 - i * 850 + int(Game.day / 7) * 15, "ours": false})
	for artist in Game.staff:
		var p = profile(artist)
		if not p.is_empty(): rows.append({"name": p["name"], "id": p["id"], "fame": p["fame"], "ours": true})
	rows.sort_custom(func(a: Dictionary, b: Dictionary): return a["fame"] > b["fame"] if a["fame"] != b["fame"] else str(a["id"]) < str(b["id"]))
	for i in rows.size(): rows[i]["rank"] = i + 1
	return rows

static func on_release(song: Dictionary, ids: Array) -> void:
	for id in ids:
		var artist = Game.get_artist(str(id))
		var p = profile(artist)
		if p.is_empty() or song["id"] in p["releases"]: continue
		p["releases"].append(song["id"])
		p["fame"] = mini(20000, int(p["fame"]) + maxi(30, int(song["rating"]) * 8))
		p["album_tracks"].append(song["id"])
		data()["collections"].append({"id": Game._id("single"), "type": "Single", "artist_id": id, "name": artist["name"], "art_id": Art.model_id(artist), "title": song["title"], "songs": [song["id"]], "rating": song["rating"], "day": Game.day})

static func make_album(id: String) -> String:
	var p = profile(Game.get_artist(id))
	if p.is_empty() or p["album_tracks"].size() < 3: return Locale.text("stars_album_need")
	if Game.money < 2500: return Locale.text("life_no_money")
	var tracks: Array = p["album_tracks"].slice(0, 3)
	var score = 0
	for song_id in tracks: score += int(StudioStage.song_by_id(song_id).get("rating", 0))
	Game.add_money(-2500)
	for song_id in tracks: p["album_tracks"].erase(song_id)
	data()["collections"].append({"id": Game._id("album"), "type": "Album", "artist_id": id, "name": p["name"], "art_id": p["art_id"], "title": p["name"] + " / Vol. " + str(data()["collections"].filter(func(c: Dictionary): return c["artist_id"] == id and c["type"] == "Album").size() + 1), "songs": tracks, "rating": score / 3, "day": Game.day})
	p["fame"] = mini(20000, int(p["fame"]) + 250)
	Game.save_game()
	return Locale.text("stars_album_done")

static func offer_for(artist: Dictionary, kind: String) -> Dictionary:
	var p = profile(artist)
	if p.is_empty() or p["releases"].is_empty() or not JOBS.has(kind): return {}
	if Game.day < int(p.get("brand_pause_until", -1)): return {}
	var fee = roundi((int(JOBS[kind]["base"]) + minf(10000, int(p["fame"]) * 1.4)) * (0.6 + int(p["trust"]) / 250.0))
	var offer = {"id": Game._id("brand"), "artist_id": artist["id"], "name": artist["name"], "brand": BRANDS.pick_random(), "kind": kind, "fee": fee, "days": JOBS[kind]["days"], "expires": Game.day + 10, "song_id": p["releases"].back()}
	data()["offers"].append(offer)
	return offer

static func accept(id: String) -> String:
	if StudioCity.fire_active(): return Locale.text("city_fire_wait")
	for offer in data()["offers"]:
		if offer["id"] != id: continue
		var artist = Game.get_artist(offer["artist_id"])
		if artist.is_empty() or artist.get("role", "") != "Vocal" or Game.day >= int(offer["expires"]): return Locale.text("staff_missing")
		if Game.day < int(profile(artist).get("brand_pause_until", -1)): return Locale.text("news_brand_pause")
		if offer["kind"] != "license":
			if not StudioLife.available(artist): return Locale.text("artist_busy")
			for booking in Game.production_queue:
				if artist["id"] in booking["team"] and int(booking["start_day"]) < Game.day + int(offer["days"]): return Locale.text("schedule_conflict")
			data()["assignments"].append({"id": id, "artist_id": artist["id"], "name": artist["name"], "kind": offer["kind"], "fee": offer["fee"], "start": Game.day, "until": Game.day + int(offer["days"])})
		else:
			Game.add_money(int(offer["fee"]))
			data()["royalties"].append({"id": id, "song_id": offer["song_id"], "weekly": maxi(100, int(offer["fee"]) / 10), "remaining": 8, "next": Game.day + 7})
		data()["offers"].erase(offer)
		Game.staff_changed.emit()
		Game.save_game()
		return Locale.text("stars_accepted")
	return Locale.text("stars_expired")

static func create_news(artist: Dictionary, kind: int) -> Dictionary:
	var p = profile(artist)
	if p.is_empty() or not data()["news"].is_empty(): return {}
	var event = {"id": Game._id("news"), "artist_id": artist["id"], "name": artist["name"], "kind": clampi(kind, 0, 2), "day": Game.day}
	data()["news"].append(event)
	p["last_news"] = Game.day
	data()["last_news_day"] = Game.day
	Game.hot_news.emit(event)
	Game.save_game()
	return event

static func resolve_news(id: String, choice: int) -> String:
	if choice < 0 or choice > 2: return Locale.text("back")
	for event in data()["news"]:
		if event["id"] != id: continue
		var impact = news_impact(event, choice)
		var cost = int(impact["cost"])
		if cost > 0 and Game.money < cost: return Locale.text("life_no_money")
		Game.add_money(-cost)
		var p: Dictionary = data()["profiles"][event["artist_id"]]
		p["fame"] = maxi(0, int(p["fame"]) + int(impact["fame"]))
		p["trust"] = clampi(int(p["trust"]) + int(impact["trust"]), 0, 100)
		var artist = Game.get_artist(event["artist_id"])
		if not artist.is_empty():
			var identity = MarketShift.identity(artist)
			identity["trust"] = clampi(int(identity["trust"]) + int(impact["trust"]), 0, 100)
		Game.reputation = clampi(Game.reputation + int(impact["reputation"]), 0, 100)
		if choice == 0: p["brand_pause_until"] = Game.day + 3
		data()["news"].erase(event)
		Game.staff_changed.emit()
		Game.save_game()
		return Locale.text("news_outcome", [cost, impact["fame"], impact["trust"], impact["reputation"]])
	return Locale.text("stars_news_resolved")

static func news_impact(event: Dictionary, choice: int) -> Dictionary:
	var result = {"cost":[1600,600,0][choice], "fame":[-40,-100,-220][choice], "trust":[3,-4,-15][choice], "reputation":[0,-1,-4][choice]}
	if int(event["kind"]) == 1 and choice == 2:
		result["fame"] = -70; result["trust"] = 1; result["reputation"] = -1
	if int(event["kind"]) == 2 and choice == 1:
		result["fame"] = -60; result["trust"] = 2; result["reputation"] = 0
	return result

static func news_choice(event: Dictionary, choice: int) -> String:
	var impact = news_impact(event, choice)
	return Locale.text("news_action_%d" % choice) + "\n" + Locale.text("news_outcome", [impact["cost"],impact["fame"],impact["trust"],impact["reputation"]])

static func tick_day() -> void:
	if StudioCity.fire_active(): return
	var state = data()
	for task in state["assignments"].duplicate():
		if Game.day < int(task["until"]): continue
		state["assignments"].erase(task)
		Game.add_money(int(task["fee"]))
		var p: Dictionary = state["profiles"].get(task["artist_id"], {})
		if not p.is_empty(): p["fame"] = mini(20000, int(p["fame"]) + (180 if task["kind"] == "concert" else 70))
		Game.alice_notice.emit(Locale.text("stars_paid", [task["name"], Data.money(task["fee"])]))
		Game.staff_changed.emit()
	for royalty in state["royalties"].duplicate():
		while int(royalty["remaining"]) > 0 and Game.day >= int(royalty["next"]):
			Game.add_money(int(royalty["weekly"]))
			royalty["remaining"] = int(royalty["remaining"]) - 1
			royalty["next"] = int(royalty["next"]) + 7
		if int(royalty["remaining"]) == 0: state["royalties"].erase(royalty)
	state["offers"] = state["offers"].filter(func(o: Dictionary): return Game.day < int(o["expires"]) and not Game.get_artist(o["artist_id"]).is_empty())
	var week = int(Game.day / 7)
	if not DemoCareer.active() and week > int(state["last_week"]):
		state["last_week"] = week
		for artist in Game.staff:
			var p = profile(artist)
			if p.is_empty() or int(p["fame"]) < 150 or state["offers"].size() >= 6: continue
			if randf() < 0.65:
				var offer = offer_for(artist, JOBS.keys().pick_random())
				if not offer.is_empty(): Game.alice_notice.emit(Locale.text("stars_brand_offer", [artist["name"], offer["brand"]]))
	if not DemoCareer.active() and Game.day >= 28 and Game.day - int(state["last_news_day"]) >= 28 and state["news"].is_empty():
		for artist in Game.staff:
			var p = profile(artist)
			if not p.is_empty() and int(p["fame"]) >= 600 and randf() < 0.008:
				create_news(artist, randi_range(0, 2))
				break
