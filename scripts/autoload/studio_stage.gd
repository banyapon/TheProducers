class_name StudioStage
extends RefCounted
## Charts, band chemistry and Music Hall shows. State lives in Game.life.stage.
const SHOW_COST := 1200
const SHOW_GAP := 28
const RIVALS := ["Midnight Avenue", "Golden Hour", "Neon Rain", "Paper Moon", "Afterglow", "City of Stars"]
const RIVAL_TITLES := ["Glass Heart", "Night Bus", "Paper Crown", "Slow Burn", "Gold Static", "Second Floor"]

static func stage() -> Dictionary:
	migrate()
	return Game.life["stage"]

static func migrate() -> void:
	if not Game.life.has("stage") or not (Game.life["stage"] is Dictionary):
		Game.life["stage"] = {}
	var data: Dictionary = Game.life["stage"]
	for key in ["pairs", "cooldowns", "split_day", "genre_fans", "last_together"]:
		if not data.has(key) or not (data[key] is Dictionary):
			data[key] = {}
	if not data.has("bands") or not (data["bands"] is Array):
		data["bands"] = []
	if not data.has("chart") or not (data["chart"] is Array):
		data["chart"] = []
	if not data.has("chart_week"): data["chart_week"] = 0
	if not data.has("last_show_day"): data["last_show_day"] = -99
	if not data.has("show") or not (data["show"] is Dictionary):
		data["show"] = {}
	if not data.has("fan_request"): data["fan_request"] = ""
	for song in Game.songs:
		if not song.has("chart_boost"): song["chart_boost"] = 0
		if not song.has("peak_rank"): song["peak_rank"] = 0
		if not song.has("weeks_on_chart"): song["weeks_on_chart"] = 0
		if not song.has("hype"): song["hype"] = hype_of(song)
		if not song.has("team") or not (song["team"] is Array): song["team"] = []
		if not song.has("remix_of"): song["remix_of"] = ""
		if not song.has("band_word"): song["band_word"] = ""
		if not song.has("band_genre"): song["band_genre"] = ""

static func tick_day() -> void:
	migrate()
	var show: Dictionary = stage()["show"]
	if not show.is_empty() and Game.day > int(show.get("until", -1)):
		stage()["show"] = {}
	var training: Array = Game.life.get("training", [])
	var trainees: Array = []
	for task in training:
		trainees.append(str(task["artist_id"]))
	_bump_group(trainees, 1)
	for a in Game.staff:
		var partner = str(a.get("social", {}).get("partner", ""))
		if partner == "" or partner == "producer" or partner <= str(a["id"]): continue
		var other = Game.get_artist(partner)
		if other.is_empty() or str(other.get("social", {}).get("partner", "")) != str(a["id"]): continue
		var key = pair_key(str(a["id"]), partner)
		var seen = int(stage()["last_together"].get(key, a.get("joined_day", Game.day)))
		if Game.day - seen >= 21:
			split_pair(str(a["id"]), partner)

static func performing(id: String) -> bool:
	if StudioStars.busy(id): return true
	var show: Dictionary = Game.life.get("stage", {}).get("show", {})
	return not show.is_empty() and Game.day <= int(show.get("until", -1)) and id in show.get("team", [])

static func pair_key(a: String, b: String) -> String:
	return a + "|" + b if a < b else b + "|" + a

static func chemistry(a: String, b: String) -> int:
	if a == "" or b == "" or a == b: return 0
	var key = pair_key(a, b)
	var pairs: Dictionary = stage()["pairs"]
	if not pairs.has(key):
		pairs[key] = _initial(a, b)
	return int(pairs[key])

static func set_chemistry(a: String, b: String, value: int) -> void:
	stage()["pairs"][pair_key(a, b)] = clampi(value, 0, 100)
	_refresh_bands()

static func add_chemistry(a: String, b: String, amount: int) -> void:
	if a == "" or b == "" or a == b or amount == 0: return
	var key = pair_key(a, b)
	stage()["pairs"][key] = clampi(chemistry(a, b) + amount, 0, 100)
	stage()["last_together"][key] = Game.day
	_refresh_bands()

