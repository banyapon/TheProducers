extends Node
## Definitions are immutable. Runtime IDs, evidence and rewards live in Game.life per save.
## Guests walk into the office on their own. The quest menu lists only accepted stories.
signal changed
signal visitor_arrived(id: String)
signal visitor_left
const DEFINITIONS := "res://data/quests/story_quests.json"
const REPUTATION_GATES := [25, 45, 60, 75, 90]
var definitions: Array = []
var registry: Dictionary = {}

func _ready() -> void:
	definitions = JSON.parse_string(FileAccess.get_file_as_string(DEFINITIONS))["quests"]
	for quest in definitions: registry[str(quest["id"])] = quest
	Game.state_loaded.connect(sync)
	Game.song_released.connect(_released)
	Game.week_passed.connect(func(_week: int): changed.emit())
	Locale.language_changed.connect(func(_language: String): changed.emit())

func text(value: Dictionary) -> String:
	return str(value.get(Locale.language, value.get("en", "")))

func definition(id: String) -> Dictionary:
	return registry.get(id, {})

func state_data() -> Dictionary:
	if not Game.life.has("story_quests"):
		Game.life["story_quests"] = {"version":1, "states":{}, "songs":{}, "recruits":{}, "cooldowns":{}}
	var state: Dictionary = Game.life["story_quests"]
	for key in ["states", "songs", "recruits", "cooldowns"]:
		if not state.get(key) is Dictionary: state[key] = {}
	if not state.has("visitor"): state["visitor"] = ""
	if not state.has("visitor_day"): state["visitor_day"] = -1
	if not state.has("next_visit_day"): state["next_visit_day"] = 0
	return state

func state(id: String) -> Dictionary:
	return Game.life.get("story_quests", {}).get("states", {}).get(id, {})

func completed_count() -> int:
	var count = 0
	for item in Game.life.get("story_quests", {}).get("states", {}).values():
		if item.get("status", "") == "completed": count += 1
	return count

func unlocked(id: String) -> bool:
	var q = definition(id)
	if q.is_empty() or completed_count() < int(q["prereq_count"]): return false
	for required in q["prerequisites"]:
		if state(required).get("status", "") != "completed": return false
	return true

func reputation_need(q: Dictionary) -> int:
	var band = clampi((int(q.get("order", 1)) - 1) / 4, 0, REPUTATION_GATES.size() - 1)
	return REPUTATION_GATES[band]

func pending_visitor() -> String:
	if not Game.running: return ""
	return str(state_data().get("visitor", ""))

func accepted_ids() -> Array:
	var ids: Array = []
	if not Game.running: return ids
	for q in definitions:
		if str(state(q["id"]).get("status", "")) in ["active", "completed"]:
			ids.append(str(q["id"]))
	return ids

## One guest at a time. Reputation opens the next story; otherwise a story can still arrive by chance.
func consider_visit() -> void:
	if not Game.running or DemoCareer.active() or Game.tutorial_step >= 0: return
	if StudioCity.fire_active(): return
	var data = state_data()
	var current = str(data.get("visitor", ""))
	if current != "" and Game.day - int(data.get("visitor_day", Game.day)) >= 3:
		data["cooldowns"]["visit_" + current] = Game.day + 4
		data["visitor"] = ""
		data["next_visit_day"] = Game.day + 2
		visitor_left.emit()
		changed.emit()
		return
	if current != "" or Game.day < int(data.get("next_visit_day", 0)): return
	var id = _pick_visitor()
	if id == "": return
	data["visitor"] = id
	data["visitor_day"] = Game.day
	visitor_arrived.emit(id)
	changed.emit()
	Game.save_game()

func decline_visit() -> void:
	if not Game.running: return
	var data = state_data()
	var id = str(data.get("visitor", ""))
	if id == "": return
	data["cooldowns"]["visit_" + id] = Game.day + 5
	data["visitor"] = ""
	data["next_visit_day"] = Game.day + 3
	visitor_left.emit()
	changed.emit()
	Game.save_game()

