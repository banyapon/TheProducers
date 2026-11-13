class_name Hud
extends Control
signal panel_requested(panel_name: String)
signal zoom_requested(factor: float)
var money_label: Label
var date_label: Label
var fans_label: Label
var project_label: Label
var project_bar: ProgressBar
var user_label: Label
var toasts: VBoxContainer
var _top: VBoxContainer
var speed_buttons: Dictionary = {}
var action_buttons: Dictionary = {}
var zoom_label: Label
var zoom_level := 1.0
var demo_card: PanelContainer
var demo_title: Label
var demo_next: Button

func set_zoom(value: float) -> void:
	zoom_level = value
	if is_instance_valid(zoom_label): zoom_label.text = "x%d" % roundi(value) if absf(value - roundf(value)) < 0.04 else "x%.1f" % value

func _process(_delta: float) -> void:
	for value in speed_buttons:
		if is_instance_valid(speed_buttons[value]): speed_buttons[value].set_pressed_no_signal(Game.speed == value)

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	_build()
	for sig in [Game.money_changed, Game.date_changed, Game.fans_changed]: sig.connect(_update.unbind(1))
	Game.state_loaded.connect(_update)
	Game.project_progress.connect(_update.unbind(1))
	Game.project_started.connect(_update.unbind(1))
	Game.project_ended.connect(_update)
	Game.jobs_changed.connect(_update)
	Game.meeting_changed.connect(_update)
	Game.offers_changed.connect(_update)
	Locale.language_changed.connect(func(_lang: String): UIKit.clear(self); _build(); _update())
	_update()

func _build() -> void:
	var top = PanelContainer.new()
	top.name = "TopToolbar"
	top.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
	top.offset_bottom = 116
	_compact_panel(top)
	add_child(top)
	_top = VBoxContainer.new()
	_top.add_theme_constant_override("separation", 4)
	top.add_child(_top)
	var first = HBoxContainer.new()
	first.add_theme_constant_override("separation", 20)
	_top.add_child(first)
	user_label = UIKit.label("THE PRODUCERS", 36)
	user_label.clip_text = true
	user_label.modulate = Color("ffd166")
	user_label.size_flags_horizontal = SIZE_EXPAND_FILL
	first.add_child(user_label)
	money_label = UIKit.label("", 30)
	first.add_child(money_label)
	var alice_button = UIKit.button("Alice", func(): panel_requested.emit("alice"))
	alice_button.name = "AliceButton"
	first.add_child(alice_button)
	var quests_button = UIKit.button("Quest", func(): panel_requested.emit("quests"))
	quests_button.name = "OpenQuests"
	first.add_child(quests_button)
	action_buttons["alice"] = alice_button
	first.add_child(UIKit.button("EN / TH", func(): Locale.set_language("en" if Locale.language == "th" else "th")))
	for speed in [0, 1, 2, 4]:
		var button = UIKit.button("II" if speed == 0 else "x" + str(speed), func(): Game.speed = speed, 78)
		button.name = "Speed%d" % speed
		button.toggle_mode = true
		button.add_theme_font_override("font", UIKit.readable_font())
		button.add_theme_font_size_override("font_size", 48)
		first.add_child(button)
		speed_buttons[speed] = button
	for control in first.get_children():
		if control is Button:
			control.custom_minimum_size.y = 44
			for state in ["normal", "hover", "pressed", "disabled", "focus"]:
				var skin = control.get_theme_stylebox(state).duplicate()
				skin.content_margin_top = 4
				skin.content_margin_bottom = 4
				control.add_theme_stylebox_override(state, skin)
	var second = HBoxContainer.new()
	_top.add_child(second)
	date_label = UIKit.label("", 30)
	second.add_child(date_label)
	project_label = UIKit.label("", 30)
	project_label.size_flags_horizontal = SIZE_EXPAND_FILL
	project_label.clip_text = true
	second.add_theme_constant_override("separation", 24)
	second.add_child(project_label)
	fans_label = UIKit.label("", 24)
	second.add_child(fans_label)
	project_bar = ProgressBar.new()
	project_bar.custom_minimum_size.y = 4
	project_bar.show_percentage = false
	_top.add_child(project_bar)
	var bottom = PanelContainer.new()
	bottom.name = "BottomToolbar"
	bottom.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	bottom.offset_top = -80
	_compact_panel(bottom)
	add_child(bottom)
	var actions = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	bottom.add_child(actions)
	for key in ["jobs", "hire", "studio", "library", "shop", "staff", "city", "floor", "column", "options"]:
		var button = UIKit.button(Locale.text(key), func(): panel_requested.emit("menu" if key == "options" else key), 142)
		button.name = "Action_" + key
		button.icon = Art.texture("res://assets/ui/pixel/icon-%s.png" % ("hire" if key == "staff" else ("jobs" if key == "city" else key)))
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 32)
		button.add_theme_constant_override("h_separation", 10)
		button.tooltip_text = Locale.text(key)
		actions.add_child(button)
		action_buttons[key] = button
	var zoom_panel = PanelContainer.new()
	zoom_panel.name = "ZoomControls"
	zoom_panel.set_anchors_and_offsets_preset(PRESET_BOTTOM_RIGHT)
	zoom_panel.offset_left = -280
	zoom_panel.offset_right = -24
	zoom_panel.offset_top = -166
	zoom_panel.offset_bottom = -92
	add_child(zoom_panel)
	var zoom_row = HBoxContainer.new()
	zoom_panel.add_child(zoom_row)
	var minus = UIKit.button("-",func(): zoom_requested.emit(1.0/1.1),44)
	zoom_row.add_child(minus)
	zoom_label = UIKit.label("",36)
	zoom_label.custom_minimum_size.x = 96
	zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zoom_label.size_flags_vertical = SIZE_SHRINK_CENTER
	zoom_row.add_child(zoom_label)
	zoom_row.add_child(UIKit.button("+",func(): zoom_requested.emit(1.1),44))
	set_zoom(zoom_level)
	toasts = VBoxContainer.new()
	toasts.set_anchors_and_offsets_preset(PRESET_TOP_RIGHT)
	toasts.offset_left = -560
	toasts.offset_right = -20
	toasts.offset_top = 136
	toasts.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(toasts)
	var hint_panel = PanelContainer.new()
	hint_panel.name = "WorldHintPanel"
	hint_panel.set_anchors_and_offsets_preset(PRESET_BOTTOM_LEFT)
	hint_panel.offset_left = 24
	hint_panel.offset_right = 24
	hint_panel.offset_top = -158
	hint_panel.offset_bottom = -96
	hint_panel.grow_vertical = GROW_DIRECTION_BEGIN
	hint_panel.mouse_filter = MOUSE_FILTER_IGNORE
	var hint_skin = StyleBoxFlat.new()
	hint_skin.bg_color = Color("0b1423")
	hint_skin.border_color = Color("547584")
	hint_skin.set_border_width_all(2)
	hint_skin.content_margin_left = 20
	hint_skin.content_margin_right = 20
	hint_skin.content_margin_top = 10
	hint_skin.content_margin_bottom = 10
	hint_skin.shadow_color = Color(0, 0, 0, 0.65)
	hint_skin.shadow_size = 4
	hint_skin.shadow_offset = Vector2(0, 4)
	hint_panel.add_theme_stylebox_override("panel", hint_skin)
	add_child(hint_panel)
	var hint = UIKit.label(Locale.text("world_hint"), 36)
	hint.name = "WorldHintText"
	hint.add_theme_color_override("font_color", Color("fff2d6"))
	hint.mouse_filter = MOUSE_FILTER_IGNORE
	hint_panel.add_child(hint)
	demo_card = PanelContainer.new()
	demo_card.name = "DemoNextStep"
	demo_card.position = Vector2(24, 136)
	demo_card.custom_minimum_size = Vector2(550, 0)
	add_child(demo_card)
	var guide = VBoxContainer.new()
	demo_card.add_child(guide)
	demo_title = UIKit.label("", 28)
	guide.add_child(demo_title)
	demo_next = UIKit.button("", func(): panel_requested.emit("demo_next"), 300, "ConfirmButton")
	guide.add_child(demo_next)

