class_name CompositionDesign
extends RefCounted

static func brief(job: Dictionary) -> Dictionary:
	var kind = str(job.get("brief_kind", ["cafe", "sport", "debut"][absi(str(job.get("id", "")).hash()) % 3]))
	var specs = {
		"cafe": {"bpm": [70, 105], "density": [0.2, 0.5], "rise": 0.0},
		"sport": {"bpm": [120, 160], "density": [0.45, 0.85], "rise": 0.25},
		"debut": {"bpm": [95, 140], "density": [0.3, 0.75], "rise": 0.125}}
	var result: Dictionary = specs.get(kind, specs["debut"]).duplicate(true)
	result["kind"] = kind
	result["lesson"] = int(job.get("demo_index", 2))
	result["artist_genre"] = str(job.get("artist_genre", Data.sorted_tags(job["mix"])[0]))
	if not job.has("artist_genre"):
		for artist in Game.staff:
			if artist.get("role", "") != "Vocal": continue
			var skills: Dictionary = artist.get("skills", {})
			var strongest = -1.0
			for genre in Data.GENRES:
				if float(skills.get(genre, 0)) > strongest:
					strongest = float(skills.get(genre, 0))
					result["artist_genre"] = genre
			break
	var plan: Dictionary = job.get("shift_plan", {})
	if not plan.is_empty():
		result["artist_genre"] = plan["home"] if plan["strategy"] == "hold" else plan["target"]
		result["artist_genres"] = [plan["home"], plan["target"]] if plan["strategy"] == "blend" else [result["artist_genre"]]
	return result

static func band_fit(value: float, limits: Array, tolerance: float) -> float:
	return clampf(1.0 - maxf(float(limits[0]) - value, value - float(limits[1])) / tolerance, 0.0, 1.0)

static func analyze(m: Dictionary) -> Dictionary:
	var b: Dictionary = m.get("brief", {"kind": "debut", "bpm": [95,140], "density": [0.3,0.75], "rise": 0.125, "artist_genre": m.get("genre", "Pop")})
	var energy = [0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0]
	var occupied = {}
	var signatures = {}
	var matching = 0.0
	var coherent = 0.0
	for p in m["placed"]:
		var block: Dictionary = m["deck"][p["block"]]
		var col = int(p["col"])
		energy[col] += (0.65 if int(block.get("style", 0)) == 2 else 1.0) * float(block.get("volume", 1.0)) / 4.0
		occupied[col] = true
		if block["genre"] in b.get("artist_genres", [b["artist_genre"]]): matching += 1
		if posmod(int(block.get("transpose", 0)), 12) in [0, 7] or p["row"] == 3: coherent += 1
		if p["row"] == 0:
			signatures[col] = "%s:%s:%s" % [block["genre"], block.get("style",0), block.get("transpose",0)]
	var count = m["placed"].size()
	var density = float(count) / 32.0
	var intro = (energy[0] + energy[1]) / 2.0
	var verse = (energy[2] + energy[3] + energy[4]) / 3.0
	var hook = (energy[5] + energy[6] + energy[7]) / 3.0
	var tempo = band_fit(float(m["bpm"]), b["bpm"], 45.0)
	var texture = band_fit(density, b["density"], 0.4)
	var rise = clampf(1.0 - absf(hook - verse - float(b["rise"])) / 0.4, 0, 1)
	var structure = (rise * 0.6 + float(occupied.size()) / 8.0 * 0.4)
	if b["kind"] != "cafe": structure *= 0.6 + 0.4 * clampf((hook - intro + 0.1) / 0.3, 0, 1)
	var repeat = 0.0
	for col in [5,6,7]:
		if not signatures.has(col): continue
		for previous in range(col):
			if signatures.get(previous, "") == signatures[col]: repeat = 1.0
	var hook_score = repeat * 0.7 + (0.3 if signatures.has(5) or signatures.has(6) or signatures.has(7) else 0.0)
	var artist = (matching / maxi(1,count) * 0.7 + coherent / maxi(1,count) * 0.3)
	var parts = [roundi(40 * (tempo * 0.55 + texture * 0.45)), roundi(25 * structure), roundi(20 * hook_score), roundi(15 * artist)]
	if count == 0: parts = [0,0,0,0]
	var total = parts[0] + parts[1] + parts[2] + parts[3]
	return {"score": total, "idea": roundi(total * 0.3), "stats": parts, "genre_fit": artist, "energy": energy, "density": density, "rise": hook - verse, "tempo_fit": tempo, "repeat": repeat}

static func advice(m: Dictionary) -> String:
	var a = analyze(m)
	if m["placed"].is_empty(): return Locale.text("arr_advice_empty")
	if a["tempo_fit"] < 0.8: return Locale.text("arr_advice_tempo")
	if a["density"] > float(m["brief"]["density"][1]): return Locale.text("arr_advice_dense")
	if m["brief"]["kind"] != "cafe" and a["rise"] < 0.1: return Locale.text("arr_advice_rise")
	if a["repeat"] == 0: return Locale.text("arr_advice_hook")
	return Locale.text("arr_advice_good")

static func report(result: Dictionary) -> String:
	return Locale.text("arr_report", result["stats"] + [result["score"]])
