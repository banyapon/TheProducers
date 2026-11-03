extends Node
## Root scene. Scene-to-scene signals are wired in main.tscn ([connection] entries); autoload
## signals are wired in _ready(). Conversations are "flows": coroutines that drive the DialogBox,
## run strictly one at a time through a queue so pop-ups never overlap.

var PLAYER: Dictionary:
	get: return Game.player_portrait()
var CONTRACTOR: Dictionary:
	get: return {"name": Locale.text("legacy_136"), "art_id": "npc-03-male-sidepart"}
var SHOPKEEPER: Dictionary:
	get: return {"name": Locale.text("legacy_137"), "art_id": "npc-08-female-bun", "gender": "female"}

@onready var office: Office = $Office
@onready var hud: Hud = $UI/HUD
@onready var job_board: UIPanel = $UI/JobBoard
@onready var hire_board: UIPanel = $UI/HireBoard
@onready var production: UIPanel = $UI/ProductionPanel
@onready var release_panel: UIPanel = $UI/ReleasePanel
@onready var library: UIPanel = $UI/Library
@onready var dialog: DialogBox = $UI/DialogBox
@onready var login: LoginScreen = $UI/LoginScreen

var _queue: Array[Callable] = []
var _queue_running = false
var _booting = false
var shell: AppShell
var planner: PlanningPanel
var jam: IdeaJamPanel
var city_panel: CityPanel
var staff_panel: StaffPanel
var star_panel: StarPanel
var news_panel: NewsPanel
var coach: TutorialCoach


func _ready() -> void:
	star_panel = StarPanel.new()
	$UI.add_child(star_panel)
	news_panel = NewsPanel.new()
	$UI.add_child(news_panel)
	Game.hot_news.connect(func(event: Dictionary): _enqueue(_flow_hot_news.bind(event)))
	Game.fire_started.connect(_on_fire_started)
	Game.state_loaded.connect(func():
		if StudioCity.fire_active(): _on_fire_started())
	city_panel = CityPanel.new()
	$UI.add_child(city_panel)
	Game.contest_announced.connect(func(result: Dictionary): _enqueue(_flow_contest.bind(result)))
	staff_panel = StaffPanel.new()
	$UI.add_child(staff_panel)
	staff_panel.stars_requested.connect(star_panel.open)
	library.collection_requested.connect(func(): star_panel.tab = 2; star_panel.open())
	staff_panel.talk_requested.connect(func(id: String): _enqueue(_flow_staff_call.bind(id)))
	Game.monthly_feedback.connect(func(month: int): _enqueue(_flow_monthly_feedback.bind(month)))
	hud.zoom_requested.connect(office._zoom)
	office.zoom_changed.connect(hud.set_zoom)
	jam = IdeaJamPanel.new()
	$UI.add_child(jam)
	jam.office = office
	Game.meeting_changed.connect(_on_meeting_changed)
	Game.demo_completed.connect(func(): _enqueue(_flow_demo_end))
	Game.recovery_requested.connect(func(event: Dictionary): _enqueue(_flow_recovery.bind(event)))
	Game.creative_decision_requested.connect(func(id: String): _enqueue(_flow_creative_decision.bind(id)))
	Game.manual_composition_requested.connect(func(id: String): _enqueue(_flow_manual_composition.bind(id)))
	planner = PlanningPanel.new()
	$UI.add_child(planner)
	planner.call_requested.connect(func(job: Dictionary): _enqueue(_flow_call.bind(job)))
	planner.record_requested.connect(func(job_id: String):
		if Game.needs_manual_composition(Game.get_job(job_id)):
			_enqueue(_flow_manual_composition.bind(job_id))
			return
		production._setup_mode = true
		production.open()
		production.select_job(job_id))
	planner.jam_requested.connect(func(job: Dictionary):
		var error = Game.begin_idea_meeting(job)
		if not error.is_empty(): hud.toast(error))
	planner.report_requested.connect(func(): _enqueue(_flow_alice))
	Game.alice_notice.connect(func(message: String): _enqueue(_flow_alice_notice.bind(message)))
	shell = AppShell.new()
	$UI.add_child(shell)
	shell.return_to_title.connect(_return_to_title)
	shell.career_restarted.connect(_on_career_restarted)
	Game.week_passed.connect(_weekly_report)
	Game.notify.connect(hud.toast)
	Game.project_reset.connect(hud.toast)
	Game.walk_in_client.connect(_on_walk_in_client)
	Game.contract_expired.connect(_on_contract_expired)
	Game.project_completed.connect(_on_project_completed)
	production.review_requested.connect(func(job_id: String): production.close(); _enqueue(_flow_release.bind(job_id)))
	Game.job_failed.connect(_on_job_failed)
	coach = TutorialCoach.new()
	coach.main = self
	$UI.add_child(coach)
	login.open()
	if Game.resume_after_restart:
		Game.resume_after_restart = false
		login.hide()
		_on_login_completed.call_deferred(Game.save_slot)


