class_name ImprovisePanel
extends Control

signal saved(notes: Array, lane: int, first_bar: int, bars: int)
signal dismissed
signal prepare_backing(first_bar: int, lane: int)
signal recording_started(first_bar: int, lane: int)
signal recording_stopped

const KEY_CODES := [KEY_A, KEY_W, KEY_S, KEY_E, KEY_D, KEY_F, KEY_T, KEY_G, KEY_Y, KEY_H, KEY_U, KEY_J, KEY_K]
const KEY_NAMES := ["A", "W", "S", "E", "D", "F", "T", "G", "Y", "H", "U", "J", "K"]
const NOTE_NAMES := ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B", "C"]
const DRUM_KEYS := [KEY_Z, KEY_X, KEY_C]
const DRUM_NOTES := [36, 38, 42]
var bpm := 120
var lane := 0
var first_bar := 0
var bars := 1
var octave := 4
var notes: Array = []
var recording := false
var counting := false
var elapsed := 0.0
var _last_click := -99
var _held: Dictionary = {}
var _voices: Dictionary = {}
var _sounds: Dictionary = {}
var _buttons: Dictionary = {}
var _settings: Array[OptionButton] = []
var status: Label
var roll: Control
var record_button: Button
var save_button: Button
var preview_button: Button
var preview_player: AudioStreamPlayer
var click_player: AudioStreamPlayer

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var body = UIKit.centered_window(self, 1500, 900)
	body.add_theme_constant_override("separation", 16)
	var header = HBoxContainer.new()
	body.add_child(header)
	var title = UIKit.label("Improvise / เล่นและบันทึกไลน์", 38)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(UIKit.button("Cancel take & back", func(): stop(); dismissed.emit()))
	body.add_child(UIKit.label("เล่นด้วยเมาส์หรือปุ่ม A–K • กลอง Z / X / C • นับเข้า 4 จังหวะก่อนอัด", 28))
	var settings = HBoxContainer.new()
	body.add_child(settings)
	var track = OptionButton.new()
	for caption in ["Melody", "Harmony", "Bass", "Beat / Drums"]: track.add_item(caption)
	track.select(lane)
	track.item_selected.connect(func(index: int): _release_all(); lane = index; _update_status())
	settings.add_child(track); _settings.append(track)
	var start = OptionButton.new()
	for i in 8: start.add_item("Start: Bar %d" % (i + 1))
	start.select(first_bar)
	start.item_selected.connect(func(index: int): first_bar = index; _update_status())
	settings.add_child(start); _settings.append(start)
	var length = OptionButton.new()
	for i in 8: length.add_item("Record %d bar(s)" % (i + 1))
	length.item_selected.connect(func(index: int): bars = index + 1; _update_status())
	settings.add_child(length); _settings.append(length)
	var register = OptionButton.new()
	for i in range(2, 7): register.add_item("Octave %d" % i)
	register.select(octave - 2)
	register.item_selected.connect(func(index: int): _release_all(); octave = index + 2; _warm_sounds(); _update_status())
	settings.add_child(register); _settings.append(register)
	settings.add_child(UIKit.label("%d BPM" % bpm, 30))
	status = UIKit.label("", 28)
	body.add_child(status)
	var keyboard = Control.new()
	keyboard.custom_minimum_size.y = 260
	body.add_child(keyboard)
	var white_notes = [0,2,4,5,7,9,11,12]
	for i in white_notes.size():
		var note: int = white_notes[i]
		var key = _key_button(NOTE_NAMES[note] + "\n" + KEY_NAMES[note], false)
		keyboard.add_child(key)
		key.anchor_left = i / 8.0; key.anchor_right = (i + 1) / 8.0
		key.anchor_bottom = 1.0; key.offset_right = -4
		key.button_down.connect(_press.bind(note, false))
		key.button_up.connect(_release.bind(note, false))
		_buttons[note] = key
	for pair in [[1,1], [3,2], [6,4], [8,5], [10,6]]:
		var note: int = pair[0]
		var key = _key_button(KEY_NAMES[note], true)
		keyboard.add_child(key)
		key.anchor_left = (pair[1] - 0.30) / 8.0; key.anchor_right = (pair[1] + 0.30) / 8.0
		key.anchor_bottom = 0.60
		key.button_down.connect(_press.bind(note, false))
		key.button_up.connect(_release.bind(note, false))
		_buttons[note] = key
	var pads = HBoxContainer.new()
	body.add_child(pads)
	for i in 3:
		var pad = UIKit.button(["Z • Kick", "X • Snare", "C • Hi-hat"][i], func(): pass)
		pad.focus_mode = FOCUS_NONE
		pad.size_flags_horizontal = SIZE_EXPAND_FILL
		pad.custom_minimum_size.y = 80
		pad.button_down.connect(_press.bind(i, true))
		pad.button_up.connect(_release.bind(i, true))
		pads.add_child(pad)
		_buttons[100 + i] = pad
	roll = Control.new()
	roll.custom_minimum_size.y = 110
	roll.size_flags_vertical = SIZE_EXPAND_FILL
	roll.draw.connect(_draw_roll)
	body.add_child(roll)
	var actions = HBoxContainer.new()
	body.add_child(actions)
	record_button = UIKit.button("Record / อัดใหม่", start_recording)
	actions.add_child(record_button)
	actions.add_child(UIKit.button("Stop", stop))
	preview_button = UIKit.button("Listen to take", listen)
	actions.add_child(preview_button)
	actions.add_child(UIKit.button("Clear take", func(): stop(); notes.clear(); _update_status()))
	save_button = UIKit.button("Save line & back", func():
		stop()
		if not notes.is_empty(): saved.emit(notes.duplicate(true), lane, first_bar, bars))
	actions.add_child(save_button)
	preview_player = AudioStreamPlayer.new(); preview_player.bus = "Composer"; add_child(preview_player)
	click_player = AudioStreamPlayer.new(); click_player.bus = "Composer"; click_player.volume_db = -10; add_child(click_player)
	click_player.stream = _sound(84, false)
	_warm_sounds()
	_update_status()

