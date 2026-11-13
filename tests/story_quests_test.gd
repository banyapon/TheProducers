extends Node
var failures := 0
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)

func song_for(q: Dictionary, index: int) -> Dictionary:
	var genre = q["genre"] if q["genre"] != "" else "Pop"
	if q["criterion"] == "dance_pair": genre = ["EDM", "HipHop"][index % 2]
	if q["criterion"] == "distinct": genre = ["Pop", "Jazz", "Rock"][index % 3]
	return {"id":"qa_" + q["id"] + str(index), "title":"QA " + q["id"], "rating":maxi(35, int(q["rating"])),
		"mix":{genre:100}, "story_quest_id":q["id"], "day":Game.day,
		"story_metrics":{"bpm":90, "density":0.4, "repeat":1.0, "rise":0.2, "improvise":true, "melody_improvise":true}}

func _ready() -> void:
	Game.set_process(false)
	Game.save_slot = "story_quests_qa"
	Game.new_game()
	Game.running = false
	check(not StoryQuests.accept("mali"), "title catalogue cannot mutate a career")
	Game.running = true
	Game.speed = 0
	StoryQuests.sync()
	check(StoryQuests.definitions.size() == 20, "twenty distinct quests")
	check(StoryQuests.status("leo") == "locked" and StoryQuests.status("aurelian") == "locked", "story prerequisites enforced")
	check(not StoryQuests.accept("unknown"), "unknown IDs rejected")
	for q in StoryQuests.definitions:
		var insufficient = song_for(q, 900)
		if int(q["rating"]) > 0:
			insufficient["rating"] = int(q["rating"]) - 1
			check(not StoryQuests._matches(q, insufficient), q["id"] + " minimum rating enforced")
		var missing_metrics = song_for(q, 901)
		missing_metrics["story_metrics"] = {}
		if q["criterion"] in ["gentle", "hook", "rise", "improvise", "melody_improvise"]:
			check(not StoryQuests._matches(q, missing_metrics), q["id"] + " required arrangement evidence enforced")
		for language in ["th", "en"]:
			check(not q["title"][language].is_empty(), q["id"] + " translated title")
			for scene in ["intro", "hint", "success", "scene", "return"]:
				check(not q["dialogue"][scene][language].is_empty(), q["id"] + " translated scene")
		if q["mode"] == "collection":
			for i in int(q["count"]): StoryQuests._released(song_for(q, i))
		check(StoryQuests.accept(q["id"]), q["id"] + " accepted")
		check(not StoryQuests.accept(q["id"]), q["id"] + " cannot accept twice")
		if q["mode"] == "commission":
			check(not StoryQuests.claim(q["id"]), q["id"] + " unearned reward blocked")
			var wrong = song_for(q, 99)
			wrong["story_quest_id"] = "other"
			StoryQuests._released(wrong)
			check(StoryQuests.progress(q["id"])["count"] == 0, q["id"] + " requires its own brief")
			for i in int(q["count"]): StoryQuests._released(song_for(q, i))
		check(StoryQuests.status(q["id"]) == "ready", q["id"] + " objective can be satisfied")
		var before = Game.money
		check(StoryQuests.claim(q["id"]), q["id"] + " reward claimed")
		check(Game.money == before + int(q["reward"]["money"]), q["id"] + " exact cash reward")
		check(not StoryQuests.claim(q["id"]), q["id"] + " no double reward")
		StoryQuests._released(song_for(q, 0))
		check(Game.money == before + int(q["reward"]["money"]), q["id"] + " duplicate event gives no money")
	check(StoryQuests.completed_count() == 20, "all twenty stories completable")
	check(Game.trophies.filter(func(t): return t.has("story_quest")).size() == 2, "deterministic story contests give two trophies")
	check(is_equal_approx(StoryQuests.client_multiplier(Game.get_client("Story / Vivian")), 1.8), "VIP premium unlocks")
	check(StoryQuests.issue_brief("vivian"), "VIP commission generated")
	check(Game.offers.back()["pay"] == 21600, "VIP commission pays 1.8x base")
	check(not StoryQuests.issue_brief("vivian"), "duplicate commission prevented")
	Game.offers.erase(Game.offers.back())
	check(not StoryQuests.issue_brief("vivian"), "declining cannot farm deposits")
	Game.day += 7
	check(StoryQuests.issue_brief("vivian"), "VIP work returns after cooldown")
	var staff_before = Game.staff.size()
	check(StoryQuests.recruit("rex") == "", "unlocked rapper can be hired")
	check(Game.staff.size() == staff_before + 1, "hire adds one employee")
	check(StoryQuests.recruit("rex") != "" and Game.staff.size() == staff_before + 1, "cannot hire duplicate rapper")
	check(Game.get_artist("story_artist_rex")["art_id"] == "quest-rex", "recruit uses own visual identity")
	check(Game.get_artist("story_artist_rex").get("romance_unlocked", false), "passing an artist story unlocks romance")
	var relationship_mode = Locale.relationship_mode
	Locale.relationship_mode = "all_genders"
	check(StudioCity.date_reason(Game.get_artist("story_artist_rex"), false) == "", "story teammate can be dated without the four-month wait")
	Locale.relationship_mode = relationship_mode
	check(Game.get_client("Story / Vivian").get("regular", false) and int(Game.get_client("Story / Vivian")["rel"]) >= 55, "passing a client story makes a regular")
	check(not Game.get_client("Story / Rex").get("regular", false), "an artist story does not also become a regular client")
	Game.save_game()
	check(Game.load_game(), "quest save loads")
	StoryQuests.sync()
	check(StoryQuests.completed_count() == 20 and not StoryQuests.claim("rex"), "completion and reward guards survive reload")
	check(StoryQuests.state("rose")["choice"] == "together", "dialogue choice persists")
	StoryQuests.mark_ending_seen("rose")
	check(StoryQuests.state("rose")["ending_seen"], "ending replay state persists")
	var job = {"id":"qaj", "mix":{"EDM":100}}
	var arrangement = IdeaRules.create_studio(job)
	arrangement["placed"] = [{"block":0,"row":0,"col":0}]
	arrangement["deck"][0]["recorded_notes"] = [{"beat":0,"note":60,"duration":1}]
	var released = {}
	StoryQuests.annotate_release({"story_quest_id":"beep", "arrangement":arrangement}, released)
	check(released["story_metrics"]["improvise"] and released["story_metrics"]["melody_improvise"], "release captures real recorded clips")
	arrangement["bpm"] = 90
	arrangement["placed"] = [{"block":0,"row":0,"col":0}, {"block":0,"row":0,"col":5}, {"block":0,"row":0,"col":6}, {"block":0,"row":0,"col":7}]
	StoryQuests.annotate_release({"story_quest_id":"mali", "arrangement":arrangement}, released)
	released["mix"] = {"Pop":100}; released["rating"] = 35
	check(StoryQuests._matches(StoryQuests.definition("mali"), released), "real sparse slow arrangement satisfies teacher")
	released["story_quest_id"] = "pim"; released["mix"] = {"R&B":100}
	check(StoryQuests._matches(StoryQuests.definition("pim"), released), "real repeated Melody satisfies hook")
	released["story_quest_id"] = "selene"
	check(StoryQuests._matches(StoryQuests.definition("selene"), released), "real Build-to-Hook rise satisfies singer")
	check(StoryQuests.primary_genre({"mix":{"Jazz":50,"Pop":50}}) == "", "tied genre does not silently count")
	var silent_song = song_for(StoryQuests.definition("mali"), 902)
	silent_song["story_metrics"]["density"] = 0.0
	check(not StoryQuests._matches(StoryQuests.definition("mali"), silent_song), "an empty arrangement cannot satisfy a gentle music quest")
	var remixed = song_for(StoryQuests.definition("vivian"), 10)
	remixed["remix_of"] = "source"
	check(not StoryQuests._matches(StoryQuests.definition("vivian"), remixed), "remixes excluded from collections")
	Game.new_game()
	StoryQuests.sync()
	check(StoryQuests.completed_count() == 0 and StoryQuests.progress("vivian")["count"] == 0, "new career has no previous quest progress")
	StoryQuests.accept("mali")
	StoryQuests.issue_brief("mali")
	var live_job = Game.offers.back()
	Game.accept_offer(live_job, "manual")
	live_job["arrangement"] = arrangement.duplicate(true)
	live_job["idea_rounds"] = 1
	check(Game.start_project(live_job["id"], Game.staff.map(func(a): return a["id"]), {"Pop":100}, "Quest integration") == "", "quest brief starts normal recording")
	for i in 30:
		Game._tick_project()
		if Game.project.get("creative_pending", false): CreativeJourney.resolve(live_job["id"], 0)
	check(Game.project.get("done", false), "quest recording completes through production")
	var actual_song = Game.release_project(0)
	check(actual_song.get("story_quest_id", "") == "mali", "normal release preserves quest link")
	check(StoryQuests.state_data()["songs"].has(actual_song.get("id", "")), "release signal automatically updates quest evidence")
	check(actual_song.get("story_metrics", {}).get("bpm", 0) == 90, "normal release captures actual arrangement")
	Game.new_game()
	Game.running = true
	Game.speed = 0
	Game.tutorial_step = -1
	check(StoryQuests.accepted_ids().is_empty(), "quest menu starts with no accepted stories")
	Game.reputation = 35
	Game.day = 3
	StoryQuests.consider_visit()
	check(StoryQuests.pending_visitor() == "mali", "reputation brings the first guest to the office")
	StoryQuests.decline_visit()
	Game.day = 6
	StoryQuests.consider_visit()
	check(StoryQuests.pending_visitor() == "boon", "the next guest arrives after a decline")
	check(StoryQuests.pending_visitor() != "aurelian", "late stories stay behind their prerequisites")
	StoryQuests.decline_visit()
	Game.reputation = 100
	Game.day = 30
	StoryQuests.consider_visit()
	check(StoryQuests.pending_visitor() != "aurelian" and StoryQuests.pending_visitor() != "leo", "reputation cannot skip story prerequisites")
	StoryQuests.accept(StoryQuests.pending_visitor())
	check(StoryQuests.accepted_ids().size() == 1, "quest menu lists only the accepted story")
	check(StoryQuests.pending_visitor() == "", "accepting sends the guest on their way")
	Game.reputation = 0
	var surprise = ""
	for day in range(1, 80):
		Game.day = day
		StoryQuests.state_data()["visitor"] = ""
		StoryQuests.state_data()["next_visit_day"] = 0
		StoryQuests.consider_visit()
		if StoryQuests.pending_visitor() != "":
			surprise = StoryQuests.pending_visitor()
			break
	check(surprise != "" and StoryQuests.reputation_need(StoryQuests.definition(surprise)) > Game.reputation, "a quest can still walk in by chance below its reputation")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game._save_path()))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.character_parts_path()))
	Game.running = false
	print("STORY QUESTS: %d checks, %d failures" % [checks, failures])
	await Audio.shutdown()
	get_tree().quit(failures)
