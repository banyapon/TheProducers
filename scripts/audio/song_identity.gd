class_name SongIdentity
extends RefCounted
const DEFAULT = {"motif":0, "mood":0, "lead":0, "transition":0}

static func apply(m: Dictionary, key: String, value: int) -> void:
	if not key in DEFAULT or value < 0 or value > 2: return
	var identity: Dictionary = m.get("signature", DEFAULT.duplicate())
	for field in DEFAULT:
		if not identity.has(field): identity[field] = DEFAULT[field]
	identity[key] = value
	m["signature"] = identity
	for block in m["deck"]: block["signature"] = identity.duplicate()

static func phrase(block: Dictionary, lane: int, col: int) -> Array:
	var s: Dictionary = block["signature"]
	var scale: Array = [[0,2,4,5,7,9,11], [0,2,4,7,9,12,14], [0,2,3,5,7,8,10]][int(s["mood"])]
	var root = [0,3,5,4][col % 4]
	if lane == 1: return [[0.0,scale[root]], [2.0,scale[root]]]
	if lane == 2: return [[0.0,scale[root]], [2.0,scale[root]]]
	if lane == 3:
		if col == 4 and int(s["transition"]) == 1: return []
		if col == 4 and int(s["transition"]) == 2: return [[0.0,0],[1.0,0],[2.0,0],[2.5,0],[3.0,0],[3.25,0],[3.5,0],[3.75,0]]
		return block["notes"]
	var patterns: Array = [[[0.0,0],[1.0,2],[2.0,4],[3.0,2]], [[0.0,4],[0.5,4],[1.5,2],[2.5,1],[3.5,0]], [[0.0,0],[0.75,1],[1.5,2],[2.5,4],[3.5,5]]]
	var notes = []
	for i in patterns[int(s["motif"])].size():
		var note = patterns[int(s["motif"] )][i]
		if int(block.get("style",0)) == 2 and i % 2 == 1: continue
		var beat = float(note[0])
		if int(block.get("style",0)) == 1 and i % 2 == 1: beat = minf(3.75, beat + 0.25)
		notes.append([beat, scale[int(note[1])]])
	return notes

static func label(s: Dictionary) -> String:
	if s.is_empty(): return ""
	var parts = []
	for key in DEFAULT: parts.append(Locale.text("identity_%s_%d" % [key,int(s[key])]))
	return " / ".join(parts)
