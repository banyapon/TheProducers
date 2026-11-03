extends UIPanel
## Studio screen (Game Dev Story style): pick an accepted job, blend up to 3 genre tags,
## choose the band. The team then walks to the studio and earns points every day.

signal production_started
signal review_requested(job_id: String)

@onready var setup_box: Control = %SetupBox
@onready var status_box: Control = %StatusBox
@onready var job_option: OptionButton = %JobOption
@onready var job_info: Label = %JobInfo
@onready var title_edit: LineEdit = %TitleEdit
@onready var tag_options: Array = [%Tag1, %Tag2, %Tag3]
@onready var sliders: Array = [%Pct1, %Pct2, %Pct3]
@onready var pct_labels: Array = [%PctLabel1, %PctLabel2, %PctLabel3]
@onready var mix_preview: Label = %MixPreview
@onready var team_grid: GridContainer = %TeamGrid
@onready var team_info: Label = %TeamInfo
@onready var error_label: Label = %ErrorLabel
@onready var status_label: Label = %StatusLabel
@onready var status_bar: ProgressBar = %StatusBar

var _job_ids: Array = []
var _team_page = 0
var _selected: Dictionary = {}
var room_option: OptionButton
var session_tabs: HBoxContainer
var _setup_mode := false
var _checks = {}  ## artist_id -> CheckBox


func _ready() -> void:
	super()
	for option: OptionButton in tag_options:
		option.add_item(Locale.text("legacy_269"))
		for genre in Data.GENRES:
			option.add_item(genre)
	Game.project_progress.connect(_on_project_progress)
	_compact_layout()
	room_option = OptionButton.new()
	job_info.get_parent().add_child(room_option)
	job_info.get_parent().move_child(room_option,2)
	session_tabs = HBoxContainer.new()
	setup_box.get_parent().get_parent().add_child(session_tabs)
	setup_box.get_parent().get_parent().move_child(session_tabs, 1)
	Locale.language_changed.connect(_refresh_if_open.unbind(1))


func refresh() -> void:
	error_label.text = ""
	room_option.clear()
	room_option.add_item(Locale.text("room_auto"))
	for i in Game.count_rooms("studio"): room_option.add_item(Locale.text("room_number",[i+1]))
	UIKit.clear(session_tabs)
	for session in Game.all_projects():
		var session_id = str(session["job_id"])
		var session_button = UIKit.button(Locale.text("room_session", [int(session.get("room", 0)) + 1, session["title"]]), func(): Game.focus_project(session_id); _setup_mode = false; refresh())
		session_button.clip_text = true
		session_button.size_flags_horizontal = SIZE_EXPAND_FILL
		session_tabs.add_child(session_button)
	if Game.count_rooms("studio") > 0:
		session_tabs.add_child(UIKit.button(Locale.text("new_session"), func(): _setup_mode = true; refresh()))
	var busy = not Game.project.is_empty() and not _setup_mode
	setup_box.get_parent().visible = not busy
	status_box.visible = busy
	if busy:
		_refresh_status()
		return
	job_option.clear()
	_job_ids.clear()
	for job in Game.jobs:
		if job["status"] == "active" and not _job_recording(job["id"]):
			job_option.add_item(Locale.text("legacy_270") % [job["title"], job["client"], ceili(Game.job_days_left(job) / 7.0)])
			_job_ids.append(job["id"])
	job_option.disabled = _job_ids.is_empty()
	if _job_ids.is_empty():
		job_option.add_item(Locale.text("legacy_271"))
	title_edit.text = Data.random_song_title()
	_selected.clear()
	_team_page = 0
	_build_team()
	_on_job_selected(0)


func _current_job() -> Dictionary:
	var index = job_option.selected
	if index < 0 or index >= _job_ids.size():
		return {}
	return Game.get_job(_job_ids[index])


func _on_job_selected(_index: int) -> void:
	var job = _current_job()
	if job.is_empty():
		job_info.text = ""
		_on_mix_changed()
		return
	var client = Game.get_client(job["client"])
	job_info.text = Locale.text("legacy_272") % [
		job["client"], client["type"], client["rel"], Game.describe_tags(job), Data.roles_text(job["roles"]),
		Data.money(int(job["pay"]) - int(job["upfront"]))]
	if job.has("research_hint"):
		job_info.text += "\n" + Locale.text("hint_60", [job["research_hint"]])
	var known = Game.revealed_tags(job)
	for i in 3:
		var option: OptionButton = tag_options[i]
		var slider: HSlider = sliders[i]
		if i < known.size():
			option.select(Data.GENRES.find(known[i]) + 1)
			slider.value = job["mix"][known[i]]
		else:
			option.select(0)
			slider.value = 0
	_on_mix_changed()
	var start_button = find_child("StartBtn",true,false)
	start_button.text = Locale.text("schedule_submit") if int(job.get("planned_day",Game.day)) > Game.day else Locale.text("record_now")
	_build_team()


