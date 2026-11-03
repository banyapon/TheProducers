extends Node
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok: failures += 1; push_error(label)
	else: print("ok: ", label)
func _ready() -> void:
	Game.save_slot = "agency_qa"
	Game.new_game()
	Game.running = true
	Game.speed = 0
	Game.tutorial_step = -1
	var names: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/company_list.json"))
	var unique = {}
	for company in names: unique[company] = true
	check(names.size() == 300 and unique.size() == 300, "300 unique English companies")
	check(Game.items["research"] == 0, "consult must be purchased")
	Game.money = 799
	check(not Game.buy_item("research") and Game.items["research"] == 0, "cannot buy without 800")
	Game.money = 5000
	check(Game.buy_item("research") and Game.money == 4200, "fixed package price 800")
	var job: Dictionary = Game.offers[0]
	var low = {"mix": {"Pop": 100}, "roles": ["Vocal"], "deadline": 8}
	var high = {"mix": {"Pop": 50, "Rock": 50}, "roles": ["Vocal", "Guitar"], "deadline": 2}
	check(Game.research_price(high) > Game.research_price(low), "complex and urgent work costs more")
	Game.money = 0
	Game.start_research(job)
	check(Game.items["research"] == 1 and Game.research_tasks.is_empty(), "insufficient service fee preserves package")
	Game.money = 5000
	var fee = Game.research_price(job)
	Game.start_research(job)
	check(Game.money == 5000 - fee and Game.items["research"] == 0 and Game.research_tasks.size() == 1, "research charges fee and consumes one package")
	Game.start_research(job)
	check(Game.money == 5000 - fee, "no double charge while busy")
	for id in ["super-02", "super-04", "super-06"]:
		check(Game.client_contact({"art_id": id, "name": names[0]}).begins_with("Ms."), "female VIP " + id)
	check(names.has(Game._pick_client()), "new client uses company pool")
	Game.research_tasks.clear()
	var panel = CityPanel.new()
	add_child(panel)
	panel.location = "agency"
	panel.open()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_webp("D:/EP45/ndlp/Producers/agency-qa.webp", true)
	panel.close()
	panel.queue_free()
	await get_tree().process_frame
	print("AGENCY failures: ", failures)
	get_tree().quit(failures)
