extends Node
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
func _ready() -> void:
	var frames = Art.producer_office_frames()
	for animation in ["idle", "walk", "play", "talk"]:
		check(frames.get_frame_count(animation) == 9, "nine frames")
		for index in 9:
			var frame = frames.get_frame_texture(animation, index) as AtlasTexture
			check(frame.atlas.get_size() == Vector2(480,480), "original sheet size")
			check(frame.region == Rect2((index % 3)*160,(index / 3)*160,160,160), "row major frame")
	var i := 0
	for state in [Worker.State.IDLE, Worker.State.WALK, Worker.State.WORK, Worker.State.CHAT]:
		var actor = load("res://scenes/office/worker.tscn").instantiate()
		add_child(actor)
		actor.artist_id = "producer"
		actor.configure_art("producer", true)
		actor.position = Vector2(220 + i*300, 450)
		actor.state = state
		actor._update_visual(0.1)
		check(actor.body.animation == ["idle","walk","play","talk"][i], "state mapping")
		check(actor.body.scale == Vector2.ONE and actor.body.position == Vector2(-80,-137), "native scale and foot anchor")
		check(actor.hit_test(actor.global_position + Vector2(0,-100)), "upper body clickable")
		check(not actor._instrument_front.visible, "no old instrument overlay")
		actor.name_label.text = ["Idle","Walk","Play","Talk"][i]
		i += 1
	var alice = load("res://scenes/office/worker.tscn").instantiate()
	add_child(alice)
	alice.artist_id = "alice"
	alice.configure_art("alice", true)
	check(alice.body.sprite_frames == Art.office_frames("alice") and alice.body.position == Vector2(-80,-137), "Alice uses native sheets")
	for id in ["producer", "alice"] + Art.npc_ids + Art.vip_ids:
		alice.configure_art(id)
		check(not alice.body.flip_h, "default faces right: " + id)
		alice._path = [{"pos":alice.position + Vector2(10,0), "floor":0}]
		alice._walk(0.01)
		check(not alice.body.flip_h, "rightward walk keeps native orientation: " + id)
		alice._path = [{"pos":alice.position - Vector2(10,0), "floor":0}]
		alice._walk(0.01)
		check(alice.body.flip_h, "leftward walk mirrors native orientation: " + id)
		alice.state = Worker.State.CHAT
		alice._update_visual(0.01)
		check(not alice.body.flip_h, "talk returns to right-facing default: " + id)
	await get_tree().create_timer(0.4).timeout
	if "--visual" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_webp("D:/EP45/ndlp/Producers/producer-original.webp", true)
	print("PRODUCER ORIGINAL: ", failures, " failures")
	await Audio.shutdown()
	get_tree().quit(failures)
