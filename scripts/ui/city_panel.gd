class_name CityPanel
extends UIPanel

var location := "city"
var contact := ""
var is_client := false
var message := ""
var ceremony: Dictionary = {}
var show_song := ""
var show_team: Dictionary = {}
var choosing_companion := true
var social_action := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	Locale.relationship_mode_changed.connect(_refresh_if_open)
	Locale.language_changed.connect(_refresh_if_open.unbind(1))
	super()

func visit(id: String = "", client: bool = false) -> void:
	contact = id
	is_client = client
	message = ""
	ceremony = {}
	social_action = ""
	location = "city"
	choosing_companion = true
	open()

func announce(result: Dictionary) -> void:
	ceremony = result
	choosing_companion = false
	location = "hall"
	message = Locale.text("city_winner" if result["win"] else "city_runner_up", [result["song"], result["rating"]])
	if not result["win"]: message = str(result.get("winner", "Rival")) + " — " + message
	open()

func refresh() -> void:
	StudioCity.migrate()
	UIKit.clear(self)
	var body = UIKit.centered_window(self, 1500, 960)
	var header = HBoxContainer.new()
	body.add_child(header)
	var title = UIKit.label(Locale.text("city_title"), 40)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(UIKit.button(Locale.text("close"), close))
	header.add_child(UIKit.button("Marketing Agency", func(): location = "agency"; refresh()))
	header.add_child(UIKit.button(Locale.text("risk_title"), func(): location = "risk"; refresh()))
	if location == "risk":
		var info = UIKit.label(Locale.text("risk_help", [maxi(0,int(StudioResilience.data()["insurance_until"]) - Game.day), maxi(0,int(StudioResilience.data()["inspection_until"]) - Game.day)]), 34)
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(info)
		for kind in ["insurance", "inspection"]:
			body.add_child(UIKit.button(Locale.text("risk_" + kind), func(): message = StudioResilience.purchase(kind); refresh()))
		body.add_child(UIKit.label(message, 30))
		body.add_child(UIKit.button(Locale.text("back"), func(): location = "city"; refresh()))
		return
	if location == "agency":
		var art = TextureRect.new()
		art.texture = Art.texture("res://assets/city/agency.png")
		art.custom_minimum_size = Vector2(860, 484)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		body.add_child(art)
		body.add_child(UIKit.label(Locale.text("agency_help"), 30))
		body.add_child(UIKit.label(Locale.text("agency_stock", [Game.items.get("research", 0)]), 30))
		body.add_child(UIKit.button("Package Consult | $800", func():
			message = Locale.text("legacy_199" if Game.buy_item("research") else "legacy_200")
			Game.save_game()
			refresh()))
		body.add_child(UIKit.label(message, 30))
		body.add_child(UIKit.button(Locale.text("back"), func(): location = "city"; refresh()))
		return
	if ceremony.is_empty():
		if not RelationshipOptions.allows_city_companion(StudioCity.person_for(contact, is_client)):
			contact = ""
			is_client = false
			choosing_companion = true
		if choosing_companion:
			_companion_picker(body)
			return
		header.add_child(UIKit.button(Locale.text("city_change_companion"), func(): choosing_companion = true; refresh()))
	var nav = HBoxContainer.new()
	body.add_child(nav)
	for place in ["city", "park", "restaurant", "hall"]:
		nav.add_child(UIKit.button(Locale.text("city_" + place), func(): location = place; ceremony = {}; refresh()))
	var row = HBoxContainer.new()
	row.size_flags_vertical = SIZE_EXPAND_FILL
	body.add_child(row)
	var scene = TextureRect.new()
	scene.name = "CityBackdrop"
	scene.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scene.texture = Art.texture("res://assets/story/award-hall.png" if ceremony.get("win", false) else "res://assets/city/" + location + ".png")
	scene.custom_minimum_size = Vector2(860, 484)
	scene.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scene.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	scene.size_flags_vertical = SIZE_SHRINK_CENTER
	row.add_child(scene)
	if location == "hall" and not ceremony.get("win", false):
		var host = TextureRect.new()
		host.name = "Announcer"
		var atlas = AtlasTexture.new()
		atlas.atlas = Art.texture("res://assets/city/announcer-6x4.png")
		atlas.region = Rect2(0, 144, 32, 48)
		host.texture = atlas
		host.position = Vector2(418, 246)
		host.size = Vector2(57, 86)
		host.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		scene.add_child(host)
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(scroll)
	var info = VBoxContainer.new()
	info.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(info)
	if location == "hall": _hall(info)
	else:
		_social(info)
	if ceremony.is_empty(): _stage_people(scene)
	var feedback = UIKit.label(message, 30)
	feedback.name = "CityFeedback"
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(feedback)

