class_name ComposerFlow
extends RefCounted

static func snapshot(m: Dictionary) -> Dictionary:
	return {"deck":m["deck"].duplicate(true), "placed":m["placed"].duplicate(true), "bpm":m["bpm"]}

static func prepare(m: Dictionary, job: Dictionary) -> void:
	if m.has("listening_reference"): return
	if int(job.get("demo_index", -1)) == 0 and m["placed"].is_empty(): starter(m)
	m["listening_reference"] = snapshot(m)

static func starter(m: Dictionary) -> void:
	# Independent clips remain editable, and a deliberately busy drum part invites revision.
	m["placed"] = []
	m["bpm"] = 95 if m["brief"]["kind"] == "cafe" else 130
	for col in 8:
		for row in [0, 3]:
			var style = 2 if row == 0 else 1
			for source in m["deck"].duplicate():
				if not source.get("palette", false) or source["genre"] != m["genre"] or int(source["style"]) != style: continue
				var clip: Dictionary = source.duplicate(true)
				clip["id"] = m["deck"].size(); clip["palette"] = false
				m["deck"].append(clip)
				m["placed"].append({"block":clip["id"], "row":row, "col":col})
				break

static func preview_state(m: Dictionary, before: bool, solo: int, muted: Array) -> Dictionary:
	var state: Dictionary = m.get("listening_reference", m) if before else m
	var result = snapshot(state)
	result["placed"] = result["placed"].filter(func(p: Dictionary): return (solo < 0 or int(p["row"]) == solo) and not int(p["row"]) in muted)
	return result

static func tempo_name(bpm: int) -> String:
	return Locale.text("flow_slow" if bpm <= 105 else ("flow_mid" if bpm <= 135 else "flow_fast"))

static func arrangement_mix(job: Dictionary) -> Dictionary:
	var m: Dictionary = job.get("arrangement", {})
	var mix = {}
	for p in m.get("placed", []):
		var genre: String = m["deck"][p["block"]]["genre"]
		mix[genre] = float(mix.get(genre, 0)) + 100.0 / m["placed"].size()
	return mix

static func feedback(m: Dictionary) -> String:
	var r = CompositionDesign.analyze(m)
	if m["placed"].is_empty(): return Locale.text("flow_empty")
	if int(m["brief"].get("lesson", 2)) == 0:
		var busy = m["placed"].filter(func(p: Dictionary): return int(p["row"]) == 3 and int(m["deck"][p["block"]].get("style", 0)) != 2)
		if not busy.is_empty(): return Locale.text("flow_coffee_hint")
	return CompositionDesign.advice(m)
