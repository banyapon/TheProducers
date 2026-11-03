extends Node
var failures := 0
var checks := 0
var main: Node
var visual := false
var original_language := ""

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
	else: print("  ok  ", message)

func descendants(node: Node, type: String) -> Array:
	var out: Array = []
	if node.is_class(type): out.append(node)
	for child in node.get_children(): out.append_array(descendants(child, type))
	return out

func button(root: Node, value: String) -> Button:
	for item in descendants(root, "Button"):
		if item.text == value: return item
	return null

func frame(label: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if main != null and main.login.visible and main.login._page == "home":
		var panel: Control = main.login.get_node("TitleMenu")
		var screen: Vector2 = main.login.size
		check(panel.get_global_rect().position.x >= screen.x * 0.7 - 1, "login remains in the right thirty percent: " + label)
		check(panel.get_global_rect().end.x <= screen.x + 1 and panel.get_global_rect().end.y <= screen.y + 1, "login fits the screen without scrolling: " + label)
		check(panel.get_global_rect().end.y <= main.login.get_node("TitleCreditBar").get_global_rect().position.y, "compact login leaves the credit footer unobstructed: " + label)
		for control in descendants(panel, "Control"):
			if control is BaseButton or control is LineEdit:
				check(panel.get_global_rect().grow(1).encloses(control.get_global_rect()), "login control stays inside its panel: " + str(control.name))
	if visual:
		await RenderingServer.frame_post_draw
		var qa_dir = OS.get_environment("PRODUCERS_QA_DIR")
		if qa_dir == "": qa_dir = ProjectSettings.globalize_path("user://qa")
		DirAccess.make_dir_recursive_absolute(qa_dir)
		get_viewport().get_texture().get_image().save_webp(qa_dir.path_join("" + label + ".webp"),true)

func _ready() -> void:
	visual = "--visual" in OS.get_cmdline_user_args()
	original_language = Locale.language
	if visual:
		DisplayServer.window_set_title("The Producers Feature QA")
		get_tree().root.always_on_top = true
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1600, 900))
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await frame("home-th")
	Locale.set_language("en")
	check(button(main.login, "Create account") != null, "English home switch")
	await frame("home-en")
	check(descendants(main.login, "LineEdit").is_empty(), "Play tab hides account form")
	check(main.login.get_node("TitleToolbar").get_parent() == main.login, "language and options live outside the entry panel")
	main.login._select_home_tab(1)
	await frame("title-signin-en")
	check(descendants(main.login, "LineEdit").size() == 2, "sign-in tab shows only its two fields")
	var login_content = main.login.get_node("TitleMenu").find_child("TabContent", true, false)
	check(login_content.has_node("GoogleSignIn"), "Google connection lives in sign-in tab")
	var google_logo = login_content.get_node("GoogleSignIn/OfficialGoogleLogo") as TextureRect
	check(google_logo.texture.resource_path == "res://assets/ui/brand/google-g.png" and google_logo.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR, "Google logo uses unchanged brand asset without pixel filtering")
	main.login._authenticate(false)
	check(main.login.status_label.visible and main.login.status_label.text == Locale.text("auth_invalid"), "compact panel reveals validation errors when needed")
	await frame("title-signin-error-en")
	main.login._set_status("")
	check(not main.login.status_label.visible, "empty login status does not reserve panel space")
	main.login.email_edit.text = "qa@example.invalid"
	main.login.email_edit.text_changed.emit(main.login.email_edit.text)
	main.login._select_home_tab(2)
	await frame("title-signup-en")
	check(main.login.email_edit.text == "qa@example.invalid", "email survives switching account tabs")
	check(not main.login.get_node("TitleMenu").find_child("TabContent", true, false).has_node("GoogleSignIn"), "signup tab keeps only the registration action")
	main.login._select_home_tab(0)
	Locale.set_language("th")
	check(Locale.text("intro_3").contains("พี่{producer}") and Locale.text("report").begins_with("พี่"), "Alice addresses the Thai player as phi in the introduction and reports")
	check(Locale.text("alice_no_romance").contains("เพื่อนของพี่") and Locale.text("mode_prompt").begins_with("พี่"), "Alice uses phi in social and work conversations")
	await frame("title-play-th")
	main.login._select_home_tab(1)
	await frame("title-signin-th")
	main.login._select_home_tab(2)
	await frame("title-signup-th")
	main.login.escape()
	check(main.login._home_tab == 0 and descendants(main.login, "LineEdit").is_empty(), "ESC leaves account tabs before exiting title")
	Locale.set_language("en")
	main.login._select_home_tab(0)
	main.login._request_consent()
	var accept := button(main.login, Locale.text("accept_continue"))
	check(accept != null and accept.disabled, "consent blocks registration by default")
	var boxes := descendants(main.login, "CheckBox")
	check(boxes.size() == 2 and not boxes[0].button_pressed and not boxes[1].button_pressed, "separate unchecked terms and privacy")
	check(boxes[1].disabled, "privacy acceptance requires visiting privacy page")
	await frame("terms-en")
	button(main.login, Locale.text("privacy_title")).pressed.emit()
	boxes = descendants(main.login, "CheckBox")
	check(not boxes[1].disabled, "privacy page unlocks its checkbox")
	boxes[0].button_pressed = true
	check(button(main.login, Locale.text("accept_continue")).disabled, "one consent is insufficient")
	boxes[1].button_pressed = true
	check(not button(main.login, Locale.text("accept_continue")).disabled, "both consents enable continuation")
	await frame("privacy-en")
	main.login.open()
	main.login.hide()
	Game._pause_requests = 0
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save_features_qa.dat"))
	main._on_login_completed("features_qa")
	await frame("profile-en")
	check(main.shell.visible and main.shell.page == "identity", "first run requires Producer and Studio names")
	check(Game.is_paused(), "clock paused throughout naming")
	check(not Game.set_identity(" ", "AB"), "blank identity rejected")
	var names := descendants(main.shell, "LineEdit")
	names[0].text = "River"
	names[0].text_changed.emit(names[0].text)
	names[1].text = "Second Verse"
	names[1].text_changed.emit(names[1].text)
	button(main.shell, Locale.text("begin")).pressed.emit()
	await frame("intro-en")
	check(main.dialog.visible, "Alice comeback story starts after naming")
	check(main.dialog.left_portrait.art_id == "producer" and main.dialog.right_portrait.art_id == "alice", "main character portraits use main assets")
	check(main.dialog.right_portrait.flip_h, "right portrait faces left")
	check(is_equal_approx(main.dialog.left_portrait.get_global_rect().end.y, main.dialog.box.get_global_rect().end.y), "Producer portrait aligns with compact dialog bottom")
	check(is_equal_approx(main.dialog.right_portrait.get_global_rect().end.y, main.dialog.box.get_global_rect().end.y), "right portrait aligns with compact dialog bottom")
	check(is_equal_approx(main.dialog.box.anchor_bottom,1.0) and is_equal_approx(main.dialog.box.get_global_rect().end.y,get_viewport().get_visible_rect().size.y-24), "dialog box snaps to bottom-center")
	for i in 4:
		main.dialog._advance()
		main.dialog._advance()
		await get_tree().process_frame
	check(Game.intro_seen and not main.dialog.visible, "four story lines finish and persist")
	check(not Game.is_paused(), "onboarding releases all modal pauses")
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	main._input(escape)
	check(main.shell.visible and Game.is_paused(), "ESC inside game opens pause and rankings")
	main._input(escape)
	check(not main.shell.visible and not Game.is_paused(), "second ESC resumes the game")
	check(Game.producer_name == "River" and Game.studio_name == "Second Verse", "custom names applied")
	check(main.office.principals.size() == 2 and main.office.workers.size() == 2, "separate main characters and starter band")
	for id in Art.npc_ids + Art.vip_ids + ["producer", "alice"]:
		var animations := Art.frames(id)
		check(animations.get_frame_count("walk") == 6 and animations.get_frame_count("talk") == 6, id + " world animation")
		for expression in 4:
			var portrait := Art.portrait(id, expression) as AtlasTexture
			check(portrait != null and portrait.region.size == Vector2(64, 64) and portrait.region.position.y == (expression / 2) * 64, id + " native portrait frame " + str(expression))
	await frame("office-en")
	main.dialog.open(main.PLAYER, Art.portrait_data(Game.listing[0]))
	main.dialog.ask("right", Locale.text("legacy_143") % ["Pop 70% / Jazz 30%", "Vocal / Producer", 20], [Locale.text("legacy_144"), Locale.text("legacy_145"), Locale.text("legacy_146") % 3, Locale.text("legacy_147") % 1, Locale.text("legacy_148"), Locale.text("legacy_149")])
	await frame("dialog-six-choices-en")
	main.dialog.choice_selected.emit(4)
	main.dialog.close()
	var theme = ThemeDB.get_project_theme()
	check(theme.get_stylebox("normal", "Button") is StyleBoxTexture, "buttons use cropped PNG texture styles")
	check(theme.get_stylebox("panel", "PanelContainer") is StyleBoxTexture, "all panels use cropped PNG texture styles")
	check(theme.get_stylebox("normal", "LineEdit") is StyleBoxTexture, "text fields use cropped PNG texture styles")
	check(theme.get_stylebox("fill", "ProgressBar") is StyleBoxTexture, "progress bars use cropped PNG texture styles")
	check(GoogleDesktop.base64url("dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk".sha256_buffer()) == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM", "Google PKCE challenge matches RFC 7636")
	check(GoogleDesktop.callback_query("GET /?state=wrong&code=abc HTTP/1.1\r\n\r\n", "expected").is_empty(), "Google callback rejects mismatched state")
	check(GoogleDesktop.callback_query("GET /?state=expected&code=a%2Bb HTTP/1.1\r\n\r\n", "expected").get("code", "") == "a+b", "Google callback decodes authorization code")
	main.hire_board.open()
	await frame("musicians-en")
	var portraits := descendants(main.hire_board, "TextureRect")
	check(portraits.size() == 4, "musician page shows four portraits")
	check(descendants(main.hire_board, "ScrollContainer").is_empty(), "musician roster uses pages, no vertical scroll")
	main.hire_board.close()
	main.job_board.open()
	await frame("jobs-en")
	main.job_board.close()
	main.shell.open()
	check(Game.rankings("fame").size() == 5, "studio league includes our studio and four rivals")
	var ours := false
	for entry in Game.rankings("fame"):
		if entry.get("ours", false): ours = entry["name"] == "Second Verse"
	check(ours, "rankings identify the named player studio")
	var day_before := Game.day
	Game._process(30.0)
	check(Game.day == day_before, "pause freezes calendar")
	var actor: Worker = main.office.principals["alice"]
	var before := actor.position
	actor._process(30.0)
	check(actor.position == before, "pause freezes walking characters")
	await frame("rankings-en")
	main.shell.close()
	Locale.set_language("th")
	check(Data.ROLE_TH["Vocal"] == Locale.text("legacy_002"), "data tables switch back to Thai")
	main.hire_board.open()
	await frame("musicians-th")
	main.hire_board.close()
	var job: Dictionary = Game.offers[0]
	Game.accept_offer(job)
	main.production.open()
	await frame("production-setup-th")
	main.production.close()
	var ids: Array = []
	for artist in Game.staff: ids.append(artist["id"])
	check(Game.start_project(job["id"], ids, job["mix"], "Comeback") == "", "recording session starts with original simulation")
	main.production.open()
	await frame("recording-status-th")
	main.production.close()
	var index := 0
	for id in main.office.workers:
		var worker: Worker = main.office.workers[id]
		worker.place(1, main.office.SHAFT_W + 110 + index * 60)
		worker.state = Worker.State.WORK
		worker._update_visual(0.5)
		check(worker._instrument_front.texture != null, "recording musician receives instrument atlas")
		check(worker._notes.size() > 0, "recording emits note sprites")
		index += 1
	await frame("recording-world-th")
	Game.project["done"] = true
	Game.project["eval"] = Game.evaluate_project()
	main.release_panel.open()
	await frame("release-pixel-th")
	check(main.release_panel.get_node("Window/Scroll").vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "release controls fit without vertical scrolling")
	main.release_panel.close()
	var example_song = Game.release_project(0)
	main.coach.finish()
	main.dialog.close()
	var fixture_audio = AudioStreamWAV.new()
	fixture_audio.data = PackedByteArray([128, 128, 128, 128])
	fixture_audio.save_to_wav("user://library-source-qa.wav")
	example_song["local_audio"] = "user://library-source-qa.wav"
	Game.songs.append(example_song.duplicate(true))
	for i in range(8):
		var copy = example_song.duplicate(true)
		copy["title"] = "Library track " + str(i + 1)
		Game.songs.append(copy)
	main.library.open()
	await frame("library-pixel-th")
	check(main.library.song_list.get_parent().vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "library uses pages without vertical scrolling")
	var song_grid = main.library.song_list.get_node("SongGrid")
	check(song_grid.columns == 3 and song_grid.get_child_count() == 9, "library shows nine songs in three columns")
	check(button(main.library, "<<").disabled and not button(main.library, ">>").disabled, "ASCII library arrows show correct page state")
	for card in song_grid.get_children():
		check(main.library.get_node("Window").get_global_rect().encloses(card.get_global_rect()), "library card fits in window")
	song_grid.get_child(0).pressed.emit()
	await frame("library-detail-th")
	check(main.library.has_node("SongDetailModal"), "song click opens side modal")
	for control in descendants(main.library.get_node("SongDetailModal"), "Button"):
		check(main.library.get_global_rect().encloses(control.get_global_rect()), "song detail action fits on screen")
	main.library._close_detail()
	Locale.set_language("en")
	main.library.refresh()
	await frame("library-grid-en")
	var cloud_example = example_song.duplicate(true)
	cloud_example["audio_url"] = "https://example.invalid/fixture.mp3"
	main.library._show_song(cloud_example)
	await frame("library-detail-en")
	for control in descendants(main.library.get_node("SongDetailModal"), "Button"):
		check(main.library.get_global_rect().encloses(control.get_global_rect()), "cloud song detail action fits on screen")
	main.library._close_detail()
	button(main.library, ">>").pressed.emit()
	await frame("library-page-two")
	check(main.library.song_list.get_node("SongGrid").get_child_count() == 1, "library last page shows remaining song")
	main.library._download_song = example_song
	var copy_path = ProjectSettings.globalize_path("user://library-download-qa.wav")
	main.library._save_song(copy_path)
	check(FileAccess.file_exists(copy_path), "library saves local song download")
	if FileAccess.file_exists(copy_path): DirAccess.remove_absolute(copy_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://library-source-qa.wav"))
	main.library.close()
	Game.save_game()
	var saved_fame := Game.fame
	Game.producer_name = "Changed"
	check(Game.load_game() and Game.producer_name == "River" and Game.fame == saved_fame, "identity and league stats survive save/load")
	# Old saves acquire visual IDs and experience without resetting the roster.
	for artist in Game.staff:
		artist.erase("art_id")
		artist.erase("experience")
	Game._migrate_visuals()
	check(Game.staff[0].has("art_id") and Game.staff[0].has("experience"), "legacy musician saves migrate")
	Game.running = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game._save_path()))
	Locale.set_language(original_language)
	print("FEATURE TESTS: %d checks, %d failures" % [checks, failures])
	if visual and "--hold" in OS.get_cmdline_user_args():
		get_tree().root.title = "The Producers Feature QA"
		main.login.hide()
		Game.running = true
		Game.push_pause()
		return
	await Audio.shutdown()
	get_tree().quit(1 if failures else 0)
