extends Node
## Run with the native display backend to exercise both Options fullscreen toggles.
var failures := 0
var checks := 0
var main: Node

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	await get_tree().create_timer(0.25).timeout
	await get_tree().process_frame

func fullscreen_checkbox(node: Node) -> CheckBox:
	if node is CheckBox and node.text == Locale.text("fullscreen"):
		return node
	for child in node.get_children():
		var found := fullscreen_checkbox(child)
		if found != null:
			return found
	return null

func check_fits(label: String) -> void:
	var window := get_tree().root
	var logical := window.get_visible_rect().size
	var scaled := window.get_stretch_transform().get_scale() * logical
	check(scaled.x <= window.size.x + 1 and scaled.y <= window.size.y + 1,
		"viewport fits client area after " + label)
	var menu: Control = main.login.get_node("TitleMenu")
	check(Rect2(Vector2.ZERO, logical).grow(1).encloses(menu.get_global_rect()),
		"title menu fits logical viewport after " + label)
	check(menu.get_global_rect().end.y <= main.login.get_node("TitleCreditBar").get_global_rect().position.y,
		"title menu clears footer after " + label)

func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await settle()
	for panel in [main.login, main.shell]:
		if panel == main.login:
			main.login._page = "options"
			main.login._render()
		else:
			main.login.hide()
			main.shell.open()
		var toggle := fullscreen_checkbox(panel)
		check(toggle != null, "Options fullscreen checkbox exists")
		if toggle == null:
			continue
		# Use the actual UI signal handlers, including a fullscreen -> windowed round trip.
		toggle.button_pressed = true
		await settle()
		check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "Options enters fullscreen")
		toggle.button_pressed = false
		await settle()
		check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED, "Options restores windowed mode")
		if panel == main.shell:
			main.shell.close()
		main.login.open()
		for target in [Vector2i(1600, 900), Vector2i(1280, 720), Vector2i(1024, 768)]:
			DisplayServer.window_set_size(target)
			await settle()
			check_fits(str(target))
			for tab in [1, 2, 0]:
				main.login._select_home_tab(tab)
				await settle()
				check_fits("tab %d at %s" % [tab, target])
	var qa_dir := OS.get_environment("PRODUCERS_QA_DIR")
	if not qa_dir.is_empty():
		DisplayServer.window_set_size(Vector2i(1600, 900))
		await settle()
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(qa_dir)
		get_viewport().get_texture().get_image().save_png(qa_dir.path_join("windowed-1600x900.png"))
	print("WINDOW MODE TESTS: %d checks, %d failures" % [checks, failures])
	await Audio.shutdown()
	get_tree().quit(1 if failures else 0)
