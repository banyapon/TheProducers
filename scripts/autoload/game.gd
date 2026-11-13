extends Node
## Global game state + simulation clock (autoload "Game").
## Every gameplay change goes through this node and is announced with a signal;
## scenes (Office, HUD, panels, the dialog flows in Main) only listen and call these methods.

signal monthly_feedback(month: int)
signal trophy_awarded(trophy: Dictionary)
signal alice_notice(message: String)
signal meeting_changed
signal schedule_changed
signal research_changed
signal demo_completed
signal recovery_requested(event: Dictionary)
signal manual_composition_requested(job_id: String)
signal state_loaded
signal money_changed(money: int)
signal date_changed(day: int)
signal week_passed(week: int)
signal fans_changed(fans: int)
signal staff_changed
signal listing_changed
signal offers_changed
signal jobs_changed
signal items_changed
signal building_changed
signal project_started(project: Dictionary)
signal project_progress(progress: float)
signal points_generated(artist_id: String, category: String, amount: int)
signal project_completed(project: Dictionary)
signal project_ended
signal project_reset(reason: String)
signal contract_expired(artist: Dictionary)
signal job_failed(job: Dictionary)
signal walk_in_client(job: Dictionary)
signal song_released(song: Dictionary)
signal song_updated(song: Dictionary)
signal notify(text: String)

const DAY_SECONDS := 2.0
const START_MONEY := 50000
const ONLINE_AD_COST := 1500
const STAFF_PER_OFFICE := 4
const MAX_OFFERS := 6
const SAVE_KEYS := ["archived_songs", "player_character", "producer_name", "studio_name", "identity_initialized", "intro_seen", "fame", "reputation", "money", "day", "fans", "_next_id", "staff", "listing", "online_candidates", "offers", "jobs", "clients", "items", "songs", "project", "floors", "parallel_projects", "research_tasks", "invoices", "trophies", "contest_edition", "idea_meeting", "production_queue", "tutorial_step", "tutorial_start_songs", "life"]

var life: Dictionary = {}
var character_appearance: Dictionary = {}

## Seed missing recipes once per save; preserve existing outfits and colors.
func initiate_character_parts(reset: bool = false) -> void:
	if reset: character_appearance = {}
	var defaults: Dictionary = ModularCharacter.catalogue()["characters"]
	for id in defaults:
		var recipe: Dictionary = character_appearance.get(id, {}) if character_appearance.get(id, {}) is Dictionary else {}
		if int(recipe.get("art_version", 1)) < 2:
			if recipe.get("body", defaults[id]["body"]) == defaults[id].get("previous_body", ""):
				recipe["body"] = defaults[id]["body"]
			recipe["art_version"] = 2
		for key in ["body", "cloth_tint", "inner_tint", "pants_tint", "shoes_tint", "skin_tint"]:
			if not recipe.has(key): recipe[key] = defaults[id].get(key, "#ffffff")
		if not recipe["body"] in ModularCharacter.catalogue()["outfits"]: recipe["body"] = defaults[id]["body"]
		for key in ["cloth_tint", "inner_tint", "pants_tint", "shoes_tint", "skin_tint"]:
			if not recipe[key] is String or not Color.html_is_valid(recipe[key]): recipe[key] = defaults[id].get(key, "#ffffff")
		character_appearance[id] = recipe

func character_parts_path() -> String:
	return "user://save_%s.fullbody.json" % save_slot.validate_filename()

func _save_character_parts() -> void:
	var file = FileAccess.open(character_parts_path(), FileAccess.WRITE)
	if file: file.store_string(JSON.stringify({"version":2, "characters":character_appearance}, "\t"))

var player_character: String = "producer"

func player_portrait() -> Dictionary:
	return {"name": producer_name, "art_id": player_character, "gender": Art.gender(player_character), "principal": true}

func assistant_portrait() -> Dictionary:
	var art = "producer" if player_character == "alice" else "alice"
	return {"id": "alice", "name": "Producer" if art == "producer" else "Alice", "art_id": art, "gender": Art.gender(art), "principal": true, "assistant": true}

var producer_name: String = "Producer"
var studio_name: String = "New Sound Studio"
var identity_initialized: bool = false
var intro_seen: bool = false
var fame: int = 0
var reputation: int = 35

var running: bool = false
var speed: float = 1.0
var save_slot: String = "offline"
var _pause_requests: int = 0
var _day_timer: float = 0.0
var _next_id: int = 0

var money: int = 0
var day: int = 0
var fans: int = 0
var staff: Array = []              ## signed artists
var listing: Array = []            ## free hire board
var online_candidates: Array = []  ## from paid online ads
var offers: Array = []             ## jobs on the job board
var jobs: Array = []               ## accepted jobs
var clients: Dictionary = {}       ## name -> {name, type, color, rel}
var items: Dictionary = {}
var songs: Array = []
var archived_songs: Array = []
var resume_after_restart := false
var project: Dictionary = {}       ## focused recording session; other room bookings live in parallel_projects
var parallel_projects: Array = []
var idea_meeting: Dictionary = {}
var production_queue: Array = []
var tutorial_step: int = 0
var tutorial_start_songs: int = 0
var tutorial_gate: bool = false
var research_tasks: Array = []
var invoices: Array = []
var trophies: Array = []
var contest_edition: int = 1
var floors: Array = []             ## floors[f][c] = room type


func _process(delta: float) -> void:
	if running and check_bankruptcy(): return
	PlaytestLog.tick(delta)
	if not running or is_paused() or tutorial_gate:
		return
	_day_timer += delta * speed
	while running and _day_timer >= DAY_SECONDS and not is_paused():
		_day_timer -= DAY_SECONDS
		_advance_day()


# --- clock -------------------------------------------------------------------

func is_paused() -> bool:
	return _pause_requests > 0 or speed <= 0.0


## Dialogs and panels call push/pop so time stops while the player is reading.
func push_pause() -> void:
	_pause_requests += 1


func pop_pause() -> void:
	_pause_requests = maxi(0, _pause_requests - 1)


func date_text() -> String:
	return Locale.text("legacy_097") % [day / 336 + 1, (day % 336) / 28 + 1, (day % 28) / 7 + 1, day % 7 + 1]


# --- lifecycle ---------------------------------------------------------------

func start(slot: String) -> void:
	save_slot = slot if slot != "" else "offline"
	if not load_game():
		new_game()
		if slot == "demo_career" or PlaytestLog.data()["runs"].has(slot): DemoCareer.setup()
	running = true
	if check_bankruptcy():
		_emit_all()
		return
	PlaytestLog.start_session()
	_save_character_parts()
	_emit_all()


func new_game() -> void:
	initiate_character_parts(true)
	archived_songs = []
	life = {}
	_reset_identity()
	money = START_MONEY
	day = 0
	fans = 0
	_next_id = 0
	staff = []
	listing = []
	online_candidates = []
	offers = []
	jobs = []
	clients = {}
	songs = []
	project = {}
	idea_meeting = {}
	production_queue = []
	tutorial_step = 0
	tutorial_start_songs = 0
	tutorial_gate = false
	parallel_projects = []
	research_tasks = []
	invoices = []
	trophies = []
	contest_edition = 1
	items = {"research": 0, "gift": 1, "energy": 1, "pizza": 1, "coffee": 0}
	floors = [["meeting", "lounge", "studio"]]
	# Starter crew so the first song is possible right away.
	for role in ["Vocal", "Producer"]:
		var artist = generate_artist(0.35, role)
		artist["weeks_left"] = 12
		staff.append(artist)
	_refresh_listing()
	# First offers are tailored to the starter crew (genres they know, roles they cover, long deadline).
	for i in 3:
		offers.append(generate_job(true))
	offers[0]["mix"] = {"Pop": 100}
	offers[0]["revealed"] = ["Pop"]
	offers[0]["tutorial_brief"] = true
	StudioLife.migrate()