func _social(box: VBoxContainer) -> void:
	var person = StudioCity.person_for(contact, is_client)
	if person.is_empty(): return
	box.add_child(UIKit.label(Game.client_contact(person) if is_client else str(person["name"]), 32))
	var s: Dictionary = person["social"]
	var portrait = PortraitView.new()
	portrait.name = "CityCompanionPortrait"
	portrait.custom_minimum_size = Vector2(110, 110)
	box.add_child(portrait)
	portrait.configure(Art.model_id(person))
	portrait.custom_minimum_size = Vector2(150, 170)
	portrait.use_fullbody(true, true)
	portrait.talking = social_action != "" and social_action != "walk"
	var status = UIKit.label(Locale.text("social_prompt", [s["trust"], s["comfort"], s["attraction"]]), 30)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status)
	var hint = Locale.text("city_partner_status") if s["partner"] == "producer" else StudioCity.date_reason(person, is_client)
	if hint == "": hint = Locale.text("city_ready")
	var note = UIKit.label(hint, 28)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)
	for action in StudioCity.ACTIONS:
		var spec: Dictionary = StudioCity.ACTIONS[action]
		var button = UIKit.button(Locale.text("city_action_" + action, [Data.money(spec["cost"])]), _act.bind(action))
		button.name = "CityAction_" + action
		button.disabled = int(Game.life["city"]["last_action_day"]) == Game.day or int(s["last_day"]) == Game.day or (action == "date" and StudioCity.date_reason(person, is_client) != "") or (not is_client and not StudioLife.available(person)) or Game.money < int(spec["cost"])
		box.add_child(button)
	var rules = UIKit.label(Locale.text("city_rules"), 26)
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(rules)

func _act(action: String) -> void:
	if choosing_companion or not RelationshipOptions.allows_city_companion(StudioCity.person_for(contact, is_client)):
		choosing_companion = true
		refresh()
		return
	var result = StudioCity.interact(contact, action, is_client)
	message = result["text"]
	if result["ok"]:
		location = result["scene"]
		social_action = action
	refresh()

func _stage_people(scene: TextureRect) -> void:
	var person = StudioCity.person_for(contact, is_client)
	if person.is_empty(): return
	for i in 2:
		var view = PortraitView.new()
		view.name = "CityProducer" if i == 0 else "CityCompanion"
		view.size = Vector2(160, 228)
		var destination = Vector2(244 + i * 230, 208)
		view.position = destination + Vector2(-90 if i == 0 else 90, 0)
		scene.add_child(view)
		view.configure(Game.player_character if i == 0 else Art.model_id(person), i == 1)
		view.body_pose = "walk"
		view.use_fullbody(true)
		var arrival = view.create_tween()
		arrival.tween_property(view, "position", destination, 0.85)
		arrival.tween_callback(func():
			view.body_pose = "idle"
			view.talking = social_action != "" and social_action != "walk")

func companion_entries() -> Array:
	var entries: Array = []
	for person in Game.staff + [StudioCity.alice()]:
		if RelationshipOptions.allows_city_companion(person):
			entries.append({"id": person["id"], "client": false, "person": person, "label": person["name"]})
	for person in Game.clients.values():
		if RelationshipOptions.allows_city_companion(person):
			entries.append({"id": person["name"], "client": true, "person": person, "label": Game.client_contact(person)})
	return entries

func _companion_picker(body: VBoxContainer) -> void:
	var title = UIKit.label(Locale.text("city_choose_companion"), 40)
	title.name = "CityCompanionPicker"
	body.add_child(title)
	var mode = "relationship_mode_all" if Locale.relationship_mode == "all_genders" else "relationship_mode_different"
	body.add_child(UIKit.label(Locale.text("city_companion_mode", [Locale.text(mode)]), 28))
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	body.add_child(scroll)
	var list = VBoxContainer.new()
	list.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(list)
	var entries = companion_entries()
	for entry in entries:
		var row = HBoxContainer.new()
		list.add_child(row)
		var portrait = PortraitView.new()
		portrait.custom_minimum_size = Vector2(80, 80)
		row.add_child(portrait)
		portrait.configure(Art.model_id(entry["person"]))
		var button = UIKit.button(entry["label"], func():
			contact = entry["id"]
			is_client = entry["client"]
			message = ""
			choosing_companion = false
			refresh())
		button.name = "CityCompanion_" + str(entry["id"])
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(button)
	if entries.is_empty(): list.add_child(UIKit.label(Locale.text("city_no_companions"), 30))

