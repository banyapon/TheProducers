extends Node
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("ok: ",label)
	else: failures += 1; push_error(label)
func capture(label: String) -> void:
	if not "--visual" in OS.get_cmdline_user_args(): return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_webp("D:/EP45/ndlp/Producers/quality-" + label + ".webp", true)
func _ready() -> void:
	Game.save_slot = "shift_quality_qa"
	Game.new_game()
	Game.running = true; Game.speed = 0; Game.tutorial_step = -1
	Game.money = 20000
	var singer: Dictionary = Game.staff[0]
	singer["role"] = "Vocal"
	singer["identity"] = {"genre":"Lofi", "loyalty":70, "trust":70}
	MarketShift.state()["seed"] = Data.GENRES.find("Rock")
	var today = MarketShift.genre()
	var next = MarketShift.genre(1)
	Game.day += 28
	check(MarketShift.genre() == next and today != next, "forecast matches next market cycle")
	Game.day = 0
	var job: Dictionary = Game.offers[0]
	Game.accept_offer(job)
	check(MarketShift.choose(job,"pivot"), "choose reinvention before composing")
	var song = {"id":"shift-song", "mix":{"Rock":100}, "rating":32, "weekly_sales":1000}
	MarketShift.release(job,song,[singer["id"]])
	check(song["weekly_sales"] > 1000, "successful relevant reinvention increases sales")
	check(singer["identity"]["loyalty"] == 58 and singer["identity"]["trust"] == 64, "reinvention has explicit loyalty and trust costs")
	check(singer["identity"]["genre"] == "Rock", "successful release changes artist signature")
	MarketShift.release(job,song,[singer["id"]])
	check(singer["identity"]["loyalty"] == 58, "release cannot apply market effects twice")
	job["idea_rounds"] = 1
	check(not MarketShift.choose(job,"hold"), "submitted promise cannot be changed")
	job["idea_rounds"] = 0
	var broken = {"id":"broken", "mix":{"Jazz":100}, "rating":32, "weekly_sales":1000}
	MarketShift.release(job,broken,[singer["id"]])
	check(not broken["shift_result"]["followed"] and broken["shift_result"]["trust"] == -4, "actual released sound must match promised direction")
	job["arrangement"] = {"deck":[{"genre":"Jazz"}], "placed":[{"block":0}]}
	var manual_song = {"mix":{"Rock":100}, "rating":32, "weekly_sales":1000}
	MarketShift.release(job,manual_song,[singer["id"]])
	check(not manual_song["shift_result"]["followed"], "Manual checks placed clips instead of declared mix")
	job.erase("arrangement")
	var uncredited = {"mix":{"Rock":100}, "rating":32, "weekly_sales":1000}
	MarketShift.release(job,uncredited,[])
	check(not uncredited.has("shift_result") and uncredited["weekly_sales"] == 1000, "artist direction requires the named vocalist on the recording")
	Game.begin_idea_meeting(job)
	Game.idea_meeting["phase"] = "ready"
	var composer = IdeaJamPanel.new(); add_child(composer); composer.open()
	composer.market_open = true; composer.refresh()
	await capture("strategy")
	composer.close(); composer.queue_free(); Game.idea_meeting = {}
	var baseline = Game.money
	StudioResilience.purchase("insurance")
	check(Game.money == baseline - 800, "insurance costs fixed 800")
	StudioResilience.purchase("insurance")
	check(Game.money == baseline - 800, "active insurance cannot charge twice")
	StudioResilience.purchase("inspection")
	check(is_equal_approx(StudioResilience.fire_chance(),0.006), "inspection halves fire chance")
	check(StudioCity.ignite(0), "fire starts")
	var damage: Dictionary = Game.life["city"]["damage"][0]
	check(damage["until"] == Game.day + 4, "fire retains four-day duration")
	var during = Game.money
	StudioResilience.purchase("insurance")
	check(Game.money == during, "cannot insure after ignition")
	Game.day = damage["until"]
	StudioCity.extinguish(damage)
	var paid = Game.money
	check(paid == during + int(Data.ROOM_TYPES["studio"]["cost"] * 0.6), "insured fire pays construction reimbursement")
	check(Game.floors[damage["floor"]][damage["column"]] == "empty", "room remains empty for player rebuilding")
	StudioCity.extinguish(damage)
	check(Game.money == paid, "extinguishing cannot pay insurance twice")
	var recovery: Dictionary = StudioResilience.data()["recoveries"][0]
	var due = job["due_day"]
	StudioResilience.resolve(recovery["id"],1)
	check(job["due_day"] == due + 3 and Game.money == paid - 1200, "paid recovery extends active jobs by three days")
	StudioResilience.resolve(recovery["id"],1)
	check(Game.money == paid - 1200, "recovery cannot charge twice")
	var city = CityPanel.new(); add_child(city); city.location = "risk"; city.open()
	await capture("protection")
	city.close(); city.queue_free()
	var rumor = StudioStars.news_impact({"kind":1},2)
	var confirmed = StudioStars.news_impact({"kind":0},2)
	check(rumor["trust"] > confirmed["trust"], "evidence changes best scandal response")
	var event = StudioStars.create_news(singer,0)
	var news = NewsPanel.new(); add_child(news); news.event = event; news.open()
	await capture("news")
	StudioStars.resolve_news(event["id"],0)
	check(StudioStars.profile(singer)["brand_pause_until"] == Game.day + 3, "investigation pauses new brand bookings")
	news.message = "Resolved"; news.refresh()
	await capture("news-result")
	news.close(); news.queue_free()
	Game.save_game(); Game.load_game()
	check(Game.life.has("market_shift") and Game.life.has("resilience"), "new systems survive saves")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game._save_path()))
	Game.running = false
	print("SHIFT QUALITY: %d checks, %d failures" % [checks,failures])
	await Audio.shutdown()
	get_tree().quit(failures)