## Wipes the save for the current slot and starts over.
func reset_game() -> void:
	if FileAccess.file_exists(_save_path()):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_save_path()))
	_day_timer = 0.0
	new_game()
	running = true
	_emit_all()
	save_game()


func save_game(force: bool = false) -> void:
	if not running and not force:
		return
	if not PlaytestLog.current().is_empty(): PlaytestLog.save()
	var data = {"version": 3}
	data["character_appearance"] = character_appearance
	for key in SAVE_KEYS:
		data[key] = get(key)
	var file = FileAccess.open(_save_path(), FileAccess.WRITE)
	if file:
		file.store_var(data)
		_save_character_parts()


func load_game() -> bool:
	character_appearance = {}
	archived_songs = []
	life = {}
	_reset_identity()
	idea_meeting = {}
	production_queue = []
	tutorial_step = -1
	tutorial_gate = false
	parallel_projects = []
	research_tasks = []
	invoices = []
	trophies = []
	contest_edition = 1
	var path = _save_path()
	if not FileAccess.file_exists(path):
		return false
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var data = file.get_var()
	if not data is Dictionary:
		return false
	Data.migrate_legacy_genres(data)
	if data.get("character_appearance") is Dictionary:
		character_appearance = data["character_appearance"]
	if FileAccess.file_exists(character_parts_path()):
		var saved_parts = JSON.parse_string(FileAccess.get_file_as_string(character_parts_path()))
		if saved_parts is Dictionary and saved_parts.get("characters") is Dictionary:
			character_appearance = saved_parts["characters"]
	initiate_character_parts()
	for key in SAVE_KEYS:
		if data.has(key):
			set(key, data[key])
	if player_character not in ["producer", "alice"]: player_character = "producer"
	_migrate_visuals()
	_migrate_planning()
	StudioLife.migrate()
	if not data.has("tutorial_step"): tutorial_step = -1 if not songs.is_empty() else 0
	# Resume the arrangement without charging another brief; re-gather actors in the lounge.
	if not idea_meeting.is_empty(): idea_meeting["phase"] = "gathering"
	return true


func _save_path() -> String:
	return "user://save_%s.dat" % save_slot.validate_filename()


func _emit_all() -> void:
	money_changed.emit(money)
	date_changed.emit(day)
	fans_changed.emit(fans)
	staff_changed.emit()
	listing_changed.emit()
	offers_changed.emit()
	jobs_changed.emit()
	items_changed.emit()
	building_changed.emit()
	state_loaded.emit()
	meeting_changed.emit()
	if not production_queue.is_empty(): call_deferred("_tick_schedule")
	if project.is_empty():
		project_ended.emit()
	else:
		if project["done"]:
			project_completed.emit(project)
		else:
			project_started.emit(project)
	for session in parallel_projects:
		if session["done"]: project_completed.emit(session)
		else: project_started.emit(session)


func _id(prefix: String) -> String:
	_next_id += 1
	return "%s%d" % [prefix, _next_id]


func add_money(amount: int) -> void:
	if life.get("bankrupt", false): return
	money += amount
	money_changed.emit(money)
	check_bankruptcy()

signal bankrupted

func check_bankruptcy() -> bool:
	if money >= 0 and not life.get("bankrupt", false): return false
	running = false
	if not life.get("bankrupt", false):
		life["bankrupt"] = true
	save_game(true)
	bankrupted.emit()
	return true


# --- daily / weekly simulation -------------------------------------------------

signal contest_announced(result: Dictionary)
signal hot_news(event: Dictionary)
signal fire_started
signal creative_decision_requested(job_id: String)

func _advance_day() -> void:
	if life.get("bankrupt", false): return
	day += 1
	date_changed.emit(day)
	if StudioCity.emergency_day(): return
	StudioCity.try_fire()
	if StudioCity.fire_active():
		StudioCity.defer_calendar()
		save_game()
		return
	StudioCity.resume_calendar()
	StudioLife.tick_day()
	if life.get("bankrupt", false): return
	StudioCity.tick_day()
	if life.get("bankrupt", false): return
	StudioStars.tick_day()
	if life.get("bankrupt", false): return
	_tick_all_projects()
	_tick_schedule()
	_tick_research()
	_tick_invoices()
	if life.get("bankrupt", false): return
	for job in jobs.duplicate():
		if job_days_left(job) <= 0: _fail_job(job)
	if day % 28 == 0 and not DemoCareer.active(): _run_contest()
	if not DemoCareer.active() and offers.size() < MAX_OFFERS and randf() < 0.3 + VipOffice.offer_bonus():
		offers.append(generate_job())
		offers_changed.emit()
	if not DemoCareer.active() and randf() < 0.04:
		var walk_in = generate_job()
		walk_in["walk_in"] = true
		offers.append(walk_in)
		offers_changed.emit()
		walk_in_client.emit(walk_in)
	StoryQuests.consider_visit()
	if day % 7 == 0:
		_advance_week()


func _advance_week(deferred_week: int = -1) -> void:
	if life.get("bankrupt", false): return
	var week = deferred_week if deferred_week >= 0 else int(day / 7)
	var payroll = 0
	for a in staff:
		payroll += StudioCity.weekly_fee(a)
	if payroll > 0:
		add_money(-payroll)
		if life.get("bankrupt", false):
			save_game()
			return
		notify.emit(Locale.text("legacy_098") % Data.money(payroll))

	var income = 0
	for s in songs:
		if int(s["weeks_left"]) > 0:
			var sale = int(s["weekly_sales"])
			income += sale
			s["earned"] = int(s["earned"]) + sale
			s["weekly_sales"] = int(sale * 0.72)
			s["weeks_left"] = int(s["weeks_left"]) - 1
			fans += sale / 100
	if income > 0:
		add_money(income)
		notify.emit(Locale.text("legacy_099") % Data.money(income))
	fans_changed.emit(fans)

	for job in jobs.duplicate():
		if job["status"] != "active":
			continue
		job["weeks_left"] = ceili((int(job.get("due_day", day + int(job["weeks_left"]) * 7 - 7)) - day) / 7.0)
		if int(job["weeks_left"]) <= 0:
			_fail_job(job)
		elif int(job["weeks_left"]) == 1:
			notify.emit(Locale.text("legacy_100") % job["title"])
	for job in offers.duplicate():
		job["expires"] = int(job["expires"]) - 1
		if int(job["expires"]) <= 0:
			offers.erase(job)
	offers_changed.emit()
	jobs_changed.emit()

	var expired = []
	for a in staff:
		if StudioCity.weekly_fee(a) == 0 and a.get("social", {}).get("partner", "") == "producer": continue
		a["weeks_left"] = int(a["weeks_left"]) - 1
		if int(a["weeks_left"]) <= 0:
			expired.append(a)
	staff_changed.emit()
	for a in expired:
		StudioLife.ensure_artist(a)
		if a["auto_renew"] and a["met"]:
			var error = renew_contract(a, 4)
			if error.is_empty():
				alice_notice.emit(Locale.text("auto_renew_done", [a["name"], Data.money(renewal_cost(a,4))]))
				continue
			alice_notice.emit(Locale.text("auto_renew_failed", [a["name"]]))
		contract_expired.emit(a)
	StudioStage.on_week()

	if week % 4 == 0:
		_refresh_listing()
	week_passed.emit(week)
	save_game()


