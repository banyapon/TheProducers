class_name StarPanel
extends UIPanel
var tab := 0
var message := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	super()
	Locale.language_changed.connect(_refresh_if_open.unbind(1))

func close() -> void:
	Audio.stop_preview()
	super()

func refresh() -> void:
	UIKit.clear(self)
	var body = UIKit.centered_window(self, 1550, 960)
	var nav = HBoxContainer.new()
	body.add_child(nav)
	for i in 3:
		nav.add_child(UIKit.button(Locale.text(["stars_ranking", "stars_offers", "stars_collection"][i]), func(): tab = i; refresh()))
	nav.add_child(UIKit.button(Locale.text("close"), close))
	var note = UIKit.label(message if not message.is_empty() else Locale.text("stars_help"), 30)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(note)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	body.add_child(scroll)
	var list = VBoxContainer.new()
	list.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(list)
	if tab == 0:
		for row in StudioStars.rankings():
			list.add_child(UIKit.label("#%d  %s | %s | Fame %d" % [row["rank"], row["name"], StudioStars.tier(row["fame"]), row["fame"]], 32))
			if row["ours"]:
				var p = StudioStars.profile(Game.get_artist(row["id"]))
				list.add_child(UIKit.label(Locale.text("stars_trust", [p["trust"]]), 28))
	elif tab == 1:
		for task in StudioStars.data()["assignments"]:
			list.add_child(UIKit.label(Locale.text("stars_away", [task["name"], maxi(0, int(task["until"]) - Game.day)]), 30))
		for offer in StudioStars.data()["offers"]:
			var text = "%s | %s | %s | %s" % [offer["name"], offer["brand"], Locale.text("stars_" + offer["kind"]), Data.money(offer["fee"])]
			var detail = Locale.text("stars_offer_detail", [offer["days"], int(offer["expires"]) - Game.day])
			if offer["kind"] == "license": detail += "\n" + Locale.text("stars_royalty", [Data.money(maxi(100, int(offer["fee"]) / 10))])
			list.add_child(make_row(Color.CORNFLOWER_BLUE, text, detail, [[Locale.text("stars_accept"), func(): message = StudioStars.accept(offer["id"]); refresh()]]))
		if StudioStars.data()["offers"].is_empty(): list.add_child(UIKit.label(Locale.text("stars_no_offers"), 30))
	else:
		for artist in Game.staff:
			var p = StudioStars.profile(artist)
			if p.is_empty(): continue
			list.add_child(UIKit.button(Locale.text("stars_album", [artist["name"], p["album_tracks"].size()]), func(): message = StudioStars.make_album(artist["id"]); refresh()))
		var records: Array = StudioStars.data()["collections"].duplicate()
		records.reverse()
		for record in records:
			list.add_child(make_row(Color.GOLD, record["type"] + " | " + record["title"], "%s | %d/40 | %d tracks" % [record["name"], record["rating"], record["songs"].size()]))
			for song_id in record["songs"]:
				var song = StudioStage.song_by_id(song_id)
				if not song.is_empty(): list.add_child(UIKit.button(Locale.text("jam_listen") + " | " + song["title"], func(): Audio.play_song(song, false)))
		if records.is_empty(): list.add_child(UIKit.label(Locale.text("stars_no_collection"), 30))
