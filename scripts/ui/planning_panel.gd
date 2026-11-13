class_name PlanningPanel
extends UIPanel
signal call_requested(job: Dictionary)
signal jam_requested(job: Dictionary)
signal record_requested(job_id: String)
signal report_requested
var tab := 0
var page := 0
var playback_label: Label
var content: VBoxContainer

func open() -> void:
	var entering = not visible
	super()
	if entering and tab == 3: Audio.sfx("reward")

func close() -> void:
	Audio.stop_preview()
	super()
	Game.save_game()

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	Audio.playback_status.connect(func(message: String): if visible and is_instance_valid(playback_label): playback_label.text = message)
	Game.research_changed.connect(_refresh_if_open)
	Game.schedule_changed.connect(_refresh_if_open)
	Locale.language_changed.connect(_refresh_if_open.unbind(1))
	super()

func refresh() -> void:
	UIKit.clear(self)
	var body = UIKit.centered_window(self, 1420, 900)
	var header = HBoxContainer.new()
	body.add_child(header)
	var portrait = PortraitView.new()
	portrait.custom_minimum_size = Vector2(96, 96)
	header.add_child(portrait)
	portrait.configure(Game.assistant_portrait()["art_id"])
	var title = UIKit.label(Locale.text("alice_desk"), 34)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(UIKit.button(Locale.text("talk_alice_desk"), func(): close(); report_requested.emit()))
	header.add_child(UIKit.button(Locale.text("close"), close))
	var tabs = HBoxContainer.new()
	body.add_child(tabs)
	for i in 4:
		var b = UIKit.button(Locale.text(["timeline", "research_desk", "billing", "trophies"][i]), func():
			if i == 3 and tab != 3: Audio.sfx("reward")
			tab = i; page = 0; refresh())
		b.toggle_mode = true
		b.button_pressed = tab == i
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		tabs.add_child(b)
	content = VBoxContainer.new()
	content.size_flags_vertical = SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	body.add_child(content)
	match tab:
		0: _timeline()
		1: _research()
		2: _billing()
		3: _trophies()