func _fail_job(job: Dictionary) -> void:
	if StudioCity.rescue_deadline(job): return
	reputation = maxi(0, reputation - 6)
	cancel_scheduled(str(job["id"]))
	if idea_meeting.get("job_id", "") == job["id"]: cancel_idea_meeting()
	job["status"] = "failed"
	jobs.erase(job)
	add_money(-int(job["upfront"]))
	add_relationship(job["client"], -15)
	for session in all_projects():
		if session["job_id"] == job["id"]:
			_remove_session(session)
			project_reset.emit(Locale.text("legacy_101") % job["title"])
			project_ended.emit()
	jobs_changed.emit()
	job_failed.emit(job)
	if job.has("demo_index") and not life.get("demo", {}).get("finished", true): DemoCareer.next_brief(int(job["demo_index"]))


# --- clients & jobs --------------------------------------------------------------

func generate_job(easy := false) -> Dictionary:
	var client_name = _pick_client()
	var tag_count = randi_range(1, 2) if easy else randi_range(1, 3)
	var tags: Array = Data.GENRES.duplicate()
	tags.shuffle()
	if easy:
		# Put genres the current staff is good at first.
		var known = []
		for a in staff:
			for tag in Data.sorted_tags(a["skills"]).slice(0, 2):
				if not known.has(tag):
					known.append(tag)
		known.shuffle()
		for tag in known:
			tags.erase(tag)
		tags = known + tags
	# Split 100% into chunks of 5% so every tag gets at least 5%.
	var chunks = []
	var weights = []
	for i in tag_count:
		chunks.append(1)
		weights.append(randf_range(0.5, 3.0))
	for n in 20 - tag_count:
		chunks[_weighted_index(weights)] += 1
	var mix = {}
	for i in tag_count:
		mix[tags[i]] = int(chunks[i]) * 5

	var roles = ["Vocal"]
	if easy:
		roles.append("Producer")
	else:
		var others: Array = Data.ROLES.duplicate()
		others.erase("Vocal")
		others.shuffle()
		roles.append_array(others.slice(0, randi_range(1, 2)))

	var deadline = randi_range(6, 8) if easy else randi_range(2, 8)
	# Same base scope: urgent commissions carry a premium; relaxed briefs pay less.
	var base_pay = int(round((randf_range(10000.0, 18000.0) + fans * 2.0) / 500.0)) * 500
	var pay = commission_pay(base_pay, deadline)
	pay = int(round(pay * StoryQuests.client_multiplier(get_client(client_name))))
	var job = {
		"id": _id("j"),
		"client": client_name,
		"title": "%s %s" % [Data.JOB_TITLES.pick_random(), Data.random_song_title()],
		"pay": pay,
		"deadline": deadline,
		"base_pay": base_pay,
		"idea": 0,
		"idea_seed": randi(),
		"planned_day": 0,
		"weeks_left": deadline,
		"expires": randi_range(2, 4),
		"mix": mix,
		"roles": roles,
		"revealed": [],
		"chatted": false,
		"upfront": 0,
		"upfront_pct": 0,
		"status": "offer",
	}
	job["vip_connection"] = VipOffice.connection(get_client(client_name))
	var bands = StudioStage.playable_bands()
	if not bands.is_empty() and randf() < 0.30:
		job["requested_band"] = bands[randi() % bands.size()]["id"]
	return job


func _weighted_index(weights: Array) -> int:
	var total = 0.0
	for w in weights:
		total += w
	var r = randf() * total
	for i in weights.size():
		r -= weights[i]
		if r <= 0.0:
			return i
	return weights.size() - 1


func _pick_client() -> String:
	var unused = []
	var companies: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/company_list.json"))
	for company in companies:
		if not clients.has(company):
			unused.append({"name": company, "type": Data.CLIENTS.pick_random()["type"]})
	if not unused.is_empty() and (clients.size() < 4 or randf() < 0.3):
		var c: Dictionary = unused.pick_random()
		clients[c["name"]] = {
			"name": c["name"],
			"art_id": Art.vip_ids.pick_random() if not Art.vip_ids.is_empty() else "producer",
			"type": c["type"],
			"color": Color.from_hsv(randf(), randf_range(0.4, 0.75), randf_range(0.7, 0.95)),
			"rel": randi_range(0, 30),
		}
		StudioCity.ensure_person(clients[c["name"]], true)
		return c["name"]
	var names = clients.keys()
	var weights: Array = []
	for key in names:
		weights.append(1.0 + VipOffice.connection(clients[key]) * 3.0 + (8.0 if clients[key].get("regular", false) else 0.0))
	return names[_weighted_index(weights)]


func get_client(client_name: String) -> Dictionary:
	return clients.get(client_name, {})


func add_relationship(client_name: String, amount: int) -> void:
	if not clients.has(client_name):
		return
	clients[client_name]["rel"] = clampi(int(clients[client_name]["rel"]) + amount, 0, 100)
	offers_changed.emit()


## Tags the player can see: more of them unlock as the relationship grows; items reveal extra ones.
func revealed_tags(job: Dictionary) -> Array:
	var order = Data.sorted_tags(job["mix"])
	var rel = int(get_client(job["client"]).get("rel", 0))
	var count = 0
	if rel >= 20:
		count = 1
	if rel >= 50:
		count = 2
	if rel >= 80:
		count = order.size()
	var out = []
	for i in order.size():
		if i < count or job["revealed"].has(order[i]):
			out.append(order[i])
	return out


func describe_tags(job: Dictionary) -> String:
	var known = revealed_tags(job)
	var parts = PackedStringArray()
	for tag in Data.sorted_tags(job["mix"]):
		parts.append("%s %d%%" % [tag, job["mix"][tag]] if known.has(tag) else "???")
	return " | ".join(parts)


func chat_with_client(job: Dictionary) -> int:
	if job["chatted"]:
		return 0
	job["chatted"] = true
	var gain = randi_range(4, 10)
	add_relationship(job["client"], gain)
	return gain


func use_item(key: String, job: Dictionary) -> String:
	if key == "research" and int(items.get(key, 0)) <= 0:
		return Locale.text("research_need")
	if int(items.get(key, 0)) <= 0:
		return Locale.text("legacy_102") % Data.ITEMS[key]["name"]
	match key:
		"research":
			return start_research(job)
		"energy", "pizza", "coffee":
			return boost_idea(key, job)
		"gift":
			items[key] -= 1
			items_changed.emit()
			add_relationship(job["client"], 20)
			return Locale.text("legacy_105")
	return ""


func buy_item(key: String) -> bool:
	var price = int(Data.ITEMS[key]["price"])
	if money < price:
		return false
	add_money(-price)
	items[key] = int(items.get(key, 0)) + 1
	items_changed.emit()
	return true


## Accepting pays a random 25% or 50% deposit up front.
func accept_offer(job: Dictionary, mode: String = "manual") -> int:
	if jobs.has(job): return 0
	job["play_mode"] = mode if mode in ["manual", "auto"] else "manual"
	if job["play_mode"] == "auto": StudioLife.auto_arrange(job)
	var pct: int = [25, 50].pick_random()
	job["upfront_pct"] = pct
	job["upfront"] = int(job["pay"] * pct / 100.0)
	job["status"] = "active"
	job["weeks_left"] = job["deadline"]
	job["due_day"] = day + int(job["deadline"]) * 7
	job["planned_day"] = day
	offers.erase(job)
	jobs.append(job)
	PlaytestLog.accepted(job)
	add_money(job["upfront"])
	add_relationship(job["client"], 3)
	offers_changed.emit()
	jobs_changed.emit()
	return pct


func decline_offer(job: Dictionary) -> void:
	offers.erase(job)
	add_relationship(job["client"], -2)
	offers_changed.emit()
	if job.has("demo_index") and not life.get("demo", {}).get("finished", true): DemoCareer.next_brief(int(job["demo_index"]))


func get_job(id: String) -> Dictionary:
	for job in jobs:
		if job["id"] == id:
			return job
	return {}


# --- artists ---------------------------------------------------------------------

