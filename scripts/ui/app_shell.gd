class_name AppShell
extends Control
signal identity_completed
signal return_to_title
signal career_restarted
var _reset_busy := false
var _reset_status := ""
var page = "pause"
var _metric = "fame"
var _producer = ""
var _studio = ""
var _character = "producer"
var _online_entries: Array = []
var _ranking_status := ""
var _ranking_busy := false
var _ranking_page := 0
var _ranking_request := 0

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	hide()
	Locale.language_changed.connect(func(_lang: String):
		if visible: _render())

func open(mode: String = "pause") -> void:
	if mode == "identity" and page != "identity":
		_character = "producer"
		_producer = ""
		_studio = ""
	page = mode
	if not visible:
		show()
		Game.push_pause()
	_render()

func close() -> void:
	if _reset_busy: return
	if not visible or page == "identity": return
	if page in ["credits", "ranking", "reset"]:
		_ranking_request += 1
		_ranking_busy = false
		page = "pause"
		_render()
		return
	hide()
	Game.pop_pause()

func _render() -> void:
	UIKit.clear(self)
	var body = UIKit.centered_window(self, 1280, 850 if page == "credits" else 990)
	var head = HBoxContainer.new()
	body.add_child(head)
	var heading = UIKit.label(Locale.text("credits_title" if page == "credits" else ("profile_title" if page == "identity" else "pause")), 38)
	heading.size_flags_horizontal = SIZE_EXPAND_FILL
	head.add_child(heading)
	head.add_child(UIKit.button("EN / TH", func(): Locale.set_language("en" if Locale.language == "th" else "th")))
	if page == "reset":
		heading.text = Locale.text("reset_title")
		var explanation = UIKit.label(Locale.text("reset_prompt"), 30)
		explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(explanation)
		var status = UIKit.label(Locale.text(_reset_status), 28)
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(status)
		for option in [false, true]:
			var action = UIKit.button(Locale.text("reset_delete" if option else "reset_keep"), _restart.bind(option))
			action.theme_type_variation = "CancelButton" if option else "ConfirmButton"
			action.disabled = _reset_busy
			body.add_child(action)
		var cancel = UIKit.button(Locale.text("back"), close)
		cancel.disabled = _reset_busy
		body.add_child(cancel)
		return
	if page == "ranking":
		heading.text = Locale.text("ranking_online")
		_render_ranking(body)
		return
	if page == "credits":
		CreditsPage.populate(body, func(): page = "pause"; _render())
		return
	if page == "identity":
		var actor = PortraitView.new()
		actor.custom_minimum_size = Vector2(192, 192)
		body.add_child(actor)
		actor.configure(_character)
		var roles = HBoxContainer.new()
		body.add_child(roles)
		for role in ["producer", "alice"]:
			var choice = UIKit.button(role.capitalize(), func(): _character = role; _producer = role.capitalize(); _render(), 260)
			choice.name = "Choose" + role.capitalize()
			choice.size_flags_horizontal = SIZE_EXPAND_FILL
			choice.toggle_mode = true
			choice.button_pressed = role == _character
			roles.add_child(choice)
		body.add_child(UIKit.label(Locale.text("play_as_hint_" + _character), 26))
		body.add_child(UIKit.label("ชื่อตัวละคร" if Locale.language == "th" else "Character name"))
		var producer = LineEdit.new()
		producer.max_length = 24
		producer.text = _producer
		producer.placeholder_text = _character.capitalize()
		producer.text_changed.connect(func(value: String): _producer = value)
		body.add_child(producer)
		body.add_child(UIKit.label(Locale.text("studio_name")))
		var studio = LineEdit.new()
		studio.max_length = 24
		studio.text = _studio
		studio.placeholder_text = "New Sound Studio"
		studio.text_changed.connect(func(value: String): _studio = value)
		body.add_child(studio)
		body.add_child(UIKit.label(Locale.text("name_hint"), 24))
		var begin = UIKit.button(Locale.text("begin"), func():
			if Game.set_identity(producer.text, studio.text, _character):
				hide()
				Game.pop_pause()
				identity_completed.emit())
		begin.disabled = _producer.strip_edges().length() < 2 or _studio.strip_edges().length() < 2
		producer.text_changed.connect(func(_value: String): begin.disabled = producer.text.strip_edges().length() < 2 or studio.text.strip_edges().length() < 2)
		studio.text_changed.connect(func(_value: String): begin.disabled = producer.text.strip_edges().length() < 2 or studio.text.strip_edges().length() < 2)
		body.add_child(begin)
		producer.grab_focus()
		return
	body.add_child(UIKit.label(Game.studio_name + " | " + Game.producer_name, 32))
	body.add_child(UIKit.label(Locale.text("ranking_hint"), 22))
	var metrics = HBoxContainer.new()
	body.add_child(metrics)
	for metric in ["fame", "reputation"]:
		metrics.add_child(UIKit.button(Locale.text(metric), func(): _metric = metric; _render(), 350))
	var entries = Game.rankings(_metric)
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var row = UIKit.label("%d   %s%s     %s: %d" % [i + 1, "▶ " if entry.get("ours", false) else "", entry["name"], Locale.text(_metric), entry[_metric]], 28)
		if entry.get("ours", false): row.modulate = Color("ffd166")
		body.add_child(row)
	var actions = HBoxContainer.new()
	body.add_child(actions)
	actions.add_child(UIKit.button(Locale.text("resume") + " (ESC)", close, 340))
	actions.add_child(UIKit.button(Locale.text("save"), func(): Game.save_game(), 250))
	actions.add_child(UIKit.button(Locale.text("ranking_online"), func(): page = "ranking"; _load_ranking()))
	var full = CheckBox.new()
	full.text = Locale.text("fullscreen")
	full.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	full.toggled.connect(func(on: bool): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED))
	body.add_child(full)
	AudioOptions.add_controls(body)
	RelationshipOptions.add_controls(body)
	var extras = HBoxContainer.new()
	body.add_child(extras)
	var tutorial = UIKit.button(Locale.text("tutorial_replay"), func(): Game.tutorial_step = 0; Game.tutorial_start_songs = Game.songs.size(); Game.save_game(); close())
	tutorial.size_flags_horizontal = SIZE_EXPAND_FILL
	extras.add_child(tutorial)
	var credits = UIKit.button(Locale.text("credits_title"), func(): page = "credits"; _render())
	credits.name = "OpenCredits"
	credits.size_flags_horizontal = SIZE_EXPAND_FILL
	extras.add_child(credits)
	var reset = UIKit.button(Locale.text("reset_title"), func(): page = "reset"; _reset_status = ""; _render())
	reset.name = "RestartCareer"
	extras.add_child(reset)
	body.add_child(UIKit.button(Locale.text("signout"), func(): close(); return_to_title.emit()))
	body.add_child(UIKit.button(Locale.text("quit"), Audio.quit_game))

