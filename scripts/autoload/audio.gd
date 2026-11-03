extends Node
## Separate music, preview, ambience and one-shot channels; preferences survive saves.
signal playback_status(message: String)
var bgm := AudioStreamPlayer.new()
var ambient := AudioStreamPlayer.new()
var effects := AudioStreamPlayer.new()
var clicks := AudioStreamPlayer.new()
var preview := AudioStreamPlayer.new()
var levels := {"Master": 0.8, "BGM": 0.65, "SFX": 0.8, "Composer": 0.85}
var playlist: Array[String] = []
var _was_running := false
var _ambient_wait := 8.0
var _request := 0
var _last_track := ""
var _cache: Dictionary = {}
var _quitting := false
var workshop_quiet := false

func quit_game() -> void:
	if _quitting: return
	_quitting = true
	Game.save_game()
	await shutdown()
	get_tree().quit()

func _exit_tree() -> void:
	_release_streams()

func _release_streams() -> void:
	for player in [bgm, ambient, effects, clicks, preview]:
		if not is_instance_valid(player): continue
		player.stream_paused = false
		player.stop()
		player.stream = null
	_cache.clear()

func shutdown() -> void:
	set_process(false)
	_quitting = true
	# Flush any voice that was queued in this frame before retiring its player.
	await get_tree().create_timer(0.08).timeout
	_release_streams()
	for player in [bgm, ambient, effects, clicks, preview]:
		if is_instance_valid(player): player.queue_free()
	# Let AudioServer retire playback voices before exiting the process.
	await get_tree().create_timer(0.2).timeout

func _ready() -> void:
	for bus in ["BGM", "SFX", "Composer"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	for player in [bgm, ambient, effects, clicks, preview]: add_child(player)
	bgm.bus = "BGM"
	preview.bus = "BGM"
	for player in [ambient, effects, clicks]: player.bus = "SFX"
	var config = ConfigFile.new()
	config.load("user://audio.cfg")
	for bus in levels: set_level(bus, float(config.get_value("audio", bus, levels[bus])), false)
	for file in DirAccess.get_files_at("res://assets/bgm"):
		if file.ends_with(".mp3") and file != "title.mp3": playlist.append("res://assets/bgm/" + file)
	bgm.finished.connect(_next_bgm)
	preview.finished.connect(stop_preview)
	ambient.finished.connect(func(): _ambient_wait = randf_range(12, 28))
	get_tree().node_added.connect(_wire_button)
	_wire_tree(get_tree().root)
	Game.project_completed.connect(func(_p: Dictionary): sfx("success"))
	Game.song_released.connect(func(_s: Dictionary): sfx("success"))
	Game.job_failed.connect(func(_j: Dictionary): sfx("fail"))
	Game.trophy_awarded.connect(func(_t: Dictionary): sfx("reward"))
	_next_bgm()

func _wire_tree(node: Node) -> void:
	_wire_button(node)
	for child in node.get_children(): _wire_tree(child)

func _wire_button(node: Node) -> void:
	if node is BaseButton and not node.has_meta("audio_click"):
		node.set_meta("audio_click", true)
		node.pressed.connect(func(): sfx("click"))

func set_level(bus: String, value: float, persist := true) -> void:
	if not levels.has(bus): return
	levels[bus] = clampf(value, 0, 1)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), linear_to_db(maxf(0.0001, levels[bus])))
	AudioServer.set_bus_mute(AudioServer.get_bus_index(bus), levels[bus] <= 0)
	if persist:
		var config = ConfigFile.new()
		for key in levels: config.set_value("audio", key, levels[key])
		config.save("user://audio.cfg")

func sfx(key: String) -> void:
	if _quitting or workshop_quiet: return
	var path = "res://assets/sfx/%s.mp3" % key
	if not ResourceLoader.exists(path): return
	var player = clicks if key == "click" else effects
	player.stream = _stream(path)
	player.play()

func _stream(path: String) -> AudioStream:
	if not _cache.has(path): _cache[path] = load(path)
	return _cache[path]

func _next_bgm() -> void:
	if _quitting: return
	var path = "res://assets/bgm/title.mp3"
	if Game.running and not playlist.is_empty():
		var choices = playlist.filter(func(p: String): return p != _last_track)
		path = choices.pick_random() if not choices.is_empty() else playlist[0]
	_last_track = path
	if ResourceLoader.exists(path):
		bgm.stream = _stream(path)
		bgm.play()
		bgm.stream_paused = workshop_quiet

func _process(delta: float) -> void:
	if Game.running != _was_running:
		_was_running = Game.running
		stop_preview()
		ambient.stop()
		_next_bgm()
	var quiet = Game.running and Game.idea_meeting.get("phase", "") in ["ready", "playing"]
	if quiet and not workshop_quiet:
		stop_preview()
		effects.stop()
		clicks.stop()
	workshop_quiet = quiet
	bgm.stream_paused = quiet
	if quiet:
		ambient.stream_paused = true
		return
	if not Game.running: return
	var meeting = not Game.research_tasks.is_empty() or not Game.idea_meeting.is_empty()
	var workshop = not Game.idea_meeting.is_empty()
	ambient.stream_paused = Game.is_paused() and not workshop
	if Game.is_paused() and not workshop: return
	var path = "res://assets/sfx/meeting.mp3" if meeting else "res://assets/sfx/office.mp3"
	if ambient.playing and ambient.stream != _stream(path): ambient.stop(); _ambient_wait = 0
	_ambient_wait -= delta
	if not ambient.playing and (meeting or _ambient_wait <= 0):
		ambient.stream = _stream(path)
		ambient.play()
		_ambient_wait = randf_range(12, 28)

func stop_preview() -> void:
	_request += 1
	preview.stop()
	bgm.volume_db = 0

func play_song(song: Dictionary, cloud := true) -> void:
	stop_preview()
	var request = _request
	var stream: AudioStream
	if cloud:
		var url = str(song.get("audio_url", ""))
		if url.is_empty(): playback_status.emit(Locale.text("cloud_missing")); return
		playback_status.emit(Locale.text("legacy_262"))
		var response: Dictionary = await Http.fetch(self, Cloudinary.mp3_url(url))
		if request != _request: return
		if response["code"] != 200: playback_status.emit(Locale.text("legacy_263") % response["code"]); return
		stream = AudioStreamMP3.load_from_buffer(response["body"])
	else:
		var path = str(song.get("local_audio", ""))
		stream = AudioStreamWAV.load_from_file(path) if FileAccess.file_exists(path) else await MusicGen.generate_async(song)
	if request != _request: return
	if stream == null: playback_status.emit(Locale.text("cloud_missing")); return
	preview.stream = stream
	bgm.volume_db = -24
	preview.play()
	playback_status.emit(Locale.text("legacy_261") % song["title"])
