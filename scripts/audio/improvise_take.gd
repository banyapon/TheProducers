class_name ImproviseTake
extends RefCounted
## Recorded notes use beats, MIDI pitches and held durations, independent of tempo.

static func apply(meeting: Dictionary, notes: Array, lane: int, first_bar: int, bars: int) -> bool:
	if not meeting.get("freeform", false) or notes.is_empty(): return false
	if lane < 0 or lane > 3 or first_bar < 0 or bars < 1 or first_bar + bars > 8: return false
	meeting["placed"] = meeting["placed"].filter(func(p: Dictionary):
		return int(p["row"]) != lane or int(p["col"]) < first_bar or int(p["col"]) >= first_bar + bars)
	for bar in bars:
		var recorded: Array = []
		var scoring_notes: Array = []
		for note in notes:
			if float(note["beat"]) < bar * 4.0 or float(note["beat"]) >= (bar + 1) * 4.0: continue
			var copy: Dictionary = note.duplicate(true)
			copy["beat"] = float(copy["beat"]) - bar * 4.0
			copy["duration"] = clampf(float(copy["duration"]), 0.05, bars * 4.0 - float(note["beat"]))
			recorded.append(copy)
			scoring_notes.append([copy["beat"], int(copy["note"]) - [72,60,48,36][lane]])
		if recorded.is_empty(): continue
		var id = meeting["deck"].size()
		meeting["deck"].append({"id":id, "width":1, "lane":lane, "genre":meeting["genre"],
			"style":2 if recorded.size() <= 2 else 0, "palette":false, "freeform":true,
			"stats":[1,1,1], "notes":scoring_notes, "recorded_notes":recorded})
		meeting["placed"].append({"block":id, "row":lane, "col":first_bar + bar})
	meeting["phase"] = "playing"
	return true
