class_name IdeaRules
extends RefCounted
const COLS := 8
const ROWS := 4

static func create(job: Dictionary, freeform: bool = false) -> Dictionary:
	if freeform: return create_studio(job)
	var rng = RandomNumberGenerator.new()
	rng.seed = int(job.get("idea_seed", str(job["id"]).hash())) + int(job.get("idea_rounds", 0))
	var genre = str(Data.sorted_tags(job["mix"])[0])
	var others = Data.GENRES.duplicate()
	others.erase(genre)
	var deck: Array = []
	# A guaranteed feasible core plus randomized alternatives with different shapes/stat tradeoffs.
	for i in 12:
		var width = rng.randi_range(1, 3)
		var stats = [rng.randi_range(2, 6), rng.randi_range(2, 6), rng.randi_range(2, 6)]
		var notes: Array = []
		for j in width: notes.append([j, [0, 2, 4, 7, 9][rng.randi_range(0, 4)]])
		deck.append({"id": i, "width": width, "genre": genre if i < 4 or rng.randf() < 0.45 else others[rng.randi_range(0, others.size()-1)], "stats": stats, "notes": notes, "lane": i % 4})
	var target = [0, 0, 0]
	for i in 4:
		for stat in 3: target[stat] += deck[i]["stats"][stat]
	if not job.get("tutorial_brief",false):
		for i in range(deck.size()-1,0,-1):
			var j = rng.randi_range(0,i)
			var temporary = deck[i]
			deck[i] = deck[j]
			deck[j] = temporary
		for i in deck.size(): deck[i]["id"] = i
	return {"job_id": job["id"], "deck": deck, "target": target, "genre": genre, "placed": [], "remaining": 90.0, "bpm": 120, "phase": "gathering"}

static func can_place(meeting: Dictionary, block: int, row: int, col: int) -> bool:
	if block < 0 or block >= meeting["deck"].size() or row < 0 or row >= ROWS or col < 0: return false
	if meeting.get("freeform", false): return col < COLS
	var card: Dictionary = meeting["deck"][block]
	if col + int(card["width"]) > COLS or row != int(card["lane"]): return false
	for occupied in meeting["placed"]:
		if int(occupied["block"]) == block: continue
		if int(occupied["row"]) == row:
			var other: Dictionary = meeting["deck"][int(occupied["block"])]
			if col < int(occupied["col"]) + int(other["width"]) and col + int(card["width"]) > int(occupied["col"]): return false
	return true

static func score(meeting: Dictionary) -> Dictionary:
	if meeting.get("freeform", false):
		return CompositionDesign.analyze(meeting)
	var stats = [0, 0, 0]
	var matching = 0
	for placement in meeting["placed"]:
		var block: Dictionary = meeting["deck"][int(placement["block"])]
		for i in 3: stats[i] += int(block["stats"][i])
		if block["genre"] == meeting["genre"]: matching += 1
	var fit = 0.0
	for i in 3: fit += maxf(0.0, 1.0 - absf(stats[i] - meeting["target"][i]) / maxf(1, meeting["target"][i])) / 3.0
	var genre_fit = float(matching) / maxi(1, meeting["placed"].size())
	var score = int(round(100 * (fit * 0.7 + genre_fit * 0.3))) if not meeting["placed"].is_empty() else 0
	return {"stats": stats, "score": score, "idea": int(round(score * 0.3)), "genre_fit": genre_fit}

static func create_studio(job: Dictionary) -> Dictionary:
	var deck: Array = []
	for genre in Data.GENRES:
		for style in 3:
			var index = Data.GENRES.find(genre)
			var notes: Array = []
			var rhythm = [[0.0, 1.0, 2.0, 3.0], [0.0, 0.75, 1.5, 2.5, 3.5], [0.0, 2.0]][style]
			if style != 2:
				if genre in ["Jazz", "Lofi"]: rhythm = [0.0, 0.67, 1.0, 1.67, 2.0, 2.67, 3.0, 3.67]
				elif genre in ["HipHop", "R&B"]: rhythm = [0.0, 0.75, 1.5, 2.0, 2.75, 3.5]
				elif genre in ["EDM", "Metal"]: rhythm = [0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5]
				elif genre == "Motown": rhythm = [0.0, 0.5, 1.0, 1.75, 2.0, 2.5, 3.0, 3.75]
				elif genre == "Country": rhythm = [0.0, 0.5, 1.5, 2.0, 2.5, 3.5]
			var scale = [0, 2, 4, 7, 9] if index % 2 == 0 else [0, 3, 5, 7, 10]
			for n in rhythm.size(): notes.append([rhythm[n], scale[(n + index + style) % scale.size()]])
			deck.append({"id": deck.size(), "width": 1, "lane": 0, "genre": genre, "style": style, "palette": true, "stats": [1, 1, 1], "notes": notes, "freeform": true})
	return {"job_id": job["id"], "freeform": true, "brief": CompositionDesign.brief(job), "deck": deck, "target": [16, 4, 16], "genre": Data.sorted_tags(job["mix"])[0], "placed": [], "remaining": 0.0, "bpm": 120, "phase": "gathering"}
