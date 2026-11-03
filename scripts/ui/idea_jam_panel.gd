class_name IdeaJamPanel
extends UIPanel
var office: Office
var selected := -1
var body_root: Control
var player: AudioStreamPlayer
var audition: AudioStreamPlayer
var _guide_step := -1
var genre_index := 0
var playhead: Label
var _preview_bpm := 120
const PITCH_STEPS := [0, 2, 4, 7, 12, -12, -7, -4, -2]
var pitch_step := 0
var pitch_changed := false
var pitch_button: Button
var tempo_slider: HSlider
var seek_slider: HSlider
var play_button: Button
var _scrubbing := false
var cells: Array = []
var energy_bars: Array = []
var inspected := -1
var loop_section := -1
var _shown_job := ""
var market_open := false

func _build_transport(body: VBoxContainer, meeting: Dictionary) -> void:
	var transport = HBoxContainer.new()
	transport.name = "ComposerTransport"
	transport.add_theme_constant_override("separation", 16)
	body.add_child(transport)
	var timeline = VBoxContainer.new()
	timeline.size_flags_horizontal = SIZE_EXPAND_FILL
	transport.add_child(timeline)
	playhead = UIKit.label(Locale.text("composer_bar", [1]), 28)
	timeline.add_child(playhead)
	seek_slider = HSlider.new()
	seek_slider.name = "ComposerSeek"
	seek_slider.min_value = 0
	seek_slider.max_value = 31.99 if meeting.get("freeform", false) else 3.99
	seek_slider.step = 0.01
	seek_slider.tooltip_text = Locale.text("composer_seek")
	seek_slider.custom_minimum_size = Vector2(280, 30)
	timeline.add_child(seek_slider)
	seek_slider.drag_started.connect(func(): _scrubbing = true)
	seek_slider.drag_ended.connect(func(_changed: bool): _scrubbing = false)
	seek_slider.value_changed.connect(func(beat: float):
		if player.playing: player.seek(beat * 60.0 / _preview_bpm))
	play_button = UIKit.button(Locale.text("composer_play"), toggle_playback)
	play_button.name = "ComposerPlay"
	play_button.custom_minimum_size = Vector2(150, 64)
	play_button.size_flags_vertical = SIZE_SHRINK_CENTER
	transport.add_child(play_button)
	var stop = UIKit.button(Locale.text("jam_stop"), stop_playback)
	stop.name = "ComposerStop"
	stop.size_flags_vertical = SIZE_SHRINK_CENTER
	transport.add_child(stop)
	pitch_button = UIKit.button("Shift Pitch: %+d" % PITCH_STEPS[pitch_step], shift_pitch)
	pitch_button.name = "ComposerPitch"
	pitch_button.disabled = int(meeting.get("brief", {}).get("lesson", 2)) == 0
	pitch_button.custom_minimum_size = Vector2(220, 64)
	pitch_button.size_flags_vertical = SIZE_SHRINK_CENTER
	transport.add_child(pitch_button)
	var tempo_box = VBoxContainer.new()
	transport.add_child(tempo_box)
	var tempo = UIKit.label(str(int(meeting["bpm"])) + " BPM", 28)
	tempo_box.add_child(tempo)
	tempo_slider = HSlider.new()
	tempo_slider.name = "ComposerTempo"
	tempo_slider.min_value = 60
	tempo_slider.max_value = 180
	tempo_slider.step = 5
	tempo_slider.value = int(meeting["bpm"])
	tempo_slider.custom_minimum_size = Vector2(220, 30)
	tempo_box.add_child(tempo_slider)
	tempo_slider.value_changed.connect(func(value: float): tempo.text = str(int(value)) + " BPM"; _set_tempo(value))
	var volume_box = VBoxContainer.new()
	transport.add_child(volume_box)
	var volume_label = UIKit.label(Locale.text("composer_volume", [roundi(Audio.levels["Composer"] * 100)]), 28)
	volume_box.add_child(volume_label)
	var volume = HSlider.new()
	volume.name = "ComposerVolume"
	volume.min_value = 0
	volume.max_value = 100
	volume.step = 1
	volume.value = Audio.levels["Composer"] * 100
	volume.custom_minimum_size = Vector2(180, 30)
	volume_box.add_child(volume)
	volume.value_changed.connect(func(value: float):
		Audio.set_level("Composer", value / 100.0)
		volume_label.text = Locale.text("composer_volume", [roundi(value)]))
	var submit_button = UIKit.button(Locale.text("composer_save"), submit, 180, "ConfirmButton")
	submit_button.name = "SubmitIdea"
	submit_button.custom_minimum_size.y = 64
	submit_button.size_flags_vertical = SIZE_SHRINK_CENTER
	submit_button.disabled = meeting["placed"].is_empty()
	transport.add_child(submit_button)