func _pick_visitor() -> String:
	var ready: Array = []
	var surprise: Array = []
	var data = state_data()
	for q in definitions:
		var id = str(q["id"])
		if status(id) != "available": continue
		if Game.day < int(data["cooldowns"].get("visit_" + id, 0)): continue
		if Game.reputation >= reputation_need(q): ready.append(q)
		else: surprise.append(q)
	if not ready.is_empty():
		ready.sort_custom(func(a: Dictionary, b: Dictionary): return int(a["order"]) < int(b["order"]))
		return str(ready[0]["id"])
	if surprise.is_empty(): return ""
	var rng = RandomNumberGenerator.new()
	rng.seed = hash("story-visit:%s:%d:%d:%d" % [Game.save_slot, Game.day, Game.reputation, completed_count()])
	if rng.randf() > 0.35: return ""
	return str(surprise[rng.randi() % surprise.size()]["id"])

func status(id: String) -> String:
	var saved = str(state(id).get("status", ""))
	if saved == "completed": return saved
	if saved == "active": return "ready" if progress(id)["ready"] else "active"
	return "available" if unlocked(id) else "locked"

func sync() -> void:
	if not Game.running: return
	state_data()
	for song in Game.songs + Game.archived_songs:
		if song is Dictionary: _remember_song(song)
	changed.emit()

func _remember_song(song: Dictionary) -> void:
	var id = str(song.get("id", ""))
	if id.is_empty(): return
	var evidence = {}
	for key in ["id", "title", "mix", "rating", "day", "remix_of", "story_quest_id", "story_metrics"]:
		if song.has(key): evidence[key] = song[key]
	state_data()["songs"][id] = evidence.duplicate(true)

func _released(song: Dictionary) -> void:
	_remember_song(song)
	var ready: Array[String] = []
	for q in definitions:
		var s = state(q["id"])
		if s.get("status", "") == "active" and progress(q["id"])["ready"] and not s.get("notified", false):
			s["notified"] = true
			ready.append(text(q["npc"]["name"]))
	if not ready.is_empty(): Game.notify.emit(("Quest พร้อมส่ง: " if Locale.language == "th" else "Quests ready: ") + ", ".join(ready))
	changed.emit()

func annotate_release(job: Dictionary, song: Dictionary) -> void:
	song["story_quest_id"] = str(job.get("story_quest_id", ""))
	var m: Dictionary = job.get("arrangement", {})
	var metrics: Dictionary = {}
	if not m.is_empty() and m.has("deck") and m.has("placed"):
		metrics = CompositionDesign.analyze(m).duplicate(true)
		metrics["bpm"] = int(m.get("bpm", 120))
		metrics["improvise"] = false
		metrics["melody_improvise"] = false
		for p in m["placed"]:
			var block: Dictionary = m["deck"][int(p["block"])]
			if not block.get("recorded_notes", []).is_empty():
				metrics["improvise"] = true
				if int(p["row"]) == 0: metrics["melody_improvise"] = true
	song["story_metrics"] = metrics

func primary_genre(song: Dictionary) -> String:
	var mix: Dictionary = song.get("mix", {})
	var top = -1.0
	var result = ""
	var tied = false
	for genre in mix:
		if float(mix[genre]) > top:
			top = float(mix[genre]); result = genre; tied = false
		elif is_equal_approx(float(mix[genre]), top): tied = true
	return "" if tied else result

func _matches(q: Dictionary, song: Dictionary) -> bool:
	if int(song.get("rating", 0)) < int(q["rating"]): return false
	if not str(song.get("remix_of", "")).is_empty(): return false
	if q["mode"] == "commission" and str(song.get("story_quest_id", "")) != q["id"]: return false
	var genre = primary_genre(song)
	if genre.is_empty(): return false
	if q["criterion"] == "dance_pair":
		if genre not in ["EDM", "HipHop"]: return false
	elif q["genre"] != "" and genre != q["genre"]: return false
	var metrics: Dictionary = song.get("story_metrics", {})
	match str(q["criterion"]):
		"gentle": return int(metrics.get("bpm", 999)) <= 105 and float(metrics.get("density", 1.0)) > 0.0 and float(metrics.get("density", 1.0)) <= 0.5
		"hook": return float(metrics.get("repeat", 0.0)) >= 1.0
		"rise": return float(metrics.get("rise", 0.0)) >= 0.1
		"improvise": return metrics.get("improvise", false)
		"melody_improvise": return metrics.get("melody_improvise", false)
	return true

