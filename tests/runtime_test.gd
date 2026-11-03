extends Node
var failures := 0
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func files(path: String) -> Array:
	var out: Array = []
	for filename in DirAccess.get_files_at(path): out.append(path.path_join(filename))
	for folder in DirAccess.get_directories_at(path): out.append_array(files(path.path_join(folder)))
	return out

func _ready() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	check(UIKit.readable_font().resource_path == "res://fonts/2005_iannnnnAMD.ttf","the shared UI font is the requested iannnnnAMD file")
	check(ThemeDB.get_project_theme().default_font.resource_path == UIKit.readable_font().resource_path,"default theme uses the same font")
	for codepoint in [0x0e33, 0x0e4d, 0x0e32, 0x0e48, 0x0e49]:
		check(UIKit.readable_font().has_char(codepoint), "selected font contains Thai vowel/tone glyph U+%04X" % codepoint)
	# Glyph existence alone does not catch a GSUB rule deleting the sara-am dot.
	var text_server = TextServerManager.get_primary_interface()
	var font_rids = UIKit.readable_font().get_rids()
	var nikhahit = text_server.font_get_glyph_index(font_rids[0], 48, 0x0e4d, 0)
	for word in ["กำ", "คำแนะนำ", "กำลังทำงาน", "สำเร็จ", "น้ำ", "ต่ำ", "ย้ำ", "ช้ำ"]:
		var shaped = text_server.create_shaped_text()
		text_server.shaped_text_add_string(shaped, word, font_rids, 48, {}, "th")
		text_server.shaped_text_shape(shaped)
		var dots = 0
		for glyph in text_server.shaped_text_get_glyphs(shaped):
			if glyph["index"] == nikhahit: dots += 1
		check(dots == word.count("ำ"), "Thai shaping preserves each sara-am upper dot: " + word)
		text_server.free_rid(shaped)
	check(FirebaseAuth.mask_email("abcdefghij@example.com") == "abcdef****@example.com", "email hides the final forty percent before @")
	check(FirebaseAuth.mask_email("a@example.com") == "****@example.com", "short email never exposes its full local part")
	check(FirebaseAuth.mask_email("abc@example.com") == "a****@example.com", "partial mask rounds hidden characters up")
	var original_uid = FirebaseAuth.uid
	var original_email = FirebaseAuth.email
	FirebaseAuth.uid = "privacy-test-account-id"
	FirebaseAuth.email = "abcdefghij@example.com"
	for language in ["en", "th"]:
		var previous_language = Locale.language
		Locale.set_language(language)
		main.library.refresh()
		check(main.library.cloud_label.text.contains("abcdef****@example.com") and not main.library.cloud_label.text.contains("Cloudinary") and not main.library.cloud_label.text.contains(FirebaseAuth.uid), "library shows masked account without cloud storage identifiers: " + language)
		Locale.set_language(previous_language)
	check(FirebaseAuth.email == "abcdefghij@example.com", "display masking preserves the actual authentication email")
	FirebaseAuth.uid = original_uid
	FirebaseAuth.email = original_email
	check(is_equal_approx(main.dialog.get_node("DialogDim65").color.a,0.65),"dialog scrim darkens the complete game by 65 percent")
	check(main.dialog.box.anchor_left == 0.5 and main.dialog.box.anchor_bottom == 1.0,"dialog anchor is Middle / Bottom")
	check(main.dialog.text_label.get_theme_font_size("normal_font_size") == 44,"dialog text stays larger than general UI while reducing box height")
	for value in [1,2,4]: check(main.hud.speed_buttons[value].get_theme_font("font").resource_path == UIKit.readable_font().resource_path,"speed control uses the same iannnnnAMD font")
	main.office.camera.zoom = Vector2.ONE
	main.office._zoom(1.1)
	check(main.office.camera.zoom == Vector2(2,2),"zoom snaps from native 1x to integer 2x")
	main.office._zoom(1.1)
	check(main.office.camera.zoom == Vector2(3,3),"zoom reaches native 3x")
	for i in 5: main.office._zoom(1.1)
	check(main.office.camera.zoom == Vector2(4,4),"zoom caps at native 4x")
	for i in 8: main.office._zoom(1.0/1.1)
	check(main.office.camera.zoom == Vector2(0.5,0.5),"overview zoom remains bounded")
	Game.running = true
	Game.speed = 1
	main.office.camera.zoom = Vector2.ONE
	var wheel = InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	main.office._unhandled_input(wheel)
	check(main.office.camera.zoom == Vector2.ONE, "wheel input does not jump the camera immediately")
	main.office._tick_wheel_zoom(1.0/60.0)
	var initial_zoom = main.office.camera.zoom.x
	check(initial_zoom > 1.0 and initial_zoom < 1.02, "wheel starts gently rather than jumping to 2x")
	main.office._tick_wheel_zoom(1.0/60.0)
	check(main.office.camera.zoom.x > initial_zoom, "zoom continues smoothly after the wheel is released")
	for i in 90: main.office._tick_wheel_zoom(1.0/60.0)
	check(main.office.camera.zoom.x > 1.06 and main.office.camera.zoom.x < 1.07 and not main.office._wheel_active, "one wheel notch settles at a small bounded scale change")
	var results = []
	for fps in [30, 144]:
		main.office.camera.zoom = Vector2.ONE
		main.office._cancel_wheel_zoom()
		main.office._scroll_zoom(3)
		for i in fps: main.office._tick_wheel_zoom(1.0/fps)
		results.append(main.office.camera.zoom.x)
	check(absf(results[0]-results[1]) < 0.0002, "zoom inertia is consistent at 30 and 144 FPS")
	main.office._scroll_zoom(100)
	for i in 120: main.office._tick_wheel_zoom(1.0/60.0)
	check(is_equal_approx(main.office.camera.zoom.x,4.0), "smooth wheel zoom retains the native 4x maximum")
	main.office._scroll_zoom(-1)
	Game.push_pause()
	main.office._process(0.1)
	check(not main.office._wheel_active and is_equal_approx(main.office.camera.zoom.x,4.0), "opening a modal cancels residual zoom motion")
	Game.pop_pause()
	Game.running = false
	var art_files = files("res://assets")
	check(not art_files.any(func(path: String): return path.ends_with(".aseprite") or path.ends_with(".ase")),"all editable art sources are outside the runtime project")
	var pngs = 0
	for path in art_files:
		if not path.ends_with(".png"): continue
		pngs += 1
		var texture = load(path) as Texture2D
		check(texture != null and texture.get_width() > 0,"retained texture loads: "+path)
	check(pngs == 144,"144 runtime PNGs include the title wallpaper and exclude the unused city-faint background")
	for room in ["studio","office","lobby","lounge","meeting","cafeteria","storage"]:
		check(Art.room(room) != null and Art.room(room,true) != null,"dynamic room foreground/background retained: "+room)
	for instrument in Art.INSTRUMENTS: check(Art.instrument_info(instrument)["texture"] != null,"instrument retained: "+instrument)
	for chat in Art.CHATS: check(Art.texture("res://assets/chatmusic/chat-%s-6frames.png" % chat) != null,"chat atlas retained: "+chat)
	for id in Art.npc_ids + Art.vip_ids:
		check(Art.frames(id).get_frame_count("walk") == 6 and Art.portrait(id) != null,"native world and portrait textures retained: "+id)
	var logo = (load("res://assets/title/the-producer-logo.png") as Texture2D).get_image()
	check(logo.get_size() == Vector2i(288,96),"hand-pixel logo has native 288x96 dimensions")
	var colors: Dictionary = {}
	var binary = true
	for y in logo.get_height():
		for x in logo.get_width():
			var c = logo.get_pixel(x,y)
			if c.a != 0 and c.a != 1: binary = false
			if c.a > 0: colors[c.to_rgba32()] = true
	check(binary and colors.size() <= 5,"logo edges use binary alpha and five exact colors without smoothing")
	print("RUNTIME TESTS: %d checks, %d failures" % [checks,failures])
	await Audio.shutdown()
	get_tree().quit(1 if failures else 0)