func toggle_playback() -> void:
	if player.playing:
		player.stream_paused = not player.stream_paused
	else:
		preview(seek_slider.value if is_instance_valid(seek_slider) else 0.0)

func stop_playback() -> void:
	player.stop()
	audition.stop()
	player.stream_paused = false
	if is_instance_valid(seek_slider): seek_slider.set_value_no_signal(0)

func _input(event: InputEvent) -> void:
	if not visible or not body_root.visible or Game.idea_meeting.is_empty(): return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SHIFT:
		if player.playing and not player.stream_paused and not get_viewport().gui_is_dragging():
			shift_tempo()
		else: shift_pitch()
		get_viewport().set_input_as_handled()

func shift_pitch() -> void:
	if int(Game.idea_meeting.get("brief", {}).get("lesson", 2)) == 0: return
	pitch_step = (pitch_step + 1) % PITCH_STEPS.size()
	pitch_changed = true
	if is_instance_valid(pitch_button): pitch_button.text = "Shift Pitch: %+d" % PITCH_STEPS[pitch_step]

func shift_tempo() -> void:
	var next = int(Game.idea_meeting.get("bpm", 120)) + 10
	if next > 180: next = 60
	if is_instance_valid(tempo_slider): tempo_slider.value = next

func _set_tempo(value: float) -> void:
	remember()
	var was_playing = player.playing
	var was_paused = player.stream_paused
	var beat = player.get_playback_position() * _preview_bpm / 60.0 if was_playing else 0.0
	Game.idea_meeting["bpm"] = int(value)
	Game.save_game()
	if was_playing:
		preview(beat)
		player.stream_paused = was_paused

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	texture_filter = TEXTURE_FILTER_NEAREST
	body_root = Control.new()
	body_root.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(body_root)
	player = AudioStreamPlayer.new()
	player.bus = "Composer"
	add_child(player)
	audition = AudioStreamPlayer.new()
	audition.bus = "Composer"
	add_child(audition)
	Locale.language_changed.connect(_refresh_if_open.unbind(1))
	super()

func close() -> void:
	Game.save_game()
	player.stop()
	audition.stop()
	super()

func _process(_delta: float) -> void:
	if not visible or Game.idea_meeting.is_empty(): return
	if Game.idea_meeting["phase"] == "gathering" and (office == null or office.meeting_ready()):
		Game.idea_meeting["phase"] = "ready"
		refresh()
	if is_instance_valid(playhead):
		var beat = player.get_playback_position() * _preview_bpm / 60.0 if player.playing else (seek_slider.value if is_instance_valid(seek_slider) else 0.0)
		var current_bar = int(beat / 4.0) % 8
		for cell in cells:
			if is_instance_valid(cell): cell.modulate.a = 1.0 if cell.col == current_bar and player.playing else 0.8
		if loop_section >= 0 and player.playing and beat >= [8.0,20.0,32.0][loop_section]: player.seek([0.0,8.0,20.0][loop_section] * 60.0 / _preview_bpm)
		playhead.text = Locale.text("composer_bar", [1 + int(beat / 4.0) % 8])
		if player.playing and is_instance_valid(seek_slider) and not _scrubbing: seek_slider.set_value_no_signal(beat)
	if is_instance_valid(play_button): play_button.text = Locale.text("composer_pause" if player.playing and not player.stream_paused else "composer_play")

