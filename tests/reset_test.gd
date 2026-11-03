extends Node
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
	else: print("ok: ", message)

func _ready() -> void:
	Game.save_slot = "reset_qa"
	Game.new_game()
	Game.running = true
	Game.speed = 0
	Game.set_identity("Alice", "Original Studio", "alice")
	Game.money = 900000
	Game.songs = [{"id": "old_song", "title": "Old song", "audio_url": "", "cover_url": ""}]
	MusicGen.active_jobs = 1
	check(await CareerReset.restart(false) == "reset_busy", "reset blocked during render/upload")
	MusicGen.active_jobs = 0
	check(Game.songs.size() == 1 and Game.money == 900000, "busy reset leaves progress intact")
	check(await CareerReset.restart(false) == "", "offline keep succeeds")
	check(Game.songs.is_empty() and Game.archived_songs.size() == 1, "history separated from current income and scores")
	check(Game.money == Game.START_MONEY and not Game.identity_initialized, "career reset requires new identity")
	check(Game.archived_songs[0]["origin_studio"] == "Original Studio" and Game.archived_songs[0]["origin_producer"] == "Alice", "original credits retained")
	check(Game.load_game() and Game.archived_songs.size() == 1, "archive survives loading")
	Game.set_identity("Second", "Next Studio")
	check(await CareerReset.restart(false) == "" and Game.archived_songs[0]["origin_studio"] == "Original Studio", "repeated reset preserves original credit")
	Game.archived_songs[0]["audio_url"] = "https://example.invalid/music.mp3"
	Game.archived_songs[0]["owner_uid"] = "different_account"
	check(await CareerReset.restart(true) == "reset_failed", "remote deletion without owner session blocked")
	check(Game.archived_songs.size() == 1, "failed deletion retains history for retry")
	Game.archived_songs[0]["audio_url"] = ""
	check(await CareerReset.restart(true) == "" and Game.archived_songs.is_empty(), "deleting local-only catalogue clears history")
	var shell = AppShell.new()
	add_child(shell)
	shell.open()
	check(shell.find_child("RestartCareer", true, false) != null, "Options exposes reset")
	shell.find_child("RestartCareer", true, false).pressed.emit()
	check(shell.page == "reset", "reset opens explicit keep/delete prompt")
	if "--visual" in OS.get_cmdline_user_args():
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_webp("D:/EP45/ndlp/Producers/reset-options.webp")
	shell.close()
	check(shell.page == "pause" and Game.archived_songs.is_empty(), "cancel returns to Options without reset")
	Game.running = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game._save_path()))
	print("RESET TESTS: %d checks, %d failures" % [checks, failures])
	await Audio.shutdown()
	get_tree().quit(1 if failures else 0)
