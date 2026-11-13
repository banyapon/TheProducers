class_name QuestPanel
extends UIPanel

var preview_only := false
var selected := "mali"
var filter := "all"
var message := ""
var scene_stage := ""
var scene_index := 0
var catalogue_scroll: ScrollContainer
var detail_scroll_view: ScrollContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	StoryQuests.changed.connect(_refresh_if_open, CONNECT_DEFERRED)
	super()

func open_catalogue(preview: bool = false) -> void:
	preview_only = preview
	if preview: filter = "all"
	scene_stage = ""
	message = ""
	if not preview: StoryQuests.sync()
	open()

func refresh() -> void:
	var catalogue_position = catalogue_scroll.scroll_vertical if is_instance_valid(catalogue_scroll) else 0
	var detail_position = detail_scroll_view.scroll_vertical if is_instance_valid(detail_scroll_view) else 0
	UIKit.clear(self)
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var body = UIKit.centered_window(self, 1740, 940)
	var header = HBoxContainer.new()
	body.add_child(header)
	var title = UIKit.label(StoryQuests.ui("title"), 42)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(UIKit.button("EN / TH", func(): Locale.set_language("en" if Locale.language == "th" else "th")))
	header.add_child(UIKit.button(StoryQuests.ui("close"), close))
	if preview_only:
		body.add_child(_copy(StoryQuests.ui("preview"), Color("ffd166")))
	else:
		body.add_child(_copy("%d / 20 • %s" % [StoryQuests.completed_count(), StoryQuests.ui("completed")], Color("ffd166")))
		body.add_child(_copy(StoryQuests.ui("visit_hint"), Color("a9bbc9")))
	var columns = HBoxContainer.new()
	columns.size_flags_vertical = SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 24)
	body.add_child(columns)
	var catalogue = VBoxContainer.new()
	catalogue.custom_minimum_size.x = 490
	columns.add_child(catalogue)
	var tabs = HBoxContainer.new()
	catalogue.add_child(tabs)
	for key in ["all", "active", "completed"]:
		var tab = UIKit.button(StoryQuests.ui(key), func(): filter = key; refresh())
		tab.size_flags_horizontal = SIZE_EXPAND_FILL
		tab.toggle_mode = true; tab.button_pressed = filter == key
		tab.disabled = preview_only and key != "all"
		tabs.add_child(tab)
	var scroll = ScrollContainer.new()
	catalogue_scroll = scroll
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	catalogue.add_child(scroll)
	var list = VBoxContainer.new()
	list.size_flags_horizontal = SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	var listed: Array = []
	for q in StoryQuests.definitions:
		if _show_in_list(q): listed.append(q)
	if not preview_only:
		var ids: Array = listed.map(func(item: Dictionary): return str(item["id"]))
		if not ids.has(selected): selected = str(ids[0]) if not ids.is_empty() else ""
	for entry in listed:
		var row = HBoxContainer.new()
		list.add_child(row)
		var portrait = TextureRect.new()
		portrait.texture = Art.portrait(entry["npc"]["art_id"])
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.custom_minimum_size = Vector2(72, 88)
		portrait.texture_filter = TEXTURE_FILTER_NEAREST
		row.add_child(portrait)
		var quest_id = str(entry["id"])
		var caption = "%02d  %s" % [int(entry["order"]), StoryQuests.text(entry["npc"]["name"])]
		if not preview_only: caption += "\n" + StoryQuests.ui(StoryQuests.status(quest_id))
		var button = UIKit.button(caption, func(): selected = quest_id; scene_stage = ""; message = ""; detail_scroll_view.scroll_vertical = 0; refresh())
		button.name = "Quest_" + quest_id
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		button.toggle_mode = true; button.button_pressed = selected == quest_id
		row.add_child(button)
	if list.get_child_count() == 0:
		list.add_child(_copy(StoryQuests.ui("accepted_empty" if not preview_only and StoryQuests.accepted_ids().is_empty() else "not_ready")))
	var detail_scroll = ScrollContainer.new()
	detail_scroll_view = detail_scroll
	scroll.set_deferred("scroll_vertical", catalogue_position)
	detail_scroll.set_deferred("scroll_vertical", detail_position)
	detail_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(detail_scroll)
	var detail = VBoxContainer.new()
	detail.size_flags_horizontal = SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 16)
	detail_scroll.add_child(detail)
	var q = StoryQuests.definition(selected)
	if q.is_empty():
		detail.add_child(_copy(StoryQuests.ui("accepted_empty")))
		return
	if scene_stage != "": _build_scene(detail, q); return
	_build_detail(detail, q)