func refresh() -> void:
	UIKit.clear(body_root)
	# Keep the meeting pause while the actors walk, but leave the office visible.
	body_root.visible = not Game.idea_meeting.is_empty() and Game.idea_meeting.get("phase", "") != "gathering"
	if not body_root.visible: return
	var meeting: Dictionary = Game.idea_meeting
	if _shown_job != str(meeting["job_id"]):
		_shown_job = str(meeting["job_id"])
		market_open = int(Game.get_job(meeting["job_id"]).get("demo_index", 0)) > 0
		genre_index = maxi(0, Data.GENRES.find(meeting["genre"]))
		selected = -1; inspected = -1; pitch_step = 0; loop_section = -1
	if not meeting.has("brief"): meeting["brief"] = CompositionDesign.brief(Game.get_job(meeting["job_id"]))
	var job = Game.get_job(meeting["job_id"])
	MarketShift.plan(job)
	meeting["brief"] = CompositionDesign.brief(job)
	cells.clear()
	energy_bars.clear()
	var body = UIKit.centered_window(body_root, 1740, 990)
	body.add_theme_constant_override("separation", 8)
	var head = HBoxContainer.new()
	body.add_child(head)
	var title = UIKit.label(Locale.text("composer_title"), 36)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UIKit.button(Locale.text("arr_save_back"), close))
	head.add_child(UIKit.button(Locale.text("shift_strategy"), func(): market_open = not market_open; refresh()))
	if market_open:
		var outlook = UIKit.label(MarketShift.outlook(job), 36)
		outlook.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(outlook)
		var rules = UIKit.label(Locale.text("shift_rules"), 28)
		rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(rules)
		for strategy in ["hold", "blend", "pivot"]:
			var button = UIKit.button(Locale.text("shift_" + strategy) + "\n" + Locale.text("shift_desc_" + strategy), func():
				MarketShift.choose(job, strategy)
				market_open = false
				refresh())
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.custom_minimum_size.y = 120
			body.add_child(button)
		return
	var hero = HBoxContainer.new()
	hero.add_theme_constant_override("separation", 20)
	body.add_child(hero)
	var art = TextureRect.new()
	art.texture = Art.texture("res://assets/story/composer-studio.png")
	art.custom_minimum_size = Vector2(320, 170)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero.add_child(art)
	var guide = VBoxContainer.new()
	guide.size_flags_horizontal = SIZE_EXPAND_FILL
	hero.add_child(guide)
	var help = UIKit.label(Locale.text("arr_brief_" + meeting["brief"]["kind"]) + "\n" + Locale.text("arr_artist", [meeting["brief"]["artist_genre"]]), 30)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide.add_child(help)
	var shift_hint = UIKit.label(Locale.text("composer_shift_help"), 26)
	shift_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide.add_child(shift_hint)
	guide.add_child(UIKit.button(Locale.text("arr_advice"), func(): shift_hint.text = CompositionDesign.advice(Game.idea_meeting)))
	if meeting["phase"] == "gathering":
		guide.add_child(UIKit.label(Locale.text("jam_gather")))
		body.add_child(UIKit.button(Locale.text("cancel"), Game.cancel_idea_meeting))
		return
	var palette = HBoxContainer.new()
	body.add_child(palette)
	var genre = OptionButton.new()
	genre.name = "ComposerGenre"
	genre.disabled = int(meeting["brief"].get("lesson", 2)) == 0
	for name in Data.GENRES: genre.add_item(name)
	genre.select(genre_index)
	genre.item_selected.connect(func(index: int): genre_index = index; selected = -1; refresh())
	palette.add_child(genre)
	for block in meeting["deck"]:
		if meeting.get("freeform", false) and (not block.get("palette", false) or block["genre"] != Data.GENRES[genre_index]): continue
		if not meeting.get("freeform", false) and int(block["id"]) > 3: continue
		var tile = IdeaTile.new()
		tile.name = "IdeaBlock%d" % block["id"]
		tile.block_id = block["id"]
		tile.caption = str(block["genre"]) + " / " + Locale.text("arr_clip_%d" % int(block.get("style", 0)))
		tile.custom_minimum_size = Vector2(280, 62)
		var label = UIKit.label(tile.caption, 28)
		label.mouse_filter = MOUSE_FILTER_IGNORE
		tile.add_child(label)
		tile.selected.connect(func(id: int): selected = id; inspected = -1; audition_clip(id); refresh())
		if selected == tile.block_id: tile.modulate = Color("ffd166")
		palette.add_child(tile)
	palette.add_child(UIKit.button(Locale.text("composer_clear"), func(): remember(); Game.idea_meeting["placed"] = []; stop_playback(); Game.save_game(); refresh()))
	var editing = HBoxContainer.new()
	body.add_child(editing)
	editing.add_child(UIKit.button(Locale.text("arr_undo"), undo))
	editing.add_child(UIKit.button(Locale.text("arr_redo"), redo))
	editing.add_child(UIKit.button(Locale.text("arr_deselect"), func(): selected = -1; inspected = -1; refresh()))
	if inspected >= 0 and inspected < meeting["deck"].size():
		editing.add_child(UIKit.button(Locale.text("arr_copy"), func(): selected = inspected; Game.idea_meeting["copy_next"] = true))
		editing.add_child(UIKit.button(Locale.text("arr_delete"), _remove_clip.bind(inspected)))
		editing.add_child(UIKit.button(Locale.text("arr_style"), change_style))
		if int(meeting["brief"].get("lesson", 2)) > 0:
			editing.add_child(UIKit.button(Locale.text("arr_pitch"), func(): remember(); var clip = Game.idea_meeting["deck"][inspected]; clip["transpose"] = (int(clip.get("transpose", 0)) + 2 + 12) % 26 - 12; stop_playback(); Game.save_game(); refresh()))
		var level = HSlider.new()
		level.custom_minimum_size.x = 180
		level.min_value = 0.2; level.max_value = 1.0; level.step = 0.1
		level.value = float(meeting["deck"][inspected].get("volume", 1.0))
		level.tooltip_text = Locale.text("arr_clip_volume")
		level.drag_started.connect(remember)
		level.value_changed.connect(func(v: float): Game.idea_meeting["deck"][inspected]["volume"] = v; Game.save_game())
		editing.add_child(level)
	var sections = HBoxContainer.new()
	body.add_child(sections)
	var gutter = Control.new(); gutter.custom_minimum_size.x = 190; sections.add_child(gutter)
	for section in 3:
		var section_button = UIKit.button(["INTRO", "VERSE", "HOOK"][section], func(): loop_section = section if loop_section != section else -1; preview([0.0,8.0,20.0][section]))
		section_button.size_flags_horizontal = SIZE_EXPAND_FILL
		section_button.size_flags_stretch_ratio = [2.0,3.0,3.0][section]
		section_button.tooltip_text = Locale.text("arr_loop")
		sections.add_child(section_button)
	for lane in 4:
		var row = HBoxContainer.new()
		body.add_child(row)
		var label = UIKit.label(Locale.text("jam_lane_%d" % lane), 28)
		label.custom_minimum_size.x = 190
		row.add_child(label)
		for column in 8:
			var cell = IdeaCell.new()
			cell.name = "Lane%dStep%d" % [lane, column]
			cell.row = lane; cell.col = column
			cell.custom_minimum_size = Vector2(166, 72)
			cell.size_flags_horizontal = SIZE_EXPAND_FILL
			cell.text = str(column + 1)
			for p in meeting["placed"]:
				if int(p["row"]) == lane and column >= int(p["col"]) and column < int(p["col"]) + int(meeting["deck"][p["block"]]["width"]):
					cell.occupied = int(p["block"])
					cell.text = str(meeting["deck"][p["block"]]["genre"])
					cell.modulate = Data.GENRE_COLORS.get(cell.text, Color.WHITE).lerp(Color.WHITE, 0.55)
					var pitch = int(meeting["deck"][p["block"]].get("transpose", 0))
					if pitch != 0 and lane != 3: cell.text += " %+d" % pitch
					cell.theme_type_variation = "ConfirmButton"
			cell.block_dropped.connect(place)
			cell.block_removed.connect(_remove_clip)
			cell.pressed.connect(func():
				if selected >= 0: place(selected, cell.row, cell.col)
				elif cell.occupied >= 0: inspected = cell.occupied; refresh())
			cell.self_modulate = [Color("b0d6d0"), Color("bcc9e2"), Color("f0d29c")][0 if column < 2 else (1 if column < 5 else 2)]
			row.add_child(cell)
			cells.append(cell)
	var footer = HBoxContainer.new()
	body.add_child(footer)
	var result = IdeaRules.score(meeting)
	var energy_label = UIKit.label(Locale.text("arr_energy"), 28)
	energy_label.custom_minimum_size.x = 190
	footer.add_child(energy_label)
	for value in result["energy"]:
		var meter = ProgressBar.new()
		meter.custom_minimum_size = Vector2(0, 24)
		meter.size_flags_horizontal = SIZE_EXPAND_FILL
		meter.max_value = 1.0; meter.value = value; meter.show_percentage = false
		footer.add_child(meter)
		energy_bars.append(meter)
	body.add_child(UIKit.label(Locale.text("arr_density", [roundi(result["density"] * 100)]), 28))

	var spacer = Control.new()
	spacer.size_flags_vertical = SIZE_EXPAND_FILL
	body.add_child(spacer)
	_build_transport(body, meeting)