func _enqueue(flow: Callable) -> void:
	_queue.append(flow)
	if not _queue_running and not _booting:
		_run_queue()


func _run_queue() -> void:
	_queue_running = true
	while not _queue.is_empty():
		# Reports wait until the player closes an existing modal, including Alice's desk.
		while not _queue.is_empty() and (_board_open() or (StudioCity.fire_active() and _queue.front().get_method() != "_flow_fire_notice")):
			await get_tree().process_frame
		if _queue.is_empty(): break
		var flow: Callable = _queue.pop_front()
		await flow.call()
	_queue_running = false

func _board_open() -> bool:
	return star_panel.visible or news_panel.visible or city_panel.visible or staff_panel.visible or job_board.visible or hire_board.visible or production.visible or release_panel.visible or library.visible or planner.visible or jam.visible or shell.visible


# --- scene signal handlers (connected in main.tscn) ---------------------------------

func _on_login_completed(uid: String) -> void:
	_booting = true
	Game.start(uid)
	if not Game.identity_initialized:
		shell.open("identity")
		await shell.identity_completed
	if not Game.intro_seen:
		await _flow_intro()
	_booting = false
	for event in StudioStars.data()["news"]: _enqueue(_flow_hot_news.bind(event))
	for event in StudioResilience.data()["recoveries"]: _enqueue(_flow_recovery.bind(event))
	for session in Game.all_projects():
		if session.get("creative_pending",false): _enqueue(_flow_creative_decision.bind(session["job_id"]))
	for month in Game.life.get("feedback", []): _enqueue(_flow_monthly_feedback.bind(int(month)))
	if not _queue_running and not _queue.is_empty(): _run_queue()
	hud.toast(Locale.text("legacy_138") % FirebaseAuth.display_name())

func _on_career_restarted() -> void:
	Game.resume_after_restart = true
	Game._pause_requests = 0
	Game.running = false
	get_tree().reload_current_scene()


func _on_hud_panel_requested(panel_name: String) -> void:
	if not Game.running:
		return
	if StudioCity.fire_active() and panel_name != "menu": return
	if panel_name in ["alice", "studio"] and _resume_composition(): return
	match panel_name:
		"demo_next":
			if not _board_open() and not _queue_running: _enqueue(_flow_demo_next)
		"alice":
			planner.open()
		"jobs":
			job_board.open()
		"city":
			city_panel.visit()
		"staff":
			staff_panel.open()
		"hire":
			hire_board.open()
		"studio":
			production.open()
		"library":
			library.open()
		"shop":
			_enqueue(_flow_shop)
		"floor":
			_enqueue(_flow_expand.bind(true))
		"column":
			_enqueue(_flow_expand.bind(false))
		"menu":
			shell.open()


func _on_job_board_offer_selected(job: Dictionary) -> void:
	if job.has("demo_index"):
		job_board.close()
		_enqueue(_flow_demo_brief.bind(job))
		return
	job_board.close()
	_enqueue(_flow_offer.bind(job, true, ""))


func _on_hire_board_candidate_selected(artist: Dictionary) -> void:
	hire_board.close()
	_enqueue(_flow_interview.bind(artist))


func _on_hire_board_staff_selected(artist: Dictionary) -> void:
	hire_board.close()
	_enqueue(_flow_staff.bind(artist, true))


func _on_office_worker_clicked(artist_id: String) -> void:
	if artist_id in ["producer", "alice"]:
		if _resume_composition(): return
		_enqueue(_flow_alice)
		return
	var artist = Game.get_artist(artist_id)
	if not artist.is_empty():
		_enqueue(_flow_staff.bind(artist, false))


