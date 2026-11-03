extends Node
var checks := 0
var failures := 0
func check(ok: bool, text: String) -> void:
	checks += 1
	if ok: print("ok: ", text)
	else: failures += 1; push_error(text)

func _ready() -> void:
	var original_mode = Locale.relationship_mode
	var original_language = Locale.language
	Game.save_slot = "city_companion_qa"
	Game.new_game()
	Game.running = true
	Game.speed = 0
	Game.tutorial_step = -1
	Game.staff[0]["gender"] = "male"
	Game.staff[1]["gender"] = "female"
	Game.staff[1]["art_id"] = "npc-08-female-bun"
	Game.staff[1]["name"] = "Maya"
	var male = str(Game.staff[0]["id"])
	var female = str(Game.staff[1]["id"])
	var panel = CityPanel.new()
	add_child(panel)
	Locale.set_relationship_mode("different_gender")
	panel.visit()
	check(panel.choosing_companion and panel.contact == "", "City requires explicit companion selection")
	check(panel.find_child("CityAction_walk", true, false) == null, "activities hidden before selection")
	var entries = panel.companion_entries()
	check(entries.all(func(e): return RelationshipOptions.gender_of(e["person"]) == "female"), "Female mode filters all staff and clients by gender")
	check(panel.find_child("CityCompanion_" + male, true, false) == null, "male staff absent in Female mode")
	check(panel.find_child("CityCompanion_alice", true, false) != null, "Alice remains available without revealing secret dating unlock")
	panel.find_child("CityCompanion_" + female, true, false).pressed.emit()
	check(panel.contact == female and not panel.choosing_companion, "clicking female companion enters city")
	check(panel.find_child("CityAction_walk", true, false) != null, "activities become available after selection")
	panel.close()
	panel.visit()
	check(panel.choosing_companion and panel.contact.is_empty(), "reopening City asks again")
	Locale.set_relationship_mode("all_genders")
	check(panel.find_child("CityCompanion_" + male, true, false) != null and panel.find_child("CityCompanion_" + female, true, false) != null, "Options change refreshes picker to show both genders")
	panel.find_child("CityCompanion_" + male, true, false).pressed.emit()
	check(panel.contact == male and not panel.choosing_companion, "All Gender permits male companion")
	Locale.set_relationship_mode("different_gender")
	check(panel.choosing_companion and panel.contact == "", "switching to Female invalidates selected male")
	panel.visit(male)
	check(panel.choosing_companion and panel.contact == "", "direct visit cannot bypass mode filter")
	panel.announce({"win": true, "song": "Test", "rating": 35})
	check(not panel.choosing_companion and panel.find_child("CityBackdrop", true, false) != null, "award ceremony does not require a companion")
	panel.visit()
	Locale.set_language("th")
	await get_tree().process_frame
	await get_tree().process_frame
	if "--visual" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_webp("D:/EP45/ndlp/Producers/Star-Life-20261031/qa-city-companions.webp")
	panel.close()
	Locale.set_relationship_mode(original_mode)
	Locale.set_language(original_language)
	Game.running = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game._save_path()))
	print("CITY COMPANIONS: %d checks, %d failures" % [checks, failures])
	await Audio.shutdown()
	get_tree().quit(1 if failures else 0)
