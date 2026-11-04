class_name PortraitView
extends TextureRect
var art_id = "producer"
var talking = false
var _clock = 0.0
var _blink_at = 2.7
var _frame = -1
var fullbody: ModularCharacter
var crop_half := false
var body_pose := "idle"

## Uses the same native sprite animations as world actors.
func use_fullbody(enabled: bool, half: bool = false) -> void:
	crop_half = half
	clip_contents = enabled
	if enabled:
		if not is_instance_valid(fullbody):
			fullbody = ModularCharacter.new()
			fullbody.name = "FullBody"
			add_child(fullbody)
		fullbody.show()
		fullbody.configure(art_id)
		texture = null
		_layout_body()
	else:
		if is_instance_valid(fullbody): fullbody.hide()
		_frame = -1
		_update_frame()

func _layout_body() -> void:
	if not is_instance_valid(fullbody) or not fullbody.visible: return
	# Native 160px cell: hair near y=23, feet at y=137, waist near y=85.
	var zoom = minf(size.x / (64.0 if crop_half else 80.0), size.y / (62.0 if crop_half else 114.0))
	fullbody.scale = Vector2(-zoom if flip_h else zoom, zoom)
	fullbody.position = Vector2(size.x * 0.5, 114.0 * zoom if crop_half else size.y)
	var pose = "talk" if talking else body_pose
	if fullbody.animation != pose: fullbody.play(pose)

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func configure(id: String, face_left: bool = false) -> void:
	art_id = id
	flip_h = face_left
	_frame = -1
	if is_instance_valid(fullbody) and fullbody.visible:
		fullbody.configure(id)
		_layout_body()
		return
	_update_frame()

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if is_instance_valid(fullbody) and fullbody.visible:
		_layout_body()
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