func _on_office_room_clicked(floor_index: int, column: int, room_type: String) -> void:
	if StudioCity.fire_active(): return
	if room_type in ["studio", "meeting", "lounge"] and _resume_composition(): return
	if room_type == "empty":
		_enqueue(_flow_build_room.bind(floor_index, column))
	elif room_type in ["meeting", "lounge"]:
		planner.tab = 0
		planner.open()
	else:
		hud.toast(Locale.text("legacy_139") % [floor_index + 1, Data.ROOM_TYPES[room_type]["desc"]])


func _on_production_started() -> void:
	hud.toast(Locale.text("schedule_created") if Game.project.is_empty() and not Game.production_queue.is_empty() else Locale.text("legacy_140"))


func _on_release_panel_released(song: Dictionary) -> void:
	if song.is_empty():
		return
	MusicGen.produce(song)
	_enqueue(_flow_song_feedback.bind(song))


# --- autoload signal handlers --------------------------------------------------

func _on_walk_in_client(job: Dictionary) -> void:
	var client = Game.get_client(job["client"])
	office.spawn_visitor(client["color"], Game.client_contact(client), client)
	_enqueue(_flow_offer.bind(job, false, Locale.text("legacy_141")))


func _on_contract_expired(artist: Dictionary) -> void:
	_enqueue(_flow_contract_expired.bind(artist))


func _on_project_completed(completed: Dictionary) -> void:
	_enqueue(_flow_release.bind(str(completed["job_id"])))


func _on_job_failed(job: Dictionary) -> void:
	_enqueue(_flow_job_failed.bind(job))


# --- portraits -------------------------------------------------------------------

func _client_portrait(client: Dictionary) -> Dictionary:
	var portrait = Art.portrait_data(client)
	portrait["name"] = Game.client_contact(client)
	return portrait


func _artist_portrait(artist: Dictionary) -> Dictionary:
	var portrait = Art.portrait_data(artist)
	portrait["name"] = "%s | %s" % [artist["name"], Data.ROLE_TH[artist["role"]]]
	portrait["adviser"] = true
	return portrait


# --- flows -------------------------------------------------------------------------

## Talk with a client / employer / investor about a job offer.
func _flow_offer(job: Dictionary, from_board: bool, intro: String) -> void:
	if not Game.offers.has(job):
		return
	var client = Game.get_client(job["client"])
	dialog.open(PLAYER, _client_portrait(client))
	if intro != "":
		await dialog.say("right", intro)
	await dialog.say("right", Locale.text("legacy_142") % [job["title"], Data.money(job["pay"]), job["deadline"]])
	var done = false
	var accepted = false
	var selected_mode = "manual"
	while not done:
		var info = Locale.text("legacy_143") % [
			Game.describe_tags(job), Data.roles_text(job["roles"]), client["rel"]]
		var choice: int = await dialog.ask("right", info, [
			Locale.text("accept_choose_mode"),
			Locale.text("legacy_145"),
			Locale.text("agency_research", [Game.items.get("research", 0), Data.money(Game.research_price(job))]),
			Locale.text("legacy_147") % Game.items.get("gift", 0),
			Locale.text("legacy_148"),
			Locale.text("legacy_149"),
		])
		match choice:
			0:
				var mode = await dialog.ask("alice", Locale.text("mode_prompt"), [Locale.text("play_manual"), Locale.text("play_auto"), Locale.text("back")])
				if mode == 2: continue
				selected_mode = "manual" if mode == 0 else "auto"
				var pct = Game.accept_offer(job, selected_mode)
				accepted = true
				await dialog.say("right", Locale.text("legacy_150") % [pct, Data.money(job["upfront"])])
				await dialog.say("left", Locale.text("legacy_151"))
				done = true
			1:
				var gain = Game.chat_with_client(job)
				if gain <= 0:
					await dialog.say("right", Locale.text("legacy_152"))
				else:
					await dialog.say("left", Data.SMALL_TALK.pick_random())
					await dialog.say("right", Locale.text("legacy_153") % gain)
			2:
				await dialog.say("alice", Game.use_item("research", job))
			3:
				await dialog.say("right", Game.use_item("gift", job))
			4:
				await dialog.say("right", Locale.text("legacy_154") % job["expires"])
				done = true
			_:
				Game.decline_offer(job)
				await dialog.say("right", Locale.text("legacy_155"))
				done = true
	dialog.close()
	if accepted and selected_mode == "manual":
		_flow_manual_composition(str(job["id"]))
	elif from_board:
		job_board.open()


