class_name IdeaTile
extends PanelContainer
var block_id := 0
var caption := ""
var disabled := false
signal selected(block: int)

func _ready() -> void:
	mouse_default_cursor_shape = CURSOR_ARROW if disabled else CURSOR_DRAG

func _gui_input(event: InputEvent) -> void:
	if disabled: return
	# Rebuilding on mouse-down destroys the drag source before the movement threshold.
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not get_viewport().gui_is_dragging():
		selected.emit(block_id)

func _get_drag_data(_position: Vector2) -> Variant:
	if disabled: return null
	if Game.idea_meeting.get("phase", "") not in ["ready", "playing"]: return null
	var preview = UIKit.label(caption, 32)
	set_drag_preview(preview)
	return {"idea_block": block_id}