func generate_artist(quality: float, role := "") -> Dictionary:
	if role == "":
		role = Data.ROLES.pick_random()
	var tags: Array = Data.GENRES.duplicate()
	tags.shuffle()
	var main_count = randi_range(2, 3)
	var skills = {}
	for i in main_count + 3:
		if i < main_count:
			skills[tags[i]] = clampi(int(randf_range(35.0, 65.0) + quality * 40.0), 5, 100)
		else:
			skills[tags[i]] = randi_range(5, 30)
	var power = 0.0
	for tag in skills:
		power += skills[tag]
	var fee = int(round((80.0 + power * 1.6 + quality * 400.0) / 10.0)) * 10
	var visual_id = Art.npc_ids.pick_random() if not Art.npc_ids.is_empty() else "producer"
	return {
		"id": _id("a"),
		"name": character_name(visual_id),
		"gender": Art.gender(visual_id),
		"named_by_gender": true,
		"art_id": visual_id,
		"experience": randi_range(0, 30) + int(quality * 70),
		"role": role,
		"color": Color.from_hsv(randf(), randf_range(0.45, 0.8), randf_range(0.75, 1.0)),
		"skills": skills,
		"fee_week": fee,
		"sign_fee": fee * 2,
		"weeks_left": 0,
	}


func _refresh_listing() -> void:
	listing = []
	for i in 5:
		listing.append(generate_artist(randf_range(0.0, 0.4)))
	listing_changed.emit()


func post_online_ad() -> bool:
	if money < ONLINE_AD_COST:
		notify.emit(Locale.text("legacy_106"))
		return false
	add_money(-ONLINE_AD_COST)
	online_candidates = []
	for i in 3:
		online_candidates.append(generate_artist(randf_range(0.5, 1.0)))
	listing_changed.emit()
	return true


func remove_candidate(artist: Dictionary) -> void:
	listing.erase(artist)
	online_candidates.erase(artist)
	listing_changed.emit()


func get_artist(id: String) -> Dictionary:
	for a in staff:
		if a["id"] == id:
			return a
	return {}


func staff_capacity() -> int:
	return (count_rooms("office") + mini(1, count_rooms("meeting"))) * STAFF_PER_OFFICE


## Longer contracts get a weekly discount.
func contract_terms(artist: Dictionary, weeks: int) -> Dictionary:
	var discount = 0.0
	if weeks >= 12:
		discount = 0.1
	elif weeks >= 8:
		discount = 0.05
	return {"weeks": weeks, "fee_week": int(artist["fee_week"] * (1.0 - discount)), "sign_fee": int(artist["sign_fee"])}


func sign_artist(artist: Dictionary, weeks: int) -> String:
	if staff.size() >= staff_capacity():
		return Locale.text("legacy_107")
	var terms = contract_terms(artist, weeks)
	if money < int(terms["sign_fee"]):
		return Locale.text("legacy_108") % Data.money(terms["sign_fee"])
	add_money(-int(terms["sign_fee"]))
	artist["fee_week"] = terms["fee_week"]
	artist["weeks_left"] = weeks
	artist["joined_day"] = day
	StudioLife.ensure_artist(artist)
	artist["met"] = true
	listing.erase(artist)
	online_candidates.erase(artist)
	staff.append(artist)
	listing_changed.emit()
	staff_changed.emit()
	return ""


func renewal_cost(artist: Dictionary, weeks: int) -> int:
	if artist.get("social", {}).get("partner", "") == "producer": return 0
	return int(artist["fee_week"]) * (2 if weeks <= 4 else 3)


func renew_contract(artist: Dictionary, weeks: int) -> String:
	var cost = renewal_cost(artist, weeks)
	if money < cost:
		return Locale.text("legacy_109") % Data.money(cost)
	add_money(-cost)
	artist["weeks_left"] = maxi(0, int(artist["weeks_left"])) + weeks
	staff_changed.emit()
	return ""


## Letting an artist go mid-recording throws the whole session away (Locale.text("legacy_110")).
func release_artist(artist: Dictionary) -> void:
	var left_partner = str(artist.get("social", {}).get("partner", ""))
	for a in staff:
		if str(a.get("social", {}).get("partner", "")) == str(artist["id"]):
			StudioStage.split_pair(str(a["id"]), str(artist["id"]))
	if left_partner != "" and left_partner != "producer":
		StudioStage.split_pair(str(artist["id"]), left_partner)
	staff.erase(artist)
	life["training"] = life.get("training", []).filter(func(t: Dictionary): return t["artist_id"] != artist["id"])
	for a in staff:
		if str(a.get("social", {}).get("partner", "")) == str(artist["id"]): a["social"]["partner"] = ""
	for booking in production_queue.duplicate():
		if artist["id"] in booking["team"]: cancel_scheduled(booking["job_id"])
	if artist["id"] in idea_meeting.get("participants", []): cancel_idea_meeting()
	for task in research_tasks.duplicate():
		if artist["id"] in task.get("participants", [task.get("artist_id", "")]):
			research_tasks.erase(task)
			items["research"] = int(items.get("research", 0)) + 1
			items_changed.emit()
			research_changed.emit()
	var session = artist_project(artist["id"])
	if not session.is_empty():
		if not session["done"]:
			_remove_session(session)
			project_reset.emit(Locale.text("legacy_111") % [artist["name"], session["title"]])
			project_ended.emit()
		else: session["team"].erase(artist["id"])
	staff_changed.emit()


func is_in_project(artist_id: String) -> bool:
	return not artist_project(artist_id).is_empty()


# --- production (Game Dev Story style) ---------------------------------------------

func start_project(job_id: String, team_ids: Array, mix: Dictionary, title: String, booked_room: int = -1) -> String:
	if StudioCity.fire_active(): return Locale.text("city_fire_wait")
	if not idea_meeting.is_empty(): return Locale.text("jam_busy")
	if needs_manual_composition(get_job(job_id)): return Locale.text("manual_required")
	var sessions = all_projects()
	if sessions.size() >= count_rooms("studio"):
		return Locale.text("rooms_busy")
	for session in sessions:
		if session["job_id"] == job_id: return Locale.text("job_recording")
	var ban = StudioStage.ban_reason(team_ids)
	if ban != "": return ban
	for id in team_ids:
		if get_artist(id).is_empty() or is_in_project(id) or is_researching(id) or not StudioLife.training(id).is_empty() or StudioStage.performing(id): return Locale.text("artist_busy")
	if count_rooms("studio") == 0:
		return Locale.text("legacy_113")
	var job = get_job(job_id)
	if job.is_empty():
		return Locale.text("legacy_114")
	if team_ids.is_empty():
		return Locale.text("legacy_115")
	if mix.is_empty():
		return Locale.text("legacy_116")
	if int(job.get("planned_day", 0)) > day: return Locale.text("not_planned_yet")
	var used_rooms = []
	for session in sessions: used_rooms.append(session.get("room", 0))
	var room_index = 0
	var estimated_end = day + _session_days(job, team_ids, mix)
	while room_index < count_rooms("studio") and (room_index in used_rooms or _booking_conflicts(team_ids,room_index,day,estimated_end,job_id)): room_index += 1
	if room_index >= count_rooms("studio") and booked_room < 0: return Locale.text("schedule_conflict")
	if booked_room >= 0:
		if booked_room >= count_rooms("studio") or booked_room in used_rooms: return Locale.text("rooms_busy")
		room_index = booked_room
		if _booking_conflicts(team_ids,room_index,day,estimated_end,job_id): return Locale.text("schedule_conflict")
	if not project.is_empty(): parallel_projects.append(project)
	project = {
		"room": room_index,
		"started_day": day,
		"job_id": job_id,
		"team": team_ids.duplicate(),
		"mix": mix.duplicate(),
		"title": title,
		"progress": 0.0,
		"points": {"Melody": int(job.get("idea", 0)), "Lyrics": 0, "Groove": 0, "Sound": 0},
		"done": false,
		"eval": {},
		"remix": str(job.get("remix_of", "")) != "",
	}
	if project["remix"]:
		var source = StudioStage.song_by_id(str(job.get("remix_of", "")))
		if not source.is_empty():
			project["points"]["Melody"] = maxi(int(project["points"]["Melody"]), mini(70, int(source.get("rating", 0))))
	project_started.emit(project)
	return ""