## Interview a candidate and sign a contract (length affects weekly fee).
func _flow_interview(artist: Dictionary) -> void:
	dialog.open(PLAYER, _artist_portrait(artist))
	await dialog.say("alice", Locale.text("alice_contract", [artist["name"]]))
	await dialog.say("right", Locale.text("legacy_156") % [
		artist["name"], Data.ROLE_TH[artist["role"]], Data.skills_text(artist["skills"], 5),
		Data.money(artist["fee_week"]), Data.money(artist["sign_fee"])])
	var negotiated = false
	while true:
		var options = []
		for weeks in [4, 8, 12]:
			var terms = Game.contract_terms(artist, weeks)
			options.append(Locale.text("legacy_157") % [weeks, Data.money(terms["fee_week"])])
		options.append(Locale.text("legacy_158") if negotiated else Locale.text("legacy_159"))
		options.append(Locale.text("legacy_160"))
		var choice: int = await dialog.ask("left", Locale.text("legacy_161") % [
			Data.money(Game.money), Game.staff.size(), Game.staff_capacity()], options)
		if choice <= 2:
			var err = Game.sign_artist(artist, [4, 8, 12][choice])
			if err != "":
				await dialog.say("right", err)
				continue
			await dialog.say("right", Locale.text("legacy_162"))
			await _offer_auto_renew(artist)
			Game.save_game()
			break
		elif choice == 3:
			if negotiated:
				continue
			negotiated = true
			var r = randf()
			if r < 0.5:
				artist["fee_week"] = int(artist["fee_week"] * 0.85)
				artist["sign_fee"] = int(artist["sign_fee"] * 0.85)
				await dialog.say("right", Locale.text("legacy_163") % Data.money(artist["fee_week"]))
			elif r < 0.85:
				await dialog.say("right", Locale.text("legacy_164"))
			else:
				await dialog.say("right", Locale.text("legacy_165"))
				Game.remove_candidate(artist)
				break
		else:
			break
	dialog.close()
	hire_board.open()


## Talk to a staff member (clicked in the office or from the hire board).
func _flow_staff(artist: Dictionary, from_board: bool) -> void:
	if not Game.staff.has(artist): return
	StudioLife.ensure_artist(artist)
	artist["met"] = true
	dialog.open(PLAYER, _artist_portrait(artist))
	await dialog.say("alice", Locale.text("alice_contract", [artist["name"]]))
	var busy = Game.is_in_project(artist["id"])
	await dialog.say("right", Locale.text("legacy_166") % [
		Locale.text("legacy_167") if busy else Locale.text("legacy_168"),
		artist["weeks_left"], Data.money(StudioCity.weekly_fee(artist)), Data.skills_text(artist["skills"], 5)])
	var choice: int = await dialog.ask("left", Locale.text("legacy_169"), [
		Locale.text("legacy_170") % Data.money(Game.renewal_cost(artist, 4)),
		Locale.text("legacy_171"),
		Locale.text("legacy_172"),
		Locale.text("legacy_173"),
		Locale.text("social_menu"),
		Locale.text("training_action"),
		Locale.text("auto_renew_toggle", [Locale.text("on" if artist["auto_renew"] else "off")]),
	])
	match choice:
		0:
			var err = Game.renew_contract(artist, 4)
			await dialog.say("right", err if err != "" else Locale.text("legacy_174"))
		1:
			await dialog.say("left", Data.MORALE_LINES.pick_random())
			await dialog.say("right", Locale.text("legacy_175"))
		2:
			var confirm = 0
			if busy:
				confirm = await dialog.ask("left", Locale.text("legacy_176"), [Locale.text("legacy_172"), Locale.text("legacy_177")])
			if confirm == 0:
				Game.release_artist(artist)
				await dialog.say("right", Locale.text("legacy_178"))
		4:
			dialog.close()
			city_panel.visit(artist["id"])
			await city_panel.closed
		5:
			var genres: Array = Data.GENRES.duplicate()
			var choices: Array = genres.duplicate()
			choices.append(Locale.text("back"))
			var genre = await dialog.ask("alice", Locale.text("training_prompt", [StudioLife.TRAIN_DAYS, Data.money(StudioLife.TRAIN_COST)]), choices)
			if genre < genres.size(): await dialog.say("alice", StudioLife.train(artist, genres[genre]))
		6:
			artist["auto_renew"] = not artist["auto_renew"]
			await dialog.say("alice", Locale.text("auto_renew_set", [Locale.text("on" if artist["auto_renew"] else "off")]))
	Game.save_game()
	dialog.close()
	if from_board:
		hire_board.open()