func progress(id: String) -> Dictionary:
	var q = definition(id)
	if q.is_empty(): return {"count":0, "target":1, "ready":false, "songs":[]}
	var matches: Array = []
	var genres: Array = []
	var peak = 0
	for song in Game.life.get("story_quests", {}).get("songs", {}).values():
		if not _matches(q, song): continue
		var genre = primary_genre(song)
		if q["criterion"] in ["distinct", "dance_pair"] and genre in genres: continue
		genres.append(genre)
		matches.append(song)
		peak = maxi(peak, int(song.get("rating", 0)))
	var ready = matches.size() >= int(q["count"]) and (q["criterion"] != "peak28" or peak >= 28)
	return {"count":mini(matches.size(), int(q["count"])), "target":int(q["count"]), "ready":ready, "songs":matches, "peak":peak}

func accept(id: String, choice: String = "together") -> bool:
	if not Game.running or status(id) != "available" or choice not in ["together", "new_start"]: return false
	var data = state_data()
	data["states"][id] = {"status":"active", "day":Game.day, "choice":choice, "notified":false, "ending_seen":false}
	if str(data.get("visitor", "")) == id:
		data["visitor"] = ""
		data["next_visit_day"] = Game.day + 2
		visitor_left.emit()
	Game.save_game()
	changed.emit()
	return true

func claim(id: String) -> bool:
	if not Game.running or status(id) != "ready": return false
	var q = definition(id)
	var s = state(id)
	# Mark first: synchronous notifications cannot grant the same reward twice.
	s["status"] = "completed"
	s["completed_day"] = Game.day
	var reward: Dictionary = q["reward"]
	_register_client(q)
	if reward["kind"] == "artist": _create_recruit(q)
	if id in ["ingfah", "leo"]:
		var song: Dictionary = progress(id)["songs"].back()
		var trophy = {"edition":0, "story_quest":id, "song_id":song["id"], "song":song.get("title", ""), "rating":song["rating"], "day":Game.day, "win":true}
		Game.trophies.append(trophy)
		Game.trophy_awarded.emit(trophy)
	Game.add_money(int(reward["money"]))
	Game.fans += int(reward["fans"])
	Game.fame += 100
	Game.fans_changed.emit(Game.fans)
	Game.save_game()
	changed.emit()
	return true

func mark_ending_seen(id: String) -> void:
	if state(id).get("status", "") != "completed": return
	state(id)["ending_seen"] = true
	Game.save_game()

func _register_client(q: Dictionary) -> String:
	var client_name = "Story / " + str(q["npc"]["name"]["en"])
	if not Game.clients.has(client_name):
		Game.clients[client_name] = {"name":client_name, "art_id":q["npc"]["art_id"], "gender":q["npc"]["gender"], "type":"Music", "color":Color("e7b76a"), "rel":30, "story_npc":q["id"]}
	var entry: Dictionary = Game.clients[client_name]
	# Passing a client story makes them a regular. An artist story unlocks a romanceable teammate instead.
	if state(q["id"]).get("status", "") == "completed" and str(q["reward"]["kind"]) != "artist":
		entry["regular"] = true
		entry["rel"] = maxi(int(entry.get("rel", 0)), 55)
		entry["contact_adult"] = true
		entry["contact_opt_in"] = true
	StudioCity.ensure_person(entry, true)
	return client_name

func client_multiplier(client: Dictionary) -> float:
	var id = str(client.get("story_npc", ""))
	if state(id).get("status", "") != "completed": return 1.0
	return float(definition(id)["reward"]["multiplier"])

func _create_recruit(q: Dictionary) -> void:
	if state_data()["recruits"].has(q["id"]): return
	var artist = Game.generate_artist(0.7, q["reward"]["role"])
	artist["id"] = "story_artist_" + q["id"]
	artist["name"] = q["npc"]["name"]["en"]
	artist["art_id"] = q["npc"]["art_id"]
	artist["gender"] = q["npc"]["gender"]
	artist["story_npc"] = q["id"]
	artist["named_by_gender"] = true
	artist["romance_unlocked"] = true
	artist["social"] = {"trust":48, "comfort":42, "attraction":10, "partner":"", "last_day":-99, "last_action":"", "interested":true, "strain":0, "warning":false, "break_until":-1, "care_day":Game.day, "tick_day":Game.day}
	artist["skills"][q["genre"]] = 85
	artist["sign_fee"] = 4000
	artist["fee_week"] = 800
	state_data()["recruits"][q["id"]] = artist

