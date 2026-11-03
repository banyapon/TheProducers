class_name TutorialCoach
extends Control
var main: Node
var card: PanelContainer
var copy: Label
var heading: Label
var skip_button: Button
var target: Control
var _last := ""
var _assistant_portrait: PortraitView

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	card = PanelContainer.new()
	card.position = Vector2(24,156)
	card.custom_minimum_size = Vector2(510,180)
	add_child(card)
	var box = VBoxContainer.new()
	card.add_child(box)
	var row = HBoxContainer.new()
	box.add_child(row)
	var alice = PortraitView.new()
	_assistant_portrait = alice
	alice.custom_minimum_size = Vector2(64,64)
	row.add_child(alice)
	alice.configure(Game.assistant_portrait()["art_id"])
	Game.state_loaded.connect(_on_state_loaded)
	heading = UIKit.label(Game.assistant_portrait()["name"],28)
	heading.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(heading)
	var skip = UIKit.button(Locale.text("tutorial_skip"), finish)
	skip_button = skip
	skip.add_theme_font_size_override("font_size",32)
	row.add_child(skip)
	copy = UIKit.label("",40)
	copy.add_theme_font_override("font", UIKit.readable_font())
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.custom_minimum_size.x = 470
	box.add_child(copy)
	hide()

func _on_state_loaded() -> void:
	if is_instance_valid(_assistant_portrait):
		_assistant_portrait.configure(Game.assistant_portrait()["art_id"])
	if is_instance_valid(heading): heading.text = Game.assistant_portrait()["name"]

func finish() -> void:
	Game.tutorial_step = -1
	Game.tutorial_gate = false
	Game.save_game()
	hide()

func _button(root: Node, text: String) -> Control:
	if root is Button and root.text == text and root.is_visible_in_tree(): return root
	for child in root.get_children():
		var found = _button(child,text)
		if found: return found
	return null

func _process(_delta: float) -> void:
	Game.tutorial_gate = false
	# The dedicated music walkthrough owns guidance/input while it is open.
	if main != null and main.jam.visible and main.jam._guide_step >= 0:
		target = null
		hide()
		return
	if main == null or not Game.running or Game.tutorial_step < 0 or not Game.intro_seen or main.login.visible or main.shell.visible:
		hide()
		return
	show()
	skip_button.text = Locale.text("tutorial_skip")
	var key = "tutorial_jobs"
	target = main.hud.action_buttons.get("jobs")
	var stage = 0
	if Game.songs.size() > Game.tutorial_start_songs:
		stage = 5
		key = "tutorial_done"
		target = null
	elif main.dialog.visible:
		stage = clampi(Game.tutorial_step,0,4)
		key = "tutorial_accept" if Game.jobs.is_empty() else "tutorial_read"
		target = main.dialog.choices_box.get_node_or_null("DialogChoice0")
		if target == null: target = main.dialog.next_hint
	elif not Game.jobs.is_empty():
		var job: Dictionary = Game.jobs[0]
		if not Game.idea_meeting.is_empty():
			stage = 1
			key = "tutorial_gather" if Game.idea_meeting["phase"] == "gathering" else "tutorial_arrange"
			target = main.jam.find_child("ComposerGenre",true,false)
			if Game.idea_meeting["placed"].size() >= 4: target = main.jam.find_child("SubmitIdea",true,false)
			if main.jam.review_open: target = main.jam.find_child("ConfirmArrangement",true,false)
		elif not Game.all_projects().is_empty():
			stage = 4
			key = "tutorial_recording"
			target = main.hud.speed_buttons.get(4)
			if main.release_panel.visible:
				key = "tutorial_release"
				target = main.release_panel.marketing_box.get_child(0)
		elif not Game.production_queue.is_empty():
			stage = 3
			key = "tutorial_wait"
			target = _button(main.planner,Locale.text("close")) if main.planner.visible else main.hud.speed_buttons.get(1)
		elif int(job.get("idea_rounds",0)) == 0:
			stage = 1
			key = "tutorial_lounge"
			target = main.planner.find_child("Jam_" + job["id"],true,false) if main.planner.visible else main.hud.action_buttons.get("alice")
			if main.job_board.visible: target = _button(main.job_board,Locale.text("close"))
		else:
			stage = 2
			key = "tutorial_plan"
			target = main.hud.action_buttons.get("alice")
			if main.planner.visible:
				target = main.planner.find_child("PlanDelay1",true,false)
			if int(job.get("planned_day",Game.day)) > Game.day:
				key = "tutorial_team"
				target = _button(main.planner,Locale.text("close")) if main.planner.visible else main.hud.action_buttons.get("studio")
			if main.production.visible:
				key = "tutorial_team"
				for checkbox in main.production._checks.values():
					if not checkbox.button_pressed:
						target = checkbox
						break
				if main.production.selected_team_ids().size() >= 2:
					key = "tutorial_schedule"
					target = main.production.find_child("StartBtn",true,false)
	elif main.job_board.visible:
		key = "tutorial_talk"
		target = _button(main.job_board,Locale.text("talk"))
	Game.tutorial_step = stage
	Game.tutorial_gate = stage < 3
	# Keep the large workshop grid unobstructed: coach moves to a narrow top strip there.
	card.visible = not (main.jam.visible and Game.idea_meeting.get("phase","") == "playing")
	card.position = Vector2(get_viewport_rect().size.x-534,156) if main.jam.visible else Vector2(24,156)
	var signature = "%d:%s:%s" % [stage,key,Locale.language]
	if signature == _last:
		queue_redraw()
		return
	_last = signature
	var palette = [Color("ff9981"),Color("7cdded"),Color("c7a0ff"),Color("ffd16c"),Color("88e1b2"),Color("a3f0b9")]
	var style = StyleBoxFlat.new()
	style.bg_color = Color("15243a")
	style.border_color = palette[stage]
	style.set_border_width_all(4)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 14
	card.add_theme_stylebox_override("panel",style)
	heading.text = Locale.text("tutorial_heading",[stage+1])
	heading.modulate = palette[stage]
	copy.text = Locale.text(key)
	queue_redraw()

func _draw() -> void:
	if is_instance_valid(target) and target.is_visible_in_tree():
		var rect = target.get_global_rect().grow(5)
		draw_rect(rect,Color("8dffca"),false,4)
		draw_colored_polygon(PackedVector2Array([rect.position+Vector2(12,-16),rect.position+Vector2(30,-16),rect.position+Vector2(21,-4)]),Color("8dffca"))
