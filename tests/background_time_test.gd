extends Node

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _ready() -> void:
	Game.set_process(false)
	Game.running = true
	Game.speed = 1.0
	Game.tutorial_gate = false
	Game._pause_requests = 0
	var office = load("res://scenes/office/office.tscn").instantiate()
	add_child(office)
	office.set_process(false)
	check(is_equal_approx(office._background_daylight(), 1.0), "starts in daylight")
	for material in office._background_materials.values():
		check(material.get_shader_parameter("day_texture") != null, "day texture exists")
	var layers: Array = []
	for child in office.get_children():
		if child is Parallax2D: layers.append(child)
	office._tick_background_time(55.0)
	check(is_equal_approx(office._background_daylight(), 0.5), "sunset blends halfway")
	Game.push_pause()
	office._tick_background_time(20.0)
	check(is_equal_approx(office._background_elapsed, 55.0), "paused time is excluded")
	Game.pop_pause()
	Game.speed = 4.0
	office._tick_background_time(5.0)
	check(is_equal_approx(office._background_daylight(), 0.0), "night after 60 real play seconds regardless of speed")
	for material in office._background_materials.values():
		check(is_equal_approx(material.get_shader_parameter("daylight"), 0.0), "all layers switch together")
	for shade in office._background_shades:
		check(is_equal_approx(shade.modulate.a, 1.0), "night haze restored")
	office._tick_background_time(55.0)
	check(is_equal_approx(office._background_daylight(), 0.5), "sunrise blends halfway")
	office._tick_background_time(5.0)
	check(is_equal_approx(office._background_elapsed, 0.0), "wraps at two minutes")
	check(is_equal_approx(office._background_daylight(), 1.0), "daylight continuous across wrap")
	for layer in layers:
		check(is_instance_valid(layer) and layer.get_parent() == office, "parallax layers preserved across transition")
	for shade in office._background_shades:
		check(is_zero_approx(shade.modulate.a), "night haze hidden in daytime")
	Game.running = false
	print("BACKGROUND TIME: %d failures" % failures)
	await Audio.shutdown()
	get_tree().quit(failures)
