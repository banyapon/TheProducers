extends Node
var failures := 0
var checks := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
	else: print("ok: ", label)

func _ready() -> void:
	var original_language = Locale.language
	Locale.set_language("th")
	var old_client = Data.CLIENTS[1].name
	var old_title = Data.JOB_TITLES[0] + " Velvet Lights"
	Locale.set_language("en")
	check(Locale.display_game_text(old_title) == Data.JOB_TITLES[0] + " Velvet Lights", "saved Thai job title renders in English")
	check(Game.client_contact({"art_id":"super-02", "name":old_client}).ends_with(Data.CLIENTS[1].name), "saved VIP company renders in English")
	var decoded = StudioRankings.decode([{}, {"document":{"name":"projects/test/documents/studio_rankings/player", "fields":{"studio":{"stringValue":"QA Studio"}, "fame":{"integerValue":"321"}, "reputation":{"integerValue":"44"}}}}])
	check(decoded.size() == 1 and decoded[0].fame == 321 and decoded[0].reputation == 44, "Firestore typed score fields decode")
	check(not decoded[0].has("email"), "ranking rows contain no email")
	var result = await StudioRankings.fetch(self, "fame")
	check(result.get("error", "") == "ranking_signin", "signed-out ranking shows sign-in state")
	var shell = AppShell.new()
	add_child(shell)
	shell.open("ranking")
	shell._online_entries = []
	for i in range(23): shell._online_entries.append({"name":"Studio " + str(i), "fame":1000-i, "reputation":50, "ours":false})
	shell._ranking_status = "ranking_source"
	shell._render()
	await get_tree().process_frame
	await get_tree().process_frame
	if "--visual" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_webp("D:/EP45/ndlp/Producers/QA-latest/online-ranking-en.webp",true)
	shell.close()
	check(shell.page == "pause", "back from ranking returns to options")
	shell.close()
	if "--live-read" in OS.get_cmdline_user_args():
		if await FirebaseAuth.restore_session():
			var live = await StudioRankings.fetch(self, "fame")
			check(live.has("entries"), "live Firebase ranking read succeeds")
		else: print("LIVE READ SKIPPED: no restored account")
	Locale.set_language(original_language)
	print("ONLINE TESTS: %d checks, %d failures" % [checks, failures])
	await Audio.shutdown()
	get_tree().quit(1 if failures else 0)
