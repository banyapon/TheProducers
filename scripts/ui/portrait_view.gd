class_name PortraitView
extends TextureRect
var art_id = "producer"
var talking = false
var _clock = 0.0
var _blink_at = 2.7
var _frame = -1

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func configure(id: String, face_left: bool = false) -> void:
	art_id = id
	flip_h = face_left
	_frame = -1
	_update_frame()

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_clock += delta
	if _clock > _blink_at + 0.15:
		_clock = 0.0
		_blink_at = randf_range(2.4, 4.7)
	_update_frame()

func _update_frame() -> void:
	var expression = (2 if _clock >= _blink_at else 0) + (1 if talking and int(_clock * 8.0) % 2 == 0 else 0)
	if expression != _frame:
		_frame = expression
		texture = Art.portrait(art_id, expression)
