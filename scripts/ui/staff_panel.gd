class_name StaffPanel
extends UIPanel
signal stars_requested
signal talk_requested(artist_id: String)
var page := 0

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	Game.staff_changed.connect(_refresh_if_open)
	Locale.language_changed.connect(_refresh_if_open.unbind(1))
	super()

func refresh() -> void:
	UIKit.clear(self)
	var body = UIKit.centered_window(self, 1440, 850)
	var header = HBoxContainer.new()
	body.add_child(header)
	var title = UIKit.label(Locale.text("staff"), 42)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(UIKit.button(Locale.text("stars_title"), func(): close(); stars_requested.emit()))
	header.add_child(UIKit.button(Locale.text("close"), close))
	var hint = UIKit.label(Locale.text("staff_intro"), 32)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(hint)
	var entries = [StudioCity.alice()] + Game.staff
	var pages = maxi(1, ceili(entries.size() / 6.0))
	page = clampi(page, 0, pages - 1)
	var grid = GridContainer.new()
	grid.columns = 3
	grid.size_flags_vertical = SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	body.add_child(grid)
	for a in entries.slice(page * 6, page * 6 + 6):
		var panel = PanelContainer.new()
		panel.custom_minimum_size = Vector2(450, 270)
		panel.size_flags_horizontal = SIZE_EXPAND_FILL
		grid.add_child(panel)
		var box = VBoxContainer.new()
		panel.add_child(box)
		var head = HBoxContainer.new()
		box.add_child(head)
		var portrait = PortraitView.new()
		portrait.custom_minimum_size = Vector2(96, 96)
		head.add_child(portrait)
		portrait.configure(Art.model_id(a))
		var name_label = UIKit.label(a["name"], 32)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.size_flags_horizontal = SIZE_EXPAND_FILL
		head.add_child(name_label)
		var details: String
		if a["id"] == "alice": details = StudioCity.alice_status()
		else:
			StudioLife.ensure_artist(a)
			var s: Dictionary = a["social"]
			var partner = Game.producer_name if s["partner"] == "producer" else Game.get_artist(s["partner"]).get("name", Locale.text("single"))
			details = Locale.text("staff_stats", [s["trust"], s["comfort"], s["attraction"], partner])
			if s["partner"] == "producer": details += " ? " + Data.money(0)
			var training = StudioLife.training(a["id"])
			if not training.is_empty(): details += "\n" + Locale.text("training_eta", [training["genre"], int(training["finish_day"]) - Game.day])
			else: details += "\n" + Locale.text("staff_contract", [a["weeks_left"], Locale.text("on" if a["auto_renew"] else "off")])
			var bond = StudioStage.closest_label(str(a["id"]))
			if bond != "": details += "\n" + bond
		var label = UIKit.label(details, 30)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_vertical = SIZE_EXPAND_FILL
		box.add_child(label)
		var button = UIKit.button(Locale.text("staff_call"), func(): close(); talk_requested.emit(a["id"]))
		button.name = "Call_" + a["id"]
		box.add_child(button)
	var pager = HBoxContainer.new()
	body.add_child(pager)
	var prev = UIKit.button("<", func(): page -= 1; refresh())
	prev.disabled = page == 0
	pager.add_child(prev)
	pager.add_child(UIKit.label(Locale.text("page", [page + 1, pages]), 30))
	var next = UIKit.button(">", func(): page += 1; refresh())
	next.disabled = page + 1 >= pages
	pager.add_child(next)