static func on_couple(a: Dictionary, b: Dictionary) -> void:
	var key = pair_key(str(a["id"]), str(b["id"]))
	stage()["pairs"][key] = maxi(chemistry(str(a["id"]), str(b["id"])), 78)
	stage()["cooldowns"].erase(key)
	stage()["last_together"][key] = Game.day
	_refresh_bands()

static func on_outing(id: String) -> void:
	var artist = Game.get_artist(id)
	if artist.is_empty(): return
	var best_id := ""
	var best := -1
	for other in Game.staff:
		if str(other["id"]) == id: continue
		var score = 0
		for genre in Data.GENRES:
			score += mini(int(artist["skills"].get(genre, 0)), int(other["skills"].get(genre, 0)))
		if score > best:
			best = score
			best_id = str(other["id"])
	if best_id != "":
		add_chemistry(id, best_id, 2)

static func on_shared_room(ids: Array) -> void:
	_bump_group(ids, 1)

static func split_pair(a: String, b: String) -> void:
	migrate()
	if a == "" or b == "" or a == b: return
	var key = pair_key(a, b)
	var data: Dictionary = stage()
	if int(data["split_day"].get(key, -999)) != Game.day:
		data["split_day"][key] = Game.day
		data["pairs"][key] = clampi(chemistry(a, b) - 45, 0, 100)
		var left = Game.get_artist(a)
		var right = Game.get_artist(b)
		Game.alice_notice.emit(Locale.text("stage_split", [left.get("name", a), right.get("name", b)]))
	data["cooldowns"][key] = Game.day + 14
	for person in [Game.get_artist(a), Game.get_artist(b)]:
		if person.is_empty(): continue
		var partner = str(person.get("social", {}).get("partner", ""))
		if partner == a or partner == b:
			person["social"]["partner"] = ""
	Game.staff_changed.emit()

static func ban_reason(ids: Array, on_day: int = -1) -> String:
	var when = Game.day if on_day < 0 else on_day
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var until = int(stage()["cooldowns"].get(pair_key(str(ids[i]), str(ids[j])), -1))
			if when < until:
				var left = Game.get_artist(str(ids[i]))
				var right = Game.get_artist(str(ids[j]))
				return Locale.text("stage_room_ban", [left.get("name", ids[i]), right.get("name", ids[j]), until - when])
	return ""

static func craft_multiplier(team: Array) -> float:
	if team.size() < 2: return 1.0
	var ids: Array = []
	for artist in team: ids.append(str(artist["id"]))
	var avg = _average(ids)
	if avg >= 0.70: return 1.25
	if avg >= 0.50: return 1.10
	return 1.0

static func friction_today(ids: Array) -> bool:
	if ids.size() < 2 or Game.day % 3 != 0: return false
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			if chemistry(str(ids[i]), str(ids[j])) < 30: return true
	return false

static func lowest_pair(ids: Array) -> Array:
	var names: Array = []
	var lowest := 101
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var value = chemistry(str(ids[i]), str(ids[j]))
			if value < lowest:
				lowest = value
				names = [Game.get_artist(str(ids[i])).get("name", ids[i]), Game.get_artist(str(ids[j])).get("name", ids[j])]
	return names

static func team_summary(ids: Array) -> String:
	if ids.size() < 2: return ""
	var avg = int(round(_average(ids) * 100.0))
	var bonus = int(round((craft_multiplier(_artists(ids)) - 1.0) * 100.0))
	var line = Locale.text("stage_team_chem", [avg, bonus])
	if friction_today(ids):
		line += " " + Locale.text("stage_team_friction")
	return line

static func closest_label(id: String) -> String:
	var best_name := ""
	var best := -1
	for artist in Game.staff:
		if str(artist["id"]) == id: continue
		var value = chemistry(id, str(artist["id"]))
		if value > best:
			best = value
			best_name = str(artist["name"])
	return Locale.text("stage_chem_line", [best_name, best]) if best_name != "" else ""

