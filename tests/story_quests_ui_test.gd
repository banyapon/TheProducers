extends Control
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func settle() -> void:
	for i in 5: await get_tree().process_frame
func shot(id: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_webp("D:/Temp/quest-" + id + ".webp")
		get_viewport().get_texture().get_image().save_png("D:/Temp/quest-" + id + ".png")
func _ready() -> void:
	Game.set_process(false)
	var partial_art = "--partial-art" in OS.get_cmdline_user_args()
	var original = Locale.language
	var login = LoginScreen.new()
	add_child(login)
	await settle()
	check(login.find_child("TitleQuests", true, false) != null, "Title quest entry")
	await shot("title")
	var pauses = Game._pause_requests
	login._open_quests()
	await settle()
	for lang in ["th", "en"]:
		login._quest_catalogue.catalogue_scroll.scroll_vertical = 400
		await settle()
		Locale.set_language(lang)
		await settle()
		check(is_instance_valid(login._quest_catalogue) and login._quest_catalogue.visible, "Language keeps catalogue open")
		check(login._quest_catalogue.catalogue_scroll.scroll_vertical >= 390, "Catalogue preserves scroll through refresh")
		login._quest_catalogue.catalogue_scroll.scroll_vertical = 0
		check(login._quest_catalogue.find_child("Quest_aurelian", true, false) != null, "All 20 quest entries")
		await shot(lang)
	login.escape()
	await settle()
	check(Game._pause_requests == pauses, "Preview close releases pause")
	login.queue_free()
	await settle()
	Game.save_slot = "story_quest_ui_qa"
	Game.new_game()
	Game.running = true
	Game.speed = 0
	var panel = QuestPanel.new()
	add_child(panel)
	panel.open_catalogue()
	await settle()
	check(panel.find_child("Quest_mali", true, false) == null, "Career quest menu hides stories that have not been accepted")
	check(StoryQuests.accept("mali"), "UI career accepts quest")
	await settle()
	check(panel.find_child("Quest_mali", true, false) != null, "Accepted quest stays on the menu")
	check(panel.find_child("Quest_boon", true, false) == null, "Unaccepted quest stays off the menu")
	await shot("active")
	check(StoryQuests.issue_brief("mali"), "UI creates real commission")
	await settle()
	check(Game.offers.back().get("story_quest_id", "") == "mali", "Brief links back to quest")
	panel.scene_stage = "success"
	for index in 4:
		panel.scene_index = index
		panel.refresh()
		await settle()
	await shot("ending")
	panel.close()
	check(Game._pause_requests == pauses, "Career close releases pause")
	panel.queue_free()
	await settle()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game._save_path()))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.character_parts_path()))
	Game.running = false
	for q in StoryQuests.definitions:
		for expression in 4:
			check(Art.portrait(q.npc.art_id, expression) != null, "Portrait " + q.id)
		var all_imported = true
		for action in ["idle", "walk", "play"]:
			var motion_path = "res://assets/quests/" + q.id + "/" + action + ".png"
			if not partial_art: check(ResourceLoader.exists(motion_path), "Own imported 3x3 sheet " + q.id + " " + action)
			all_imported = all_imported and ResourceLoader.exists(motion_path)
			if ResourceLoader.exists(motion_path):
				var pixels = Art.texture(motion_path, Vector2i(480,480)).get_image()
				check(pixels.get_pixel(0,0).a == 0.0, "Transparent sheet background " + q.id + " " + action)
				var occupied = 0
				for y in range(0, 480, 4):
					for x in range(0, 480, 4):
						if pixels.get_pixel(x,y).a > 0.0: occupied += 1
				check(occupied < 5040, "No background haze between sprites " + q.id + " " + action)
		if all_imported:
			var frames = Art.office_frames(q.npc.art_id)
			for anim in ["idle","walk","play","talk"]:
				check(frames.get_frame_count(anim) == 9, "Nine motion frames " + q.id)
				for f in 9:
					check(frames.get_frame_texture(anim,f).get_size() == Vector2(160,160), "Virtual frame size " + q.id)
					var pose: AtlasTexture = frames.get_frame_texture(anim,f)
					check(pose.region.size.x > 0 and pose.region.size.y > 0, "Nonempty animation cell " + q.id)
	var backdrop = ColorRect.new()
	backdrop.color = Color("132033")
	backdrop.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(backdrop)
	var gallery = GridContainer.new()
	gallery.columns = 5
	add_child(gallery)
	for q in StoryQuests.definitions:
		var cell = VBoxContainer.new()
		cell.custom_minimum_size = Vector2(378, 260)
		gallery.add_child(cell)
		cell.add_child(UIKit.label(q.npc.name.en, 36))
		var art_row = HBoxContainer.new()
		cell.add_child(art_row)
		var face = TextureRect.new()
		face.texture = Art.portrait(q.npc.art_id)
		face.texture_filter = TEXTURE_FILTER_NEAREST
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.custom_minimum_size = Vector2(160, 160)
		art_row.add_child(face)
		var body = TextureRect.new()
		body.texture = Art.office_frames(q.npc.art_id).get_frame_texture("play", 0)
		body.texture_filter = TEXTURE_FILTER_NEAREST
		body.custom_minimum_size = Vector2(160,160)
		art_row.add_child(body)
	await settle()
	await shot("cast")
	Locale.set_language(original)
	print("QUEST UI: failures ", failures, " (partial art: ", partial_art, ")")
	await Audio.shutdown()
	get_tree().quit(1 if failures else 0)

