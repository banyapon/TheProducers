class_name CreditsPage
extends RefCounted

static func populate(body: VBoxContainer, go_back: Callable) -> void:
	var source = UIKit.label(Locale.text("credits_audio"), 38)
	source.modulate = Color("ffd166")
	body.add_child(source)
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	body.add_child(grid)
	for credit in Locale.values("credits_audio_entries"):
		var panel = PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.custom_minimum_size = Vector2(540, 130)
		grid.add_child(panel)
		var box = VBoxContainer.new()
		box.add_theme_constant_override("separation", 10)
		panel.add_child(box)
		var title = UIKit.label(credit["title"], 34)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(title)
		var author = UIKit.label(credit["creator"] + " / Pixabay", 30)
		author.modulate = Color("87e0bb")
		box.add_child(author)
	var thanks = UIKit.label(Locale.text("credits_thanks"), 38)
	thanks.modulate = Color("ffd166")
	body.add_child(thanks)
	for organization in Locale.values("credits_organizations"):
		var label = UIKit.label(str(organization), 34)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(label)
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(spacer)
	var back = UIKit.button(Locale.text("back_options"), go_back)
	back.name = "CreditsBack"
	body.add_child(back)