static func on_week() -> void:
	migrate()
	var week = int(Game.day / 7)
	if week <= 0 or int(stage()["chart_week"]) == week: return
	stage()["chart_week"] = week
	for song in Game.songs:
		var genre = dominant(song.get("mix", {}))
		stage()["genre_fans"][genre] = mini(400, int(stage()["genre_fans"].get(genre, 0)) + maxi(1, int(song.get("rating", 0)) / 5))
	if Game.day >= 21 and Game.tutorial_step < 0 and week % 2 == 0:
		var radio = radio_target()
		if not radio.is_empty():
			radio["chart_boost"] = int(radio.get("chart_boost", 0)) + 2
			Game.fans += 40
			Game.fans_changed.emit(Game.fans)
			Game.alice_notice.emit(Locale.text("stage_radio", [radio["title"]]))
	_resolve_chart()
	for song in Game.songs:
		song["chart_boost"] = maxi(0, int(song.get("chart_boost", 0)) - 1)
	if Game.day >= 21 and Game.tutorial_step < 0 and week % 3 == 0 and Game.offers.size() < Game.MAX_OFFERS:
		var offer = offer_remix()
		if not offer.is_empty():
			Game.alice_notice.emit(Locale.text("stage_remix_offer", [offer["client"], offer["title"]]))
	var request := ""
	var best_rating := -1
	for song in Game.songs:
		if current_rank(str(song["id"])) == 1: continue
		if int(song.get("rating", 0)) > best_rating:
			best_rating = int(song.get("rating", 0))
			request = str(song["id"])
	stage()["fan_request"] = request
	var best_rank := 99
	var best_title := ""
	for entry in stage()["chart"]:
		if entry.get("player", false) and int(entry["rank"]) < best_rank:
			best_rank = int(entry["rank"])
			best_title = str(entry["title"])
	if best_title != "" and Game.tutorial_step < 0:
		Game.alice_notice.emit(Locale.text("stage_chart_notice", [best_title, best_rank]))

static func song_score(song: Dictionary) -> int:
	migrate()
	var age = maxi(0, int((Game.day - int(song.get("day", Game.day))) / 7.0))
	var loyalty = genre_share(dominant(song.get("mix", {})))
	var decay = age * 0.35 * (1.0 - loyalty * 0.55)
	var fresh = 1.0 / (1.0 + decay)
	var boost = int(song.get("chart_boost", 0))
	var rating = clampi(int(song.get("rating", 0)), 0, 40)
	return int(round((rating / 40.0) * hype_of(song) * (1.0 + Game.fans / 8000.0) * fresh * (1.0 + boost * 0.22) * 100.0))

static func genre_share(genre: String) -> float:
	var total = 0
	var fans: Dictionary = stage()["genre_fans"]
	for key in fans:
		total += int(fans[key])
	if total <= 0: return 0.0
	return float(int(fans.get(genre, 0))) / float(total)

static func hype_of(song: Dictionary) -> float:
	if song.has("hype"): return float(song["hype"])
	for plan in Data.MARKETING:
		if plan["name"] == song.get("marketing", ""): return float(plan["hype"])
	return 1.0

static func radio_target() -> Dictionary:
	var top := {}
	for entry in stage()["chart"]:
		if int(entry.get("rank", 99)) <= 3:
			top[str(entry.get("song_id", ""))] = true
	var best: Dictionary = {}
	var lowest := 999999
	for song in Game.songs:
		if int(song.get("rating", 0)) < 28 or top.has(str(song["id"])): continue
		var score = song_score(song)
		if best.is_empty() or score < lowest:
			best = song
			lowest = score
	return best

static func current_rank(song_id: String) -> int:
	for entry in stage()["chart"]:
		if str(entry.get("song_id", "")) == song_id and entry.get("player", false):
			return int(entry["rank"])
	return 0

static func rank_line(song: Dictionary) -> String:
	migrate()
	var rank = current_rank(str(song.get("id", "")))
	var peak = int(song.get("peak_rank", 0))
	var head := Locale.text("stage_rank_none")
	if rank > 0 or peak > 0:
		head = Locale.text("stage_rank_line", [peak if peak > 0 else rank, int(song.get("weeks_on_chart", 0)), int(song.get("chart_boost", 0))])
		if rank > 0:
			head = "#%d | " % rank + head
	if str(song.get("band_word", "")) != "":
		head += " | " + band_label({"word": song["band_word"], "genre": song.get("band_genre", "")})
	return head

