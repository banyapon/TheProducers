extends UIPanel
signal collection_requested
## Label's song library: covers, ratings, sales, cloud status and playback
## (local WAV, or MP3 streamed from Cloudinary).

var _page = 0
var _detail: Control
var _save_dialog: FileDialog
var _download_song: Dictionary = {}
var _download_path := ""
var _download: HTTPRequest
var _collection_button: Button

@onready var song_list: VBoxContainer = %SongList
@onready var now_playing: Label = %NowPlaying
@onready var cloud_label: Label = %CloudLabel
@onready var player: AudioStreamPlayer = $Player


func _ready() -> void:
	super()
	_collection_button = UIKit.button(Locale.text("stars_collection"), func(): close(); collection_requested.emit())
	$Window/VBox/Header.add_child(_collection_button)
	# Bind the callback to this panel so it disconnects when the scene is freed.
	Locale.language_changed.connect(_on_language_changed)
	song_list.get_parent().vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	Audio.playback_status.connect(func(message: String): if visible: now_playing.text = message)
	Game.song_updated.connect(_on_song_changed)
	Game.song_released.connect(_on_song_changed)
	_save_dialog = FileDialog.new()
	_save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_save_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_save_dialog.use_native_dialog = true
	_save_dialog.file_selected.connect(_save_song)
	add_child(_save_dialog)
	_download = HTTPRequest.new()
	_download.timeout = 60
	_download.request_completed.connect(_download_finished)
	add_child(_download)


func _on_language_changed(_language: String) -> void:
	if is_instance_valid(_collection_button):
		_collection_button.text = Locale.text("stars_collection")
	_refresh_if_open()

func _on_song_changed(_song: Dictionary) -> void:
	_refresh_if_open()


func refresh() -> void:
	if FirebaseAuth.is_signed_in():
		cloud_label.text = Locale.text("legacy_249") % FirebaseAuth.display_name()
	else:
		cloud_label.text = Locale.text("legacy_250")
	clear(song_list)
	var catalogue = Game.archived_songs + Game.songs
	if catalogue.is_empty():
		song_list.add_child(make_note(Locale.text("legacy_251")))
	var pages = maxi(1, ceili(catalogue.size() / 9.0))
	_page = clampi(_page, 0, pages - 1)
	var pager = HBoxContainer.new()
	song_list.add_child(pager)
	var prev = UIKit.button("<<", func(): _page -= 1; refresh())
	prev.disabled = _page == 0
	pager.add_child(prev)
	pager.add_child(UIKit.label(Locale.text("page", [_page + 1, pages])))
	var next = UIKit.button(">>", func(): _page += 1; refresh())
	next.disabled = _page + 1 >= pages
	pager.add_child(next)
	var reversed = catalogue.duplicate()
	reversed.reverse()
	var grid = GridContainer.new()
	grid.name = "SongGrid"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	song_list.add_child(grid)
	for song in reversed.slice(_page * 9, _page * 9 + 9):
		grid.add_child(_song_card(song))


func _song_card(song: Dictionary) -> Control:
	var card = UIKit.button("", _show_song.bind(song))
	card.custom_minimum_size.y = 182
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.tooltip_text = str(song["title"])
	var row = HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 14
	row.offset_right = -14
	row.offset_top = 12
	row.offset_bottom = -12
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var cover = TextureRect.new()
	cover.custom_minimum_size = Vector2(104, 104)
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cover.texture = MusicGen.cover_texture(song)
	row.add_child(cover)
	var text_box = VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(text_box)
	var title = UIKit.label(str(song["title"]))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.max_lines_visible = 2
	text_box.add_child(title)
	if song.get("archived", false):
		var credit = UIKit.label(str(song.get("origin_studio", "")), 22)
		credit.clip_text = true
		text_box.add_child(credit)
	text_box.add_child(UIKit.label(str(song["rating"]) + "/40" + StudioStage.card_mark(song)))
	if CreativeJourney.available(song): text_box.add_child(UIKit.label(Locale.text("rights_badge"),24))
	_ignore_mouse(row)
	return card


func _ignore_mouse(node: Control) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		if child is Control: _ignore_mouse(child)


func _close_detail() -> void:
	if is_instance_valid(_detail):
		remove_child(_detail)
		_detail.queue_free()
	_detail = null


func _show_song(song: Dictionary) -> void:
	_close_detail()
	_detail = Control.new()
	_detail.name = "SongDetailModal"
	_detail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_detail)
	var shade = ColorRect.new()
	shade.color = Color(0, 0, 0, 0.65)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT: _close_detail())
	_detail.add_child(shade)
	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.anchor_left = 0.57
	panel.offset_left = 0
	panel.offset_right = -28
	panel.offset_top = 100
	panel.offset_bottom = -100
	_detail.add_child(panel)
	var body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	panel.add_child(body)
	body.add_child(UIKit.button(Locale.text("close"), _close_detail))
	body.add_child(_song_row(song))
	var story = UIKit.button(Locale.text("rights_title"), func():
		var page = SongStoryPanel.new()
		page.song = song
		add_child(page)
		page.closed.connect(page.queue_free)
		page.open())
	body.add_child(story)
	var download_button = UIKit.button(Locale.text("library_download"), _choose_download.bind(song))
	download_button.disabled = not FileAccess.file_exists(str(song.get("local_audio", ""))) and str(song.get("audio_url", "")).is_empty()
	body.add_child(download_button)
	body.add_child(UIKit.button(Locale.text("legacy_265"), _on_stop_pressed))
	var feedback = UIKit.label(now_playing.text)
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(feedback)
	feedback.set_meta("library_feedback", true)


