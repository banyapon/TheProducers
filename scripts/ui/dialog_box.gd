class_name DialogBox
extends Control
## Nodes are placed in dialog_box.tscn. Talk flows in main.gd call open(), say(), and ask().

signal opened
signal closed
signal advanced
signal choice_selected(index: int)
const CHARS_PER_SECOND := 70.0
@onready var left_portrait: PortraitView = $ProducerPortrait
@onready var right_portrait: PortraitView = $PartnerPortrait
@onready var alice_portrait: PortraitView = $AliceAdviser
@onready var speaker_label: Label = $BottomDialog/Row/Center/Speaker
@onready var text_label: Label = $BottomDialog/Row/Center/Line
@onready var choices_box: GridContainer = $BottomDialog/Row/Center/Choices
@onready var next_hint: Button = $BottomDialog/Row/Center/NextHint
@onready var box: PanelContainer = $BottomDialog
@onready var choice_pager: HBoxContainer = $BottomDialog/Row/Center/ChoicePager
var _options: Array = []
var _waiting = false
var _tween: Tween
var _left: Dictionary
var _right: Dictionary

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	speaker_label.clip_text = true
	speaker_label.add_theme_font_override("font", UIKit.readable_font())
	speaker_label.add_theme_font_size_override("font_size", 44)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_font_override("font", UIKit.readable_font())
	text_label.add_theme_font_size_override("font_size", 44)
	next_hint.custom_minimum_size.y = 52
	next_hint.add_theme_font_size_override("font_size", 36)
	next_hint.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	next_hint.pressed.connect(_advance)
	next_hint.text = Locale.text("next_hint")
	hide()

func _anchor_portraits(_right_is_principal: bool = false) -> void:
	for portrait in [left_portrait, right_portrait, alice_portrait]:
		portrait.custom_minimum_size = Vector2.ZERO
		portrait.size = Vector2(192,192)
	left_portrait.position = box.position + Vector2(-32, box.size.y - 192)
	right_portrait.position = box.position + Vector2(box.size.x - 160, box.size.y - 192)
	alice_portrait.position = box.position + Vector2(box.size.x - 256, box.size.y - 216)

func _process(_delta: float) -> void:
	if visible: _anchor_portraits()

func _resize_box(value: String, choosing: bool) -> void:
	var columns = 3 if _options.size() >= 7 else 2
	var height = 200 + ceili(_options.size() / float(columns)) * 62 if choosing else clampf(175 + ceili(value.length() / 85.0) * 32, 260, 340)
	var width = 1440 if choosing else 1280
	box.offset_left = -width / 2.0
	box.offset_right = width / 2.0
	box.offset_top = -height - 24
	box.offset_bottom = -24
	_anchor_portraits()

func open(left: Dictionary, right: Dictionary) -> void:
	_left = left
	_right = right
	_anchor_portraits(right.get("principal", false))
	left_portrait.configure(str(left.get("art_id", "producer")))
	right_portrait.configure(str(right.get("art_id", Art.model_id(right))), true)
	alice_portrait.configure(Game.assistant_portrait()["art_id"], true)
	alice_portrait.visible = right.get("adviser", false)
	_clear_choices()
	text_label.text = ""
	if not visible:
		show()
		Game.push_pause()
		opened.emit()

func close() -> void:
	if not visible: return
	_waiting = false
	left_portrait.talking = false
	right_portrait.talking = false
	alice_portrait.talking = false
	_clear_choices()
	hide()
	Game.pop_pause()
	closed.emit()

func say(side: String, value: String) -> void:
	_show_line(side, value)
	_resize_box(value, false)
	next_hint.text = Locale.text("next_hint")
	next_hint.show()
	_waiting = true
	await advanced

func ask(side: String, value: String, options: Array) -> int:
	_show_line(side, value)
	_waiting = false
	next_hint.hide()
	_options = options.duplicate()
	_resize_box(value, true)
	_render_options()
	var index: int = await choice_selected
	_clear_choices()
	return index

func _render_options() -> void:
	UIKit.clear(choices_box)
	UIKit.clear(choice_pager)
	choices_box.columns = 3 if _options.size() >= 7 else 2
	for i in _options.size():
		var button = UIKit.button(str(_options[i]), func(): choice_selected.emit(i))
		button.name = "DialogChoice%d" % i
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(0, 54)
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		button.add_theme_font_override("font", UIKit.readable_font())
		button.add_theme_font_size_override("font_size", 36)
		if i == 0: button.theme_type_variation = "ConfirmButton"
		elif i == _options.size()-1: button.theme_type_variation = "CancelButton"
		choices_box.add_child(button)
	choice_pager.hide()

func _show_line(side: String, value: String) -> void:
	_clear_choices()
	alice_portrait.visible = _right.get("adviser", false) or side == "alice"
	var data = _left if side == "left" else (Game.assistant_portrait() if side == "alice" else _right)
	speaker_label.text = Locale.display_game_text(str(data.get("name", "")))
	text_label.text = Locale.display_game_text(Locale.speaker_line(value, str(data.get("gender", Art.gender(str(data.get("art_id", "")))))))
	if data.get("assistant", false): text_label.text = Locale.display_game_text(Locale.assistant_line(value))
	text_label.visible_ratio = 0.0
	left_portrait.modulate = Color.WHITE if side == "left" else Color(0.55, 0.55, 0.65)
	right_portrait.modulate = Color.WHITE if side == "right" else Color(0.55, 0.55, 0.65)
	left_portrait.talking = side == "left"
	right_portrait.talking = side == "right"
	alice_portrait.talking = side == "alice"
	alice_portrait.modulate = Color.WHITE if side == "alice" else Color(0.75, 0.75, 0.85)
	if _tween: _tween.kill()
	_tween = create_tween()
	_tween.tween_property(text_label, "visible_ratio", 1.0, maxf(0.15, value.length() / CHARS_PER_SECOND))
	_tween.tween_callback(func(): left_portrait.talking = false; right_portrait.talking = false; alice_portrait.talking = false)

func _advance() -> void:
	if not _waiting: return
	if text_label.visible_ratio < 1.0:
		if _tween: _tween.kill()
		text_label.visible_ratio = 1.0
		left_portrait.talking = false
		right_portrait.talking = false
		alice_portrait.talking = false
		return
	_waiting = false
	next_hint.hide()
	advanced.emit()

func _input(event: InputEvent) -> void:
	if not visible or not _waiting or _pause_overlay_open(): return
	if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		get_viewport().set_input_as_handled()
		_advance()

func _clear_choices() -> void:
	UIKit.clear(choices_box)
	if choice_pager: choice_pager.hide()

func _pause_overlay_open() -> bool:
	var main = get_tree().current_scene
	if main and main.get("shell") is AppShell:
		return main.shell.visible
	return false
