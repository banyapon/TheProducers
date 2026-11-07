extends Node
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _ready() -> void:
	await get_tree().process_frame
	Game.save_slot = "vip_office_qa"
	Game.new_game()
	Game.tutorial_step = -1
	Game.tutorial_gate = false
	check(Game.floors == [["meeting", "lounge", "studio"]], "three starter rooms")
	check(Game.staff_capacity() >= Game.staff.size(), "starter team has capacity")
	var id = Game.clients.keys()[0]
	var client = Game.get_client(id)
	client["rel"] = 40
	check(VipOffice.offer_bonus() == 0.0, "no unearned connection")
	check(VipOffice.invite(id) == "", "invite known client")
	check(VipOffice.invite(id) != "", "no duplicate appointments")
	var office = load("res://scenes/office/office.tscn").instantiate()
	add_child(office)
	office._on_state_loaded()
	Game.running = true
	Game.speed = 1
	Game._pause_requests = 0
	for zoom in [0.25, 1.0, 4.0]:
		office.camera.zoom = Vector2.ONE * zoom
		office.camera.force_update_scroll()
		office._process(0)
		var label: Label = office.room_labels[0]
		check(is_equal_approx(label.get_global_transform_with_canvas().x.length(), 1.0), "room label constant screen size")
		var actor: Worker = office.workers.values()[0]
		actor._update_name_scale()
		check(is_equal_approx(actor.name_label.get_global_transform_with_canvas().x.length(), 1.0), "staff label constant screen size")
	check(is_instance_valid(office.vip_actor), "VIP visible on arrival path")
	var host: Worker = office.principals["producer"]
	office.vip_actor.position = office.vip_actor._path[-1]["pos"]
	office.vip_actor._path.clear()
	office.vip_actor._arrive()
	host.position = host._path[-1]["pos"]
	host._path.clear()
	host._arrive()
	Game.speed = 1
	office._tick_vip(1)
	check(host.state == Worker.State.CHAT and office.vip_actor.state == Worker.State.CHAT, "both talk after arriving")
	office._tick_vip(4)
	check(int(client["rel"]) == 48, "meeting relationship reward")
	check(not VipOffice.complete(), "completion idempotent")
	check(VipOffice.reason(id) != "", "daily limit")
	Game.day += 1
	check(VipOffice.reason(id) != "", "weekly client cooldown")
	Game.day += 6
	check(VipOffice.reason(id) == "", "cooldown expires")
	check(VipOffice.offer_bonus() > 0.0 and VipOffice.offer_bonus() <= 0.2, "bounded offer bonus")
	var artist: Dictionary = Game.staff[0]
	var trust = int(artist["social"]["trust"])
	var job = {"title": "VIP Test", "vip_connection": 0.8}
	var loss = VipOffice.production_pressure(job, [artist["id"]], 0.0)
	check(loss >= 3 and loss <= 6 and int(artist["social"]["trust"]) == trust - loss, "pressure on recording team")
	check(VipOffice.production_pressure(job, [artist["id"]], 0.0) == 0, "pressure once per release")
	check(VipOffice.production_pressure({"title":"normal"}, [artist["id"]], 0.0) == 0, "unconnected work safe")
	check(VipOffice.production_pressure({"vip_connection":1.0}, [artist["id"]], 0.99) == 0, "chance can avoid penalty")
	check(VipOffice.invite(id) == "", "second appointment after cooldown")
	Game.save_game()
	Game.life["vip_appointment"] = {}
	check(Game.load_game(), "load saved game")
	check(Game.life.get("vip_appointment", {}).get("client", "") == id, "pending appointment persists")
	check(Game.get_client(id).get("office_visits", 0) == 1, "VIP relationship history persists")
	Game.life["vip_appointment"] = {}
	Game.speed = 0
	office._frame_building()
	await get_tree().process_frame
	if "--visual" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_webp("D:/EP45/ndlp/Producers/vip-office-review.webp", true)
	var ui = CanvasLayer.new()
	add_child(ui)
	var panel = CityPanel.new()
	ui.add_child(panel)
	panel.location = "vip"
	panel.open()
	await get_tree().process_frame
	if "--visual" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_webp("D:/EP45/ndlp/Producers/vip-menu-review.webp", true)
	panel.close()
	print("VIP OFFICE: ", failures, " failures")
	Game.running = false
	await Audio.shutdown()
	get_tree().quit(failures)