static func card_mark(song: Dictionary) -> String:
	var rank = current_rank(str(song.get("id", "")))
	return "" if rank == 0 else " | #%d" % rank

static func offer_remix(song: Dictionary = {}) -> Dictionary:
	migrate()
	var source := song
	if source.is_empty():
		for candidate in Game.songs:
			if str(candidate.get("remix_of", "")) != "": continue
			if Game.day - int(candidate.get("day", Game.day)) < 21 or int(candidate.get("rating", 0)) < 24: continue
			if _remix_open(str(candidate["id"])): continue
			if source.is_empty() or int(candidate["rating"]) > int(source["rating"]):
				source = candidate
	if source.is_empty() or Game.get_client(str(source.get("client", ""))).is_empty(): return {}
	if _remix_open(str(source["id"])): return {}
	var mix: Dictionary = source.get("mix", {}).duplicate()
	if mix.is_empty(): return {}
	var revealed: Array = []
	for tag in mix:
		revealed.append(tag)
	var pay = int(round((4000 + int(source["rating"]) * 80) / 100.0)) * 100
	var job = {
		"id": Game._id("j"),
		"client": source["client"],
		"title": Locale.text("stage_remix_title", [source["title"]]),
		"pay": pay,
		"deadline": 3,
		"base_pay": pay,
		"idea": mini(10, int(source["rating"]) / 4),
		"idea_seed": int(source.get("cover_seed", 1)),
		"planned_day": Game.day,
		"weeks_left": 3,
		"expires": 3,
		"mix": mix,
		"roles": ["Vocal"],
		"revealed": revealed,
		"chatted": false,
		"upfront": 0,
		"upfront_pct": 0,
		"status": "offer",
		"remix_of": source["id"],
	}
	Game.offers.append(job)
	Game.offers_changed.emit()
	return job

static func fan_gain(total: int, hype: float, team_ids: Array, job: Dictionary) -> int:
	var gain = int(total * 15.0 * hype)
	var band = matching_band(team_ids)
	if band.is_empty(): return gain
	gain += int(gain * 0.25)
	if str(job.get("requested_band", "")) == str(band["id"]):
		gain += int(total * 15.0 * hype * 0.15)
	return gain

static func on_release(song: Dictionary, team_ids: Array) -> void:
	migrate()
	var genre = dominant(song.get("mix", {}))
	stage()["genre_fans"][genre] = mini(400, int(stage()["genre_fans"].get(genre, 0)) + int(song.get("rating", 0)))
	_bump_group(team_ids, 4)
	var band = matching_band(team_ids)
	if not band.is_empty():
		song["band_id"] = band["id"]
		song["band_word"] = band["word"]
		song["band_genre"] = band["genre"]
	var source = song_by_id(str(song.get("remix_of", "")))
	if not source.is_empty():
		source["chart_boost"] = int(source.get("chart_boost", 0)) + 2

static func show_wait() -> int:
	var last = int(stage()["last_show_day"])
	if last < 0: return 0
	return maxi(0, SHOW_GAP - (Game.day - last))

static func performance_score(song: Dictionary, ids: Array) -> float:
	var tired = 0.0
	for id in ids:
		if fatigued(str(id)):
			tired = 0.18
	return clampf(int(song.get("rating", 0)) / 40.0 * 0.65 + _average(ids) * 0.35 - tired, 0.0, 1.5)

static func fatigued(id: String) -> bool:
	for song in Game.songs:
		if id in song.get("team", []) and Game.day - int(song.get("day", -99)) <= 3 and Game.day >= int(song.get("day", 0)):
			return true
	for session in Game.all_projects():
		if id in session.get("team", []) and Game.day - int(session.get("started_day", -99)) <= 3:
			return true
	return false

