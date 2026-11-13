class_name Worker
extends Node2D
## One 1:1 square character. Wanders, rides the stair shaft between floors, idles, chats with
## neighbours â€” or in work mode walks to the Recording Studio and jams until the song is done.

enum State { IDLE, WALK, CHAT, WORK }

const SIZE := 43.0
const WALK_SPEED := 90.0
const CLIMB_SPEED := 70.0
var CHAT_LINES: Array:
	get: return Locale.values("world_chat")
var WORK_LINES: Array:
	get: return Locale.values("world_work")

var artist_id = ""
var office: Office
var floor_index = 0
var state = State.IDLE
var working = false
var assigned_room = Vector2i(-1, -1)
var researching = false
var gathering = false
var gather_room = Vector2i.ZERO
var is_visitor = false
var quest_id := ""
var _path: Array = []  ## [{pos: Vector2, floor: int}]
var _timer = 0.0
var _bubble_timer = 0.0
var _leaving = false
var _visit_done = false

var body: AnimatedSprite2D
var appointment := false
var name_lane := 0
var principal = false
var _native_sprite := false
var _art_id = "producer"
var _instrument = ""
var _instrument_data: Dictionary
var _instrument_front: Sprite2D
var _chat: Sprite2D
var _chat_texture: Texture2D
var _notes: Array = []
var _fx_clock = 0.0
var _note_clock = 0.0
var _note_atlas: Texture2D

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body = AnimatedSprite2D.new()
	body.centered = false
	body.position = Vector2(-16, -45)
	add_child(body)
	_instrument_front = Sprite2D.new()
	_instrument_front.centered = false
	_instrument_front.z_index = 1
	add_child(_instrument_front)
	_chat = Sprite2D.new()
	_chat.position = Vector2(0, -75)
	_chat.z_index = 2
	_chat.hide()
	add_child(_chat)
	_note_atlas = Art.texture("res://assets/lots/effects/music-notes-atlas.png")
	configure_art("producer")
@onready var bubble: Label = $Bubble
@onready var name_label: Label = $NameLabel


func setup(owner_office: Office, id: String, display_name: String, color: Color) -> void:
	office = owner_office
	artist_id = id
	# Palette is defined by the source sprite.
	name_label.modulate = Color.WHITE
	name_label.text = display_name


func place(f: int, x: float) -> void:
	floor_index = f
	position = Vector2(x, office.floor_y(f))
	state = State.IDLE
	_timer = randf_range(0.3, 2.0)


func say(text: String, duration: float) -> void:
	bubble.text = text
	bubble.visible = text != ""
	bubble.reset_size()
	bubble.position.x = -bubble.size.x * 0.5
	_bubble_timer = duration


func hit_test(p: Vector2) -> bool:
	if _native_sprite:
		return Rect2(global_position + Vector2(-30, -118), Vector2(60, 118)).has_point(p)
	return Rect2(global_position + Vector2(-SIZE * 0.5 - 6.0, -SIZE - 6.0), Vector2(SIZE + 12.0, SIZE + 12.0)).has_point(p)


func _process(delta: float) -> void:
	if office == null: return
	_update_name_scale()
	var can_gather = gathering and Game.idea_meeting.get("phase", "") == "gathering" and Game._pause_requests <= 1
	body.speed_scale = 2.0 if can_gather else 0.0 if Game.is_paused() or not Game.running else clampf(Game.speed, 0.0, 4.0)
	if (Game.is_paused() and not can_gather) or not Game.running: return
	var dt = delta * (2.0 if can_gather else clampf(Game.speed, 0.0, 4.0))
	_update_visual(dt)
	if dt <= 0.0:
		return
	if _bubble_timer > 0.0:
		_bubble_timer -= dt
		if _bubble_timer <= 0.0:
			bubble.hide()
	match state:
		State.IDLE:
			_timer -= dt
			if _timer <= 0.0:
				_decide()
		State.WALK:
			_walk(dt)
		State.CHAT:
			_timer -= dt
			if _timer <= 0.0:
				_end_chat()
			elif _bubble_timer <= 0.0 and randf() < 0.03:
				say(CHAT_LINES.pick_random(), 1.0)
		State.WORK:
			_timer -= dt
			if _timer <= 0.0:
				_timer = randf_range(0.8, 1.6)
				say(WORK_LINES.pick_random(), 0.7)


