extends Node
var failures := 0
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)

func _ready() -> void:
	Game.save_slot = "improvise_qa"
	Game.new_game(); DemoCareer.setup()
	Game.running = true; Game.speed = 0
	var job = Game.offers[0]
	Game.accept_offer(job, "manual")
	Game.begin_idea_meeting(job)
	Game.idea_meeting["phase"] = "ready"
	Game.idea_meeting["bpm"] = 120
	var panel = IdeaJamPanel.new(); add_child(panel); panel.open()
	check(panel.find_child("ComposerImprovise", true, false) != null, "composer exposes Improvise")
	var original = ComposerFlow.snapshot(Game.idea_meeting)
	panel.audition_lane = 0
	panel.open_improvise()
	var instrument = panel.improvise
	instrument.set_process(false)
	check(not panel.body_root.visible and instrument.visible, "keyboard replaces composer view")
	instrument.lane = 0
	instrument.bpm = 120
	instrument.start_recording()
	instrument._press(0, false); instrument._release(0, false)
	check(instrument.notes.is_empty(), "count-in does not record practice notes")
	instrument._process(2.0)
	check(instrument.recording, "four-beat count-in starts recording")
	instrument._press(0, false)
	instrument._press(4, false)
	instrument._process(0.5)
	instrument._release(0, false); instrument._release(4, false)
	check(instrument.notes.size() == 2, "simultaneous piano notes captured")
	check(is_equal_approx(instrument.notes[0]["duration"], 1.0), "held note duration recorded in beats")
	instrument._press(0, true); instrument._release(0, true)
	check(instrument.notes.size() == 2, "drum audition does not pollute melody take")
	instrument._process(1.5)
	check(not instrument.recording and not instrument.save_button.disabled, "recording stops after selected bars")
	if "--visual" in OS.get_cmdline_user_args():
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://improvise-preview.png")
	instrument.listen()
	check(instrument.preview_player.playing, "take preview plays")
	panel._save_improvise(instrument.notes.duplicate(true), 0, 2, 1)
	var after = ComposerFlow.snapshot(Game.idea_meeting)
	check(after != original, "recorded take updates arrangement")
	var placement = Game.idea_meeting["placed"].filter(func(p): return p["row"] == 0 and p["col"] == 2)
	check(placement.size() == 1, "save replaces only selected bar")
	var events = IdeaMusic.events(Game.idea_meeting["deck"], placement)
	check(events.size() == 2 and events[0]["note"] == 60 and events[1]["note"] == 64, "exact pitches survive event conversion")
	check(events[0]["step"] == 16.0 and events[0]["length"] == 2.0, "bar offset and held length survive playback")
	panel.undo(); check(ComposerFlow.snapshot(Game.idea_meeting) == original, "undo restores overwritten clip")
	panel.redo(); check(ComposerFlow.snapshot(Game.idea_meeting) == after, "redo restores recorded clip")
	Game.save_game()
	check(Game.load_game(), "saved arrangement loads")
	check(ComposerFlow.snapshot(Game.idea_meeting) == after, "take survives save/load")
	var m = Game.idea_meeting
	var drums = [{"beat":0.25,"note":38,"duration":0.25}, {"beat":1.0,"note":42,"duration":0.25}, {"beat":4.0,"note":36,"duration":0.25}]
	check(ImproviseTake.apply(m, drums, 3, 6, 2), "multi-bar drum take accepted")
	var drum_places = m["placed"].filter(func(p): return p["row"] == 3 and p["col"] >= 6)
	var drum_events = IdeaMusic.events(m["deck"], drum_places)
	check(drum_events.size() == 3 and drum_events[0]["note"] == 38 and drum_events[1]["note"] == 42 and drum_events[2]["note"] == 36, "snare and hat preserved independently of beat position")
	check(drum_events[0]["step"] == 48.5 and drum_events[2]["step"] == 56.0, "multi-bar drum timing preserved")
	check(not ImproviseTake.apply(m, drums, 3, 7, 2), "out-of-range take rejected")
	check(IdeaMusic.write_midi(drum_events, 120, "user://improvise-qa.mid"), "recorded notes export to MIDI")
	panel.audition_lane = 3
	panel.open_improvise()
	panel.improvise.set_process(false)
	panel.improvise.start_recording()
	panel.improvise._process(2.0)
	var key = InputEventKey.new()
	key.physical_keycode = KEY_X; key.pressed = true
	panel.improvise._input(key)
	key.echo = true; panel.improvise._input(key)
	key.echo = false; key.pressed = false; panel.improvise._input(key)
	check(panel.improvise.notes.size() == 1 and panel.improvise.notes[0]["note"] == 38, "keyboard records snare and ignores key repeat")
	panel.close()
	check(not is_instance_valid(panel.improvise) and not panel.player.playing, "closing stops recorder and accompaniment")
	Game.running = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game._save_path()))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://improvise-qa.mid"))
	print("IMPROVISE: %d checks, %d failures" % [checks, failures])
	await Audio.shutdown()
	get_tree().quit(failures)