## Normalized {tag: percent} from the three tag pickers and sliders.
func current_mix() -> Dictionary:
	var raw = {}
	var total = 0.0
	for i in 3:
		var index: int = (tag_options[i] as OptionButton).selected
		var value: float = (sliders[i] as HSlider).value
		if index <= 0 or value <= 0.0:
			continue
		var tag: String = Data.GENRES[index - 1]
		raw[tag] = raw.get(tag, 0.0) + value
		total += value
	var mix = {}
	for tag in raw:
		mix[tag] = int(round(raw[tag] / total * 100.0))
	return mix


func _on_mix_changed(_value: Variant = null) -> void:
	for i in 3:
		var on: bool = (tag_options[i] as OptionButton).selected > 0
		(sliders[i] as HSlider).editable = on
		(pct_labels[i] as Label).text = "%d" % (sliders[i] as HSlider).value if on else "-"
	var mix = current_mix()
	mix_preview.text = Locale.text("legacy_273") % (Data.mix_text(mix) if not mix.is_empty() else Locale.text("legacy_274"))
	_update_team_info()


func _build_team() -> void:
	clear(team_grid)
	_checks.clear()
	var pages = maxi(1, ceili(Game.staff.size() / 4.0))
	_team_page = clampi(_team_page, 0, pages - 1)
	for a in Game.staff.slice(_team_page * 4, _team_page * 4 + 4):
		var row = VBoxContainer.new()
		row.custom_minimum_size.x = 290
		team_grid.add_child(row)
		var portrait = PortraitView.new()
		portrait.custom_minimum_size = Vector2(64, 64)
		row.add_child(portrait)
		portrait.configure(Art.model_id(a))
		var cb = CheckBox.new()
		cb.text = "%s\n%s | XP %d" % [a["name"], Data.ROLE_TH[a["role"]], int(a.get("experience", 0))]
		cb.add_theme_font_size_override("font_size", 32)
		var future = int(_current_job().get("planned_day",Game.day)) > Game.day
		cb.disabled = (Game.is_in_project(a["id"]) or Game.is_researching(a["id"]) or not StudioLife.training(a["id"]).is_empty() or StudioStage.performing(a["id"])) and not future
		if cb.disabled: cb.text += " | " + Locale.text("busy")
		cb.button_pressed = _selected.get(a["id"], false)
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cb.toggled.connect(func(on: bool): _selected[a["id"]] = on; _update_team_info())
		row.add_child(cb)
		_checks[a["id"]] = cb
	var prev = UIKit.button("<", func(): _team_page -= 1; _build_team())
	prev.disabled = _team_page == 0
	team_grid.add_child(prev)
	var next = UIKit.button(Locale.text("page", [_team_page + 1, pages]) + " >", func(): _team_page += 1; _build_team())
	next.disabled = _team_page + 1 >= pages
	team_grid.add_child(next)

func selected_team_ids() -> Array:
	var ids: Array = []
	for artist in Game.staff:
		if _selected.get(artist["id"], false): ids.append(artist["id"])
	return ids


func _on_team_toggled(_on: bool) -> void:
	_update_team_info()


func _update_team_info() -> void:
	var job = _current_job()
	var team = []
	for id in selected_team_ids():
		team.append(Game.get_artist(id))
	var lines = PackedStringArray()
	if not job.is_empty():
		var have = {}
		for a in team:
			have[a["role"]] = true
		var missing = PackedStringArray()
		for role in job["roles"]:
			if not have.has(role):
				missing.append(Data.ROLE_TH[role])
		lines.append(Locale.text("legacy_276") % (", ".join(missing) if not missing.is_empty() else Locale.text("legacy_277")))
	var best = PackedStringArray()
	for tag in Data.sorted_tags(current_mix()):
		var b = 0
		for a in team:
			b = maxi(b, int(a["skills"].get(tag, 0)))
		best.append("%s %d%%" % [tag, b])
	if not best.is_empty():
		lines.append(Locale.text("legacy_278") % " | ".join(best))
	var payroll = 0
	for a in team:
		payroll += StudioCity.weekly_fee(a)
	lines.append(Locale.text("legacy_279") % [team.size(), Data.money(payroll)])
	var warn = false
	if not team.is_empty():
		var days = Game.estimate_days(team, current_mix())
		var line = Locale.text("legacy_280") % days
		if not job.is_empty():
			var days_left = Game.job_days_left(job)
			line += Locale.text("legacy_281") % days_left
			if days > days_left:
				line += Locale.text("legacy_282")
				warn = true
		lines.append(line)
		var expiring = PackedStringArray()
		for a in team:
			if int(a["weeks_left"]) * 7 - Game.day % 7 < days:
				expiring.append(a["name"])
		if not expiring.is_empty():
			lines.append(Locale.text("legacy_283") % ", ".join(expiring))
			warn = true
		var bond = StudioStage.team_summary(selected_team_ids())
		if bond != "": lines.append(bond)
		var ban = StudioStage.ban_reason(selected_team_ids())
		if ban != "":
			lines.append(ban)
			warn = true
	team_info.text = "\n".join(lines)
	team_info.modulate = Color(1, 0.75, 0.6) if warn else Color.WHITE


