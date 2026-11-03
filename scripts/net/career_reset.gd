class_name CareerReset
extends RefCounted

static func stamp(song: Dictionary) -> void:
	if not song.has("origin_studio"): song["origin_studio"] = Game.studio_name
	if not song.has("origin_producer"): song["origin_producer"] = Game.producer_name

static func restart(delete_remote: bool) -> String:
	if MusicGen.active_jobs > 0: return "reset_busy"
	var catalogue = Game.archived_songs + Game.songs
	for song in catalogue: stamp(song)
	Game.save_game()
	if delete_remote:
		for song in catalogue:
			for spec in [["cover", "image", "covers"], ["audio", "video", "songs"], ["archive", "raw", "history"]]:
				var key: String = spec[0]
				var public_id = str(song.get(key + "_public_id", ""))
				var url = str(song.get(key + "_url", ""))
				if public_id.is_empty() and url.is_empty(): continue
				if not FirebaseAuth.is_signed_in() or str(song.get("owner_uid", FirebaseAuth.uid)) != FirebaseAuth.uid: return "reset_failed"
				if public_id.is_empty():
					public_id = "%s/%s/%s/%s" % [Secrets.cloudinary_root, FirebaseAuth.uid, spec[2], song["id"]]
					if not url.contains("/" + public_id + "."): return "reset_failed"
				var response = await Cloudinary.destroy(public_id, spec[1])
				if response.has("error"): return "reset_failed"
				song[key + "_public_id"] = ""
				song[key + "_url"] = ""
				Game.save_game()
	else:
		var records: Array = []
		for song in catalogue:
			if str(song.get("audio_url", "")) != "" or str(song.get("cover_url", "")) != "":
				records.append({"id": song["id"], "title": song["title"], "studio": song["origin_studio"], "producer": song["origin_producer"], "audio_url": song.get("audio_url", ""), "cover_url": song.get("cover_url", "")})
		if not records.is_empty():
			if not FirebaseAuth.is_signed_in() or not Cloudinary.is_configured(): return "reset_failed"
			var archive_id = "history_" + Crypto.new().generate_random_bytes(16).hex_encode() + ".json"
			var response = await Cloudinary.upload(JSON.stringify(records).to_utf8_buffer(), archive_id, "application/json", "raw", Secrets.cloudinary_root + "/" + FirebaseAuth.uid + "/history", archive_id)
			if response.has("error"): return "reset_failed"
			# Each snapshot is retained on a song, including across repeated restarts.
			if not catalogue.is_empty():
				var holder: Dictionary = catalogue.back()
				if not holder.has("history_assets"): holder["history_assets"] = []
				holder["history_assets"].append(response.get("public_id", ""))
		for song in catalogue: song["archived"] = true
	# Delete retained snapshot files only after the song media has been deleted.
	if delete_remote:
		for song in catalogue:
			for asset in song.get("history_assets", []).duplicate():
				var response = await Cloudinary.destroy(asset, "raw")
				if response.has("error"): return "reset_failed"
				song["history_assets"].erase(asset)
				Game.save_game()
	Game.reset_game()
	if not delete_remote: Game.archived_songs = catalogue
	Game.save_game()
	return ""
