class_name StarPanel
extends UIPanel
var tab := 0
var message := ""
var page := 0
const PAGE_SIZE := 4

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	super()
	Locale.language_changed.connect(_refresh_if_open.unbind(1))

func close() -> void:
	Audio.stop_preview()
	super()

func refresh() -> void:
	UIKit.clear(self)
	var body = UIKit.centered_window(self, 1550, 960)
	var nav = HBoxContainer.new()
	body.add_child(nav)
	for i in 3:
		nav.add_child(UIKit.button(Locale.text(["stars_ranking", "stars_offers", "stars_collection"][i]), func(): tab = i; page = 0; message = ""; refresh()))
	nav.add_child(UIKit.button(Locale.text("close"), close))
	var note = UIKit.label(message if not message.is_empty() else Locale.text("stars_help"), 30)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(note)
	if tab != 1:
		_show_gallery(body)
		return
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	body.add_child(scroll)
	var list = VBoxContainer.new()
	list.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(list)
	if tab == 1:
		for task in StudioStars.data()["assignments"]:
			list.add_child(UIKit.label(Locale.text("stars_away", [task["name"], maxi(0, int(task["until"]) - Game.day)]), 30))
		for offer in StudioStars.data()["offers"]:
			var text = "%s | %s | %s | %s" % [offer["name"], offer["brand"], Locale.text("stars_" + offer["kind"]), Data.money(offer["fee"])]
			var detail = Locale.text("stars_offer_detail", [offer["days"], int(offer["expires"]) - Game.day])
			if offer["kind"] == "license": detail += "\n" + Locale.text("stars_royalty", [Data.money(maxi(100, int(offer["fee"]) / 10))])
			list.add_child(make_row(Color.CORNFLOWER_BLUE, text, detail, [[Locale.text("stars_accept"), func(): message = StudioStars.accept(offer["id"]); refresh()]]))
		if StudioStars.data()["offers"].is_empty(): list.add_child(UIKit.label(Locale.text("stars_no_offers"), 30))

func _text(parent: Node, value: String, font_size: int = 28, color: Color = Color.WHITE) -> Label:
	var label = UIKit.label(value)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _show_gallery(body: VBoxContainer) -> void:
	var rows: Array = StudioStars.rankings() if tab == 0 else StudioStars.data()["collections"].duplicate()
	if tab == 2: rows.reverse()
	var pages = maxi(1, ceili(float(rows.size()) / PAGE_SIZE))
	page = clampi(page, 0, pages - 1)
	var grid = GridContainer.new()
	grid.name = "ArtistGrid"
	grid.columns = 2
	grid.size_flags_vertical = SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	body.add_child(grid)
	for row in rows.slice(page * PAGE_SIZE, (page + 1) * PAGE_SIZE):
		_artist_card(grid, row)
	if not rows.is_empty():
		while grid.get_child_count() < PAGE_SIZE:
			var space = Control.new()
			space.custom_minimum_size = Vector2(0, 320)
			space.size_flags_horizontal = SIZE_EXPAND_FILL
			space.size_flags_vertical = SIZE_EXPAND_FILL
			grid.add_child(space)
	if rows.is_empty():
		_text(grid, Locale.text("stars_no_collection"), 32)
	var nav = HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 24)
	body.add_child(nav)
	var previous = UIKit.button("<", func(): page -= 1; refresh(), 90)
	previous.disabled = page == 0
	nav.add_child(previous)
	var counter = _text(nav, "%d / %d" % [page + 1, pages], 32, Color("#f4ca74"))
	counter.autowrap_mode = TextServer.AUTOWRAP_OFF
	counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var next = UIKit.button(">", func(): page += 1; refresh(), 90)
	next.disabled = page >= pages - 1
	nav.add_child(next)

func _artist_card(grid: GridContainer, row: Dictionary) -> void:
	var ours = bool(row.get("ours", true))
	var artist = Game.get_artist(str(row.get("id", "") if tab == 0 else row.get("artist_id", "")))
	var art_id = str(row.get("art_id", Art.model_id(artist if not artist.is_empty() else row)))
	var accent = Color("#f4ca74") if ours else Color("#85b9cf")
	var card = PanelContainer.new()
	card.name = "ArtistCard"
	card.size_flags_horizontal = SIZE_EXPAND_FILL
	card.size_flags_vertical = SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 320)
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#1c2d41")
	style.border_color = accent.darkened(0.4)
	style.set_border_width_all(2)
	style.border_width_top = 4
	style.content_margin_left = 12
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", style)
	grid.add_child(card)
	var layout = HBoxContainer.new()
	layout.add_theme_constant_override("separation", 18)
	card.add_child(layout)
	var portrait = PortraitView.new()
	portrait.name = "ArtistFullBody"
	portrait.custom_minimum_size = Vector2(190, 300)
	portrait.size_flags_vertical = SIZE_EXPAND_FILL
	layout.add_child(portrait)
	portrait.configure(art_id)
	portrait.talking = true
	portrait.use_fullbody(true)
	var details = VBoxContainer.new()
	details.size_flags_horizontal = SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 8)
	layout.add_child(details)
	_text(details, ("#%02d  /  %s" % [row["rank"], StudioStars.tier(row["fame"])]) if tab == 0 else str(row["type"]).to_upper(), 26, accent)
	_text(details, str(row["name"]), 38)
	if tab == 0:
		_text(details, "FAME  %s" % row["fame"], 32, accent)
		if ours:
			var profile = StudioStars.profile(artist)
			_text(details, Locale.text("stars_trust", [profile.get("trust", 70)]), 26)
			var releases: Array = profile.get("releases", [])
			if not releases.is_empty():
				var song = StudioStage.song_by_id(str(releases.back()))
				if not song.is_empty(): _song_button(details, song)
			else:
				_text(details, Locale.text("stars_no_collection"), 26, Color("#a4b6c9"))
			var spacer = Control.new()
			spacer.size_flags_vertical = SIZE_EXPAND_FILL
			details.add_child(spacer)
			var album = UIKit.button(Locale.text("stars_album", [artist["name"], profile.get("album_tracks", []).size()]), func(): message = StudioStars.make_album(artist["id"]); refresh())
			album.add_theme_font_size_override("font_size", 26)
			album.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			details.add_child(album)
		else:
			_text(details, "ศิลปินต่างค่าย" if Locale.language == "th" else "Other label", 26, Color("#a4b6c9"))
	else:
		_text(details, str(row["title"]), 30, accent)
		_text(details, "%d/40  |  %d tracks" % [row["rating"], row["songs"].size()], 26, Color("#a4b6c9"))
		for song_id in row["songs"]:
			var song = StudioStage.song_by_id(str(song_id))
			if not song.is_empty(): _song_button(details, song)

func _song_button(parent: Node, song: Dictionary) -> void:
	var button = UIKit.button(Locale.text("jam_listen") + " | " + str(song["title"]), func(): Audio.play_song(song, false))
	button.add_theme_font_size_override("font_size", 26)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(button)