## Contract ran out: pay to renew, or let go (an unfinished recording restarts from zero).
func _flow_contract_expired(artist: Dictionary) -> void:
	if not Game.staff.has(artist):
		return
	StudioLife.ensure_artist(artist)
	artist["met"] = true
	dialog.open(PLAYER, _artist_portrait(artist))
	await dialog.say("alice", Locale.text("alice_contract", [artist["name"]]))
	var warn = ""
	if Game.is_in_project(artist["id"]) and not Game.artist_project(artist["id"])["done"]:
		warn = Locale.text("legacy_179")
	await dialog.say("right", Locale.text("legacy_180") % warn)
	while true:
		var choice: int = await dialog.ask("left", Locale.text("legacy_181") % Data.money(Game.money), [
			Locale.text("legacy_182") % Data.money(Game.renewal_cost(artist, 4)),
			Locale.text("legacy_183") % Data.money(Game.renewal_cost(artist, 8)),
			Locale.text("legacy_184"),
		])
		if choice <= 1:
			var err = Game.renew_contract(artist, 4 if choice == 0 else 8)
			if err != "":
				await dialog.say("right", err)
				continue
			await dialog.say("right", Locale.text("legacy_185"))
			await _offer_auto_renew(artist)
			Game.save_game()
		else:
			Game.release_artist(artist)
			await dialog.say("right", Locale.text("legacy_186"))
		break
	dialog.close()


func _flow_job_failed(job: Dictionary) -> void:
	var client = Game.get_client(job["client"])
	dialog.open(PLAYER, _client_portrait(client))
	await dialog.say("right", Locale.text("legacy_187") % [job["title"], Data.money(job["upfront"])])
	await dialog.say("left", Locale.text("legacy_188"))
	dialog.close()


func _flow_release(job_id: String = "") -> void:
	if job_id != "" and not Game.focus_project(job_id): return
	if Game.project.is_empty() or not Game.project["done"]:
		return
	release_panel.open()
	await release_panel.closed


func _flow_song_feedback(song: Dictionary) -> void:
	var client = Game.get_client(song["client"])
	dialog.open(PLAYER, _client_portrait(client))
	var rating = int(song["rating"])
	var reaction = Locale.text("legacy_189")
	if rating >= 32:
		reaction = Locale.text("legacy_190")
	elif rating >= 24:
		reaction = Locale.text("legacy_191")
	elif rating >= 16:
		reaction = Locale.text("legacy_192")
	await dialog.say("right", Locale.text("legacy_193") % [reaction, Data.money(song["payout"])])
	await dialog.say("left", Locale.text("legacy_194") % [song["title"], song["marketing"]])
	dialog.close()


func _flow_shop() -> void:
	var backdrop = TextureRect.new()
	backdrop.texture = Art.texture("res://assets/city/shop.png")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	dialog.add_child(backdrop)
	dialog.move_child(backdrop, 0)
	var dim: ColorRect = dialog.get_node("DialogDim65")
	var previous_dim = dim.color
	dim.color = Color(0, 0, 0, 0.18)
	dialog.open(PLAYER, SHOPKEEPER)
	await dialog.say("right", Locale.text("legacy_195"))
	var keys = Data.ITEMS.keys()
	keys.erase("research")
	while true:
		var options = []
		for key in keys:
			var item: Dictionary = Data.ITEMS[key]
			options.append(Locale.text("legacy_196") % [item["name"], Data.money(item["price"]), Game.items.get(key, 0), item["desc"]])
		options.append(Locale.text("legacy_197"))
		var choice: int = await dialog.ask("right", Locale.text("legacy_198") % Data.money(Game.money), options)
		if choice >= keys.size():
			break
		await dialog.say("right", Locale.text("legacy_199") if Game.buy_item(keys[choice]) else Locale.text("legacy_200"))
	dialog.close()
	dim.color = previous_dim
	backdrop.queue_free()


