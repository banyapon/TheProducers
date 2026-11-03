extends Node
## Validated local asset paths, normalized nearest-neighbour sheets and shared animation caches.
var npc_ids: Array[String] = []
var vip_ids: Array[String] = []
var _textures: Dictionary = {}
var _frames: Dictionary = {}
var _portraits: Dictionary = {}
const MAIN_SHEETS := {"producer": "res://assets/main/producer-mini-6x4.png", "alice": "res://assets/main/secret-mini-6x4.png"}
const MAIN_PORTRAITS := {"producer": "res://assets/main/producer-grey-pixel-2x2.png", "alice": "res://assets/main/secret-pixel-2x2.png"}
const INSTRUMENTS := ["guitar", "drums", "electone", "saxophone", "organ", "mic", "bass"]
const CHATS := ["555-laugh", "bruh-smirk", "gg-ez-troll", "sus-eyes", "nope-angry", "ok-sweat", "what-skull", "wow-fire", "afk-sleep", "ez-cry"]

func _ready() -> void:
	for dir in DirAccess.get_directories_at("res://assets/npc"):
		if dir.begins_with("npc-"):
			npc_ids.append(dir)
	for dir in DirAccess.get_directories_at("res://assets/vip"):
		if dir.begins_with("super-"):
			vip_ids.append(dir)
	npc_ids.sort()
	vip_ids.sort()

func texture(path: String, target: Vector2i = Vector2i.ZERO) -> Texture2D:
	if not path.begins_with("res://assets/") or not path.ends_with(".png"):
		return null
	var key = path + str(target)
	if _textures.has(key):
		return _textures[key]
	if not ResourceLoader.exists(path):
		return null
	var source: Texture2D = load(path)
	var result: Texture2D = source
	if target != Vector2i.ZERO and source.get_size() != Vector2(target):
		var image = source.get_image()
		image.resize(target.x, target.y, Image.INTERPOLATE_NEAREST)
		result = ImageTexture.create_from_image(image)
	_textures[key] = result
	return result

func model_id(model: Dictionary) -> String:
	if model.has("art_id"):
		return str(model["art_id"])
	return npc_ids[absi(str(model.get("id", model.get("name", "npc"))).hash()) % npc_ids.size()] if not npc_ids.is_empty() else "producer"

func gender(id: String) -> String:
	if id == "alice" or id.contains("female"):
		return "female"
	if id.begins_with("super-"):
		return "female" if int(id.right(2)) % 2 == 0 else "male"
	return "male"

func sheet_path(id: String) -> String:
	if MAIN_SHEETS.has(id):
		return MAIN_SHEETS[id]
	if id.begins_with("super-"):
		return "res://assets/vip/%s/%s-6x4.png" % [id, id]
	return "res://assets/npc/%s/sheet-6x4.png" % id

func frames(id: String) -> SpriteFrames:
	if _frames.has(id):
		return _frames[id]
	var sheet = texture(sheet_path(id), Vector2i(192, 192))
	if sheet == null:
		sheet = texture(MAIN_SHEETS["producer"], Vector2i(192, 192))
	var result = SpriteFrames.new()
	result.remove_animation("default")
	var names = ["idle", "walk", "sway", "talk"]
	for row in 4:
		result.add_animation(names[row])
		result.set_animation_speed(names[row], [4.5, 8.3, 5.55, 7.15][row])
		for column in 6:
			result.add_frame(names[row], atlas(sheet, Rect2(column * 32, row * 48, 32, 48)))
	_frames[id] = result
	return result

func atlas(sheet: Texture2D, region: Rect2) -> AtlasTexture:
	var result = AtlasTexture.new()
	result.atlas = sheet
	result.region = region
	return result

func portrait(id: String, expression: int = 0) -> Texture2D:
	var key = id + ":" + str(expression)
	if _portraits.has(key):
		return _portraits[key]
	var path = ""
	if MAIN_PORTRAITS.has(id):
		path = MAIN_PORTRAITS[id]
	else:
		var dir = "res://assets/%s/%s/" % ["vip" if id.begins_with("super-") else "npc", id]
		path = dir + "portrait-v2-2x2.png"
	var sheet = texture(path)
	if sheet == null:
		return null
	var cell = sheet.get_size() / 2.0
	var result = atlas(sheet, Rect2(Vector2(expression % 2, expression / 2) * cell, cell))
	_portraits[key] = result
	return result

func portrait_data(model: Dictionary) -> Dictionary:
	var id = model_id(model)
	return {"name": str(model.get("name", "NPC")), "art_id": id, "gender": str(model.get("gender", gender(id))), "color": model.get("color", Color.WHITE), "principal": id in ["producer", "alice"]}

func room(type: String, foreground: bool = false) -> Texture2D:
	var id = {"studio": "recording", "lobby": "lounge"}.get(type, type)
	return texture("res://assets/lots/rooms/%s-16x9-%s.png" % [id, "front" if foreground else "back"])

func instrument_info(id: String) -> Dictionary:
	var dimensions = {"drums": Vector2i(64, 64), "electone": Vector2i(64, 48), "organ": Vector2i(64, 64)}
	var anchors = {"drums": Vector2(32, 58), "electone": Vector2(32, 45), "organ": Vector2(32, 60)}
	return {"size": dimensions.get(id, Vector2i(32, 48)), "anchor": anchors.get(id, Vector2(16, 45)), "texture": texture("res://assets/instruments/%s-6frames.png" % id)}