static func book_show(song_id: String, team_ids: Array) -> Dictionary:
	migrate()
	if StudioCity.fire_active(): return {"ok": false, "text": Locale.text("city_fire_wait")}
	if show_wait() > 0: return {"ok": false, "text": Locale.text("stage_show_wait", [show_wait()])}
	var song = song_by_id(song_id)
	if song.is_empty(): return {"ok": false, "text": Locale.text("city_no_songs")}
	if team_ids.is_empty() or team_ids.size() > 4: return {"ok": false, "text": Locale.text("stage_show_pick")}
	var unique: Array = []
	for id in team_ids:
		if str(id) in unique or Game.get_artist(str(id)).is_empty(): return {"ok": false, "text": Locale.text("staff_missing")}
		if not StudioLife.available(Game.get_artist(str(id))): return {"ok": false, "text": Locale.text("artist_busy")}
		unique.append(str(id))
	var ban = ban_reason(unique)
	if ban != "": return {"ok": false, "text": ban}
	if Game.money < SHOW_COST: return {"ok": false, "text": Locale.text("life_no_money")}
	Game.add_money(-SHOW_COST)
	var success = performance_score(song, unique) >= 0.55
	var gained = int(160 + int(song["rating"]) * 6)
	if str(song["id"]) == str(stage()["fan_request"]):
		gained += 90
	if not success:
		gained = 15
		Game.reputation = clampi(Game.reputation - 2, 0, 100)
	else:
		Game.reputation = mini(100, Game.reputation + 1)
		song["chart_boost"] = int(song.get("chart_boost", 0)) + 3
		if str(song["id"]) == str(stage()["fan_request"]):
			song["chart_boost"] = int(song["chart_boost"]) + 1
	Game.fans += gained
	Game.fans_changed.emit(Game.fans)
	if not Game.get_client(str(song.get("client", ""))).is_empty():
		Game.add_relationship(str(song["client"]), 4 if success else -3)
	var bumped := 0
	for client in Game.clients.values():
		if str(client["name"]) == str(song.get("client", "")): continue
		if int(client.get("rel", 0)) >= 30 and bumped < 2:
			Game.add_relationship(str(client["name"]), 2 if success else -1)
			bumped += 1
	_bump_group(unique, 4)
	stage()["show"] = {"song_id": song["id"], "team": unique, "until": Game.day}
	stage()["last_show_day"] = Game.day
	Game.staff_changed.emit()
	Game.save_game()
	var result_key := "stage_show_ok" if success else "stage_show_bad"
	var text = Locale.text(result_key, [song["title"], gained])
	Game.alice_notice.emit(text)
	return {"ok": true, "hit": success, "text": text, "fans": gained}

static func song_by_id(song_id: String) -> Dictionary:
	for song in Game.songs:
		if str(song.get("id", "")) == song_id: return song
	return {}

static func band_by_id(band_id: String) -> Dictionary:
	if band_id == "": return {}
	for band in stage()["bands"]:
		if str(band["id"]) == band_id: return band
	return {}

static func band_label(band: Dictionary) -> String:
	if band.is_empty(): return ""
	return Locale.text("stage_band_name", [str(band.get("word", "")), str(band.get("genre", ""))])

static func playable_bands() -> Array:
	var out: Array = []
	for band in stage()["bands"]:
		var ready := true
		for member in band["members"]:
			if Game.get_artist(str(member)).is_empty():
				ready = false
		if ready: out.append(band)
	return out

static func matching_band(team_ids: Array) -> Dictionary:
	var team: Array = []
	for id in team_ids:
		team.append(str(id))
	var best: Dictionary = {}
	var best_size := 0
	for band in stage()["bands"]:
		var inside := true
		for member in band["members"]:
			if str(member) not in team or Game.get_artist(str(member)).is_empty():
				inside = false
		if inside and band["members"].size() > best_size:
			best = band
			best_size = band["members"].size()
	return best

static func dominant(mix: Dictionary) -> String:
	var best := "Pop"
	var amount := -1
	for tag in mix:
		if int(mix[tag]) > amount:
			amount = int(mix[tag])
			best = str(tag)
	return best

static func _chart_before(a: Dictionary, b: Dictionary) -> bool:
	if int(a["score"]) == int(b["score"]):
		return bool(a["player"]) and not bool(b["player"])
	return int(a["score"]) > int(b["score"])