func _key_button(caption: String, black: bool) -> Button:
	var key = Button.new()
	key.text = caption
	key.focus_mode = FOCUS_NONE
	key.alignment = HORIZONTAL_ALIGNMENT_CENTER
	key.add_theme_font_size_override("font_size", 32)
	for state in ["normal", "hover", "pressed"]:
		var style = StyleBoxFlat.new()
		style.bg_color = Color("ffd166") if state == "pressed" else (Color("202638") if black else Color("fff8e9"))
		style.border_color = Color("0c1320")
		style.set_border_width_all(2)
		key.add_theme_stylebox_override(state, style)
		key.add_theme_color_override("font_" + ("color" if state == "normal" else state + "_color"), Color.WHITE if black else Color("172235"))
	return key

func _sound(pitch: int, drum: bool) -> AudioStreamWAV:
	var id = "%d:%s" % [pitch, drum]
	if _sounds.has(id): return _sounds[id]
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS; wav.mix_rate = IdeaMusic.RATE
	wav.data = IdeaMusic.pcm([{"step":0, "note":pitch, "length":4, "drum":drum, "instrument":-1 if drum else 0}], 120, 1.0)
	_sounds[id] = wav
	return wav

func _warm_sounds() -> void:
	for i in 13: _sound((octave + 1) * 12 + i, false)
	for pitch in DRUM_NOTES: _sound(pitch, true)

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey or event.echo: return
	if event.alt_pressed or event.ctrl_pressed or event.meta_pressed: return
	var key = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	var index = KEY_CODES.find(key)
	var drum = false
	if index < 0: index = DRUM_KEYS.find(key); drum = true
	if index < 0: return
	if event.pressed: _press(index, drum)
	else: _release(index, drum)
	get_viewport().set_input_as_handled()

func _press(index: int, drum: bool) -> void:
	var id = 100 + index if drum else index
	if _held.has(id): return
	# Both instruments can be auditioned; a take records only its selected track.
	var pitch: int = DRUM_NOTES[index] if drum else (octave + 1) * 12 + index
	var voice = AudioStreamPlayer.new()
	voice.bus = "Composer"; voice.stream = _sound(pitch, drum)
	add_child(voice); voice.play(); voice.finished.connect(voice.queue_free)
	_voices[id] = voice
	var note_index = -1
	if recording and drum == (lane == 3):
		var beat = clampf(elapsed * bpm / 60.0, 0.0, bars * 4.0 - 0.001)
		note_index = notes.size()
		notes.append({"beat":beat, "note":pitch, "duration":0.25 if drum else 0.1})
	_held[id] = {"index":note_index, "drum":drum}
	_buttons[id].modulate = Color("ffd166")
	roll.queue_redraw()

