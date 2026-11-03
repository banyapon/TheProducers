extends Node
var failures := 0
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
	else: print("ok: ", label)
func fixture(kind: String) -> Dictionary:
	return IdeaRules.create_studio({"id": "test", "mix": {"Pop":100}, "brief_kind": kind, "artist_genre":"Pop"})
func _ready() -> void:
	var cafe = fixture("cafe")
	cafe["bpm"] = 90
	for col in 8: cafe["placed"].append({"block": 2, "row": 0, "col": col})
	var calm = IdeaRules.score(cafe)["score"]
	var sport = cafe.duplicate(true)
	sport["brief"] = CompositionDesign.brief({"id":"sport", "brief_kind":"sport", "mix":{"Pop":100}})
	check(calm > IdeaRules.score(sport)["score"], "same sparse slow arrangement better serves cafe than sports")
	var dense = cafe.duplicate(true)
	for row in range(1,4):
		for col in 8: dense["placed"].append({"block":0,"row":row,"col":col})
	check(calm > IdeaRules.score(dense)["score"], "filling every lane is not optimal for a calm brief")
	sport["bpm"] = 140
	var before = IdeaRules.score(sport)["score"]
	for col in range(5,8):
		for row in [1,3]: sport["placed"].append({"block":0,"row":row,"col":col})
	check(IdeaRules.score(sport)["score"] > before, "building a hook improves the sports arrangement")
	check(IdeaRules.score(fixture("debut"))["score"] == 0, "empty song scores zero")
	Game.save_slot = "arrangement_qa"
	Game.new_game()
	Game.running = true; Game.speed = 0; Game.tutorial_step = -1
	var job: Dictionary = Game.offers[0]
	Game.accept_offer(job)
	Game.begin_idea_meeting(job)
	Game.idea_meeting["phase"] = "ready"
	var panel = IdeaJamPanel.new()
	add_child(panel); panel.open()
	panel.place(0,0,0)
	await get_tree().process_frame
	check(Game.idea_meeting["placed"].size() == 1, "place clip")
	panel.undo()
	check(Game.idea_meeting["placed"].is_empty(), "undo placement")
	panel.redo()
	check(Game.idea_meeting["placed"].size() == 1, "redo placement")
	var id = Game.idea_meeting["placed"][0]["block"]
	Game.idea_meeting["copy_next"] = true
	panel.place(id,0,5)
	await get_tree().process_frame
	check(Game.idea_meeting["placed"].size() == 2, "copy keeps original")
	if "--visual" in OS.get_cmdline_user_args():
		panel.selected = -1; panel.inspected = id; panel.refresh()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_webp("D:/EP45/ndlp/Producers/arrangement-inspector.webp", true)
	panel.close()
	check(not Game.idea_meeting.is_empty() and int(job.get("idea_rounds",0)) == 0, "closing saves draft without submitting")
	check(Game.begin_idea_meeting(job) == "", "same job can resume draft")
	Game.save_game(); Game.load_game()
	check(Game.idea_meeting["placed"].size() == 2 and not Game.idea_meeting["undo"].is_empty(), "draft and history survive save load")
	panel.close(); panel.queue_free()
	Game.idea_meeting = {}
	DemoCareer.setup()
	check(Game.offers.size() == 1 and Game.offers[0]["brief_kind"] == "cafe", "demo starts with cafe commission")
	var completed = [false]
	Game.demo_completed.connect(func(): completed[0] = true)
	for i in 3:
		var demo_job: Dictionary = Game.offers[0]
		check(demo_job["brief_kind"] == ["cafe","sport","debut"][i], "demo brief order %d" % i)
		Game.accept_offer(demo_job, "auto")
		Game.project = {"job_id":demo_job["id"], "title":demo_job["title"], "done":true, "team":[Game.staff[0]["id"]], "mix":demo_job["mix"], "eval":{"total":20,"critics":[]}}
		Game.release_project(0)
	check(completed[0] and Game.life["demo"]["completed"].size() == 3, "demo ends after three releases regardless of winning")
	Game.save_game(); Game.load_game()
	check(Game.life["demo"]["finished"], "demo ending survives reload")
	Game.running = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game._save_path()))
	print("ARRANGEMENT: %d checks, %d failures" % [checks, failures])
	await Audio.shutdown()
	get_tree().quit(failures)
