class_name UIKit
extends RefCounted
const DEFAULT_FONT_SIZE := 36

static func readable_font() -> Font:
	return preload("res://fonts/2005_iannnnnAMD.ttf")

static func label(value: String, font_size: int = 28) -> Label:
	var node = Label.new()
	node.text = Locale.display_game_text(value)
	node.add_theme_font_size_override("font_size", maxi(DEFAULT_FONT_SIZE, font_size))
	node.autowrap_mode = TextServer.AUTOWRAP_OFF
	return node

static func button(value: String, callback: Callable, min_width: float = 0, kind: String = "") -> Button:
	var node = Button.new()
	node.text = Locale.display_game_text(value)
	node.custom_minimum_size = Vector2(min_width, 52)
	node.add_theme_font_size_override("font_size", DEFAULT_FONT_SIZE)
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if kind != "":
		node.theme_type_variation = kind
	elif value in [Locale.text("begin"), Locale.text("accept_continue"), Locale.text("save")]:
		node.theme_type_variation = "ConfirmButton"
	elif value in [Locale.text("close"), Locale.text("back"), Locale.text("home_quit"), Locale.text("signout"), Locale.text("quit")]:
		node.theme_type_variation = "CancelButton"
	node.pressed.connect(callback)
	return node

static func centered_window(owner: Control, width: float = 1260, height: float = 800) -> VBoxContainer:
	var dim = ColorRect.new()
	dim.color = Color(0.025, 0.035, 0.065, 0.90)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	owner.add_child(dim)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	owner.add_child(center)
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, height)
	center.add_child(panel)
	var margin = MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)
	var body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	margin.add_child(body)
	return body

static func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
