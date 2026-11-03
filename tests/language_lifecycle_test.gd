extends Node
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
	else: print("ok: ", message)

func _ready() -> void:
	var original = Locale.language
	var before = Locale.language_changed.get_connections().size()
	var states_before = Game.state_loaded.get_connections().size()
	for cycle in 3:
		var library = load("res://scenes/ui/library.tscn").instantiate()
		add_child(library)
		var coach = TutorialCoach.new()
		add_child(coach)
		for language in ["th", "en"]:
			Locale.set_language(language)
			Game.state_loaded.emit()
			await get_tree().process_frame
			var button = library.get_node("Window/VBox/Header").get_children().back()
			check(button.text == Locale.text("stars_collection"), "collection translated: " + language)
		library.queue_free()
		coach.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
		check(Locale.language_changed.get_connections().size() == before, "library callback removed on scene teardown")
		check(Game.state_loaded.get_connections().size() == states_before, "coach callback removed on scene teardown")
		Locale.set_language("th")
		Game.state_loaded.emit()
	Locale.set_language(original)
	print("LANGUAGE LIFECYCLE: %d checks, %d failures" % [checks, failures])
	await Audio.shutdown()
	get_tree().quit(1 if failures else 0)