func get_team() -> Array:
	var out = []
	if project.is_empty():
		return out
	for id in project["team"]:
		var a = get_artist(id)
		if not a.is_empty():
			out.append(a)
	return out


## 0..1 – how well an artist's skills cover the chosen genre mix.
func artist_fit(artist: Dictionary, mix: Dictionary) -> float:
	var fit = 0.0
	for tag in mix:
		fit += float(mix[tag]) / 100.0 * float(artist["skills"].get(tag, 0)) / 100.0
	return fit


## Progress % per day: a flat studio base + each member (better genre fit = faster).
## Solo ≈ 12 days, duo ≈ 9 days, a good 4-piece ≈ 5 days.
func daily_progress(team: Array, mix: Dictionary) -> float:
	if team.is_empty():
		return 0.0
	var gain = 6.0
	for a in team:
		gain += (1.0 + artist_fit(a, mix)) * 2.5
	return gain


func estimate_days(team: Array, mix: Dictionary) -> int:
	var gain = daily_progress(team, mix)
	return ceili(100.0 / gain) if gain > 0.0 else 999


func _session_days(job: Dictionary, team_ids: Array, mix: Dictionary) -> int:
	var days = estimate_days(_team_for(team_ids), mix)
	if str(job.get("remix_of", "")) != "":
		days = maxi(2, ceili(float(days) / 1.4))
	return days


func _tick_project() -> void:
	if not project.is_empty() and not StudioCity.room_damage(int(project.get("room", 0))).is_empty(): return
	if project.is_empty() or project["done"]:
		return
	if CreativeJourney.tick(project): return
	var team = get_team()
	if team.is_empty():
		return
	var mix: Dictionary = project["mix"]
	var ids: Array = []
	for a in team:
		ids.append(str(a["id"]))
	var craft = StudioStage.craft_multiplier(team)
	var remixing = bool(project.get("remix", false))
	for a in team:
		var fit = artist_fit(a, mix)
		if randf() < 0.8:
			var cats: Array = Data.ROLE_POINTS[a["role"]]
			var cat: String = cats.pick_random()
			var amount = maxi(1, int(round((1.0 + fit * 8.0) * randf_range(0.7, 1.3) * craft * (1.15 if remixing else 1.0))))
			project["points"][cat] += amount
			points_generated.emit(a["id"], cat, amount)
	if StudioStage.friction_today(ids):
		var dropped := "Melody"
		var most := -1
		for key in project["points"]:
			if int(project["points"][key]) > most:
				most = int(project["points"][key])
				dropped = str(key)
		project["points"][dropped] = maxi(0, int(project["points"][dropped]) - 2)
		if int(project.get("chem_note_day", -1)) != day:
			project["chem_note_day"] = day
			var pair = StudioStage.lowest_pair(ids)
			if pair.size() == 2:
				alice_notice.emit(Locale.text("stage_friction", pair))
	StudioStage.on_shared_room(ids)
	var gain = daily_progress(team, mix)
	if remixing:
		gain *= 1.4
	project["progress"] = minf(100.0, float(project["progress"]) + gain)
	project_progress.emit(project["progress"])
	if CreativeJourney.tick(project):
		project["progress"] = minf(99, float(project["progress"]))
		return
	if project["progress"] >= 100.0:
		project["done"] = true
		project["eval"] = evaluate_project()


## Score = how close the mix is to the client's hidden tags + musician mastery of those tags
## + accumulated production points – missing roles. Four critics each give 1-10 (max 40).
func evaluate_project() -> Dictionary:
	var job = get_job(project["job_id"])
	var target: Dictionary = job.get("mix", {})
	var mix: Dictionary = project["mix"]
	var team = get_team()

	var all_tags = {}
	for tag in target:
		all_tags[tag] = true
	for tag in mix:
		all_tags[tag] = true
	var distance = 0.0
	for tag in all_tags:
		distance += absf(float(target.get(tag, 0)) - float(mix.get(tag, 0)))
	var closeness = clampf(1.0 - distance / 200.0, 0.0, 1.0)

	var mastery = 0.0
	for tag in target:
		var best = 0
		for a in team:
			best = maxi(best, int(a["skills"].get(tag, 0)))
		mastery += float(target[tag]) / 100.0 * best / 100.0

	var have = {}
	for a in team:
		have[a["role"]] = true
	var missing = []
	for role in job.get("roles", []):
		if not have.has(role):
			missing.append(role)

	var total_points = 0
	for cat in project["points"]:
		total_points += int(project["points"][cat])
	# Fixed craft target: urgent commission pricing must not make the same song worse.
	var expected = 100.0
	var craft = clampf(total_points / expected, 0.0, 1.0)

	var experience = 0.0
	for a in team: experience += clampf(float(a.get("experience", 0)) / 100.0, 0.0, 1.0)
	experience /= maxf(1.0, team.size())
	var score = clampf(0.05 + closeness * 0.35 + mastery * 0.30 + craft * 0.20 + experience * 0.10 - missing.size() * 0.08, 0.05, 1.0)
	var critics = []
	score = clampf(score + float(job.get("creative_score", 0.0)), 0.05, 1.0)
	var total = 0
	for c in Data.CRITICS:
		var s = clampi(int(round(score * 10.0 + randf_range(-0.65, 0.65))), 1, 10)
		total += s
		critics.append({"name": c["name"],
			"art_id": Art.vip_ids[Data.CLIENTS.find(c) % Art.vip_ids.size()] if not Art.vip_ids.is_empty() else "producer", "color": c["color"], "score": s, "comment": Data.critic_comment(s)})
	return {"closeness": closeness, "mastery": mastery, "craft": craft, "missing": missing, "critics": critics, "total": total}