func _update() -> void:
	visible = Game.running
	money_label.text = Data.money(Game.money)
	date_label.text = Game.date_text()
	action_buttons["alice"].text = Game.assistant_portrait()["name"]
	user_label.text = Game.studio_name + " | " + Game.producer_name
	user_label.tooltip_text = user_label.text
	fans_label.text = "%s %d | %s %d/100 | %s" % [Locale.text("fame"), Game.fame, Locale.text("reputation"), Game.reputation, Locale.text("legacy_239") % Game.fans]
	project_label.text = Locale.text("legacy_240") if Game.project.is_empty() else Locale.display_game_text(str(Game.project["title"]))
	if Game.all_projects().size() > 1:
		project_label.text = Locale.text("parallel_count", [Game.all_projects().size()]) + " | " + project_label.text
	project_bar.value = 0 if Game.project.is_empty() else Game.project["progress"]
	project_label.tooltip_text = project_label.text
	var step = DemoCareer.next_step()
	demo_card.visible = not step.is_empty()
	if not step.is_empty():
		demo_title.text = Locale.text("flow_demo_card", [int(step["index"]) + 1, step["job"]["title"]])
		demo_next.text = Locale.text("flow_step_" + step["action"])
	for key in ["hire", "shop", "staff", "city", "floor", "column"]:
		action_buttons[key].visible = not DemoCareer.active() or int(Game.life["demo"]["completed"].size()) >= 2

func _compact_panel(panel: PanelContainer) -> void:
	var skin = panel.get_theme_stylebox("panel").duplicate()
	skin.content_margin_top = 8
	skin.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", skin)

func toast(value: String) -> void:
	if not Game.running: return
	var panel = PanelContainer.new()
	panel.mouse_filter = MOUSE_FILTER_IGNORE
	var copy = UIKit.label(value, 24)
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.custom_minimum_size.x = 500
	panel.add_child(copy)
	toasts.add_child(panel)
	if toasts.get_child_count() > 3:
		var oldest = toasts.get_child(0)
		toasts.remove_child(oldest)
		oldest.queue_free()
	var tw = panel.create_tween()
	tw.tween_interval(4.5)
	tw.tween_property(panel, "modulate:a", 0.0, 0.6)
	tw.tween_callback(panel.queue_free)
