extends Node2D
var failures = 0
var checks = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)

func _ready() -> void:
	var config = ModularCharacter.catalogue()
	check(config["characters"].size() == 32, "32 existing character identities")
	var index = 0
	for id in config["characters"]:
		var actor = ModularCharacter.new(); add_child(actor)
		check(actor.configure(id), "assemble " + id)
		actor.set_process(false)
		actor.position = Vector2(100 + (index % 8) * 220, 230 + (index / 8) * 230)
		actor.scale = Vector2(0.5, 0.5)
		for state in config["rows"]:
			actor.set_pose(state, 3)
			check(actor.parts.values().all(func(p): return p.frame == config["rows"].find(state)*4+3 and p.texture.get_size() == Vector2(1600,1600)), "aligned parts and matching frame " + id + state)
		actor.set_pose("idle")
		var label = Label.new();label.text=id;label.position=actor.position+Vector2(-90,4);label.add_theme_font_size_override("font_size",16);add_child(label)
		index += 1
	var actor = ModularCharacter.new();add_child(actor)
	for outfit in config["outfits"]:
		check(actor.configure("producer",outfit,{"cloth_tint":"#55aacc"}), "outfit " + outfit)
		check(actor.parts["body"].material is ShaderMaterial and actor.parts["head"].material == null, "palette changes clothes without recoloring head")
	actor.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	if "--visual" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_webp("D:/EP45/ndlp/Producers/modular-gallery.webp",true)
		for child in get_children(): child.queue_free()
		await get_tree().process_frame
		for row in 4:
			for col in 4:
				var preview = ModularCharacter.new(); add_child(preview)
				preview.configure("alice" if col % 2 == 0 else "producer", config["outfits"][col], {"cloth_tint":"#ffffff","pants_tint":"#7192b0"})
				preview.set_process(false); preview.set_pose(config["rows"][row], 1)
				preview.position = Vector2(240+col*440,245+row*250)
				preview.scale = Vector2(0.57,0.57)
				var caption = Label.new(); caption.text = config["outfits"][col]+" / "+config["rows"][row]
				caption.position = preview.position + Vector2(-80,0); add_child(caption)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_webp("D:/EP45/ndlp/Producers/modular-proportions.webp",true)
	print("MODULAR: %d checks, %d failures" % [checks,failures])
	await Audio.shutdown()
	get_tree().quit(failures)