func _flow_build_room(floor_index: int, column: int) -> void:
	dialog.open(PLAYER, CONTRACTOR)
	var options = []
	for type in Data.BUILDABLE:
		var room: Dictionary = Data.ROOM_TYPES[type]
		options.append("%s | %s : %s" % [room["name"], Data.money(room["cost"]), room["desc"]])
	options.append(Locale.text("legacy_177"))
	var choice: int = await dialog.ask("right", Locale.text("legacy_201") % [floor_index + 1, column + 1, Data.money(Game.money)], options)
	if choice < Data.BUILDABLE.size():
		var err = Game.build_room(floor_index, column, Data.BUILDABLE[choice])
		await dialog.say("right", err if err != "" else Locale.text("legacy_202"))
	dialog.close()


func _flow_menu() -> void:
	dialog.open(PLAYER, {"name": Locale.text("legacy_203"), "color": Color("adb5bd")})
	var choice: int = await dialog.ask("right", Locale.text("legacy_204") % FirebaseAuth.display_name(), [
		Locale.text("legacy_205"),
		Locale.text("legacy_206"),
		Locale.text("legacy_207"),
		Locale.text("legacy_208"),
	])
	match choice:
		0:
			Game.save_game()
			await dialog.say("right", Locale.text("legacy_209"))
		1:
			var sure: int = await dialog.ask("right", Locale.text("legacy_210"), [Locale.text("legacy_211"), Locale.text("legacy_177")])
			if sure == 0:
				dialog.close()
				shell.open("reset")
				return
		2:
			Game.save_game()
			Game.running = false
			_queue.clear()
			FirebaseAuth.sign_out()
			dialog.close()
			login.open()
			return
	dialog.close()


## Grow the building upward (new floor) or sideways (new column on every floor).
func _flow_expand(new_floor: bool) -> void:
	dialog.open(PLAYER, CONTRACTOR)
	var cost = Data.FLOOR_COST if new_floor else Data.COLUMN_COST
	var what = Locale.text("legacy_213") if new_floor else Locale.text("legacy_214")
	var choice: int = await dialog.ask("right", Locale.text("legacy_215") % [what, Data.money(cost), Data.money(Game.money)], [Locale.text("legacy_216"), Locale.text("legacy_160")])
	if choice == 0:
		var err = Game.add_floor() if new_floor else Game.add_column()
		await dialog.say("right", err if err != "" else Locale.text("legacy_217"))
	dialog.close()

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"): return
	get_viewport().set_input_as_handled()
	if login.visible:
		login.escape()
	elif news_panel.visible:
		return
	elif star_panel.visible:
		star_panel.close()
	elif city_panel.visible:
		city_panel.close()
	elif shell.visible:
		shell.close()
	elif Game.running:
		shell.open()

func _alice_portrait() -> Dictionary:
	return Game.assistant_portrait()

func _flow_intro() -> void:
	dialog.open(PLAYER, _alice_portrait())
	for key in ["intro_1", "intro_2", "intro_3", "intro_4"]:
		await dialog.say("right", Locale.line(key, {"producer": Game.producer_name, "studio": Game.studio_name}))
	dialog.close()
	Game.intro_seen = true
	Game.save_game()

func _report_values() -> Dictionary:
	return {"producer": Game.producer_name, "studio": Game.studio_name, "money": Data.money(Game.money), "staff": Game.staff.size(), "songs": Game.songs.size(), "fame": Game.fame, "reputation": Game.reputation, "tip": Locale.text("tip_idle" if Game.project.is_empty() else "tip_work")}

func _flow_alice() -> void:
	dialog.open(PLAYER, _alice_portrait())
	await dialog.say("right", Locale.line("report", _report_values()))
	dialog.close()
	planner.open()

func _weekly_report(_week: int) -> void:
	hud.toast(Locale.line("weekly_report", _report_values()))