func _process(_delta: float) -> void:
	if is_instance_valid(_detail):
		for node in _detail.find_children("*", "Label", true, false):
			if node.has_meta("library_feedback"): node.text = now_playing.text


func _song_row(song: Dictionary) -> Control:
	var panel = PanelContainer.new()
	var hb = VBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	panel.add_child(hb)
	var cover = TextureRect.new()
	cover.custom_minimum_size = Vector2(120, 120)
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cover.texture = MusicGen.cover_texture(song)
	hb.add_child(cover)

	var vb = VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(vb)
	var title = Label.new()
	title.text = Locale.display_game_text(song["title"])
	title.add_theme_font_size_override("font_size", 36)
	vb.add_child(title)
	if song.get("archived", false):
		var credit = UIKit.label(Locale.text("reset_credit", [song.get("origin_producer", ""), song.get("origin_studio", "")]), 26)
		credit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(credit)
	var chart = Locale.text("legacy_252") % song["weeks_left"] if int(song["weeks_left"]) > 0 else Locale.text("legacy_253")
	var info = Label.new()
	info.text = Locale.text("legacy_254") % [
		song["rating"], song["client"], Data.mix_text(song["mix"]), Data.money(song["earned"]), song["marketing"], chart]
	info.text = Locale.display_game_text(info.text) + "\n" + StudioStage.rank_line(song)
	info.add_theme_font_size_override("font_size", 36)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(info)
	var status = Label.new()
	status.text = song["status"]
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 36)
	status.add_theme_color_override("font_color", Color("80ed99") if song["audio_url"] != "" else Color("ffd166"))
	vb.add_child(status)

	var buttons = VBoxContainer.new()
	buttons.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(buttons)
	_add_button(buttons, Locale.text("legacy_255"), _play_local.bind(song))
	var midi_path = str(song.get("idea_midi",""))
	if midi_path != "" and FileAccess.file_exists(midi_path):
		_add_button(buttons,Locale.text("show_midi"),OS.shell_open.bind(ProjectSettings.globalize_path(midi_path.get_base_dir())))
	if song["audio_url"] != "":
		_add_button(buttons, Locale.text("legacy_256"), _play_cloud.bind(song))
		_add_button(buttons, Locale.text("legacy_257"), OS.shell_open.bind(song["audio_url"]))
	elif FirebaseAuth.is_signed_in() and song["local_audio"] != "" and not str(song["status"]).begins_with(Locale.text("legacy_258")):
		_add_button(buttons, Locale.text("legacy_259"), MusicGen.upload_song.bind(song))
	return panel


func _add_button(box: Container, text: String, callback: Callable) -> void:
	var b = UIKit.button(text, callback)
	box.add_child(b)


func _choose_download(song: Dictionary) -> void:
	_download_song = song.duplicate(true)
	var local = str(song.get("local_audio", ""))
	var extension = local.get_extension() if FileAccess.file_exists(local) else "mp3"
	_save_dialog.filters = PackedStringArray(["*." + extension + " ; Audio"])
	_save_dialog.current_file = str(song["title"]).validate_filename() + "." + extension
	_save_dialog.popup_centered_ratio(0.65)


func _save_song(path: String) -> void:
	var local = str(_download_song.get("local_audio", ""))
	if FileAccess.file_exists(local):
		var error = DirAccess.copy_absolute(ProjectSettings.globalize_path(local), path)
		now_playing.text = Locale.text("library_download_done") if error == OK else Locale.text("library_download_failed")
		return
	var url = str(_download_song.get("audio_url", ""))
	if url.is_empty():
		now_playing.text = Locale.text("library_download_failed")
		return
	if _download.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	_download_path = path
	_download.download_file = path + ".part"
	var error = _download.request(url)
	now_playing.text = Locale.text("library_downloading") if error == OK else Locale.text("library_download_failed")


func _download_finished(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	var ok = result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300
	if ok:
		ok = DirAccess.rename_absolute(_download_path + ".part", _download_path) == OK
	if not ok and FileAccess.file_exists(_download_path + ".part"):
		DirAccess.remove_absolute(_download_path + ".part")
	now_playing.text = Locale.text("library_download_done") if ok else Locale.text("library_download_failed")


func _play_local(song: Dictionary) -> void:
	Audio.play_song(song, false)

func _play_cloud(song: Dictionary) -> void:
	Audio.play_song(song, true)

func _on_stop_pressed() -> void:
	player.stop()
	Audio.stop_preview()
	now_playing.text = Locale.text("legacy_265")


func close() -> void:
	_close_detail()
	player.stop()
	Audio.stop_preview()
	super()
