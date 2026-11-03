class_name IdeaMusic
extends RefCounted
## A local note sequencer: identical note events drive preview PCM, exported MIDI and released music.
const RATE := 22050

static func events(deck: Array, placed: Array) -> Array:
	var out: Array = []
	for position in placed:
		var block: Dictionary = deck[int(position["block"])]
		var base = [72, 60, 48, 36][int(position["row"])]
		if block.get("freeform", false):
			var lane = int(position["row"])
			var phrase = SongIdentity.phrase(block, lane, int(position["col"])) if block.has("signature") else block["notes"]
			for note in phrase:
				var tones = [0, 4, 7] if lane == 1 else [0]
				if lane == 1 and int(block.get("signature", {}).get("mood", 0)) == 2: tones = [0,3,7]
				for tone in tones:
					var pitch = clampi(base + int(note[1]) + tone + int(block.get("transpose", 0)), 0, 127)
					if lane == 3: pitch = 42 if not is_equal_approx(fmod(float(note[0]), 1.0), 0.0) else (38 if int(note[0]) % 2 == 1 else 36)
					out.append({"step": int(position["col"]) * 8 + float(note[0]) * 2, "note": pitch, "length": 3.4 if block.has("signature") and lane == 1 else (1.4 if lane in [1, 2] else 0.7), "drum": lane == 3, "voice": lane, "loop_steps": 64, "genre": block["genre"], "volume": float(block.get("volume", 1.0)), "instrument":int(block.get("signature", {}).get("lead", -1)) if lane == 0 else -1})
			continue
		for note in block["notes"]:
			out.append({"step": int(position["col"]) + int(note[0]), "note": base + int(note[1]), "length": 0.8, "drum": int(position["row"]) == 3})
	out.sort_custom(func(a: Dictionary, b: Dictionary): return float(a["step"]) < float(b["step"]))
	return out

static func pcm(notes: Array, bpm: int = 120, seconds: float = 0.0) -> PackedByteArray:
	var step = 30.0 / bpm
	var steps = 8
	for event in notes: steps = maxi(steps, int(event.get("loop_steps", 8)))
	var loop_length = steps * step
	var length = seconds if seconds > 0 else loop_length + 0.25
	var buf = PackedFloat32Array()
	buf.resize(int((length + 0.2) * RATE))
	for repeat in maxi(1, ceili(length / loop_length)):
		for event in notes:
			var start = repeat * loop_length + float(event["step"]) * step
			if start >= length: continue
			var duration = minf(step * float(event.get("length", 0.8)), length - start)
			var freq = 440.0 * pow(2.0, (int(event["note"]) - 69) / 12.0)
			for i in int(duration * RATE):
				var t = float(i) / RATE
				var envelope = minf(1, t * 150) * exp(-t * (20 if event.get("drum", false) else 5))
				var tone = sin(TAU * freq * t) + sin(TAU * freq * 2 * t) * 0.2
				if int(event.get("voice", -1)) == 2: tone = sin(TAU * freq * t) * 1.3
				elif event.get("genre", "") in ["Rock", "Metal", "EDM"]: tone = tanh(tone * 2.5) * 0.8
				match int(event.get("instrument", -1)):
					0: # Piano-like attack and decaying harmonics.
						tone = sin(TAU * freq * t) + 0.45 * sin(TAU * freq * 2 * t) * exp(-t * 9) + 0.2 * sin(TAU * freq * 3 * t) * exp(-t * 14)
						envelope = minf(1, t * 220) * exp(-t * 4)
					1: # Plucked guitar-like harmonic series.
						tone = sin(TAU * freq * t) + 0.5 * sin(TAU * freq * 3 * t) + 0.25 * sin(TAU * freq * 5 * t)
						envelope = minf(1, t * 400) * exp(-t * 11)
					2: # Rounded synth with a slower attack and vibrato.
						tone = sin(TAU * freq * t + 0.15 * sin(TAU * 5 * t)) + 0.35 * sin(TAU * freq * 2 * t)
						envelope = minf(1, t * 25) * exp(-t * 1.8)
				if event.get("drum", false): tone = sin(TAU * (55 + 90 * exp(-t * 35)) * t)
				if event.get("drum", false) and int(event["note"]) in [38, 42]:
					var noise = fmod(sin(float(i + 1) * 12.9898) * 43758.5453, 1.0)
					tone = noise * exp(-t * (40 if int(event["note"]) == 42 else 15))
				var idx = int(start * RATE) + i
				if idx < buf.size(): buf[idx] += tone * envelope * 0.16 * float(event.get("volume", 1.0))
	var bytes = PackedByteArray()
	bytes.resize(buf.size() * 2)
	# Lift quiet arrangements, keeping headroom even with every lane stacked.
	var peak := 0.0
	for sample in buf: peak = maxf(peak, absf(sample))
	var gain = minf(3.0, 0.9 / peak) if peak > 0.00001 else 1.0
	for i in buf.size(): bytes.encode_s16(i * 2, int(clampf(buf[i] * gain, -0.9, 0.9) * 32767))
	return bytes

static func stream(notes: Array, bpm: int) -> AudioStreamWAV:
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = pcm(notes, bpm)
	return wav

static func _vlq(value: int) -> PackedByteArray:
	var out = PackedByteArray([value & 127])
	value >>= 7
	while value > 0:
		out.insert(0, (value & 127) | 128)
		value >>= 7
	return out

static func write_midi(notes: Array, bpm: int, path: String) -> bool:
	var track = PackedByteArray([0, 255, 81, 3])
	var tempo = int(60000000.0 / bpm)
	track.append_array(PackedByteArray([(tempo >> 16) & 255, (tempo >> 8) & 255, tempo & 255]))
	# General MIDI voices: lead synth, electric piano, bass; percussion uses channel 10.
	for voice in [[0, 80], [1, 4], [2, 33]]:
		if voice[0] == 0:
			for note in notes:
				if int(note.get("instrument", -1)) >= 0:
					voice[1] = [0,24,80][int(note["instrument"])]; break
		track.append_array(PackedByteArray([0, 192 + voice[0], voice[1]]))
	var midi_events: Array = []
	for event in notes:
		var channel = 9 if event.get("drum", false) else int(event.get("voice", 0))
		var tick = roundi(float(event["step"]) * 240)
		midi_events.append([tick, 144 + channel, int(event["note"]), 110])
		midi_events.append([tick + roundi(float(event.get("length", 0.8)) * 240), 128 + channel, int(event["note"]), 0])
	midi_events.sort_custom(func(a: Array, b: Array): return a[0] < b[0] if a[0] != b[0] else a[1] < b[1])
	var previous = 0
	for event in midi_events:
		track.append_array(_vlq(event[0] - previous))
		track.append_array(PackedByteArray([event[1], event[2], event[3]]))
		previous = event[0]
	track.append_array(PackedByteArray([0, 255, 47, 0]))
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.big_endian = true
	file.store_buffer("MThd".to_ascii_buffer())
	file.store_32(6)
	file.store_16(0)
	file.store_16(1)
	file.store_16(480)
	file.store_buffer("MTrk".to_ascii_buffer())
	file.store_32(track.size())
	file.store_buffer(track)
	return true