func _return_to_title() -> void:
	Game.save_game()
	Game.running = false
	# Recreate the scene to cancel pending dialog coroutines and modal pause ownership.
	FirebaseAuth.sign_out()
	Game._pause_requests = 0
	get_tree().reload_current_scene()


func _on_fire_started() -> void:
	_queue.push_front(_flow_fire_notice)
	if not _queue_running and not _booting: _run_queue()

func _flow_fire_notice() -> void:
	await _flow_alice_notice(Locale.text("city_fire"))

func _flow_recovery(event: Dictionary) -> void:
	if not event in StudioResilience.data()["recoveries"]: return
	dialog.open(PLAYER, _alice_portrait())
	while event in StudioResilience.data()["recoveries"]:
		var choice = await dialog.ask("alice", Locale.text("risk_recovery", [Data.money(event["payout"])]), [Locale.text("risk_rebuild"), Locale.text("risk_coordinate")])
		var result = StudioResilience.resolve(event["id"], choice)
		await dialog.say("alice", result)
	dialog.close()

func _flow_creative_decision(id: String) -> void:
	var p = CreativeJourney.session(id)
	if p.is_empty() or not p.get("creative_pending", false): return
	var job = Game.get_job(id)
	var preview_player = AudioStreamPlayer.new()
	preview_player.bus = "Composer"
	add_child(preview_player)
	dialog.open(PLAYER, _alice_portrait())
	while p.get("creative_pending", false) and not CreativeJourney.session(id).is_empty():
		var options = [Locale.text("journey_listen"),Locale.text("journey_listen_less"),Locale.text("journey_keep"),Locale.text("journey_retake")]
		if CreativeJourney.can_simplify(job): options.append(Locale.text("journey_simplify"))
		var choice = await dialog.ask("right", Locale.text("journey_prompt", [p["title"]]), options)
		preview_player.stop()
		if choice < 2:
			preview_player.stream = IdeaMusic.stream(CreativeJourney.preview_notes(job,choice == 1), int(job.get("idea_bpm",120)))
			preview_player.play()
		else:
			await dialog.say("right", CreativeJourney.resolve(id,choice-2))
	preview_player.queue_free()
	dialog.close()

func _flow_alice_notice(message: String) -> void:
	if not Game.running: return
	dialog.open(PLAYER, _alice_portrait())
	await dialog.say("right", message)
	dialog.close()

func _flow_demo_end() -> void:
	var backdrop = TextureRect.new()
	backdrop.texture = Art.texture("res://assets/story/award-hall.png")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	dialog.add_child(backdrop)
	dialog.move_child(backdrop, 0)
	dialog.open(PLAYER, _alice_portrait())
	var choice = await dialog.ask("alice", DemoCareer.summary(), [Locale.text("demo_continue"), Locale.text("demo_title")])
	PlaytestLog.ending(choice)
	if not PlaytestLog.current().is_empty():
		for key in ["explore", "next", "return"]:
			if PlaytestLog.current()["survey"].has(key): continue
			var answer = await dialog.ask("alice", Locale.text("pt_question_" + key) + "\n" + Locale.text("pt_scale"), ["1", "2", "3", "4", "5", Locale.text("pt_skip")])
			PlaytestLog.answer(key, answer + 1 if answer < 5 else 0)
	dialog.close()
	backdrop.queue_free()
	if choice == 1: _return_to_title()

func _flow_call(job: Dictionary) -> void:
	if not Game.jobs.has(job): return
	var client = Game.get_client(job["client"])
	dialog.open(PLAYER, _client_portrait(client))
	var rel = int(client.get("rel", 0))
	var outcome = Locale.text("extension_preview_free" if rel >= 70 else ("extension_preview_fee" if rel >= 35 else "extension_preview_no"))
	var choice = await dialog.ask("left", Locale.text("extension_prompt", [Game.client_contact(client), rel, outcome]), [Locale.text("extension_request"), Locale.text("back"), Locale.text("city_title")])
	if choice == 0:
		var result = Game.request_extension(job)
		Game.save_game()
		await dialog.say("right", result)
	elif choice == 2:
		dialog.close()
		city_panel.visit(job["client"], true)
		await city_panel.closed
	dialog.close()
	planner.open()