func _hall(box: VBoxContainer) -> void:
	_chart_block(box)
	_show_block(box)
	var note = UIKit.label(Locale.text("city_contest_rules", [Game.contest_edition, 28 - Game.day % 28]), 28)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)
	for song in Game.songs:
		if song.get("contest_entered", false): continue
		var selected = Game.life["city"]["contest_song"] == song["id"]
		var label = ("[x] " if selected else "") + str(song["title"]) + " | %d/40 | %d%%" % [song["rating"], roundi(100 * StudioCity.contest_chance(song["rating"], Game.contest_edition))]
		var button = UIKit.button(label, func(): message = StudioCity.submit(song); refresh())
		button.name = "Submit_" + str(song["id"])
		box.add_child(button)
	if Game.songs.is_empty(): box.add_child(UIKit.label(Locale.text("city_no_songs"), 28))
	var results: Array = Game.life["city"]["results"].duplicate()
	results.reverse()
	for result in results.slice(0, 6):
		var item = UIKit.label("#%d | %s | %s" % [result["edition"], result["song"], Locale.text("city_win" if result["win"] else "city_loss")], 26)
		item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(item)

func _chart_block(box: VBoxContainer) -> void:
	var title = UIKit.label(Locale.text("stage_chart_title"), 32)
	title.name = "StageChart"
	box.add_child(title)
	var chart: Array = StudioStage.stage()["chart"]
	if chart.is_empty():
		var empty = UIKit.label(Locale.text("stage_chart_empty"), 26)
		empty.name = "StageChartEmpty"
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(empty)
		return
	for entry in chart.slice(0, 5):
		var studio = Locale.text("stage_chart_you") if entry.get("player", false) else str(entry["studio"])
		var line = UIKit.label(Locale.text("stage_chart_line", [entry["rank"], entry["title"], studio]), 26)
		line.name = "ChartLine%d" % int(entry["rank"])
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(line)

func _show_block(box: VBoxContainer) -> void:
	var rules = UIKit.label(Locale.text("stage_show_rules", [Data.money(StudioStage.SHOW_COST)]), 26)
	rules.name = "StageShowRules"
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(rules)
	var wait = StudioStage.show_wait()
	if wait > 0:
		box.add_child(UIKit.label(Locale.text("stage_show_wait", [wait]), 26))
	var request = str(StudioStage.stage()["fan_request"])
	if request != "":
		var song = StudioStage.song_by_id(request)
		if not song.is_empty():
			var ask = UIKit.label(Locale.text("stage_show_fans", [song["title"]]), 26)
			ask.name = "StageFanRequest"
			ask.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			box.add_child(ask)
	if Game.songs.is_empty():
		return
	for song in Game.songs:
		var selected = show_song == str(song["id"])
		var button = UIKit.button(("* " if selected else "") + str(song["title"]), _pick_show.bind(str(song["id"])))
		button.name = "ShowSong_" + str(song["id"])
		box.add_child(button)
	if show_song == "":
		return
	for artist in Game.staff:
		var toggle = CheckBox.new()
		toggle.text = str(artist["name"])
		toggle.button_pressed = bool(show_team.get(artist["id"], false))
		toggle.disabled = not StudioLife.available(artist)
		toggle.toggled.connect(_on_show_toggled.bind(str(artist["id"])))
		box.add_child(toggle)
	var book = UIKit.button(Locale.text("stage_show_book"), _book_show)
	book.name = "StageShowBook"
	book.disabled = wait > 0 or Game.money < StudioStage.SHOW_COST
	box.add_child(book)

func _pick_show(id: String) -> void:
	show_song = id
	refresh()

func _on_show_toggled(on: bool, id: String) -> void:
	show_team[id] = on

func _book_show() -> void:
	var ids: Array = []
	for id in show_team:
		if show_team[id]: ids.append(id)
	var result = StudioStage.book_show(show_song, ids)
	message = str(result["text"])
	refresh()

func _process(_delta: float) -> void:
	if not visible: return
	var host = find_child("Announcer", true, false) as TextureRect
	if host:
		(host.texture as AtlasTexture).region.position.x = (int(Time.get_ticks_msec() / 160) % 6) * 32
