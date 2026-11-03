extends Node
## Song pipeline after release:
##   1. assigned cast portrait cover       -> user://covers/<id>.png
##   2. audio: built-in SongSynth (free/offline) -> user://songs/<id>.wav
##      (+ optional Hugging Face MusicGen track if configured)
##   3. signed Cloudinary upload into <root>/<firebase uid>/covers|songs (the player's storage)

var _cover_cache = {}
var active_jobs := 0


func produce(song: Dictionary) -> void:
	active_jobs += 1
	_set_status(song, Locale.text("legacy_126"))
	DirAccess.make_dir_recursive_absolute("user://songs")
	DirAccess.make_dir_recursive_absolute("user://covers")

	var cover = await CoverArt.generate_song(song, self)
	var cover_path = "user://covers/%s.png" % song["id"]
	cover.save_png(cover_path)
	song["local_cover"] = cover_path
	song["cover_version"] = 2
	_cover_cache.erase(song["id"])
	Game.save_game()
	Game.song_updated.emit(song)

	var wav: AudioStreamWAV = await generate_async(song)
	var wav_path = "user://songs/%s.wav" % song["id"]
	wav.save_to_wav(wav_path)
	song["local_audio"] = wav_path

	if Secrets.music_provider == "huggingface":
		_set_status(song, Locale.text("legacy_127"))
		song["ai_local"] = await _generate_hf(song)

	await upload_song(song)
	active_jobs -= 1


## Renders the song with the procedural synth on a worker thread.
func generate_async(song: Dictionary) -> AudioStreamWAV:
	var mix: Dictionary = song["mix"].duplicate()
	var seed_value = int(song["cover_seed"])
	var thread = Thread.new()
	var notes: Array = song.get("idea_notes", []).duplicate(true)
	var bpm = int(song.get("idea_bpm", 120))
	var render_seconds = 24.0
	for note in notes: render_seconds = maxf(render_seconds, float(note.get("loop_steps", 8)) * 30.0 / bpm)
	var pcm: PackedByteArray
	if OS.has_feature("web") and not OS.has_feature("threads"):
		await get_tree().process_frame
		pcm = IdeaMusic.pcm(notes, bpm, render_seconds) if not notes.is_empty() else SongSynth.new().render(mix, seed_value)
	else:
		thread.start(func(): return IdeaMusic.pcm(notes, bpm, render_seconds) if not notes.is_empty() else SongSynth.new().render(mix, seed_value))
		while thread.is_alive():
			await get_tree().process_frame
		pcm = thread.wait_to_finish()
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SongSynth.RATE
	wav.stereo = false
	wav.data = pcm
	return wav


func upload_song(song: Dictionary) -> void:
	if not FirebaseAuth.is_signed_in():
		_set_status(song, Locale.text("legacy_128"))
		return
	if not Cloudinary.is_configured():
		_set_status(song, Locale.text("legacy_129"))
		return
	_set_status(song, Locale.text("legacy_130"))
	active_jobs += 1
	var folder = "%s/%s" % [Secrets.cloudinary_root, FirebaseAuth.uid]
	var tags = ["the_producers", "uid_" + FirebaseAuth.uid]

	var cover_res: Dictionary = await Cloudinary.upload(FileAccess.get_file_as_bytes(song["local_cover"]),
		"%s.png" % song["id"], "image/png", "image", folder + "/covers", song["id"], tags)

	var audio_path: String = song["local_audio"]
	var ai_path: String = song.get("ai_local", "")
	if ai_path != "" and FileAccess.file_exists(ai_path):
		audio_path = ai_path
	var audio_res: Dictionary = await Cloudinary.upload(FileAccess.get_file_as_bytes(audio_path),
		audio_path.get_file(), _mime_for(audio_path), "video", folder + "/songs", song["id"], tags)
	# Keep successful assets even when the other upload fails, so reset can delete both.
	for pair in [["cover", cover_res], ["audio", audio_res]]:
		if not pair[1].has("error"):
			song[pair[0] + "_public_id"] = pair[1].get("public_id", "")
			song[pair[0] + "_url"] = pair[1].get("secure_url", "")
	song["owner_uid"] = FirebaseAuth.uid
	active_jobs -= 1

	if cover_res.has("error") or audio_res.has("error"):
		_set_status(song, Locale.text("legacy_131") % audio_res.get("error", cover_res.get("error", "")))
	else:
		song["cover_url"] = cover_res.get("secure_url", "")
		song["audio_url"] = audio_res.get("secure_url", "")
		_set_status(song, Locale.text("legacy_132"))
	Game.save_game()


func cover_texture(song: Dictionary) -> Texture2D:
	if _cover_cache.has(song["id"]):
		return _cover_cache[song["id"]]
	var img: Image = null
	var path: String = song.get("local_cover", "")
	if path != "" and FileAccess.file_exists(path):
		img = Image.load_from_file(path)
	if img == null:
		img = CoverArt.generate(Data.colors_for_mix(song["mix"]), int(song["cover_seed"]))
	var tex = ImageTexture.create_from_image(img)
	_cover_cache[song["id"]] = tex
	return tex


## Optional: MusicGen via Hugging Face Inference API (free tier, needs a token). Returns a local path or "".
func _generate_hf(song: Dictionary) -> String:
	if Secrets.hf_token == "" or Secrets.hf_model_url == "":
		Game.notify.emit(Locale.text("legacy_133"))
		return ""
	var prompt = "%s instrumental track titled %s, catchy hook, studio quality" % [Data.mix_text(song["mix"]), song["title"]]
	var res: Dictionary = await Http.post(self, Secrets.hf_model_url,
		PackedStringArray(["Authorization: Bearer " + Secrets.hf_token, "Content-Type: application/json"]),
		JSON.stringify({"inputs": prompt}).to_utf8_buffer(), 180.0)
	if res["code"] != 200:
		Game.notify.emit(Locale.text("legacy_134") % res["code"])
		return ""
	var ext = "flac"
	for header in res["headers"]:
		var h = str(header).to_lower()
		if h.begins_with("content-type:"):
			if h.contains("wav"):
				ext = "wav"
			elif h.contains("mpeg") or h.contains("mp3"):
				ext = "mp3"
	var path = "user://songs/%s_ai.%s" % [song["id"], ext]
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(res["body"])
	file.close()
	return path


func _mime_for(path: String) -> String:
	match path.get_extension().to_lower():
		"mp3":
			return "audio/mpeg"
		"flac":
			return "audio/flac"
		_:
			return "audio/wav"


func _set_status(song: Dictionary, text: String) -> void:
	song["status"] = text
	Game.song_updated.emit(song)