func _decide() -> void:
	if appointment:
		_timer = 1.0
		return
	if quest_id != "":
		_wander_near_producer()
		return
	if is_visitor:
		if _visit_done:
			leave()
		return
	if gathering:
		_timer = 1.0
		return
	if researching:
		_go_to_room("lounge")
		return
	if working:
		_go_to_studio()
		return
	var r = randf()
	if r < 0.2 and _try_chat():
		return
	if r < 0.5:
		go_to(floor_index, office.random_x())
	elif r < 0.75:
		go_to(randi() % office.floor_count(), office.random_x())
	elif r < 0.85:
		_go_to_room(["lounge", "meeting", "cafeteria", "office"].pick_random())
	else:
		_timer = randf_range(1.5, 4.0)
		if randf() < 0.3:
			say("zzz", 1.5)


## Path = (walk to shaft -> climb to target floor ->) walk to x.
func go_to(f: int, x: float) -> void:
	_path.clear()
	if f != floor_index:
		var sx = office.shaft_x()
		_path.append({"pos": Vector2(sx, office.floor_y(floor_index)), "floor": floor_index})
		_path.append({"pos": Vector2(sx, office.floor_y(f)), "floor": f})
	_path.append({"pos": Vector2(x, office.floor_y(f)), "floor": f})
	state = State.WALK


func _go_to_studio() -> void:
	if assigned_room.x >= 0:
		go_to(assigned_room.x, office.random_x_in_room(assigned_room.y))
	else: _go_to_room("studio")

func set_researching(on: bool) -> void:
	if researching == on: return
	researching = on
	if on: _go_to_room("lounge")
	else:
		state = State.IDLE
		_timer = 0.5

func _go_to_room(type: String) -> void:
	var rooms = office.find_rooms(type)
	if rooms.is_empty():
		state = State.IDLE
		_timer = 2.0
		return
	var room: Vector2i = rooms.pick_random()
	go_to(room.x, office.random_x_in_room(room.y))


func _walk(dt: float) -> void:
	if _path.is_empty():
		_arrive()
		return
	var target: Vector2 = _path[0]["pos"]
	var vertical = absf(target.y - position.y) > 0.5
	if not vertical: body.flip_h = target.x < position.x
	position = position.move_toward(target, (CLIMB_SPEED if vertical else WALK_SPEED) * dt)
	if position.distance_to(target) < 0.5:
		position = target
		floor_index = _path[0]["floor"]
		_path.pop_front()


func _arrive() -> void:
	if _leaving:
		queue_free()
		return
	if quest_id != "":
		state = State.IDLE
		_timer = randf_range(0.8, 2.2)
		return
	if is_visitor and not _visit_done:
		_visit_done = true
		state = State.IDLE
		_timer = 6.0
		say(Locale.text("legacy_223"), 2.0)
		return
	if gathering and office.is_in_room(position, floor_index, "lounge"):
		state = State.CHAT
		_timer = 100
		say(Locale.text("jam_world"), 1.5)
		return
	if researching and office.is_in_room(position, floor_index, "lounge"):
		state = State.CHAT
		_timer = 3.0
		say(Locale.text("research_world"), 2.0)
		return
	if working and office.is_in_room(position, floor_index, "studio"):
		state = State.WORK
		_timer = 0.3
		name_label.hide()  # bandmates crowd the studio; bubbles + popups say enough
		return
	state = State.IDLE
	_timer = randf_range(1.0, 4.0)


func _wander_near_producer() -> void:
	var host: Worker = office.principals.get("producer")
	var anchor_floor = host.floor_index if is_instance_valid(host) else 0
	var anchor_x = host.position.x + 84.0 if is_instance_valid(host) else position.x
	anchor_x = clampf(anchor_x, office.shaft_x() + 36.0, office.building_width() - 36.0)
	if floor_index != anchor_floor or absf(position.x - anchor_x) > 150.0:
		go_to(anchor_floor, anchor_x)
		return
	if randf() < 0.5:
		var x = clampf(anchor_x + randf_range(-120.0, 120.0), office.shaft_x() + 36.0, office.building_width() - 36.0)
		go_to(floor_index, x)
	else:
		state = State.IDLE
		_timer = randf_range(1.2, 3.4)


func _try_chat() -> bool:
	for other in get_parent().get_children():
		var w = other as Worker
		if w == null or w == self:
			continue
		if w.state != State.IDLE or w.working or w.appointment or w.is_visitor or w.floor_index != floor_index:
			continue
		if absf(w.position.x - position.x) > 150.0:
			continue
		var duration = randf_range(2.5, 4.5)
		start_chat(duration)
		w.start_chat(duration)
		return true
	return false


func start_chat(duration: float) -> void:
	_chat_texture = Art.texture("res://assets/chatmusic/chat-%s-6frames.png" % Art.CHATS.pick_random())
	state = State.CHAT
	_timer = duration
	say(CHAT_LINES.pick_random(), 1.2)


func _end_chat() -> void:
	state = State.IDLE
	_timer = randf_range(0.5, 2.0)