func start_timer() -> void:
	if not Game.idea_meeting.is_empty(): Game.idea_meeting["phase"] = "playing"; refresh()

func _finish_walkthrough() -> void:
	_guide_step = -1
	refresh()

func place(block: int, row: int, col: int) -> void:
	if not IdeaRules.can_place(Game.idea_meeting, block, row, col): return
	remember()
	if Game.idea_meeting.get("copy_next", false):
		var clone: Dictionary = Game.idea_meeting["deck"][block].duplicate(true)
		clone["palette"] = false
		block = Game.idea_meeting["deck"].size()
		clone["id"] = block
		Game.idea_meeting["deck"].append(clone)
		Game.idea_meeting.erase("copy_next")
	var transpose: Variant = PITCH_STEPS[pitch_step] if pitch_changed or Game.idea_meeting["deck"][block].get("palette", false) else null
	if Game.place_idea(block, row, col, transpose):
		selected = -1
		pitch_changed = false
		player.stop()
		var placed: Dictionary = Game.idea_meeting["placed"].back().duplicate()
		placed["col"] = 0
		var notes = IdeaMusic.events(Game.idea_meeting["deck"], [placed])
		var wav = AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = IdeaMusic.RATE
		wav.data = IdeaMusic.pcm(notes, int(Game.idea_meeting["bpm"]), 0.45)
		audition.stream = wav
		audition.play()
		Game.save_game()
		call_deferred("refresh")

