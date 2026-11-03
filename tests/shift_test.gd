extends Node
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if ok: print("ok: ", message)
	else: failures += 1; push_error(message)

func capture(label: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if "--visual" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_webp("D:/EP45/ndlp/Producers/shift-" + label + ".webp")

func _ready() -> void:
	var legacy = {"skills": {"Lukthung": 55}, "mix": {"Lukthung": 100}, "deck": [{"genre": "Lukthung"}], "training": [{"genre": "Lukthung"}], "research_hint": "Lukthung", "title": "Lukthung", "name": "Lukthung"}
	Data.migrate_legacy_genres(legacy)
	check(legacy["skills"].get("Motown") == 55 and legacy["mix"].get("Motown") == 100, "legacy genre skills and song mix migrate without losing values")
	check(legacy["deck"][0]["genre"] == "Motown" and legacy["training"][0]["genre"] == "Motown" and legacy["research_hint"] == "Motown", "saved clips training and research use Motown")
	check(legacy["title"] == "Lukthung" and legacy["name"] == "Lukthung", "genre migration preserves player-created names and titles")
	var lang = Locale.language
	Locale.set_language("th")
	var title = LoginScreen.new()
	add_child(title)
	check(title.find_child("TitleTagline", true, false) != null, "title displays SHIFT tagline")
	await capture("title-th")
	Locale.set_language("en")
	await capture("title-en")
	title.hide()
	Game.save_slot = "shift_qa"
	Game.new_game()
	Game.running = true
	Game.speed = 0
	var job: Dictionary = Game.offers[0]
	Game.accept_offer(job)
	Game.begin_idea_meeting(job)
	Game.idea_meeting["phase"] = "ready"
	var panel = IdeaJamPanel.new()
	add_child(panel)
	panel.open()
	var key = InputEventKey.new()
	key.keycode = KEY_SHIFT
	key.pressed = true
	panel._input(key)
	check(panel.PITCH_STEPS[panel.pitch_step] == 2, "Shift selects next pitch while editing")
	panel.place(0, 0, 0)
	check(panel.audition.playing and panel.audition.bus == "Composer", "placing a clip auditions its notes on composer volume bus")
	var volume = panel.find_child("ComposerVolume", true, false)
	var saved_volume = Audio.levels["Composer"]
	var bgm_volume = Audio.levels["BGM"]
	volume.value = 0
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Composer")), "zero volume fully mutes composer audio")
	volume.value = 70
	check(is_equal_approx(Audio.levels["Composer"], 0.7) and Audio.levels["BGM"] == bgm_volume, "composer volume changes independently from background music")
	var config = ConfigFile.new()
	config.load("user://audio.cfg")
	check(is_equal_approx(float(config.get_value("audio", "Composer", -1)), 0.7), "composer volume persists in audio preferences")
	volume.value = saved_volume * 100
	var pcm = panel.audition.stream.data
	var peak = 0
	for i in range(0, pcm.size(), 2): peak = maxi(peak, absi(pcm.decode_s16(i)))
	check(peak > 9000 and peak <= 29491, "single clip is louder with safe peak headroom")
	await get_tree().process_frame
	var placed_id = int(Game.idea_meeting["placed"][0]["block"])
	var notes = IdeaMusic.events(Game.idea_meeting["deck"], Game.idea_meeting["placed"])
	check(notes[0]["note"] == 74, "placed pitch transposes generated MIDI notes by two semitones")
	panel.place(placed_id, 0, 2)
	check(Game.idea_meeting["deck"][placed_id]["transpose"] == 2, "moving a clip preserves pitch")
	Game.place_idea(0, 3, 0, 12)
	var drums = IdeaMusic.events(Game.idea_meeting["deck"], [Game.idea_meeting["placed"].back()])
	check(drums[0]["note"] == 36, "drum lane preserves GM kit mapping")
	await get_tree().process_frame
	panel.preview()
	var original_notes = notes.duplicate(true)
	panel._input(key)
	check(Game.idea_meeting["bpm"] == 130 and panel.player.playing, "Shift during playback changes overall BPM and continues playing")
	check(panel.player.pitch_scale == 1.0, "tempo change does not transpose the audio")
	check(IdeaMusic.events(Game.idea_meeting["deck"], [Game.idea_meeting["placed"][0]]) == original_notes.map(func(n): var copy = n.duplicate(); copy["step"] += 16; return copy), "tempo change leaves musical pitches and arrangement intact")
	panel.tempo_slider.value = 180
	panel._input(key)
	check(Game.idea_meeting["bpm"] == 60 and panel.player.playing, "tempo cycles safely at maximum")
	key.echo = true
	panel._input(key)
	check(Game.idea_meeting["bpm"] == 60, "key repeat does not race through speeds")
	panel.toggle_playback()
	check(panel.player.stream_paused, "bottom Play button pauses playback")
	panel.toggle_playback()
	check(not panel.player.stream_paused and panel.player.playing, "bottom Play button resumes playback")
	panel.seek_slider.value = 12.0
	check(absf(panel.player.get_playback_position() - 12.0) < 0.2, "timeline seeks to selected beat at 60 BPM")
	panel.stop_playback()
	check(not panel.player.playing and panel.seek_slider.value == 0, "Stop resets transport to start")
	panel.seek_slider.value = 8.0
	panel.toggle_playback()
	check(panel.player.playing and absf(panel.player.get_playback_position() - 8.0) < 0.2, "Play starts at position chosen while stopped")
	Locale.set_language("th")
	await capture("composer-th")
	Game.save_game()
	check(Game.load_game() and Game.idea_meeting["bpm"] == 60 and Game.idea_meeting["deck"][placed_id]["transpose"] == 2, "pitch and BPM survive save/load")
	var result = Game.finish_idea_meeting()
	job = Game.get_job(job["id"])
	check(not result.is_empty() and job["idea_bpm"] == 60 and job["idea_notes"].any(func(n): return n["note"] == 74), "submitted song retains pitch and tempo")
	var midi = FileAccess.get_file_as_bytes(job["idea_midi"])
	check(midi.slice(0, 4).get_string_from_ascii() == "MThd", "MIDI exports successfully with instrument programs")
	panel.close()
	Game.running = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game._save_path()))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(job["idea_midi"]))
	Locale.set_language(lang)
	print("SHIFT: %d checks, %d failures" % [checks, failures])
	await Audio.shutdown()
	get_tree().quit(1 if failures else 0)
