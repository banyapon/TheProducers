class_name SceneProp
extends AnimatedSprite2D
## Position is the ground anchor. Add background props before character nodes; bar uses foreground z=6.
const MANIFEST := "res://assets/props/manifest.json"
static var _catalog: Dictionary = {}
var prop_id := ""

static func catalogue() -> Dictionary:
 if _catalog.is_empty():
  _catalog = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))["props"]
 return _catalog

func configure(id: String, coat_color: Color = Color.WHITE) -> bool:
 if not catalogue().has(id): return false
 var spec: Dictionary = catalogue()[id]
 prop_id = id
 texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
 centered = false
 offset = -Vector2(spec.anchor[0], spec.anchor[1])
 z_index = int(spec.z_index)
 self_modulate = coat_color if spec.tintable else Color.WHITE
 sprite_frames = SpriteFrames.new()
 sprite_frames.set_animation_speed("default", float(spec.get("fps", 1)))
 var sheet = load(str(spec.texture)) as Texture2D
 for i in int(spec.frames):
  var frame_texture = AtlasTexture.new()
  frame_texture.atlas = sheet
  frame_texture.region = Rect2(i * int(spec.cell[0]), 0, int(spec.cell[0]), int(spec.cell[1]))
  sprite_frames.add_frame("default", frame_texture)
 play("default")
 return true