static func _resolve_chart() -> void:
	var rows: Array = []
	for song in Game.songs:
		rows.append({"song_id": song["id"], "title": song["title"], "studio": Game.studio_name, "score": song_score(song), "player": true, "rating": song.get("rating", 0)})
	var week = int(Game.day / 7)
	for i in RIVALS.size():
		var n = week * 13 + i * 5
		var rating = 14 + (n % 20)
		var age = n % 4
		var rival_hype = 1.15 + (i % 3) * 0.15
		var fresh = 1.0 / (1.0 + age * 0.3)
		var score = int(round((rating / 40.0) * rival_hype * fresh * 100.0))
		rows.append({"song_id": "rival_%d_%d" % [week, i], "title": RIVAL_TITLES[(week + i) % RIVAL_TITLES.size()], "studio": RIVALS[i], "score": score, "player": false, "rating": rating})
	rows.sort_custom(_chart_before)
	var chart: Array = []
	for i in mini(10, rows.size()):
		var entry: Dictionary = rows[i]
		entry["rank"] = i + 1
		chart.append(entry)
		if entry["player"]:
			var song = song_by_id(str(entry["song_id"]))
			if song.is_empty(): continue
			song["weeks_on_chart"] = int(song.get("weeks_on_chart", 0)) + 1
			var peak = int(song.get("peak_rank", 0))
			song["peak_rank"] = int(entry["rank"]) if peak == 0 else mini(peak, int(entry["rank"]))
	stage()["chart"] = chart

static func _remix_open(song_id: String) -> bool:
	for job in Game.offers + Game.jobs:
		if str(job.get("remix_of", "")) == song_id: return true
	return false

static func _initial(a: String, b: String) -> int:
	var left = Game.get_artist(a)
	var right = Game.get_artist(b)
	if left.is_empty() or right.is_empty(): return 40
	var shared := 0
	for genre in Data.GENRES:
		if int(left["skills"].get(genre, 0)) >= 40 and int(right["skills"].get(genre, 0)) >= 40:
			shared += 1
	return clampi(28 + shared * 8, 20, 72)

static func _average(ids: Array) -> float:
	if ids.size() < 2: return 0.62
	var total := 0.0
	var count := 0
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			total += chemistry(str(ids[i]), str(ids[j])) / 100.0
			count += 1
	return total / float(maxi(1, count))

static func _artists(ids: Array) -> Array:
	var team: Array = []
	for id in ids:
		var artist = Game.get_artist(str(id))
		if not artist.is_empty(): team.append(artist)
	return team

static func _bump_group(ids: Array, amount: int) -> void:
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			add_chemistry(str(ids[i]), str(ids[j]), amount)

static func _refresh_bands() -> void:
	var roster: Array = []
	for artist in Game.staff:
		roster.append(str(artist["id"]))
	for i in roster.size():
		for j in range(i + 1, roster.size()):
			for k in range(j + 1, roster.size()):
				var members: Array = [roster[i], roster[j], roster[k]]
				if _average(members) >= 0.70:
					_form_band(members)
	for i in roster.size():
		for j in range(i + 1, roster.size()):
			var members: Array = [roster[i], roster[j]]
			if chemistry(members[0], members[1]) >= 70:
				_form_band(members)

static func _form_band(members: Array) -> void:
	var copy: Array = []
	for member in members:
		copy.append(str(member))
	copy.sort()
	for band in stage()["bands"]:
		var have: Array = []
		for member in band["members"]:
			have.append(str(member))
		have.sort()
		if have == copy: return
		var contains := true
		for member in copy:
			if member not in have:
				contains = false
		if contains: return
	var word = Data.STAGE_NAMES[absi(str(copy).hash()) % Data.STAGE_NAMES.size()]
	var genre = _band_genre(copy)
	var band = {"id": "band:" + "+".join(PackedStringArray(copy)), "word": word, "genre": genre, "members": copy, "formed_day": Game.day}
	stage()["bands"].append(band)
	var names: PackedStringArray = []
	for member in copy:
		names.append(str(Game.get_artist(member).get("name", member)))
	Game.alice_notice.emit(Locale.text("stage_band_formed", [band_label(band), ", ".join(names)]))

static func _band_genre(members: Array) -> String:
	var best := "Pop"
	var amount := -1
	for genre in Data.GENRES:
		var score := 0
		for member in members:
			score += int(Game.get_artist(str(member))["skills"].get(genre, 0))
		if score > amount:
			amount = score
			best = genre
	return best
