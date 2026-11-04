class_name ModularCharacter
extends Node2D
## All parts share a 400x400 cell and a feet anchor at (200,400).
## configure("producer", "suit", {"cloth_tint":"#7799cc"})
const RECIPE_PATH = "res://data/character_parts.json"
const PALETTE_SHADER = preload("res://scripts/art/character_palette.gdshader")
static var _config: Dictionary = {}
var parts: Dictionary = {}
var animation := "idle"
var frame := 0
var elapsed := 0.0

static func catalogue() -> Dictionary:
	if _config.is_empty():
		_config = JSON.parse_string(FileAccess.get_file_as_string(RECIPE_PATH))
	return _config

func configure(character_id: String, outfit: String = "", colors: Dictionary = {}) -> bool:
	var config = catalogue()
	if not config["characters"].has(character_id): return false
	var recipe: Dictionary = config["characters"][character_id].duplicate(true)
	recipe.merge(Game.character_appearance.get(character_id, {}), true)
	if outfit.is_empty(): outfit = recipe["body"]
	if not outfit in config["outfits"]: return false
	recipe.merge(colors, true)
	var donor: Dictionary = config["characters"][character_id]
	if outfit != donor["body"]:
		donor = config["characters"][config["outfit_templates"][outfit]]
	for part in parts.values(): remove_child(part); part.queue_free()
	parts.clear()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for key in config["layer_order"]:
		var part = Sprite2D.new()
		var source_recipe: Dictionary = donor if key in ["body", "arms", "foreground"] else config["characters"][character_id]
		var path: String = source_recipe["parts"][key]
		part.texture = load(path)
		part.name = key.capitalize()
		part.hframes = 4; part.vframes = 4
		part.centered = false
		part.position = Vector2(-200, -400)
		# New sheets are already colored. Replace only changed palette entries.
		part.material = _palette_material(key, source_recipe["palette"], recipe)
		add_child(part); parts[key] = part
	set_pose(animation, frame)
	return true

static func _ramp(value: String) -> Array[Color]:
	var c = Color(value)
	var r = roundf(c.r * 255.0); var g = roundf(c.g * 255.0); var b = roundf(c.b * 255.0)
	return [Color(floorf(r * 0.69) / 255.0, floorf(g * 0.67) / 255.0, floorf(b * 0.76) / 255.0), c,
		Color(floorf(r + (255.0-r)*0.32)/255.0, floorf(g + (250.0-g)*0.32)/255.0, floorf(b + (244.0-b)*0.32)/255.0)]

static func _palette_material(part: String, palette: Dictionary, recipe: Dictionary) -> ShaderMaterial:
	var materials: Array = ["pants"] if part == "legs" else (["shoes"] if part == "shoes" else (["cloth", "inner", "skin"] if part in ["body", "arms", "foreground"] else []))
	var sources: Array[Color] = []; var targets: Array[Color] = []
	for key in materials:
		var source_color = str(palette.get(key, "#ffffff"))
		var target_color = str(recipe.get(key + "_tint", source_color))
		if Color(source_color).is_equal_approx(Color(target_color)): continue
		sources.append_array(_ramp(source_color)); targets.append_array(_ramp(target_color))
	if sources.is_empty(): return null
	var material = ShaderMaterial.new(); material.shader = PALETTE_SHADER
	var count = sources.size()
	while sources.size() < 15: sources.append(Color.TRANSPARENT); targets.append(Color.TRANSPARENT)
	material.set_shader_parameter("source_colors", sources)
	material.set_shader_parameter("target_colors", targets)
	material.set_shader_parameter("color_count", count)
	return material

func set_pose(state: String, column: int = 0) -> void:
	var row = catalogue()["rows"].find(state)
	if row < 0: return
	animation = state; frame = posmod(column, 4)
	for part in parts.values(): part.frame = row * 4 + frame

func play(state: String) -> void:
	if not state in catalogue()["rows"]: return
	elapsed = 0.0
	set_pose(state)

func _process(delta: float) -> void:
	if parts.is_empty() or not is_visible_in_tree(): return
	elapsed += delta
	var interval = 1.0 / float(catalogue()["fps"][animation])
	if elapsed >= interval:
		var steps = int(elapsed / interval)
		elapsed = fmod(elapsed, interval)
		set_pose(animation, frame + steps)
