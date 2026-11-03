extends Node
var requests: Array = []
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok: failures += 1; push_error(label)
	else: print("ok: ", label)
func _ready() -> void:
	Game.save_slot = "manual_gate_qa"
	Game.new_game()
	Game.manual_composition_requested.connect(func(id: String): requests.append(id))
	var job: Dictionary = Game.offers[0]
	Game.accept_offer(job, "manual")
	var team = [Game.staff[0]["id"]]
	check(Game.needs_manual_composition(job), "Manual requires composition")
	check(Game.start_project(job["id"], team, job["mix"], "Manual") == Locale.text("manual_required"), "recording cannot bypass minigame")
	check(Game.schedule_project(job["id"], team, job["mix"], "Manual", Game.day + 1) == Locale.text("manual_required"), "scheduling cannot bypass minigame")
	Game.items["research"] = 2
	Game.money = 100000
	Game.start_research(job)
	Game.day += 3
	Game._tick_research()
	check(requests == [job["id"]], "completed Manual research requests minigame")
	Game._tick_research()
	check(requests.size() == 1, "research completion requests only once")
	job["idea_rounds"] = 1
	check(not Game.needs_manual_composition(job), "completed arrangement permits production")
	job["idea_rounds"] = 0
	job["play_mode"] = "auto"
	check(not Game.needs_manual_composition(job), "Auto skips minigame")
	Game.start_research(job)
	Game.day += 3
	Game._tick_research()
	check(requests.size() == 1, "Auto research does not request minigame")
	print("MANUAL GATE failures: ", failures)
	Game.running = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game._save_path()))
	await Audio.shutdown()
	get_tree().quit(failures)