func _on_random_title_pressed() -> void:
	title_edit.text = Data.random_song_title()


func _on_start_pressed() -> void:
	var job = _current_job()
	if job.is_empty():
		error_label.text = Locale.text("legacy_284")
		return
	if Game.needs_manual_composition(job):
		var meeting_error = Game.begin_idea_meeting(job)
		if meeting_error != "": error_label.text = meeting_error
		return
	var title = title_edit.text.strip_edges()
	if title == "":
		title = Data.random_song_title()
	var start = int(job.get("planned_day",Game.day))
	var err = Game.schedule_project(job["id"],selected_team_ids(),current_mix(),title,start,room_option.selected-1) if start > Game.day else Game.start_project(job["id"], selected_team_ids(), current_mix(), title,room_option.selected-1)
	if err != "":
		error_label.text = err
		return
	_setup_mode = false
	close()
	production_started.emit()


func _on_project_progress(_progress: float) -> void:
	if visible and status_box.visible:
		_refresh_status()


func _refresh_status() -> void:
	_status_portraits()
	var p = Game.project
	var job = Game.get_job(p["job_id"])
	var names = PackedStringArray()
	for a in Game.get_team():
		names.append(a["name"])
	var points = PackedStringArray()
	for cat in Data.POINT_CATS:
		points.append("%s %d" % [Data.POINT_TH[cat], p["points"][cat]])
	status_label.text = Locale.text("legacy_285") % [
		p["title"], job.get("title", "-"), job.get("client", "-"), Data.mix_text(p["mix"]), ", ".join(names), " | ".join(points)]
	if p["done"]:
		status_label.text += Locale.text("legacy_286")
	status_bar.value = p["progress"]
	if not status_box.has_node("ReviewSession"):
		var review = UIKit.button(Locale.text("review_session"), func(): review_requested.emit(str(Game.project["job_id"])))
		review.name = "ReviewSession"
		status_box.add_child(review)
	status_box.get_node("ReviewSession").visible = p["done"]

func _compact_layout() -> void:
	job_option.fit_to_longest_item = false
	job_option.custom_minimum_size.x = 400
	job_option.clip_text = true
	# Two columns make the complete setup visible without nested scrolling.
	var setup_scroll = setup_box.get_parent() as ScrollContainer
	setup_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var layout = HBoxContainer.new()
	layout.add_theme_constant_override("separation", 28)
	setup_box.add_child(layout)
	var left = VBoxContainer.new()
	left.custom_minimum_size.x = 650
	left.size_flags_horizontal = SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	layout.add_child(left)
	var right = VBoxContainer.new()
	right.custom_minimum_size.x = 650
	right.size_flags_horizontal = SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	layout.add_child(right)
	for node_name in ["JobRow", "JobInfo", "TitleRow", "MixLabel", "MixRow1", "MixRow2", "MixRow3", "MixPreview"]:
		setup_box.get_node(node_name).reparent(left)
	for node_name in ["TeamLabel", "TeamScroll", "TeamInfo"]:
		setup_box.get_node(node_name).reparent(right)
	var team_scroll = team_grid.get_parent() as ScrollContainer
	team_scroll.custom_minimum_size.y = 420
	team_scroll.size_flags_vertical = SIZE_SHRINK_BEGIN
	team_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	team_grid.columns = 2
	# Four portraits on each setup page leave room for the overview and start button.
	setup_box.move_child(layout, 0)
	var portraits = GridContainer.new()
	portraits.columns = 12
	portraits.name = "TeamPortraits"
	status_box.add_child(portraits)

func _status_portraits() -> void:
	var row = status_box.get_node("TeamPortraits")
	clear(row)
	for artist in Game.get_team():
		var portrait = PortraitView.new()
		portrait.custom_minimum_size = Vector2(72, 72)
		row.add_child(portrait)
		portrait.configure(Art.model_id(artist))


func _job_recording(id: String) -> bool:
	if not Game.scheduled_job(id).is_empty(): return true
	for session in Game.all_projects():
		if session["job_id"] == id: return true
	return false


func select_job(id: String) -> void:
	var index = _job_ids.find(id)
	if index >= 0:
		job_option.select(index)
		_on_job_selected(index)
