class_name TrophyBadge
extends Control

func _ready() -> void:
	custom_minimum_size = Vector2(64, 64)
	mouse_filter = MOUSE_FILTER_IGNORE

func _draw() -> void:
	# Sixteen native pixels across, drawn as whole four-pixel blocks.
	var gold = Color("ffd166")
	var shadow = Color("b87528")
	for rect in [Rect2(4, 2, 8, 2), Rect2(5, 4, 6, 4), Rect2(6, 8, 4, 2), Rect2(7, 10, 2, 3), Rect2(4, 13, 8, 2), Rect2(2, 3, 2, 5), Rect2(12, 3, 2, 5), Rect2(3, 7, 3, 2), Rect2(10, 7, 3, 2)]:
		draw_rect(Rect2(rect.position * 4, rect.size * 4), shadow)
	for rect in [Rect2(4, 2, 8, 1), Rect2(5, 3, 6, 4), Rect2(6, 7, 4, 2), Rect2(7, 9, 2, 3), Rect2(4, 12, 8, 2), Rect2(2, 3, 1, 4), Rect2(13, 3, 1, 4)]:
		draw_rect(Rect2(rect.position * 4, rect.size * 4), gold)
	draw_rect(Rect2(24, 12, 8, 12), Color("fff0af"))
