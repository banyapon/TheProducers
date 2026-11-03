extends UIPanel
signal candidate_selected(artist: Dictionary)
signal staff_selected(artist: Dictionary)
var _tab = 0
var _page = 0
var _body: VBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	super()
	Game.listing_changed.connect(_refresh_if_open)
	Game.staff_changed.connect(_refresh_if_open)
	Locale.language_changed.connect(_refresh_if_open.unbind(1))

func refresh() -> void:
	UIKit.clear(self)
	_body = UIKit.centered_window(self, 1560, 850)
	var head = HBoxContainer.new()
	_body.add_child(head)
	var title = UIKit.label(Locale.text("hire") + " | " + Locale.text("staff_count", [Game.staff.size(), Game.staff_capacity()]), 34)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UIKit.button(Locale.text("close"), close))
	var tabs = HBoxContainer.new()
	_body.add_child(tabs)
	var names = ["free_board", "online_board", "team"]
	for i in 3:
		tabs.add_child(UIKit.button(Locale.text(names[i]), func(): _tab = i; _page = 0; refresh(), 300))
	var collections = [Game.listing, Game.online_candidates, Game.staff]
	var artists: Array = collections[_tab]
	var pages = maxi(1, ceili(artists.size() / 4.0))
	_page = clampi(_page, 0, pages - 1)
	var grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_vertical = SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	_body.add_child(grid)
	if artists.is_empty(): grid.add_child(UIKit.label(Locale.text("empty")))
	for a in artists.slice(_page * 4, _page * 4 + 4):
		var card = PanelContainer.new()
		card.custom_minimum_size = Vector2(740, 250)
		grid.add_child(card)
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		card.add_child(row)
		var portrait = PortraitView.new()
		portrait.custom_minimum_size = Vector2(128, 160)
		row.add_child(portrait)
		portrait.configure(Art.model_id(a))
		var copy = VBoxContainer.new()
		copy.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(copy)
		copy.add_child(UIKit.label(a["name"], 30))
		copy.add_child(UIKit.label(Locale.text("artist_detail", [Data.ROLE_TH[a["role"]], int(a.get("experience", 0)), Data.skills_text(a["skills"], 3), Data.money(a["fee_week"]), a["weeks_left"]]), 24))
		copy.add_child(UIKit.button(Locale.text("talk" if _tab == 2 else "interview"), func():
			if _tab == 2: staff_selected.emit(a)
			else: candidate_selected.emit(a)))
	var footer = HBoxContainer.new()
	_body.add_child(footer)
	var prev = UIKit.button("◀", func(): _page -= 1; refresh(), 100)
	prev.disabled = _page == 0
	footer.add_child(prev)
	footer.add_child(UIKit.label(Locale.text("page", [_page + 1, pages])))
	var next = UIKit.button("▶", func(): _page += 1; refresh(), 100)
	next.disabled = _page + 1 >= pages
	footer.add_child(next)
	var ad = UIKit.button(Locale.text("post_ad", [Data.money(Game.ONLINE_AD_COST)]), func(): Game.post_online_ad(); _tab = 1; _page = 0; refresh())
	ad.disabled = Game.money < Game.ONLINE_AD_COST
	footer.add_child(ad)
