extends UIPanel
signal offer_selected(job: Dictionary)
var _active = false
var _page = 0

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	super()
	Game.offers_changed.connect(_refresh_if_open)
	Game.jobs_changed.connect(_refresh_if_open)
	Locale.language_changed.connect(_refresh_if_open.unbind(1))

func refresh() -> void:
	UIKit.clear(self)
	var body = UIKit.centered_window(self, 1560, 850)
	var head = HBoxContainer.new()
	body.add_child(head)
	var title = UIKit.label(Locale.text("jobs"), 36)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UIKit.button(Locale.text("close"), close))
	var tabs = HBoxContainer.new()
	body.add_child(tabs)
	tabs.add_child(UIKit.button(Locale.text("offers"), func(): _active = false; _page = 0; refresh(), 400))
	tabs.add_child(UIKit.button(Locale.text("active_jobs"), func(): _active = true; _page = 0; refresh(), 400))
	var jobs: Array = Game.jobs if _active else Game.offers
	var pages = maxi(1, ceili(jobs.size() / 4.0))
	_page = clampi(_page, 0, pages - 1)
	var grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_vertical = SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	body.add_child(grid)
	if jobs.is_empty(): grid.add_child(UIKit.label(Locale.text("empty")))
	for job in jobs.slice(_page * 4, _page * 4 + 4):
		var card = PanelContainer.new()
		card.custom_minimum_size = Vector2(740, 275)
		grid.add_child(card)
		var row = HBoxContainer.new()
		card.add_child(row)
		var client = Game.get_client(job["client"])
		var portrait = PortraitView.new()
		portrait.custom_minimum_size = Vector2(96, 128)
		row.add_child(portrait)
		portrait.configure(Art.model_id(client))
		var copy = VBoxContainer.new()
		copy.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(copy)
		var job_title = UIKit.label(job["title"], 38)
		job_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		copy.add_child(job_title)
		var details = "%s | %s\n%s | %d %s\n%s\n%s" % [job["client"], Locale.legacy(client["type"]), Data.money(job["pay"]), job.get("weeks_left", job["deadline"]), Locale.text("weeks"), Game.describe_tags(job), Data.roles_text(job["roles"])]
		var job_details = UIKit.label(details, 36)
		job_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		copy.add_child(job_details)
		if str(job.get("remix_of", "")) != "":
			var remix = UIKit.label(Locale.text("stage_remix_tag"), 30)
			remix.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			copy.add_child(remix)
		var requested = StudioStage.band_by_id(str(job.get("requested_band", "")))
		if not requested.is_empty():
			var band = UIKit.label(Locale.text("stage_band_request", [StudioStage.band_label(requested)]), 30)
			band.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			copy.add_child(band)
		if not _active: copy.add_child(UIKit.button(Locale.text("talk"), func(): offer_selected.emit(job)))
	var footer = HBoxContainer.new()
	body.add_child(footer)
	var prev = UIKit.button("◀", func(): _page -= 1; refresh(), 100)
	prev.disabled = _page == 0
	footer.add_child(prev)
	footer.add_child(UIKit.label(Locale.text("page", [_page + 1, pages])))
	var next = UIKit.button("▶", func(): _page += 1; refresh(), 100)
	next.disabled = _page + 1 >= pages
	footer.add_child(next)
