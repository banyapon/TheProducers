class_name UIPanel
extends Control
## Base for modal windows: pauses the clock while open; subclasses override refresh().
## Also has small builders for the list rows that every board uses.

signal closed


func _ready() -> void:
	hide()


func open() -> void:
	if not visible:
		show()
		Game.push_pause()
	refresh()


func close() -> void:
	if not visible:
		return
	hide()
	Game.pop_pause()
	closed.emit()


func refresh() -> void:
	pass


func _refresh_if_open() -> void:
	if visible:
		refresh()


func _on_close_pressed() -> void:
	close()


static func clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


static func make_square(color: Color, size := 56.0) -> ColorRect:
	var square = ColorRect.new()
	square.color = color
	square.custom_minimum_size = Vector2(size, size)
	square.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	square.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return square


static func make_note(text: String) -> Label:
	var label = Label.new()
	label.text = text
	label.modulate = Color(1, 1, 1, 0.6)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


## A list row: 1:1 color square, title, detail text, and buttons given as [[text, Callable, disabled?], ...].
static func make_row(color: Color, title: String, detail: String, buttons: Array = []) -> PanelContainer:
	var panel = PanelContainer.new()
	var hb = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	panel.add_child(hb)
	hb.add_child(make_square(color))
	var vb = VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(vb)
	var title_label = Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 40)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(title_label)
	var detail_label = Label.new()
	detail_label.text = detail
	detail_label.add_theme_font_size_override("font_size", 36)
	detail_label.modulate = Color(0.85, 0.87, 0.92)
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(detail_label)
	var buttons_box = VBoxContainer.new()
	buttons_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(buttons_box)
	for spec in buttons:
		var b = Button.new()
		b.text = spec[0]
		b.pressed.connect(spec[1])
		b.disabled = spec.size() > 2 and spec[2]
		buttons_box.add_child(b)
	return panel