## Pays the rest of the fee (scaled by rating), applies marketing hype to sales and creates the song.
func release_project(marketing_index: int) -> Dictionary:
	if project.is_empty() or not project["done"]:
		return {}
	var plan: Dictionary = Data.MARKETING[marketing_index]
	add_money(-int(plan["cost"]))
	var ev: Dictionary = project["eval"]
	var job = get_job(project["job_id"])
	var total = int(ev["total"])
	var quality = total / 40.0
	var payout = maxi(0, int((int(job["pay"]) - int(job["upfront"])) * (0.5 + quality)) - int(job.get("extension_fee", 0)))
	var invoice = {"id": _id("inv"), "client": job["client"], "title": project["title"], "amount": payout, "due_day": day + 7, "paid": false}
	invoices.append(invoice)
	alice_notice.emit(Locale.text("invoice_issued", [project["title"], Data.money(payout), invoice["due_day"] + 1]))
	var hype = float(plan["hype"])
	var team_ids: Array = []
	var cover_cast: Array = []
	for member in get_team():
		team_ids.append(str(member["id"]))
		cover_cast.append({"id": member["id"], "name": member["name"], "art_id": Art.model_id(member)})
	var song = {
		"cover_cast": cover_cast,
		"origin_studio": studio_name, "origin_producer": producer_name, "owner_uid": FirebaseAuth.uid,
		"id": "song_" + Crypto.new().generate_random_bytes(16).hex_encode(),
		"title": project["title"],
		"client": job["client"],
		"mix": project["mix"],
		"idea_notes": job.get("idea_notes", []),
		"idea_bpm": job.get("idea_bpm", 120),
		"idea_midi": job.get("idea_midi", ""),
		"target": job["mix"],
		"rating": total,
		"critics": ev["critics"],
		"cover_seed": randi(),
		"marketing": plan["name"],
		"hype": hype,
		"team": team_ids.duplicate(),
		"chart_boost": 0,
		"peak_rank": 0,
		"weeks_on_chart": 0,
		"remix_of": str(job.get("remix_of", "")),
		"band_id": "",
		"band_word": "",
		"band_genre": "",
		"weekly_sales": int(pow(quality, 2.0) * (1500.0 + fans * 0.8) * hype),
		"weeks_left": 8,
		"earned": 0,
		"payout": payout,
		"day": day,
		"local_audio": "",
		"local_cover": "",
		"ai_local": "",
		"audio_url": "",
		"cover_url": "",
		"status": Locale.text("legacy_117"),
	}
	fans += StudioStage.fan_gain(total, hype, team_ids, job)
	fame += int(total * 25 * hype)
	reputation = clampi(reputation + (4 if total >= 24 else (1 if total >= 16 else -3)), 0, 100)
	for member in get_team():
		member["experience"] = mini(100, int(member.get("experience", 0)) + 3)
	var contact = get_client(job["client"])
	StudioCity.ensure_person(contact, true)
	contact["completed_jobs"] = int(contact["completed_jobs"]) + 1
	add_relationship(job["client"], int((total - 20) * 1.5))
	job["status"] = "done"
	jobs.erase(job)
	StoryQuests.annotate_release(job, song)
	songs.append(song)
	CreativeJourney.on_release(job, song)
	MarketShift.release(job, song, team_ids)
	DemoCareer.released(job, song)
	StudioStage.on_release(song, team_ids)
	StudioStars.on_release(song, team_ids)
	VipOffice.production_pressure(job, team_ids)
	var played = StudioStage.matching_band(team_ids)
	if not played.is_empty() and str(job.get("requested_band", "")) == str(played["id"]):
		alice_notice.emit(Locale.text("stage_band_delivered", [StudioStage.band_label(played), song["title"]]))
	project = {}
	if not parallel_projects.is_empty(): project = parallel_projects.pop_front()
	project_ended.emit()
	jobs_changed.emit()
	fans_changed.emit(fans)
	song_released.emit(song)
	call_deferred("_tick_schedule")
	save_game()
	return song


# --- building (SimTower style) -------------------------------------------------------

func column_count() -> int:
	return floors[0].size() if not floors.is_empty() else 0


func count_rooms(type: String) -> int:
	var n = 0
	for row in floors:
		n += row.count(type)
	return n


func add_floor() -> String:
	if floors.size() >= Data.MAX_FLOORS:
		return Locale.text("legacy_118") % Data.MAX_FLOORS
	if money < Data.FLOOR_COST:
		return Locale.text("legacy_119") % Data.money(Data.FLOOR_COST)
	add_money(-Data.FLOOR_COST)
	var row = []
	row.resize(column_count())
	row.fill("empty")
	floors.append(row)
	building_changed.emit()
	return ""


func add_column() -> String:
	if column_count() >= Data.MAX_COLUMNS:
		return Locale.text("legacy_120") % Data.MAX_COLUMNS
	if money < Data.COLUMN_COST:
		return Locale.text("legacy_119") % Data.money(Data.COLUMN_COST)
	add_money(-Data.COLUMN_COST)
	for row in floors:
		row.append("empty")
	building_changed.emit()
	return ""


func build_room(floor_index: int, column: int, type: String) -> String:
	if StudioCity.fire_active(): return Locale.text("city_fire_wait")
	if floors[floor_index][column] != "empty":
		return Locale.text("legacy_121")
	var cost = int(Data.ROOM_TYPES[type]["cost"])
	if money < cost:
		return Locale.text("legacy_119") % Data.money(cost)
	add_money(-cost)
	floors[floor_index][column] = type
	if type == "studio":
		var inserted_room = 0
		for f in floors.size():
			for c in floors[f].size():
				if f < floor_index or (f == floor_index and c < column):
					if floors[f][c] == "studio": inserted_room += 1
		for session in all_projects():
			if int(session.get("room", 0)) >= inserted_room: session["room"] = int(session.get("room", 0)) + 1
		for booking in production_queue:
			if int(booking["room"]) >= inserted_room: booking["room"] = int(booking["room"]) + 1
	building_changed.emit()
	staff_changed.emit()
	return ""

func _reset_identity() -> void:
	player_character = "producer"
	producer_name = "Producer"
	studio_name = "New Sound Studio"
	identity_initialized = false
	intro_seen = false
	fame = 0
	reputation = 35

func set_identity(producer: String, studio: String, character: String = "producer") -> bool:
	if character not in ["producer", "alice"]: return false
	producer = producer.strip_edges()
	studio = studio.strip_edges()
	if producer.length() < 2 or producer.length() > 24 or studio.length() < 2 or studio.length() > 24:
		return false
	player_character = character
	producer_name = producer
	StudioCity.alice()
	studio_name = studio
	identity_initialized = true
	save_game()
	state_loaded.emit()
	return true

func _migrate_visuals() -> void:
	for collection in [staff, listing, online_candidates]:
		for artist in collection:
			if not artist.has("art_id"):
				artist["art_id"] = Art.model_id(artist)
			if not artist.has("experience"):
				artist["experience"] = absi(str(artist.get("id", "")).hash()) % 80
	for client in clients.values():
		if not client.has("art_id") and not Art.vip_ids.is_empty():
			client["art_id"] = Art.vip_ids[absi(str(client["name"]).hash()) % Art.vip_ids.size()]

func rankings(metric: String) -> Array:
	metric = "reputation" if metric == "reputation" else "fame"
	var entries = Locale.values("rivals")
	entries.append({"name": studio_name, "fame": fame, "reputation": reputation, "ours": true})
	entries.sort_custom(func(a: Dictionary, b: Dictionary): return int(a[metric]) > int(b[metric]))
	return entries


# --- scheduling, parallel rooms and Alice's production desk ---------------------
func all_projects() -> Array:
	var sessions: Array = parallel_projects.duplicate()
	if not project.is_empty(): sessions.push_front(project)
	return sessions

func artist_project(id: String) -> Dictionary:
	for session in all_projects():
		if id in session["team"]: return session
	return {}

func focus_project(job_id: String) -> bool:
	if not project.is_empty() and project["job_id"] == job_id: return true
	for session in parallel_projects:
		if session["job_id"] == job_id:
			parallel_projects.erase(session)
			if not project.is_empty(): parallel_projects.append(project)
			project = session
			return true
	return false

func _remove_session(session: Dictionary) -> void:
	if session == project:
		project = parallel_projects.pop_front() if not parallel_projects.is_empty() else {}
	else: parallel_projects.erase(session)

func _tick_all_projects() -> void:
	if StudioCity.fire_active(): return
	var focus = project
	var completed: Array = []
	for session in all_projects():
		project = session
		var was_done = bool(session["done"])
		_tick_project()
		if not was_done and session["done"]: completed.append(session)
	project = focus
	for session in completed: project_completed.emit(session)

func commission_pay(base_pay: int, weeks: int) -> int:
	return int(round(base_pay * (0.7 + 3.2 / maxf(1.0, weeks)) / 100.0)) * 100

func job_days_left(job: Dictionary) -> int:
	return int(job.get("due_day", day + int(job.get("weeks_left", 0)) * 7 - day % 7)) - day

func is_researching(id: String) -> bool:
	if not idea_meeting.is_empty() and id in idea_meeting.get("participants", []): return true
	for task in research_tasks:
		if id in task.get("participants", ["alice", task.get("artist_id", "")]): return true
	return false