func _release(index: int, drum: bool) -> void:
	var id = 100 + index if drum else index
	if not _held.has(id): return
	var held: Dictionary = _held[id]
	if int(held["index"]) >= 0 and not drum:
		var note: Dictionary = notes[int(held["index"])]
		note["duration"] = maxf(0.05, minf(elapsed * bpm / 60.0, bars * 4.0) - float(note["beat"]))
	if not drum and is_instance_valid(_voices.get(id)): _voices[id].queue_free()
	_voices.erase(id); _held.erase(id)
	_buttons[id].modulate = Color.WHITE
	roll.queue_redraw()

func _release_all() -> void:
	for id in _held.keys(): _release(int(id) - 100 if int(id) >= 100 else int(id), int(id) >= 100)

func start_recording() -> void:
	if first_bar + bars > 8: return
	stop(); notes.clear()
	prepare_backing.emit(first_bar, lane)
	elapsed = -4.0 * 60.0 / bpm
	counting = true; _last_click = -99
	_update_status()

func stop() -> void:
	_release_all()
	recording = false; counting = false
	if is_instance_valid(preview_player): preview_player.stop()
	if is_instance_valid(click_player): click_player.stop()
	recording_stopped.emit()
	_update_status()

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	if not counting and not recording: return
	elapsed += delta
	if counting and elapsed >= 0:
		_release_all(); counting = false; recording = true
		recording_started.emit(first_bar, lane)
	if recording and elapsed * bpm / 60.0 >= bars * 4.0:
		stop(); return
	var beat = floori(elapsed * bpm / 60.0)
	if beat != _last_click:
		_last_click = beat; click_player.play()
	_update_status()

func listen() -> void:
	stop()
	if notes.is_empty(): return
	var events: Array = []
	for note in notes:
		events.append({"step":float(note["beat"]) * 2, "note":note["note"], "length":float(note["duration"]) * 2,
			"drum":lane == 3, "voice":lane, "instrument":0 if lane != 3 else -1, "loop_steps":bars * 8})
	preview_player.stream = IdeaMusic.stream(events, bpm)
	preview_player.play()

func _update_status() -> void:
	if not is_instance_valid(status): return
	var busy = recording or counting
	for option in _settings: option.disabled = busy or not notes.is_empty()
	record_button.disabled = busy or first_bar + bars > 8
	save_button.disabled = busy or notes.is_empty()
	preview_button.disabled = busy or notes.is_empty()
	if counting: status.text = "Count in: %d" % maxi(1, ceili(-elapsed * bpm / 60.0))
	elif recording: status.text = "● REC  Bar %d / %d   Beat %d" % [mini(bars, int(elapsed * bpm / 240.0) + 1), bars, int(elapsed * bpm / 60.0) % 4 + 1]
	elif first_bar + bars > 8: status.text = "เลือกช่วงอัดไม่เกินห้องที่ 8"
	else: status.text = "%d notes • บันทึกแทนที่แทร็ก %s ห้อง %d–%d • Clear take เพื่อเปลี่ยนช่วงอัด" % [notes.size(), ["Melody","Harmony","Bass","Beat"][lane], first_bar + 1, first_bar + bars]
	roll.queue_redraw()

func _draw_roll() -> void:
	roll.draw_rect(Rect2(Vector2.ZERO, roll.size), Color("0c1524"))
	for beat in bars * 4 + 1:
		var x = roll.size.x * beat / (bars * 4.0)
		roll.draw_line(Vector2(x,0), Vector2(x,roll.size.y), Color("476075") if beat % 4 == 0 else Color("233247"))
	for note in notes:
		var x = float(note["beat"]) / (bars * 4.0) * roll.size.x
		var y = (1.0 - clampf((int(note["note"]) - (36 if lane == 3 else (octave + 1) * 12)) / 13.0, 0, 1)) * (roll.size.y - 12)
		roll.draw_rect(Rect2(x,y,maxf(4, float(note["duration"]) / (bars * 4.0) * roll.size.x),10), Color("ffd166"))
	if recording:
		var x = elapsed * bpm / 60.0 / (bars * 4.0) * roll.size.x
		roll.draw_line(Vector2(x,0), Vector2(x,roll.size.y), Color("ff647c"), 2)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready(): stop()