func recruit(id: String) -> String:
	if not Game.running or state(id).get("status", "") != "completed": return ui("locked")
	var artist: Dictionary = state_data()["recruits"].get(id, {})
	if artist.is_empty(): return ui("locked")
	if not Game.get_artist(str(artist["id"])).is_empty(): return ui("hired")
	var error = Game.sign_artist(artist.duplicate(true), 4)
	Game.save_game()
	changed.emit()
	return error

func can_issue(id: String) -> bool:
	if not Game.running or status(id) not in ["active", "completed"]: return false
	var q = definition(id)
	if status(id) == "active" and q["mode"] == "collection": return false
	for job in Game.offers + Game.jobs:
		if str(job.get("story_quest_id", "")) == id: return false
	return Game.day >= int(state_data()["cooldowns"].get(id, -1))

func issue_brief(id: String) -> bool:
	if not can_issue(id): return false
	var q = definition(id)
	var genre = str(q["genre"])
	if q["criterion"] == "dance_pair":
		genre = "EDM"
		for song in progress(id)["songs"]:
			if primary_genre(song) == "EDM": genre = "HipHop"
	if genre == "": genre = "Pop"
	var name = _register_client(q)
	var pay = int(12000 * client_multiplier(Game.clients[name]))
	var job = {"id":Game._id("story_job"), "story_quest_id":id, "client":name, "title":text(q["title"]), "brief_kind":q["brief"],
		"pay":pay, "base_pay":pay, "deadline":8, "idea":0, "idea_seed":hash(id), "planned_day":Game.day,
		"weeks_left":8, "expires":4, "mix":{genre:100}, "roles":["Vocal", "Producer"], "revealed":[genre],
		"chatted":false, "upfront":0, "upfront_pct":0, "status":"offer"}
	Game.offers.append(job)
	# Applies even when declined or failed: deposits cannot be farmed by reissuing.
	state_data()["cooldowns"][id] = Game.day + 7
	Game.offers_changed.emit()
	Game.save_game()
	changed.emit()
	return true

func objective(q: Dictionary) -> String:
	var genre = q["genre"] if q["genre"] != "" else ui("any_genre")
	if q["criterion"] == "dance_pair": genre = "EDM + HipHop"
	var result = ("เผยแพร่ %s %d เพลง • คะแนนขั้นต่ำ %d/40" if Locale.language == "th" else "Release %d %s song(s) • Minimum score %d/40")
	result = result % ([genre, q["count"], q["rating"]] if Locale.language == "th" else [q["count"], genre, q["rating"]])
	var requirements = {
		"gentle": {"th":"BPM ไม่เกิน 105 และเติมช่องเพลงไม่เกิน 50%", "en":"BPM at most 105; arrangement density at most 50%"},
		"hook": {"th":"ใช้ Melody แนว/สไตล์/คีย์เดิมซ้ำในช่วง Hook อย่างน้อย 1 ห้อง", "en":"Repeat an earlier Melody genre/style/key in at least one Hook bar"},
		"rise": {"th":"เพิ่มพลังเฉลี่ยจากช่วง Build ไป Hook อย่างน้อย 0.10", "en":"Raise average energy from Build to Hook by at least 0.10"},
		"peak28": {"th":"อย่างน้อย 1 เพลงต้องได้ 28/40 ขึ้นไป", "en":"At least one release must score 28/40 or higher"},
		"improvise": {"th":"วางคลิปที่อัดโน้ตด้วย Improvise ลงในเพลง", "en":"Place an Improvise clip with recorded notes in the arrangement"},
		"melody_improvise": {"th":"วางคลิปที่อัดด้วย Improvise ในแถว Melody", "en":"Place an Improvise recording on the Melody row"},
		"distinct": {"th":"แต่ละเพลงต้องมีแนวหลักต่างกัน", "en":"Each qualifying release must have a different primary genre"},
		"dance_pair": {"th":"ทำ EDM 1 เพลง และ HipHop 1 เพลง", "en":"Release one EDM song and one HipHop song"},
	}
	if requirements.has(q["criterion"]): result += "\n" + text(requirements[q["criterion"]])
	return result + "\n" + text(q["dialogue"]["hint"]) + "\n" + ui("retroactive" if q["mode"] == "collection" else "linked_brief")

