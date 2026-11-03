class_name IdeaCell
extends Button
var row := 0
var col := 0
var occupied := -1
signal block_dropped(block: int, row: int, col: int)
signal block_removed(block: int)

func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("idea_block") and Game.idea_meeting.get("phase", "") in ["ready", "playing"] and IdeaRules.can_place(Game.idea_meeting, int(data["idea_block"]), row, col)

func _drop_data(_position: Vector2, data: Variant) -> void:
	block_dropped.emit(int(data["idea_block"]), row, col)

func _get_drag_data(_position: Vector2) -> Variant:
	if occupied < 0 or Game.idea_meeting.get("phase", "") not in ["ready", "playing"]: return null
	set_drag_preview(UIKit.label(text, 30))
	return {"idea_block": occupied}

func _gui_input(event: InputEvent) -> void:
	if occupied >= 0 and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		block_removed.emit(occupied)
		accept_event()
