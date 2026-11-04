extends Node

var failures := 0
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func capture(stem: String) -> void:
	if not "--visual" in OS.get_cmdline_user_args(): return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_webp("D:/EP45/ndlp/Producers/" + stem + ".webp", true)

func _ready() -> void:
	Game.save_slot = "outdoor_fullbody_qa"
	Game.new_game()
	Game.speed = 0
	Game.running = true
	var panel = CityPanel.new()
	add_child(panel)
	panel.visit("alice")
	panel.choosing_companion = false
	for place in ["city", "park", "restaurant", "hall"]:
		panel.location = place
		panel.refresh()
		var view = panel.find_child("CityProducer", true, false) as PortraitView
		var partner = panel.find_child("CityCompanion", true, false) as PortraitView
		check(view != null and partner != null, place + " has both assembled actors")
		check(view.fullbody.parts.size() == 7 and partner.fullbody.parts.size() == 7, "seven new part layers")
		await get_tree().create_timer(0.2).timeout
		check(view.fullbody.animation == "walk", "arrival uses walk animation")
		await get_tree().create_timer(0.75).timeout
		check(view.fullbody.animation == "idle" and partner.flip_h, "arrival settles and partner faces player")
	panel.location = "park"
	panel.social_action = "talk"
	panel.refresh()
	await get_tree().create_timer(1.0).timeout
	var companion = panel.find_child("CityCompanion", true, false) as PortraitView
	check(companion.fullbody.animation == "talk", "social conversation animates assembled parts")
	check(companion.fullbody.parts["body"].texture.resource_path == "res://assets/fullbody/body/alice-4x4.png" and companion.fullbody.parts["body"].material == null, "new colored Alice art used without double tint")
	var city_portrait = panel.find_child("CityCompanionPortrait", true, false) as PortraitView
	check(city_portrait.crop_half and city_portrait.clip_contents and city_portrait.fullbody.visible, "City conversation uses cropped assembled character")
	await capture("city-fullbody")
	panel.close()
	var dialog = load("res://scenes/ui/dialog_box.tscn").instantiate() as DialogBox
	add_child(dialog)
	dialog.open(Game.player_portrait(), Game.assistant_portrait())
	dialog._show_line("right", "Let's take a walk and talk about our next song.")
	dialog._resize_box("Let's take a walk and talk about our next song.", false)
	await get_tree().create_timer(0.1).timeout
	check(not is_instance_valid(dialog.right_portrait.fullbody) and dialog.right_portrait.texture != null, "regular dialogue uses original portrait")
	await capture("regular-dialog-pixel")
	dialog.close()
	Game.running = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game._save_path()))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save_outdoor_fullbody_qa.fullbody.json"))
	print("OUTDOOR FULLBODY: %d checks, %d failures" % [checks, failures])
	await Audio.shutdown()
	get_tree().quit(failures)