func _show_in_list(q: Dictionary) -> bool:
	if preview_only: return true
	var saved = str(StoryQuests.state(q["id"]).get("status", ""))
	if saved not in ["active", "completed"]: return false
	var status = StoryQuests.status(q["id"])
	if filter == "active" and status not in ["active", "ready"]: return false
	if filter == "completed" and status != "completed": return false
	return true

func _copy(value: String, color: Color = Color.WHITE) -> Label:
	var label = UIKit.label(value, 36)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", color)
	return label

func _hero(body: VBoxContainer, q: Dictionary, expression: int = 0) -> void:
	var hero = HBoxContainer.new()
	hero.add_theme_constant_override("separation", 24)
	body.add_child(hero)
	var portrait = TextureRect.new()
	portrait.texture = Art.portrait(q["npc"]["art_id"], expression)
	portrait.texture_filter = TEXTURE_FILTER_NEAREST
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(256, 256)
	hero.add_child(portrait)
	var motion_box = Control.new()
	motion_box.custom_minimum_size = Vector2(160, 256)
	hero.add_child(motion_box)
	var motion = AnimatedSprite2D.new()
	motion.sprite_frames = Art.office_frames(q["npc"]["art_id"])
	motion.position = Vector2(80, 148)
	motion.texture_filter = TEXTURE_FILTER_NEAREST
	motion_box.add_child(motion)
	motion.play("talk" if scene_stage != "" else "idle")
	var copy = VBoxContainer.new()
	copy.size_flags_horizontal = SIZE_EXPAND_FILL
	hero.add_child(copy)
	copy.add_child(_copy(StoryQuests.text(q["npc"]["name"]), Color("ffd166")))
	copy.add_child(_copy(StoryQuests.text(q["title"])))
	copy.add_child(_copy("%d %s • %s" % [q["npc"]["age"], "ปี" if Locale.language == "th" else "years", q["genre"] if q["genre"] != "" else StoryQuests.ui("any_genre")], Color("a9bbc9")))