func _restart(delete_remote: bool) -> void:
	if _reset_busy: return
	_reset_busy = true
	_reset_status = "reset_working"
	_render()
	var error = await CareerReset.restart(delete_remote)
	_reset_busy = false
	if not error.is_empty():
		_reset_status = error
		_render()
		return
	page = "pause"
	close()
	career_restarted.emit()

func _load_ranking() -> void:
	_ranking_request += 1
	var request = _ranking_request
	_ranking_busy = true
	_ranking_status = "ranking_loading"
	_online_entries.clear()
	_ranking_page = 0
	_render()
	var result = await StudioRankings.fetch(self, _metric)
	if request != _ranking_request or page != "ranking": return
	_ranking_busy = false
	_online_entries = result.get("entries", [])
	_ranking_status = result.get("error", "ranking_empty" if _online_entries.is_empty() else "ranking_source")
	_render()

func _publish_ranking() -> void:
	_ranking_busy = true
	_ranking_status = "ranking_loading"
	_render()
	var status = await StudioRankings.publish(self)
	if page != "ranking": return
	_ranking_busy = false
	_ranking_status = status
	if status == "ranking_published": _load_ranking()
	else: _render()

func _render_ranking(body: VBoxContainer) -> void:
	var note = UIKit.label(Locale.text("ranking_privacy"))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(note)
	var controls = HBoxContainer.new()
	body.add_child(controls)
	for metric in ["fame", "reputation"]:
		var button = UIKit.button(Locale.text(metric), func(): _metric = metric; _load_ranking(), 250)
		button.disabled = _ranking_busy
		controls.add_child(button)
	var refresh_button = UIKit.button(Locale.text("ranking_refresh"), _load_ranking)
	refresh_button.disabled = _ranking_busy
	controls.add_child(refresh_button)
	var publish_button = UIKit.button(Locale.text("ranking_publish"), _publish_ranking)
	publish_button.disabled = _ranking_busy or not FirebaseAuth.is_signed_in() or FirebaseAuth.is_anonymous
	controls.add_child(publish_button)
	var status = UIKit.label(Locale.text(_ranking_status))
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(status)
	for i in range(_ranking_page * 10, mini(_online_entries.size(), _ranking_page * 10 + 10)):
		var entry: Dictionary = _online_entries[i]
		var line = UIKit.label("%d. %s   %s: %d" % [i + 1, entry.name, Locale.text(_metric), entry[_metric]])
		line.clip_text = true
		line.custom_minimum_size.y = 40
		if entry.ours: line.modulate = Color("ffd166")
		body.add_child(line)
	var pages = maxi(1, ceili(_online_entries.size() / 10.0))
	var pager = HBoxContainer.new()
	body.add_child(pager)
	var prev = UIKit.button("<<", func(): _ranking_page -= 1; _render())
	prev.disabled = _ranking_page == 0
	pager.add_child(prev)
	pager.add_child(UIKit.label(Locale.text("page", [_ranking_page + 1, pages])))
	var next = UIKit.button(">>", func(): _ranking_page += 1; _render())
	next.disabled = _ranking_page + 1 >= pages
	pager.add_child(next)
	body.add_child(UIKit.button(Locale.text("back"), close))
