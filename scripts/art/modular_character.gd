class_name ModularCharacter
extends Node2D
## Compatibility facade: every full-body view now renders native assets/sprites.
## configure("producer", "suit", {"cloth_tint":"#7799cc"})
const RECIPE_PATH = "res://data/character_parts.json"
static var _config: Dictionary = {}
var parts: Dictionary = {}
var animation := "idle"
var frame := 0
var elapsed := 0.0

static func catalogue() -> Dictionary:
	if _config.is_empty():
		_config = JSON.parse_string(FileAccess.get_file_as_string(RECIPE_PATH))
	return _config

var body: AnimatedSprite2D

func configure(character_id: String, _outfit: String = "", _colors: Dictionary = {}) -> bool:
	if not is_instance_valid(body):
		body = AnimatedSprite2D.new()
		body.centered = false
		body.position = Vector2(-80, -137)
		add_child(body)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.sprite_frames = Art.office_frames(character_id)
	play(animation)
	return true

func set_pose(state: String, column: int = 0) -> void:
	if not is_instance_valid(body): return
	animation = "talk" if state == "upset" else state
	if not body.sprite_frames.has_animation(animation): animation = "idle"
	body.animation = animation
	frame = posmod(column, 9)
	body.frame = frame

func play(state: String) -> void:
	set_pose(state)
	if is_instance_valid(body): body.play(animation)