func _build_detail(body: VBoxContainer, q: Dictionary) -> void:
	_hero(body, q)
	body.add_child(_copy(StoryQuests.text(q["dialogue"]["intro"])))
	body.add_child(_copy(StoryQuests.objective(q), Color("c7dbdf")))
	if int(q["prereq_count"]) > 0: body.add_child(_copy(StoryQuests.ui("finish_count") % q["prereq_count"], Color("ffd166")))
	for required in q["prerequisites"]:
		body.add_child(_copy(StoryQuests.ui("finish_first") % StoryQuests.text(StoryQuests.definition(required)["title"]), Color("ffd166")))
	var reward = StoryQuests.ui("reward") + ": " + Data.money(q["reward"]["money"]) + " • +%d fans" % q["reward"]["fans"]
	if q["reward"]["kind"] == "artist": reward += "\n" + StoryQuests.ui("unlock_artist")
	else: reward += "\n" + StoryQuests.ui("unlock_client") % q["reward"]["multiplier"]
	body.add_child(_copy(reward, Color("9ce0b2")))
	if preview_only: return
	var status = StoryQuests.status(selected)
	var progress = StoryQuests.progress(selected)
	var meter = ProgressBar.new()
	meter.custom_minimum_size.y = 28
	meter.max_value = progress["target"]; meter.value = progress["count"]
	meter.show_percentage = false
	body.add_child(meter)
	body.add_child(_copy("%s • %d / %d" % [StoryQuests.ui(status), progress["count"], progress["target"]]))
	if not progress["songs"].is_empty():
		body.add_child(_copy(StoryQuests.ui("evidence"), Color("a9bbc9")))
		for song in progress["songs"].slice(0, 5):
			body.add_child(_copy("• %s — %s — %d/40" % [song.get("title", song["id"]), StoryQuests.primary_genre(song), song["rating"]]))
	var actions = HFlowContainer.new()
	body.add_child(actions)
	match status:
		"active":
			if q["mode"] == "commission": _brief_button(actions)
			body.add_child(_copy(StoryQuests.text(q["dialogue"]["hint"])))
		"ready":
			actions.add_child(UIKit.button(StoryQuests.ui("claim"), func():
				if StoryQuests.claim(selected): scene_stage = "success"; scene_index = 0; refresh(), 0, "ConfirmButton"))
		"completed":
			actions.add_child(UIKit.button(StoryQuests.ui("replay"), func(): scene_stage = "success"; scene_index = 0; refresh()))
			if q["reward"]["kind"] == "artist":
				var recruit = UIKit.button(StoryQuests.ui("recruit"), func(): message = StoryQuests.recruit(selected); refresh())
				recruit.disabled = not Game.get_artist("story_artist_" + selected).is_empty()
				if recruit.disabled: recruit.text = StoryQuests.ui("hired")
				actions.add_child(recruit)
			else: _brief_button(actions)
			body.add_child(_copy(StoryQuests.text(q["dialogue"]["return"])))
	if not message.is_empty(): body.add_child(_copy(message, Color("ffd166")))

func _brief_button(actions: HFlowContainer) -> void:
	var button = UIKit.button(StoryQuests.ui("brief"), func():
		if StoryQuests.issue_brief(selected): message = StoryQuests.ui("brief") + " ✓"; refresh())
	button.disabled = not StoryQuests.can_issue(selected)
	button.tooltip_text = StoryQuests.ui("retry")
	actions.add_child(button)
	if button.disabled: actions.add_child(_copy(StoryQuests.ui("retry"), Color("a9bbc9")))

func _build_scene(body: VBoxContainer, q: Dictionary) -> void:
	_hero(body, q, 1 if scene_index == 0 else 0)
	var lines: Array = []
	if scene_stage == "accepted":
		lines = [StoryQuests.ui("fresh_reply" if StoryQuests.state(selected).get("choice", "") == "new_start" else "choice_reply"), StoryQuests.text(q["dialogue"]["hint"])]
	else:
		lines = [StoryQuests.text(q["dialogue"]["success"]), StoryQuests.text(q["dialogue"]["scene"]), StoryQuests.ui("alice_end"), StoryQuests.text(q["dialogue"]["return"])]
	body.add_child(_copy(StoryQuests.ui("ending") if scene_stage == "success" else StoryQuests.text(q["title"]), Color("ffd166")))
	var speaker = StoryQuests.text(q["npc"]["name"])
	if scene_stage == "accepted" and scene_index == 0: speaker = "Producer"
	if scene_stage == "success" and scene_index == 1: speaker = "…"
	if scene_stage == "success" and scene_index == 2: speaker = "Alice"
	body.add_child(_copy(speaker, Color("9ce0b2")))
	body.add_child(_copy(lines[scene_index]))
	body.add_child(UIKit.button(StoryQuests.ui("next"), func():
		scene_index += 1
		if scene_index >= lines.size():
			if scene_stage == "success": StoryQuests.mark_ending_seen(selected)
			scene_stage = ""
		refresh()))