func ui(key: String) -> String:
	var copy = {
		"title":["Quest • เรื่องราวหลังห้องอัด","Quest • Story Encounters"], "close":["กลับ","Back"],
		"all":["ทั้งหมด","All"], "active":["กำลังทำ","Active"], "completed":["สำเร็จแล้ว","Completed"],
		"available":["รับได้","Available"], "ready":["พร้อมส่งผลงาน","Ready to finish"], "locked":["ยังไม่ปลดล็อก","Locked"],
		"accept":["ร่วมทำเพลงด้วยกัน","Let's make it together"], "new_start":["มาลองเริ่มต้นใหม่","Let's try a fresh start"],
		"brief":["รับ brief ที่บอร์ดงาน","Create brief on commissions board"], "claim":["ส่งผลงานและรับรางวัล","Finish & claim rewards"],
		"replay":["ดูเหตุการณ์อีกครั้ง","Replay ending"], "next":["ต่อไป","Next"], "ending":["หลังเสียงเพลงจบลง…","After the music…"],
		"recruit":["เซ็นสัญญา 4 สัปดาห์","Sign a 4-week contract"], "hired":["อยู่ในทีมแล้ว","Already on your team"],
		"preview":["เริ่มเกมหรือโหลดเซฟเพื่อรับ Quest • หน้านี้เปิดอ่านเรื่องราวได้","Start or load a career to accept quests • Browse the stories here"],
		"retroactive":["นับผลงานเก่า • ไม่รวมรีมิกซ์ • แนวหลักต้องไม่เสมอกัน","Earlier releases count • No remixes • Primary genre must not tie"],
		"linked_brief":["ต้องรับ brief ของตัวละครนี้ก่อน แล้วเผยแพร่เพลงจากงานนั้น","Create this character's brief, then release a song from that commission"],
		"any_genre":["แนวใดก็ได้","any genre"], "reward":["รางวัล","Rewards"], "evidence":["ผลงานที่นับแล้ว","Qualifying releases"],
		"retry":["รับ brief ใหม่ได้หลัง 7 วันเกม หากไม่มีงานเดิมค้างอยู่","A new brief is available after 7 game days, with no outstanding brief"],
		"not_ready":["ยังไม่ครบเงื่อนไข ลองดูเป้าหมายและผลงานที่นับด้านบน","Not ready yet. Check the goals and qualifying releases above"],
		"unlock_artist":["ผ่านแล้วเป็นทีมงานที่จีบได้ • ค่าเซ็น $4,000 / ค่าจ้าง $800 ต่อสัปดาห์","Passing makes them a teammate you can romance • $4,000 signing fee / $800 per week"],
		"unlock_client":["ผ่านแล้วเป็นลูกค้าขาประจำ • งานใหม่ค่าจ้าง x%.1f","Passing makes them a regular client • new commissions pay x%.1f"],
		"visit_hint":["เหตุการณ์ใหม่เดินเข้าออฟฟิศเอง ตามชื่อเสียง หรือแบบไม่ทันตั้งตัว","New stories walk into the office on their own, by reputation or by chance."],
		"accepted_empty":["ยังไม่มีเควสที่รับไว้ แขกจะเดินเข้ามาที่ออฟฟิศเอง","No accepted quests yet. Guests walk into the office on their own."],
		"arrived":["%s เดินเข้ามาที่ออฟฟิศ","%s walks into the office"],
		"visit_ask":["จะรับเรื่องนี้ไว้ไหม","Will you take this on?"],
		"later":["ไว้ก่อน","Not now"],
		"later_reply":["งั้นฉันไว้ก่อนนะ วันหลังค่อยแวะมาใหม่","I'll leave it for now. I'll stop by another day."],
		"visit_brief":["รับงานนี้เข้าบอร์ดเลยไหม","Put this commission on the board now?"],
		"finish_first":["ต้องจบเรื่องราวก่อน: %s","Complete first: %s"], "finish_count":["จบ Quest อย่างน้อย %d รายการ","Complete at least %d quests"],
		"choice_reply":["เราจะเริ่มจากสิ่งที่เป็นตัวคุณ แล้วค่อย ๆ ทำให้ทุกคนได้ยิน","We'll start with what makes you unique, then help everyone hear it."],
		"fresh_reply":["ครั้งนี้ไม่ต้องเหมือนครั้งก่อน เรามาเริ่มจากเสียงที่คุณอยากร้องกัน","This time doesn't have to be like the last. Let's start with the voice you want to share."],
		"alice_end":["อีกคนหนึ่งได้เริ่มบทใหม่จากเพลงของเราแล้วค่ะ","Our music helped someone begin a new chapter."],
	}
	if not copy.has(key): return key
	return copy[key][0 if Locale.language == "th" else 1]