func start_research(job: Dictionary) -> String:
	if not jobs.has(job) and not offers.has(job): return Locale.text("legacy_114")
	if count_rooms("lounge") == 0: return Locale.text("research_room")
	if not idea_meeting.is_empty(): return Locale.text("jam_busy")
	if not research_tasks.is_empty(): return Locale.text("research_busy")
	if int(items.get("research", 0)) <= 0: return Locale.text("research_need")
	var participant = ""
	var participants: Array = ["producer", "alice"]
	for artist in staff:
		if is_in_project(artist["id"]) or not StudioLife.training(artist["id"]).is_empty() or StudioStage.performing(artist["id"]): return Locale.text("jam_staff_busy")
		participants.append(artist["id"])
		participant = artist["id"]
	if participant.is_empty(): return Locale.text("research_crew")
	var fee = research_price(job)
	if money < fee: return Locale.text("agency_funds", [Data.money(fee)])
	add_money(-fee)
	items["research"] -= 1
	research_tasks.append({"job_id": job["id"], "artist_id": participant, "participants": participants, "finish_day": day + 3, "brief": job})
	items_changed.emit()
	research_changed.emit()
	save_game()
	return Locale.text("research_started", [job["title"]])

func research_price(job: Dictionary) -> int:
	# Charge for genre complexity, team scope and urgency at the time of use.
	var genres = 0
	for weight in job.get("mix", {}).values():
		if float(weight) > 0: genres += 1
	var weeks = int(job.get("deadline", 8))
	if job.has("due_day"): weeks = maxi(1, int(ceil((int(job["due_day"]) - day) / 7.0)))
	return 400 + maxi(0, genres - 1) * 200 + maxi(0, job.get("roles", []).size() - 1) * 150 + maxi(0, 6 - weeks) * 150

func _tick_research() -> void:
	for task in research_tasks.duplicate():
		if day < int(task["finish_day"]): continue
		var job = get_job(str(task["job_id"]))
		if job.is_empty():
			for offer in offers:
				if offer["id"] == task["job_id"]: job = offer
		if job.is_empty():
			research_tasks.erase(task)
			research_changed.emit()
			continue
		# A 60% reliable recommendation, never the exact recipe.
		var hint = str(Data.sorted_tags(job["mix"])[0])
		if randf() >= 0.6:
			var alternatives = Data.GENRES.duplicate()
			alternatives.erase(hint)
			hint = alternatives.pick_random()
		job["research_hint"] = hint
		job["idea"] = mini(30, int(job.get("idea", 0)) + 8)
		research_tasks.erase(task)
		research_changed.emit()
		alice_notice.emit(Locale.text("research_result", [job["title"], hint]))
		if jobs.has(job) and needs_manual_composition(job):
			manual_composition_requested.emit(str(job["id"]))

func needs_manual_composition(job: Dictionary) -> bool:
	return not job.is_empty() and job.get("play_mode", "manual") != "auto" and int(job.get("idea_rounds", 0)) == 0

func boost_idea(key: String, job: Dictionary) -> String:
	if key not in ["energy", "pizza", "coffee"] or int(items.get(key, 0)) <= 0: return Locale.text("boost_empty")
	if int(job.get("idea", 0)) >= 30: return Locale.text("boost_cap")
	items[key] -= 1
	var gain = mini(30 - int(job.get("idea", 0)), {"energy": 6, "pizza": 12, "coffee": 4}[key])
	job["idea"] = mini(30, int(job.get("idea", 0)) + gain)
	for session in all_projects():
		if session["job_id"] == job["id"] and not session["done"]:
			session["points"]["Melody"] += gain
	items_changed.emit()
	return Locale.text("boost_result", [job["title"], job["idea"]])

func request_extension(job: Dictionary) -> String:
	if not jobs.has(job): return Locale.text("legacy_114")
	if job.get("extension_requested", false): return Locale.text("extension_used")
	job["extension_requested"] = true
	var rel = int(get_client(job["client"]).get("rel", 0))
	if rel < 35:
		add_relationship(job["client"], -3)
		return Locale.text("extension_refused")
	var fee = int(job["pay"] * 0.1) if rel < 70 else 0
	# Withhold the charge from the final invoice, never create cash from renegotiation.
	job["extension_fee"] = fee
	job["due_day"] = day + job_days_left(job) + 7
	job["weeks_left"] = ceili(job_days_left(job) / 7.0)
	add_relationship(job["client"], -5)
	jobs_changed.emit()
	return Locale.text("extension_ok", [Data.money(fee)])

func _tick_invoices() -> void:
	for invoice in invoices:
		if not invoice["paid"] and day >= int(invoice["due_day"]):
			invoice["paid"] = true
			add_money(int(invoice["amount"]))
			alice_notice.emit(Locale.text("invoice_paid", [invoice["title"], Data.money(invoice["amount"])]))

func _run_contest() -> void:
	StudioCity.contest()

func character_name(visual_id: String) -> String:
	var names = ["Emma", "Olivia", "Sophia", "Maya", "Chloe", "Nina", "Lily", "Hana", "Isabella", "Aria", "Zoe", "Clara"] if Art.gender(visual_id) == "female" else ["Liam", "Noah", "Oliver", "James", "Lucas", "Ethan", "Leo", "Henry", "Jack", "Oscar", "Daniel", "Theo"]
	return "%s %s" % [names[absi(visual_id.hash()) % names.size()], Data.STAGE_NAMES.pick_random()]

func client_contact(client: Dictionary) -> String:
	if client.has("story_npc"):
		var quest = StoryQuests.definition(str(client["story_npc"]))
		if not quest.is_empty(): return StoryQuests.text(quest["npc"]["name"])
	var id = str(client.get("art_id", "super-01"))
	var names = {"super-01": "Mr. Victor", "super-02": "Ms. Evelyn", "super-03": "Mr. Adrian", "super-04": "Ms. Scarlett", "super-05": "Mr. Winston", "super-06": "Ms. Victoria"}
	return "%s | %s" % [names.get(id, "Client"), Locale.legacy(str(client.get("name", "")))]

func _migrate_planning() -> void:
	for artist in staff + listing + online_candidates:
		if not artist.get("named_by_gender", false):
			artist["name"] = character_name(Art.model_id(artist))
			artist["named_by_gender"] = true
		artist["gender"] = Art.gender(Art.model_id(artist))
	for job in jobs:
		if not job.has("due_day"): job["due_day"] = day + int(job["weeks_left"]) * 7 - day % 7
	var room = 0
	for session in all_projects():
		if not session.has("room"): session["room"] = room
		room += 1


# --- Lounge arrangement puzzle ------------------------------------------------
func begin_idea_meeting(job: Dictionary) -> String:
	if idea_meeting.get("job_id", "") == job.get("id", "") and not idea_meeting.is_empty():
		meeting_changed.emit()
		return ""
	if StudioCity.fire_active(): return Locale.text("city_fire_wait")
	if not jobs.has(job): return Locale.text("legacy_114")
	if not idea_meeting.is_empty():
		if str(idea_meeting.get("job_id", "")) != str(job["id"]): return Locale.text("jam_busy")
		meeting_changed.emit()
		return ""
	for a in staff:
		if not StudioLife.training(a["id"]).is_empty() or StudioStage.performing(a["id"]): return Locale.text("artist_busy")
	if not jobs.has(job): return Locale.text("legacy_114")
	if count_rooms("lounge") == 0: return Locale.text("jam_need_lounge")
	if not idea_meeting.is_empty() or not research_tasks.is_empty(): return Locale.text("jam_busy")
	for session in all_projects():
		if not session["done"]: return Locale.text("jam_staff_busy")
	if int(job.get("idea_rounds", 0)) >= 1: return Locale.text("jam_once")
	idea_meeting = IdeaRules.create(job, true)
	ComposerFlow.prepare(idea_meeting, job)
	var participants: Array = ["producer", "alice"]
	for artist in staff: participants.append(artist["id"])
	idea_meeting["participants"] = participants
	meeting_changed.emit()
	save_game()
	return ""

