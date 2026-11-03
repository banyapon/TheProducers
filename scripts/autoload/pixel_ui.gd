extends Node
## The PNGs are authored at native resolution in Aseprite, exported at integer 2x.
const ROOT := "res://assets/ui/pixel/"

func _ready() -> void:
	Input.set_custom_mouse_cursor(load(ROOT + "cursor-arrow-2x.png"), Input.CURSOR_ARROW, Vector2(2, 2))
	Input.set_custom_mouse_cursor(load(ROOT + "cursor-hand-2x.png"), Input.CURSOR_POINTING_HAND, Vector2(12, 2))
	Input.set_custom_mouse_cursor(load(ROOT + "cursor-text-2x.png"), Input.CURSOR_IBEAM, Vector2(24, 22))
	get_tree().node_added.connect(_style_node)

func _style_node(node: Node) -> void:
	if node is BaseButton:
		node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if node is CanvasItem:
		node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _exit_tree() -> void:
	# Release the hardware cursor textures before RenderingServer is destroyed.
	for shape in [Input.CURSOR_ARROW, Input.CURSOR_POINTING_HAND, Input.CURSOR_IBEAM]:
		Input.set_custom_mouse_cursor(null, shape)