func _copy(value: String, font_size: int = 30) -> void:
	var label = UIKit.label(value, font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(label)

func _pages(entries: Array, render: Callable) -> void:
	var pages = maxi(1, ceili(entries.size() / 2.0))
	page = clampi(page, 0, pages - 1)
	if entries.is_empty(): _copy(Locale.text("desk_empty"))
	for entry in entries.slice(page * 2, page * 2 + 2): render.call(entry)
	var row = HBoxContainer.new()
	content.add_child(row)
	var prev = UIKit.button("◀", func(): page -= 1; refresh())
	prev.disabled = page == 0
	row.add_child(prev)
	row.add_child(UIKit.label(Locale.text("page", [page + 1, pages]), 24))
	var next = UIKit.button("▶", func(): page += 1; refresh())
	next.disabled = page + 1 >= pages
	row.add_child(next)

func _card(title: String, detail: String, job_id: String = "") -> HBoxContainer:
	var panel = ScheduleCard.new() if job_id != "" else PanelContainer.new()
	if panel is ScheduleCard: panel.job_id = job_id
	content.add_child(panel)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(UIKit.label(title, 34))
	var label = UIKit.label(detail, 30)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(label)
	var actions = HBoxContainer.new()
	box.add_child(actions)
	return actions

func _timeline() -> void:
	_copy(Locale.text("timeline_intro", [Game.day + 1, Game.all_projects().size(), Game.count_rooms("studio")]))
	_pages(Game.jobs, func(job: Dictionary):
		var session: Dictionary = {}
		for p in Game.all_projects():
			if p["job_id"] == job["id"]: session = p
		var status = Locale.text("planned_day", [int(job.get("planned_day", Game.day)) + 1])
		if not session.is_empty(): status = Locale.text("room_progress", [int(session.get("room", 0)) + 1, int(session["progress"])])
		var booking = Game.scheduled_job(str(job["id"]))
		if not booking.is_empty(): status = Locale.text("scheduled_status", [int(booking["start_day"])+1, int(booking["end_day"])+1, int(booking["room"])+1])
		var actions = _card(job["title"], Locale.text("timeline_job", [Game.job_days_left(job), status, Data.money(job["pay"])]),str(job["id"]))
		if session.is_empty():
			var resuming = str(Game.idea_meeting.get("job_id", "")) == str(job["id"])
			var jam = UIKit.button(Locale.text("composer_resume" if resuming else "play_manual"), func(): close(); jam_requested.emit(job))
			jam.name = "Jam_" + job["id"]
			jam.disabled = not resuming and int(job.get("idea_rounds",0)) > 0
			actions.add_child(jam)
			if booking.is_empty(): actions.add_child(UIKit.button(Locale.text("studio"), func(): close(); record_requested.emit(str(job["id"]))))
			else: actions.add_child(UIKit.button(Locale.text("schedule_cancel"), func(): Game.cancel_scheduled(job["id"]); Game.save_game(); refresh()))
		# Fourteen equal day cells visualize planned work against the actual deadline.
		var days = HBoxContainer.new()
		actions.get_parent().add_child(days)
		var start_day = int(booking.get("start_day",job.get("planned_day",Game.day)))
		var end_day = int(booking.get("end_day",start_day+1))
		if not session.is_empty():
			start_day = int(session.get("started_day",Game.day))
			end_day = Game.day + maxi(1,ceili((100-float(session["progress"])) / maxf(1,Game.daily_progress(Game._team_for(session["team"]),session["mix"]))))
		for d in 14:
			var cell = ScheduleDay.new()
			cell.job_id = job["id"]
			cell.start_day = Game.day+d
			cell.text = str(Game.day + d + 1)
			cell.custom_minimum_size = Vector2(0,46)
			cell.disabled = not session.is_empty()
			cell.add_theme_font_override("font", UIKit.readable_font())
			cell.add_theme_font_size_override("font_size",36)
			cell.moved.connect(_move_plan)
			cell.pressed.connect(func(): _move_plan(job["id"],cell.start_day))
			cell.size_flags_horizontal = SIZE_EXPAND_FILL
			cell.modulate = Color("ff927a") if d >= Game.job_days_left(job) else (Color("ffd16c") if Game.day+d == start_day else (Color("87e0bb") if Game.day+d > start_day and Game.day+d < end_day else Color("76849b")))
			days.add_child(cell)
		if session.is_empty():
			var plan_row = HBoxContainer.new()
			actions.get_parent().add_child(plan_row)
			for delay in [0, 1, 3, 7]:
				var plan = UIKit.button(Locale.text("plan_delay", [delay]), func(): _move_plan(job["id"],Game.day+delay))
				plan.name = "PlanDelay%d" % delay
				plan_row.add_child(plan)
		var phone = UIKit.button(Locale.text("call_client"), func(): close(); call_requested.emit(job))
		phone.disabled = job.get("extension_requested", false)
		actions.add_child(phone)
	)

func _research() -> void:
	_copy(Locale.text("research_intro"))
	for task in Game.research_tasks:
		_copy(Locale.text("research_eta", [task["brief"]["title"], maxi(0, int(task["finish_day"]) - Game.day)]))
	var entries = Game.jobs.duplicate()
	entries.append_array(Game.offers)
	_pages(entries, func(job: Dictionary):
		var hint = Locale.text("hint_unknown") if not job.has("research_hint") else Locale.text("hint_60", [job["research_hint"]])
		var actions = _card(job["title"], hint + " | " + Locale.text("idea_points", [job.get("idea", 0)]))
		actions.add_child(UIKit.button(Locale.text("research_action"), func(): _result(Game.start_research(job))))
		for key in ["energy", "pizza", "coffee"]:
			var item_key: String = key
			var b = UIKit.button("%s  x%d" % [Data.ITEMS[key]["name"], Game.items.get(key, 0)], func(): _result(Game.use_item(item_key, job)))
			b.disabled = int(Game.items.get(key, 0)) <= 0
			b.add_theme_font_size_override("font_size", 32)
			actions.add_child(b)
	)

func _result(message: String) -> void:
	refresh()
	_copy(message, 22)

func _billing() -> void:
	_copy(Locale.text("billing_intro"))
	var bills = Game.invoices.duplicate()
	bills.reverse()
	_pages(bills, func(invoice: Dictionary):
		_card(invoice["title"], "%s | %s | %s" % [Data.money(invoice["amount"]), invoice["client"], Locale.text("invoice_received") if invoice["paid"] else Locale.text("invoice_due", [int(invoice["due_day"]) + 1])])
	)

func _trophies() -> void:
	playback_label = UIKit.label("", 30)
	content.add_child(playback_label)
	_copy(Locale.text("contest_intro", [Game.contest_edition, 28 - Game.day % 28, mini(36, 26 + Game.contest_edition)]))
	var collection = Game.trophies.duplicate()
	collection.reverse()
	_pages(collection, func(trophy: Dictionary):
		var award_title = "BEST TRACK #%d | 1st" % trophy["edition"]
		if trophy.has("story_quest"):
			award_title = "Quest | " + StoryQuests.text(StoryQuests.definition(trophy["story_quest"])["title"])
		var actions = _card(award_title, "%s | %d/40" % [trophy["song"], trophy["rating"]])
		actions.add_child(TrophyBadge.new())
		var song: Dictionary = {}
		for candidate in Game.songs:
			if candidate["id"] == trophy.get("song_id", "") or (not trophy.has("song_id") and candidate["title"] == trophy["song"]): song = candidate; break
		var play = UIKit.button(Locale.text("trophy_cloud_play"), func(): Audio.play_song(song, true))
		play.name = "TrophyCloudPlay"
		play.disabled = str(song.get("audio_url", "")).is_empty()
		play.tooltip_text = Locale.text("cloud_missing") if play.disabled else str(song.get("title", ""))
		actions.add_child(play)
		actions.add_child(UIKit.button(Locale.text("stop_music"), Audio.stop_preview))
		if play.disabled: actions.get_parent().add_child(UIKit.label(Locale.text("cloud_missing"), 28))
	)


func _move_plan(job_id: String, start: int) -> void:
	var error = Game.move_scheduled(job_id,start)
	refresh()
	if not error.is_empty(): _copy(error,26)
