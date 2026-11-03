extends Node
var failures := 0
var checks := 0
var visual := false

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok: print("ok: ", message)
	else: failures += 1; push_error(message)

func _ready() -> void:
	visual = "--visual" in OS.get_cmdline_user_args()
	var original_mode = Locale.relationship_mode
	var original_language = Locale.language
	Game.save_slot = "relationship_options_qa"
	Game.new_game()
	Game.running = true
	Game.speed = 0
	Game.money = 100000
	Game.day = 120
	var a: Dictionary = Game.staff[0]
	var b: Dictionary = Game.staff[1]
	for person in [a, b]:
		person["gender"] = "male"
		person["social"]["trust"] = 80
		person["social"]["comfort"] = 80
		person["social"]["interested"] = true
	Locale.set_relationship_mode("different_gender")
	check(not StudioLife.pair_staff(a, b), "same-gender staff cannot start romance before opt-in")
	check(not StudioCity.interact(a["id"], "date")["ok"], "same-gender player date blocked before opt-in")
	check(StudioCity.interact(a["id"], "talk")["ok"], "friendship still available in either mode")
	b["gender"] = "female"
	check(StudioCity.date_reason(b, false) == "", "different-gender date is available by default")
	check(StudioLife.pair_staff(a, b), "different-gender staff may pair")
	for person in [a, b]: person["social"]["partner"] = ""
	var client: Dictionary = Game.clients.values()[0]
	client["gender"] = "male"
	client["met_day"] = 0; client["completed_jobs"] = 2; client["rel"] = 80
	client["contact_opt_in"] = true; client["contact_adult"] = true
	client["social"]["interested"] = true
	client["social"]["trust"] = 80; client["social"]["comfort"] = 80
	check(StudioCity.date_reason(client, true) == Locale.text("relationship_mode_unavailable"), "client romance respects mode")
	var main = load("res://scenes/main.tscn").instantiate()
	main._booting = true
	add_child(main)
	main.login._page = "options"
	main.login._render()
	var picker = main.login.find_child("RelationshipMode", true, false) as OptionButton
	check(picker != null and picker.selected == 0, "title Options starts with different-gender selection")
	picker.select(1)
	picker.item_selected.emit(1)
	check(Locale.relationship_mode == "all_genders", "explicit selection enables LGBTQ+ mode")
	var settings = ConfigFile.new()
	settings.load(Locale.SETTINGS_PATH)
	check(settings.get_value("gameplay", "relationship_mode") == "all_genders", "mode is saved for next launch")
	check(StudioCity.date_reason(client, true) == "", "opt-in enables eligible same-gender client romance")
	Game.day += 1
	check(StudioCity.interact(a["id"], "date")["ok"], "opt-in enables eligible same-gender player date")
	b["gender"] = "male"
	check(StudioLife.pair_staff(a, b), "opt-in enables same-gender staff pairs")
	Locale.set_relationship_mode("different_gender")
	check(a["social"]["partner"] == b["id"] and b["social"]["partner"] == a["id"], "switching back preserves existing NPC couples")
	for person in [a, b]: person["social"]["partner"] = ""
	a["social"]["partner"] = "producer"
	check(StudioCity.date_reason(a, false) == "", "existing player partner remains dateable after switching back")
	Locale.set_relationship_mode("invalid")
	check(Locale.relationship_mode == "different_gender", "invalid setting cannot enable mode")
	main.login.hide()
	for lang in ["en", "th"]:
		Locale.language = lang
		main.shell.open()
		await get_tree().process_frame
		await get_tree().process_frame
		var ingame = main.shell.find_child("RelationshipMode", true, false) as OptionButton
		check(ingame != null and ingame.selected == 0, "in-game Options shares preference: " + lang)
		check(ingame.get_global_rect().end.y <= get_viewport().get_visible_rect().size.y, "relationship control fits viewport: " + lang)
		if visual:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("D:/EP45/ndlp/Producers/City-Life/qa-relationship-" + lang + ".png")
		main.shell.close()
	Locale.language = original_language
	Locale.set_relationship_mode(original_mode)
	main._queue.clear()
	Game.running = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game._save_path()))
	print("RELATIONSHIP OPTIONS: %d checks, %d failures" % [checks, failures])
	await Audio.shutdown()
	get_tree().quit(1 if failures else 0)