func _remove_clip(id: int) -> void:
	remember()
	inspected = -1
	Game.remove_idea(id)
	player.stop()
	audition.stop()
	Game.save_game()
	refresh()

func preview(from_beat: float = 0.0) -> void:
	if Game.idea_meeting.is_empty(): return
	audition.stop()
	var notes = IdeaMusic.events(Game.idea_meeting["deck"], Game.idea_meeting["placed"])
	if notes.is_empty(): return
	_preview_bpm = int(Game.idea_meeting["bpm"])
	var wav = IdeaMusic.stream(notes, _preview_bpm)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = int((64 if Game.idea_meeting.get("freeform", false) else 8) * 30.0 / _preview_bpm * IdeaMusic.RATE)
	if loop_section >= 0:
		wav.loop_begin = int([0.0,8.0,20.0][loop_section] * 60.0 / _preview_bpm * IdeaMusic.RATE)
		wav.loop_end = int([8.0,20.0,32.0][loop_section] * 60.0 / _preview_bpm * IdeaMusic.RATE)
	player.stream = wav
	player.stream_paused = false
	player.play(from_beat * 60.0 / _preview_bpm)

func submit() -> void:
	var result = Game.finish_idea_meeting()
	if not result.is_empty(): Game.alice_notice.emit(CompositionDesign.report(result))

func snapshot() -> Dictionary:
	var m = Game.idea_meeting
	return {"deck": m["deck"].duplicate(true), "placed": m["placed"].duplicate(true), "bpm": m["bpm"]}

func remember() -> void:
	if Game.idea_meeting.is_empty(): return
	var m = Game.idea_meeting
	if not m.has("undo"): m["undo"] = []
	m["undo"].append(snapshot())
	if m["undo"].size() > 30: m["undo"].pop_front()
	m["redo"] = []

func restore_history(source: String, destination: String) -> void:
	var m = Game.idea_meeting
	if m.get(source, []).is_empty(): return
	if not m.has(destination): m[destination] = []
	m[destination].append(snapshot())
	var state: Dictionary = m[source].pop_back()
	for key in state: m[key] = state[key]
	selected = -1; inspected = -1
	stop_playback()
	Game.save_game()
	refresh()

func undo() -> void:
	restore_history("undo", "redo")

func redo() -> void:
	restore_history("redo", "undo")

func audition_clip(id: int) -> void:
	var notes = IdeaMusic.events(Game.idea_meeting["deck"], [{"block": id, "row": 0, "col": 0}])
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = IdeaMusic.RATE
	wav.data = IdeaMusic.pcm(notes, int(Game.idea_meeting["bpm"]), 1.2)
	audition.stream = wav
	audition.play()

func change_style() -> void:
	if inspected < 0: return
	remember()
	var clip: Dictionary = Game.idea_meeting["deck"][inspected]
	var style = (int(clip.get("style", 0)) + 1) % 3
	for candidate in Game.idea_meeting["deck"]:
		if candidate.get("palette", false) and candidate["genre"] == clip["genre"] and candidate.get("style", 0) == style:
			clip["style"] = style
			clip["notes"] = candidate["notes"].duplicate(true)
			break
	stop_playback()
	Game.save_game()
	refresh()