func place_idea(block: int, row: int, col: int, transpose: Variant = null) -> bool:
	if idea_meeting.get("phase", "") not in ["ready", "playing"] or not IdeaRules.can_place(idea_meeting, block, row, col): return false
	if idea_meeting.get("freeform", false):
		if idea_meeting["deck"][block].get("palette", false):
			var copy: Dictionary = idea_meeting["deck"][block].duplicate(true)
			copy["palette"] = false
			copy["id"] = idea_meeting["deck"].size()
			idea_meeting["deck"].append(copy)
			block = int(copy["id"])
		if transpose != null: idea_meeting["deck"][block]["transpose"] = clampi(int(transpose), -12, 12)
		idea_meeting["placed"] = idea_meeting["placed"].filter(func(p: Dictionary): return int(p["block"]) != block and not (int(p["row"]) == row and int(p["col"]) == col))
		idea_meeting["placed"].append({"block": block, "row": row, "col": col})
		idea_meeting["phase"] = "playing"
		return true
	# Start only after a legal placement. Hovering/invalid drops do not consume
	# time, and the source remains alive until Godot completes the drag gesture.
	if idea_meeting["phase"] == "ready":
		idea_meeting["phase"] = "playing"
		if speed <= 0: speed = 1
	idea_meeting["placed"] = idea_meeting["placed"].filter(func(p: Dictionary): return int(p["block"]) != block)
	idea_meeting["placed"].append({"block": block, "row": row, "col": col})
	return true

func remove_idea(block: int) -> void:
	if idea_meeting.is_empty(): return
	idea_meeting["placed"] = idea_meeting["placed"].filter(func(p: Dictionary): return int(p["block"]) != block)

func finish_idea_meeting() -> Dictionary:
	if idea_meeting.is_empty(): return {}
	if idea_meeting.get("freeform", false) and idea_meeting["placed"].is_empty(): return {}
	var result = IdeaRules.score(idea_meeting)
	var job = get_job(str(idea_meeting["job_id"]))
	if not job.is_empty():
		job["idea"] = mini(30, int(job.get("idea", 0)) + int(result["idea"]))
		job["idea_notes"] = IdeaMusic.events(idea_meeting["deck"], idea_meeting["placed"])
		job["idea_bpm"] = idea_meeting["bpm"]
		job["arrangement"] = idea_meeting.duplicate(true)
		job["arrangement"].erase("undo")
		job["arrangement"].erase("redo")
		job["arrangement"].erase("copy_next")
		job["idea_rounds"] = int(job.get("idea_rounds", 0)) + 1
		job["idea_score"] = result["score"]
		DirAccess.make_dir_recursive_absolute("user://midi")
		var midi_path = "user://midi/%s.mid" % job["id"]
		if IdeaMusic.write_midi(job["idea_notes"], job["idea_bpm"], midi_path): job["idea_midi"] = midi_path
	idea_meeting = {}
	meeting_changed.emit()
	save_game()
	return result

func cancel_idea_meeting() -> void:
	idea_meeting = {}
	meeting_changed.emit()
	save_game()

# --- Resource-aware production calendar ---------------------------------------
func scheduled_job(job_id: String) -> Dictionary:
	for booking in production_queue:
		if booking["job_id"] == job_id: return booking
	return {}

func _booking_conflicts(team: Array, room: int, start: int, end: int, ignore_job: String = "") -> bool:
	if StudioStars.conflicts(team, start, end): return true
	var damage = StudioCity.room_damage(room)
	if not damage.is_empty() and start < int(damage["until"]): return true
	for research in research_tasks:
		if start < int(research["finish_day"]):
			for id in team:
				if id in research.get("participants", [research.get("artist_id", "")]): return true
	var blocks = production_queue.duplicate()
	for session in all_projects():
		var days = 1 if session["done"] else maxi(1, ceili((100 - float(session["progress"])) / daily_progress(_team_for(session["team"]), session["mix"])))
		blocks.append({"job_id": session["job_id"], "team": session["team"], "room": session.get("room", 0), "start_day": day, "end_day": day + days})
	for booking in blocks:
		if booking["job_id"] == ignore_job: continue
		if start < int(booking["end_day"]) and end > int(booking["start_day"]):
			if int(booking["room"]) == room: return true
			for id in team:
				if id in booking["team"]: return true
	return false

func _team_for(ids: Array) -> Array:
	var team: Array = []
	for id in ids:
		var artist = get_artist(id)
		if not artist.is_empty(): team.append(artist)
	return team

func schedule_project(job_id: String, team_ids: Array, mix: Dictionary, title: String, start: int, room: int = -1) -> String:
	var job = get_job(job_id)
	if job.is_empty(): return Locale.text("legacy_114")
	if needs_manual_composition(job): return Locale.text("manual_required")
	if team_ids.is_empty() or _team_for(team_ids).size() != team_ids.size(): return Locale.text("legacy_115")
	if mix.is_empty(): return Locale.text("legacy_116")
	if start <= day: return Locale.text("schedule_future")
	for session in all_projects():
		if session["job_id"] == job_id: return Locale.text("job_recording")
	var ban = StudioStage.ban_reason(team_ids, start)
	if ban != "": return ban
	var end = start + _session_days(job, team_ids, mix)
	if end > int(job.get("due_day", day + job_days_left(job))): return Locale.text("schedule_late")
	for artist in _team_for(team_ids):
		var training = StudioLife.training(artist["id"])
		if not training.is_empty() and start < int(training["finish_day"]): return Locale.text("artist_busy")
		if end > day + int(artist["weeks_left"]) * 7 - day % 7: return Locale.text("schedule_contract")
	var chosen = room
	if chosen < 0:
		for candidate in count_rooms("studio"):
			if not _booking_conflicts(team_ids, candidate, start, end, job_id):
				chosen = candidate
				break
	if chosen < 0 or chosen >= count_rooms("studio") or _booking_conflicts(team_ids, chosen, start, end, job_id): return Locale.text("schedule_conflict")
	cancel_scheduled(job_id)
	production_queue.append({"job_id": job_id, "team": team_ids.duplicate(), "mix": mix.duplicate(), "title": title, "start_day": start, "end_day": end, "room": chosen, "blocked": false})
	job["planned_day"] = start
	schedule_changed.emit()
	save_game()
	return ""

func cancel_scheduled(job_id: String) -> void:
	production_queue = production_queue.filter(func(b: Dictionary): return b["job_id"] != job_id)
	schedule_changed.emit()

func move_scheduled(job_id: String, start: int) -> String:
	if get_job(job_id).is_empty(): return Locale.text("legacy_114")
	for session in all_projects():
		if session["job_id"] == job_id: return Locale.text("job_recording")
	var booking = scheduled_job(job_id)
	if booking.is_empty():
		get_job(job_id)["planned_day"] = maxi(day, start)
		save_game()
		return ""
	return schedule_project(job_id, booking["team"], booking["mix"], booking["title"], start, booking["room"])

func _tick_schedule() -> void:
	if StudioCity.fire_active(): return
	for booking in production_queue.duplicate():
		if day < int(booking["start_day"]): continue
		var job = get_job(booking["job_id"])
		if job.is_empty():
			cancel_scheduled(booking["job_id"])
			continue
		job["planned_day"] = day
		var error = start_project(booking["job_id"], booking["team"], booking["mix"], booking["title"], booking["room"])
		if error.is_empty():
			cancel_scheduled(booking["job_id"])
			notify.emit(Locale.text("schedule_started", [booking["title"]]))
		elif not booking["blocked"]:
			booking["blocked"] = true
			alice_notice.emit(Locale.text("schedule_blocked", [booking["title"], error]))
