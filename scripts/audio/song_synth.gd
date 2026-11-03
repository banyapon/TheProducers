class_name SongSynth
extends RefCounted
## Tiny procedural band: drums, bass, chords and a lead line picked from the song's genre mix.
## Pure data in / PCM bytes out, so it can run on a worker thread. Same seed => same song.

const RATE := 22050

enum Wave { SINE, SQUARE, SAW, TRIANGLE }

const PROFILES := {
	"Pop": {"bpm": 112, "scale": "major", "drums": "four", "lead": Wave.SQUARE, "bass": "eighth"},
	"Rock": {"bpm": 128, "scale": "minor", "drums": "rock", "lead": Wave.SAW, "bass": "eighth"},
	"Jazz": {"bpm": 96, "scale": "dorian", "drums": "swing", "lead": Wave.SINE, "bass": "walk", "swing": 0.33},
	"HipHop": {"bpm": 88, "scale": "minor", "drums": "boom", "lead": Wave.TRIANGLE, "bass": "quarter", "swing": 0.2},
	"EDM": {"bpm": 126, "scale": "minor", "drums": "four", "lead": Wave.SAW, "bass": "offbeat"},
	"R&B": {"bpm": 76, "scale": "dorian", "drums": "boom", "lead": Wave.SINE, "bass": "quarter", "swing": 0.25},
	"Motown": {"bpm": 112, "scale": "major", "drums": "rock", "lead": Wave.TRIANGLE, "bass": "walk", "swing": 0.1},
	"Metal": {"bpm": 160, "scale": "phrygian", "drums": "metal", "lead": Wave.SAW, "bass": "eighth"},
	"Indie": {"bpm": 118, "scale": "major", "drums": "rock", "lead": Wave.TRIANGLE, "bass": "quarter"},
	"Lofi": {"bpm": 72, "scale": "dorian", "drums": "boom", "lead": Wave.SINE, "bass": "quarter", "swing": 0.3},
	"Classical": {"bpm": 90, "scale": "major", "drums": "none", "lead": Wave.TRIANGLE, "bass": "quarter"},
	"Country": {"bpm": 108, "scale": "major", "drums": "rock", "lead": Wave.TRIANGLE, "bass": "country"},
}
const SCALES := {
	"major": [0, 2, 4, 5, 7, 9, 11],
	"minor": [0, 2, 3, 5, 7, 8, 10],
	"dorian": [0, 2, 3, 5, 7, 9, 10],
	"phrygian": [0, 1, 3, 5, 7, 8, 10],
	"penta": [0, 2, 4, 7, 9],
}
## 16 steps per bar: kick, snare, hat
const DRUMS := {
	"four": ["x...x...x...x...", "....x.......x...", "..x...x...x...x."],
	"rock": ["x.......x.x.....", "....x.......x...", "x.x.x.x.x.x.x.x."],
	"boom": ["x......x..x.....", "....x.......x...", "x.x.x.x.x.x.x.x."],
	"swing": ["x.......x.......", "................", "x...x..xx...x..x"],
	"metal": ["xxxxxxxxxxxxxxxx", "....x.......x...", "x.x.x.x.x.x.x.x."],
	"none": ["................", "................", "................"],
}
const PROGRESSIONS := [[0, 4, 5, 3], [0, 5, 3, 4], [5, 3, 0, 4], [0, 3, 4, 4], [0, 0, 3, 4]]

var buf = PackedFloat32Array()
var rng = RandomNumberGenerator.new()