func set_working(on: bool) -> void:
	if working == on:
		return
	working = on
	if on:
		_instrument = Art.INSTRUMENTS.pick_random()
		_instrument_data = Art.instrument_info(_instrument)
	name_label.show()
	if on:
		say("!", 1.0)
		_go_to_studio()
	else:
		if state == State.WORK:
			state = State.IDLE
			_timer = 0.5
		say(Locale.text("legacy_224"), 1.5)


func leave() -> void:
	working = false
	_leaving = true
	go_to(0, office.building_width() + 200.0)

func configure_art(id: String, is_principal: bool = false) -> void:
	_art_id = id
	principal = is_principal
	body.sprite_frames = Art.office_frames(id)
	_native_sprite = body.sprite_frames.has_animation("play")
	body.scale = Vector2.ONE
	# Native sheets face right; flip only while travelling left.
	body.flip_h = false
	body.position = Vector2(-80, -137) if _native_sprite else Vector2(-16, -45)
	_chat.position.y = -145 if _native_sprite else -75
	bubble.position.y = -145 if _native_sprite else -70
	body.play("idle")
	body.show()
	name_label.visible = true
	name_label.add_theme_font_size_override("font_size", 36)
	name_label.add_theme_color_override("font_outline_color", Color("101823"))
	name_label.add_theme_constant_override("outline_size", 5)
	name_label.z_index = 20
	_update_name_scale()
	queue_redraw()

func _update_name_scale() -> void:
	# Match UI units, cancelling only the world/camera scale (not viewport stretch).
	var transform = get_global_transform_with_canvas()
	var world_scale = Vector2(maxf(transform.x.length(), 0.001), maxf(transform.y.length(), 0.001))
	name_label.scale = Vector2.ONE / world_scale
	name_label.reset_size()
	name_label.position = Vector2(-name_label.size.x * name_label.scale.x * 0.5,
		(-132.0 if _native_sprite else -68.0) - (name_label.size.y + 8.0 + name_lane * 28.0) * name_label.scale.y)

func _update_visual(dt: float) -> void:
	_fx_clock += dt
	var animation = "idle"
	if state == State.WALK: animation = "walk"
	elif state == State.CHAT: animation = "talk"
	elif state == State.WORK: animation = "play" if _native_sprite else "sway"
	if body.animation != animation: body.play(animation)
	if state in [State.WORK, State.CHAT]: body.flip_h = false
	name_label.visible = true
	if state == State.CHAT: bubble.hide()
	_chat.visible = state == State.CHAT and _chat_texture != null
	if _chat.visible:
		_chat.texture = Art.atlas(_chat_texture, Rect2((int(_fx_clock * 7) % 6) * 80, 0, 80, 36))
	_instrument_front.visible = state == State.WORK and not _instrument_data.is_empty()
	if _instrument_front.visible:
		var dimensions: Vector2i = _instrument_data["size"]
		# The six-frame overlays sit in front of both native play and row-three sway.
		var instrument_scale = 1.0 if _native_sprite else 48.0 / 160.0
		_instrument_front.scale = Vector2.ONE * instrument_scale
		_instrument_front.position = -Vector2(_instrument_data["anchor"]) * instrument_scale
		var strip: Texture2D = _instrument_data["texture"]
		var count = body.sprite_frames.get_frame_count(body.animation)
		var instrument_frame = mini(5, floori(float(body.frame) * 6.0 / max(1, count)))
		var x = instrument_frame * dimensions.x
		_instrument_front.texture = Art.atlas(strip, Rect2(x, 0, dimensions.x, dimensions.y))
		_note_clock -= dt
		if _note_clock <= 0:
			_note_clock = randf_range(0.3, 0.7)
			_notes.append({"position": Vector2(randf_range(-20, 20), -110 if _native_sprite else -45), "life": 1.6, "row": randi() % 8, "time": 0.0})
	for note in _notes:
		note["position"] += Vector2(4, -22) * dt
		note["life"] -= dt
		note["time"] += dt
	_notes = _notes.filter(func(note: Dictionary): return note["life"] > 0)
	queue_redraw()

func _draw() -> void:
	if principal:
		var y = -122.0 if _native_sprite else -59.0
		draw_colored_polygon(PackedVector2Array([Vector2(-4, y - 5), Vector2(4, y - 5), Vector2(0, y)]), Color("ffd166") if _art_id == "producer" else Color("80ed99"))
	if _note_atlas:
		for note in _notes:
			var frame = int(note["time"] * 8) % 6
			draw_texture_rect_region(_note_atlas, Rect2(note["position"], Vector2(24, 24)), Rect2(frame * 24, int(note["row"]) * 24, 24, 24), Color(1, 1, 1, minf(1.0, note["life"])))
