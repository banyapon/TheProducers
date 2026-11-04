extends Control

func _ready() -> void:
	Game.running = false
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var body = UIKit.centered_window(self, 1100, 600)
	var heading = UIKit.label("GAME OVER", 80)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_color_override("font_color", Color("ef7967"))
	body.add_child(heading)
	var message = UIKit.label("คุณล้มเหลวในการทำธุรกิจนี้\nเงินบริษัทติดลบ จึงไม่สามารถดำเนินกิจการต่อได้" if Locale.language == "th" else "Your business has failed.\nThe company ran out of money and can no longer operate.", 44)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(message)
	var balance = UIKit.label(Data.money(Game.money), 56)
	balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	balance.add_theme_color_override("font_color", Color("f4ca74"))
	body.add_child(balance)
	var gap = Control.new()
	gap.size_flags_vertical = SIZE_EXPAND_FILL
	body.add_child(gap)
	body.add_child(UIKit.button("เริ่มธุรกิจใหม่" if Locale.language == "th" else "Start a new business", _restart, 0, "ConfirmButton"))
	body.add_child(UIKit.button(Locale.text("demo_title"), _title))

func _restart() -> void:
	Game._day_timer = 0.0
	Game.new_game()
	if Game.save_slot == "demo_career": DemoCareer.setup()
	Game.save_game(true)
	Game.resume_after_restart = true
	_title()

func _title() -> void:
	Game.running = false
	Game._pause_requests = 0
	get_tree().change_scene_to_file("res://scenes/main.tscn")
