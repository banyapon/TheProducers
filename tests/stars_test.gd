extends Node
var checks := 0
var failures := 0
var main: Node
var visual := false
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(text)
	else: print("ok: ", text)

func capture(label: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if visual:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("D:/EP45/ndlp/Producers/Star-Life-20261031/qa-" + label + ".png")

func _ready() -> void:
	visual = "--visual" in OS.get_cmdline_user_args()
	Game.save_slot = "stars_qa"
	Game.new_game()
	Game.running = true
	Game.speed = 0
	Game.tutorial_step = -1
	Game.money = 50000
	var singer: Dictionary = Game.staff[0]
	singer["role"] = "Vocal"
	var other: Dictionary = Game.staff[1]
	other["role"] = "Guitar"
	check(StudioStars.profile(other).is_empty(), "only Vocal receives a star profile")
	for i in 3:
		var song = {"id": "star-song-%d" % i, "title": "Starlight %d" % i, "rating": 35}
		Game.songs.append(song)
		StudioStars.on_release(song, [singer["id"], other["id"]])
		StudioStars.on_release(song, [singer["id"]])
	check(StudioStars.data()["collections"].size() == 3, "only Vocal gets Singles and duplicate releases are idempotent")
	check(StudioStars.profile(singer)["fame"] == 840, "Fame accumulates per credited vocalist")
	var cash = Game.money
	StudioStars.make_album(singer["id"])
	check(Game.money == cash - 2500 and StudioStars.data()["collections"].size() == 4, "three unused Singles form paid Album collection")
	cash = Game.money
	StudioStars.make_album(singer["id"])
	check(Game.money == cash and StudioStars.profile(singer)["album_tracks"].is_empty(), "same tracks cannot be farmed for repeat albums")
	var rows = StudioStars.rankings()
	for i in range(1, rows.size()): check(rows[i - 1]["fame"] >= rows[i]["fame"], "social ranking is sorted")
	var offer = StudioStars.offer_for(singer, "concert")
	StudioStars.accept(offer["id"])
	check(StudioStars.busy(singer["id"]) and not StudioLife.available(singer), "concert reserves artist")
	check(StudioStage.performing(singer["id"]) and Game._booking_conflicts([singer["id"]], 0, Game.day, Game.day + 1), "production and future bookings reject away singer")
	check(not StudioStars.conflicts([singer["id"]], Game.day + 5, Game.day + 8), "future booking after artist return is allowed")
	var another = StudioStars.offer_for(singer, "photo")
	check(StudioStars.accept(another["id"]) == Locale.text("artist_busy"), "overlapping appearance rejected")
	cash = Game.money
	Game.day += 5
	StudioStars.data()["last_week"] = int(Game.day / 7)
	Game.life["city"]["damage"] = [{"until": Game.day + 4}]
	StudioStars.tick_day()
	check(Game.money == cash and StudioStars.busy(singer["id"]), "fire suspends artist payouts and events")
	Game.life["city"]["damage"] = []
	StudioStars.tick_day()
	check(Game.money == cash + offer["fee"] and not StudioStars.busy(singer["id"]), "fee paid on return and artist becomes available")
	cash = Game.money
	StudioStars.tick_day()
	check(Game.money == cash, "completed booking pays exactly once")
	var license = StudioStars.offer_for(singer, "license")
	StudioStars.accept(license["id"])
	check(Game.money == cash + license["fee"] and not StudioStars.busy(singer["id"]), "licensing pays upfront without reserving singer")
	cash = Game.money
	Game.day += 56
	StudioStars.tick_day()
	check(Game.money == cash + maxi(100, int(license["fee"]) / 10) * 8 and StudioStars.data()["royalties"].is_empty(), "royalties pay eight weeks once including catch-up")
	StudioStars.data()["news"] = []
	var news = StudioStars.create_news(singer, 0)
	check(not news.is_empty() and StudioStars.create_news(singer, 1).is_empty(), "only one unresolved headline at a time")
	Game.money = -100
	StudioStars.resolve_news(news["id"], 0)
	check(StudioStars.data()["news"].size() == 1, "unaffordable response leaves news unresolved")
	StudioStars.resolve_news(news["id"], 2)
	check(StudioStars.data()["news"].is_empty() and Game.money == -100, "zero-cost response works in debt")
	Game.save_game()
	check(Game.load_game() and StudioStars.data()["collections"].size() == 4, "collections and star progression survive save/load")
	Game.money = 10000
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	main._booting = true
	main.login.hide()
	main.star_panel.open()
	await capture("ranking")
	var grid = main.star_panel.find_child("ArtistGrid", true, false)
	check(grid.get_child_count() == 4, "ranking shows four cards per page")
	var portrait = grid.find_child("ArtistFullBody", true, false) as PortraitView
	check(portrait.fullbody.animation == "talk" and not portrait.crop_half, "cards animate full body in talk pose")
	main.star_panel.page = 2
	main.star_panel.refresh()
	await capture("ranking-last")
	grid = main.star_panel.find_child("ArtistGrid", true, false)
	check(grid.find_children("ArtistFullBody", "", true, false).size() == StudioStars.rankings().size() - 8, "last ranking page includes remaining artists")
	main.star_panel.page = 0
	main.star_panel.tab = 1
	main.star_panel.refresh()
	await capture("offers")
	main.star_panel.tab = 2
	main.star_panel.refresh()
	await capture("collection")
	main.star_panel.close()
	news = StudioStars.create_news(Game.staff[0], 1)
	main.news_panel.event = news
	main.news_panel.open()
	await capture("hot-news")
	StudioStars.resolve_news(news["id"], 0)
	main.news_panel.close()
	main.city_panel.announce({"win": true, "song": "Starlight", "rating": 35})
	await capture("awards")
	main.city_panel.close()
	Game.running = false
	main._queue.clear()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game._save_path()))
	print("STARS TESTS: %d checks, %d failures" % [checks, failures])
	await Audio.shutdown()
	get_tree().quit(1 if failures else 0)