func _resume_composition() -> bool:
	if Game.idea_meeting.is_empty() or StudioCity.fire_active(): return false
	_on_meeting_changed()
	return true

func _on_meeting_changed() -> void:
	if Game.idea_meeting.is_empty(): jam.close()
	else:
		planner.close()
		production.close()
		jam.open()

func _flow_manual_composition(job_id: String) -> void:
	var job = Game.get_job(job_id)
	if not Game.needs_manual_composition(job): return
	var error = Game.begin_idea_meeting(job)
	if not error.is_empty():
		planner.tab = 0
		planner.open()
		hud.toast(error)

func _flow_demo_next() -> void:
	var step = DemoCareer.next_step()
	if step.is_empty(): return
	var job: Dictionary = step["job"]
	match step["action"]:
		"brief": await _flow_demo_brief(job)
		"compose": await _flow_manual_composition(job["id"])
		"record":
			production._setup_mode = true
			production.open()
			production.select_job(job["id"])
		"recording":
			Game.focus_project(job["id"])
			production._setup_mode = false
			production.open()
		"release": await _flow_release(job["id"])

func _flow_demo_brief(job: Dictionary) -> void:
	if not job in Game.offers: return
	dialog.open(PLAYER, _alice_portrait())
	var brief = Locale.text("flow_brief_" + job["brief_kind"]) + "\n" + Locale.text("flow_targets_" + job["brief_kind"])
	brief += "\n" + Data.money(job["pay"]) + " | " + str(job["deadline"]) + " " + Locale.text("weeks")
	var choice = await dialog.ask("alice", brief, [Locale.text("flow_manual"), Locale.text("flow_auto"), Locale.text("back")])
	dialog.close()
	if choice == 2: return
	Game.accept_offer(job, "manual" if choice == 0 else "auto")
	Game.save_game()
	if choice == 0: await _flow_manual_composition(job["id"])
	else:
		production._setup_mode = true
		production.open()
		production.select_job(job["id"])


func _offer_auto_renew(artist: Dictionary) -> void:
	if artist.get("renewal_prompted", false): return
	artist["renewal_prompted"] = true
	var choice = await dialog.ask("alice", Locale.text("auto_renew_prompt", [Data.money(Game.renewal_cost(artist, 4))]), [Locale.text("auto_renew_yes"), Locale.text("auto_renew_no")])
	artist["auto_renew"] = choice == 0

func _flow_staff_call(id: String) -> void:
	if id == "alice":
		dialog.open(PLAYER, _alice_portrait())
		var choice = await dialog.ask("right", StudioCity.alice_status(), [Locale.text("social_talk"), Locale.text("social_flirt"), Locale.text("back")])
		if choice == 0: await dialog.say("right", StudioLife.socialize("alice", "talk"))
		elif choice == 1:
			if not StudioCity.alice()["romance_unlocked"]:
				await dialog.say("right", StudioCity.alice_status())
			else:
				dialog.close()
				city_panel.visit("alice")
				await city_panel.closed
		dialog.close()
	else:
		var artist = Game.get_artist(id)
		if not artist.is_empty(): await _flow_staff(artist, false)
	staff_panel.open()

func _flow_monthly_feedback(month: int) -> void:
	if not Game.running or not Game.life.get("feedback", []).has(month): return
	var event = StudioLife.feedback(month)
	if event.is_empty(): return
	dialog.open(PLAYER, _alice_portrait())
	while Game.life["feedback"].has(month):
		var options = []
		for choice in event["choices"]:
			options.append(choice["text"] + "\n" + Locale.text("feedback_preview", [choice["fame"], choice["reputation"], Data.money(choice.get("cost", 0))]))
		var answer = await dialog.ask("right", Locale.text("monthly_feedback_title", [month]) + "\n" + event["text"], options)
		await dialog.say("right", StudioLife.resolve_feedback(month, answer))
	dialog.close()

func _flow_contest(result: Dictionary) -> void:
	city_panel.announce(result)
	await city_panel.closed

func _flow_hot_news(event: Dictionary) -> void:
	if not event in StudioStars.data()["news"]: return
	news_panel.event = event
	news_panel.message = ""
	news_panel.open()
	await news_panel.closed