func render(mix: Dictionary, seed_value: int, seconds := 24.0) -> PackedByteArray:
	rng.seed = seed_value
	if mix.is_empty():
		mix = {"Pop": 100}
	var tags = mix.keys()
	tags.sort_custom(func(a, b): return mix[a] > mix[b])
	var main: Dictionary = PROFILES.get(tags[0], PROFILES["Pop"])
	var second: Dictionary = PROFILES.get(tags[1], main) if tags.size() > 1 else main

	var bpm = 0.0
	var weight = 0.0
	for tag in tags:
		bpm += float(PROFILES.get(tag, main)["bpm"]) * float(mix[tag])
		weight += float(mix[tag])
	bpm = bpm / maxf(weight, 1.0) + rng.randf_range(-4.0, 4.0)
	var beat = 60.0 / bpm
	var bar_len = beat * 4.0
	var step = beat / 4.0
	var bars = clampi(int(round(seconds / bar_len / 4.0)) * 4, 8, 16)
	var length = bars * bar_len
	buf = PackedFloat32Array()
	buf.resize(int((length + 1.5) * RATE))

	var scale: Array = SCALES[main["scale"]]
	var root = rng.randi_range(45, 52)
	var prog: Array = PROGRESSIONS[rng.randi() % PROGRESSIONS.size()]
	var swing = float(main.get("swing", 0.0))
	var drums: Array = DRUMS[main["drums"]]
	var lead_wave: int = second["lead"]
	var arpeggio: bool = main["drums"] == "none"
	var motif_a = _motif()
	var motif_b = _motif()

	for b in bars:
		var t0 = b * bar_len
		var degree: int = prog[b % prog.size()]
		var chord = [degree, degree + 2, degree + 4]
		# harmony
		if arpeggio:
			for s in 8:
				_tone(t0 + s * beat * 0.5, beat * 0.5, _freq(_note(scale, root + 12, chord[s % 3] + (7 if s >= 6 else 0))), 0.12, Wave.TRIANGLE, 3.0)
		else:
			for d in chord:
				_tone(t0, bar_len, _freq(_note(scale, root + 12, d)), 0.045, Wave.SINE, 0.3)
		_bass(main["bass"], t0, beat, scale, root - 12, degree)
		# drums (first bar: hats only, as an intro)
		for s in 16:
			var st = t0 + s * step + (step * swing * 2.0 if s % 4 == 2 else 0.0)
			if b > 0 and drums[0][s] == "x":
				_kick(st)
			if b > 0 and drums[1][s] == "x":
				_snare(st)
			if drums[2][s] == "x":
				_hat(st, 0.07 if s % 4 == 0 else 0.045)
		# lead melody: motif A / B alternate every 4 bars
		if b == 0:
			continue
		var motif: Array = motif_a if (b / 4) % 2 == 0 else motif_b
		for note in motif:
			var eighth: int = note[0]
			if eighth / 8 != b % 4:
				continue
			var deg: int = note[2]
			if eighth % 8 == 0:
				deg = degree + [0, 2, 4][rng.randi() % 3]
			_tone(t0 + (eighth % 8) * beat * 0.5, int(note[1]) * beat * 0.5 * 0.95, _freq(_note(scale, root + 24, deg)), 0.13, lead_wave, 1.5)

	_fade_out(length)
	return _to_pcm16()


## A 4-bar melody: [eighth index 0..31, length in eighths, scale degree]
func _motif() -> Array:
	var notes = []
	var deg = rng.randi_range(0, 4)
	var i = 0
	while i < 32:
		if rng.randf() < 0.6:
			var len_8: int = [1, 1, 2, 2, 3][rng.randi() % 5]
			deg = clampi(deg + rng.randi_range(-2, 2), -2, 9)
			notes.append([i, mini(len_8, 32 - i), deg])
			i += len_8
		else:
			i += 1
	return notes


