class_name AudioOptions
extends RefCounted

static func add_controls(body: Container) -> void:
	for bus in ["Master", "BGM", "SFX"]:
		var row = HBoxContainer.new()
		body.add_child(row)
		var title = UIKit.label(Locale.text("volume_" + bus.to_lower()), 32)
		title.custom_minimum_size.x = 210
		row.add_child(title)
		var slider = HSlider.new()
		slider.name = "Volume" + bus
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 1
		slider.value = Audio.levels[bus] * 100
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(slider)
		var value = UIKit.label("%d%%" % slider.value, 32)
		value.custom_minimum_size.x = 90
		row.add_child(value)
		slider.value_changed.connect(func(n: float): Audio.set_level(bus, n / 100.0); value.text = "%d%%" % n)
