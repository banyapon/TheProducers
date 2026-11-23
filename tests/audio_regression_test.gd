extends Node

var failures := 0

func check(ok: bool, label: String) -> void:
	if ok: print("ok: ", label)
	else: failures += 1; push_error(label)

func _ready() -> void:
	Game.save_slot = "audio_regression_qa"
	Game.new_game()
	Game.speed = 0
	check(Audio.playlist.has("res://assets/bgm/bgm2.mp3") and Audio.playlist.has("res://assets/bgm/bgm3.mp3"), "gameplay playlist discovers imported tracks")
	Game.running = true
	Audio._process(0.0)
	check(Audio._last_track != "res://assets/bgm/title.mp3", "gameplay leaves title music")
	var previous = Audio._last_track
	Audio._next_bgm()
	check(Audio._last_track != previous, "playlist advances without immediate repeats")
	var job: Dictionary = Game.offers[0]
	Game.accept_offer(job)
	Game.begin_idea_meeting(job)
	Game.idea_meeting["phase"] = "ready"
	Game.idea_meeting["placed"].append({"block":2, "row":0, "col":0})
	var panel = IdeaJamPanel.new()
	add_child(panel)
	panel.open()
	Audio._process(0.0)
	check(Audio.bgm.stream_paused, "opening ready composer pauses BGM")
	panel.preview()
	check(panel.player.playing and panel.player.stream.data.size() > 0, "arrangement produces playable PCM")
	panel.toggle_playback()
	check(panel.player.stream_paused, "transport pauses")
	panel.toggle_playback()
	check(not panel.player.stream_paused and panel.player.playing, "transport resumes")
	panel.player.seek(1.0)
	await get_tree().create_timer(0.1).timeout
	check(panel.player.get_playback_position() >= 1.0, "transport seeks")
	panel.close()
	Audio._process(0.0)
	check(not Audio.bgm.stream_paused and Audio.bgm.playing, "closing saved draft resumes BGM")
	check(not panel.player.playing, "closing stops arrangement")
	check(not Game.idea_meeting.is_empty(), "closing preserves draft")
	check(Audio.preview.bus == "Composer", "song preview uses independent composer volume")
	panel.queue_free()
	Game.running = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game._save_path()))
	print("AUDIO REGRESSION: %d failures" % failures)
	await Audio.shutdown()
	get_tree().quit(failures)