func _bass(style: String, t0: float, beat: float, scale: Array, base: int, degree: int) -> void:
	var r = _freq(_note(scale, base, degree))
	var fifth = _freq(_note(scale, base, degree + 4))
	match style:
		"eighth":
			for s in 8:
				_tone(t0 + s * beat * 0.5, beat * 0.45, r, 0.16, Wave.SAW, 4.0)
		"offbeat":
			for s in 4:
				_tone(t0 + s * beat + beat * 0.5, beat * 0.45, r, 0.18, Wave.SAW, 5.0)
		"walk":
			for s in 4:
				_tone(t0 + s * beat, beat * 0.9, _freq(_note(scale, base, degree + [0, 2, 4, 5][s])), 0.2, Wave.TRIANGLE, 2.0)
		"country":
			for s in 4:
				_tone(t0 + s * beat, beat * 0.5, r if s % 2 == 0 else fifth, 0.2, Wave.TRIANGLE, 4.0)
		_:
			for s in 4:
				_tone(t0 + s * beat, beat * 0.8, r, 0.2, Wave.TRIANGLE, 2.0)


func _note(scale: Array, base: int, degree: int) -> int:
	var n = scale.size()
	var octave = floori(float(degree) / n)
	return base + octave * 12 + int(scale[degree - octave * n])


func _freq(midi: int) -> float:
	return 440.0 * pow(2.0, (midi - 69) / 12.0)


func _tone(start: float, dur: float, freq: float, amp: float, wave: int, decay: float) -> void:
	var s0 = int(start * RATE)
	var n = int(dur * RATE)
	var attack = int(0.006 * RATE)
	var release = maxi(1, int(minf(0.05, dur * 0.3) * RATE))
	var inc = freq / RATE
	var decay_mul = exp(-decay / RATE)
	var env_decay = 1.0
	var phase = 0.0
	var size = buf.size()
	for i in n:
		var idx = s0 + i
		if idx >= size:
			break
		var v = 0.0
		if wave == Wave.SINE:
			v = sin(TAU * phase)
		elif wave == Wave.SQUARE:
			v = 0.6 if phase < 0.5 else -0.6
		elif wave == Wave.SAW:
			v = (2.0 * phase - 1.0) * 0.7
		else:
			v = 4.0 * absf(phase - 0.5) - 1.0
		var env = env_decay
		if i < attack:
			env *= float(i) / attack
		elif i > n - release:
			env *= float(n - i) / release
		buf[idx] += v * amp * env
		env_decay *= decay_mul
		phase += inc
		if phase >= 1.0:
			phase -= 1.0


func _kick(start: float) -> void:
	var s0 = int(start * RATE)
	var phase = 0.0
	for i in int(0.22 * RATE):
		var idx = s0 + i
		if idx >= buf.size():
			break
		var t = float(i) / RATE
		phase += (40.0 + 70.0 * exp(-t * 30.0)) / RATE
		buf[idx] += sin(TAU * phase) * exp(-t * 9.0) * 0.55


func _snare(start: float) -> void:
	var s0 = int(start * RATE)
	for i in int(0.18 * RATE):
		var idx = s0 + i
		if idx >= buf.size():
			break
		var t = float(i) / RATE
		buf[idx] += rng.randf_range(-1.0, 1.0) * exp(-t * 20.0) * 0.22 + sin(TAU * 190.0 * t) * exp(-t * 30.0) * 0.15


func _hat(start: float, amp: float) -> void:
	var s0 = int(start * RATE)
	var last = 0.0
	for i in int(0.045 * RATE):
		var idx = s0 + i
		if idx >= buf.size():
			break
		var noise = rng.randf_range(-1.0, 1.0)
		buf[idx] += (noise - last) * exp(-float(i) / RATE * 70.0) * amp
		last = noise


func _fade_out(length: float) -> void:
	var from = int(maxf(0.0, length - 1.0) * RATE)
	var span = buf.size() - from
	for i in span:
		buf[from + i] *= 1.0 - float(i) / span


func _to_pcm16() -> PackedByteArray:
	var peak = 0.001
	for v in buf:
		peak = maxf(peak, absf(v))
	var gain = 0.9 / peak
	var out = PackedByteArray()
	out.resize(buf.size() * 2)
	for i in buf.size():
		out.encode_s16(i * 2, int(clampf(buf[i] * gain, -1.0, 1.0) * 32767.0))
	return out
