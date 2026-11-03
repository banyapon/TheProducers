class_name Office
extends Node2D
## Side-view office tower (SimTower style). Draws floors and rooms, spawns one 1:1 square per
## signed artist, shows point popups from the studio, and handles camera pan/zoom and clicks.

signal room_clicked(floor_index: int, column: int, room_type: String)
signal worker_clicked(artist_id: String)
signal zoom_changed(value: float)

const ROOM_W := 256.0
const FLOOR_H := 144.0
const SHAFT_W := 48.0
const SLAB := 16.0
const WORKER_SCENE := preload("res://scenes/office/worker.tscn")

@onready var workers_root: Node2D = $Workers
@onready var fx_root: Node2D = $FX
@onready var camera: Camera2D = $Camera2D

var principals = {}
var foreground: Node2D
var workers = {}  ## artist_id -> Worker
var _font: Font
var _pressed = false
var _dragging = false
var _press_pos = Vector2.ZERO
var _wheel_active := false
var _wheel_target := 0.0
var _wheel_velocity := 0.0
const WHEEL_STEP := 0.065
const ZOOM_DAMPING := 12.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	foreground = Node2D.new()
	foreground.z_index = 5
	add_child(foreground)
	_build_parallax()
	Locale.language_changed.connect(func(_lang: String): queue_redraw())
	var project_theme = ThemeDB.get_project_theme()
	_font = project_theme.default_font if project_theme and project_theme.default_font else ThemeDB.fallback_font
	Game.state_loaded.connect(_on_state_loaded)
	Game.building_changed.connect(_refresh_rooms)
	Game.building_changed.connect(_frame_building)
	Game.building_changed.connect(_refresh_work_mode)
	Game.staff_changed.connect(_sync_workers)
	Game.research_changed.connect(_refresh_work_mode)
	Game.meeting_changed.connect(_refresh_work_mode)
	Game.project_started.connect(_on_project_changed.unbind(1))
	Game.project_completed.connect(_on_project_changed.unbind(1))
	Game.project_ended.connect(_on_project_changed)
	Game.points_generated.connect(_on_points_generated)
	var fire_overlay = Node2D.new()
	fire_overlay.name = "FireOverlay"
	fire_overlay.z_index = 10
	add_child(fire_overlay)
	fire_overlay.draw.connect(_draw_fire.bind(fire_overlay))
	var fire_timer = Timer.new()
	fire_timer.wait_time = 0.12
	fire_timer.autostart = true
	fire_timer.timeout.connect(fire_overlay.queue_redraw)
	fire_overlay.add_child(fire_timer)

func _draw_fire(overlay: Node2D) -> void:
	for damage in Game.life.get("city", {}).get("damage", []):
		if Game.day >= int(damage["until"]): continue
		var room = room_rect(int(damage["floor"]), int(damage["column"]))
		overlay.draw_rect(room, Color(0.12, 0.05, 0.03, 0.45))
		for i in 3:
			var tex = Art.texture("res://assets/city/fire-%d.png" % (i + 1))
			if tex:
				var frame = (int(Time.get_ticks_msec() / 120) + i * 2) % 6
				overlay.draw_texture_rect_region(tex, Rect2(room.position + Vector2(18 + i * 69, 10), Vector2(96, 128)), Rect2(frame * 48, 0, 48, 64))
		overlay.draw_string(_font, room.position + Vector2(10, 30), Locale.text("city_damage", [int(damage["until"]) - Game.day]), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("ffe0a0"))


func _process(delta: float) -> void:
	if not Game.running or Game.is_paused():
		_cancel_wheel_zoom()
		return
	_tick_wheel_zoom(delta)
	var dir = Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		dir.x += 1
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		dir.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		dir.y += 1
	if dir != Vector2.ZERO:
		camera.position += dir * 700.0 * delta / camera.zoom.x
		_clamp_camera()


# --- geometry helpers used by Worker --------------------------------------------

func floor_count() -> int:
	return Game.floors.size()


func column_count() -> int:
	return Game.column_count()


func building_width() -> float:
	return SHAFT_W + column_count() * ROOM_W


func floor_y(f: int) -> float:
	return -f * FLOOR_H - SLAB


func shaft_x() -> float:
	return SHAFT_W * 0.5


func room_rect(f: int, c: int) -> Rect2:
	return Rect2(SHAFT_W + c * ROOM_W, -(f + 1) * FLOOR_H, ROOM_W, FLOOR_H)


func random_x() -> float:
	return randf_range(SHAFT_W + 20.0, building_width() - 20.0)


func random_x_in_room(c: int) -> float:
	var r = room_rect(0, c)
	return randf_range(r.position.x + 24.0, r.end.x - 24.0)


func find_rooms(type: String) -> Array:
	var out = []
	for f in floor_count():
		for c in column_count():
			if Game.floors[f][c] == type:
				out.append(Vector2i(f, c))
	return out


func is_in_room(pos: Vector2, f: int, type: String) -> bool:
	var c = floori((pos.x - SHAFT_W) / ROOM_W)
	return f >= 0 and f < floor_count() and c >= 0 and c < column_count() and Game.floors[f][c] == type


# --- drawing ------------------------------------------------------------------

func _draw() -> void:
	if Game.floors.is_empty():
		return
	var width = building_width()
	draw_rect(Rect2(-3000, 0, width + 6000, 800), Color("344e41"))
	draw_rect(Rect2(-3000, 0, width + 6000, 10), Color("588157"))
	draw_rect(Rect2(width, -12, 400, 12), Color("adb5bd"))  # sidewalk to the entrance
	for f in floor_count():
		var y = -(f + 1) * FLOOR_H
		draw_rect(Rect2(0, y, SHAFT_W, FLOOR_H), Color("22223b"))
		draw_line(Vector2(12, y + FLOOR_H), Vector2(SHAFT_W - 12, y + 10), Color("9a8c98"), 4)
		for i in 6:
			var p = Vector2(12, y + FLOOR_H).lerp(Vector2(SHAFT_W - 12, y + 10), i / 6.0)
			draw_line(p, p + Vector2(12, 0), Color("c9ada7"), 3)
		for c in column_count():
			var r = room_rect(f, c)
			var type: String = Game.floors[f][c]
			var info: Dictionary = Data.ROOM_TYPES[type]
			var art = Art.room(type) if type != "empty" else null
			if art: draw_texture_rect(art, r, false)
			else:
				draw_rect(r, info["color"])
				_draw_room_details(type, r)
			draw_rect(r, Color(0, 0, 0, 0.55), false, 4.0)
			draw_string(_font, r.position + Vector2(6, 16), info["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.85))
		draw_rect(Rect2(0, y + FLOOR_H - SLAB, width, SLAB), Color("1b1b1e"))
		draw_string(_font, Vector2(8, y + 22), "%dF" % (f + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.6))
	var top = -floor_count() * FLOOR_H
	draw_rect(Rect2(-10, top - 18, width + 20, 18), Color("3d405b"))
	_draw_roof_sign(top, width)


func _draw_roof_sign(top: float, width: float) -> void:
	var title = Locale.display_game_text(Game.studio_name)
	var font_size = 64
	var available_width = width - 40.0
	while font_size > 16 and _font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > available_width:
		font_size -= 1
	var text_width = _font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var left = 12.0
	var baseline = top - 46.0
	var rail_y = baseline + 5.0
	# Steel posts and feet connect the lettering to the rooftop.
	for fraction in [0.18, 0.82]:
		var x = floorf(left + text_width * fraction)
		draw_rect(Rect2(x - 5, rail_y, 10, top - 18 - rail_y), Color("101018"))
		draw_rect(Rect2(x - 2, rail_y + 2, 3, top - 20 - rail_y), Color("747b89"))
		draw_rect(Rect2(x - 11, top - 22, 22, 4), Color("101018"))
	draw_rect(Rect2(left - 4, rail_y - 3, text_width + 8, 6), Color("101018"))
	var origin = Vector2(left, baseline)
	draw_string_outline(_font, origin, title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, Color("08090d"))
	draw_string(_font, origin, title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("ffda38"))


func _draw_room_details(type: String, r: Rect2) -> void:
	var ground = r.end.y
	match type:
		"lobby":
			draw_rect(Rect2(r.position.x + 30, ground - 40, 90, 40), Color("adb5bd"))
			draw_rect(Rect2(r.end.x - 50, ground - 100, 40, 100), Color("343a40"))
			draw_circle(Vector2(r.end.x - 18, ground - 50), 3, Color("ffd166"))
		"office":
			for i in 2:
				var x = r.position.x + 40 + i * 110
				draw_rect(Rect2(x, ground - 34, 70, 8), Color("dda15e"))
				draw_rect(Rect2(x + 22, ground - 60, 28, 22), Color("1d3557"))
				draw_rect(Rect2(x + 6, ground - 26, 6, 26), Color("bc6c25"))
				draw_rect(Rect2(x + 58, ground - 26, 6, 26), Color("bc6c25"))
		"lounge":
			draw_rect(Rect2(r.position.x + 40, ground - 30, 120, 30), Color("cdb4db"))
			draw_rect(Rect2(r.position.x + 40, ground - 52, 120, 22), Color("b5838d"))
			draw_circle(Vector2(r.end.x - 40, ground - 54), 22, Color("2d6a4f"))
			draw_rect(Rect2(r.end.x - 50, ground - 32, 20, 32), Color("6f4518"))
		"studio":
			draw_rect(Rect2(r.position.x + 20, ground - 46, 110, 46), Color("343a40"))
			for i in 6:
				draw_rect(Rect2(r.position.x + 28 + i * 16, ground - 40, 8, 4), Color("ffbe0b"))
			draw_rect(Rect2(r.position.x + 140, r.position.y + 40, 6, r.size.y - 40), Color(0.7, 0.85, 1.0, 0.5))
			draw_line(Vector2(r.end.x - 60, ground), Vector2(r.end.x - 60, ground - 70), Color("adb5bd"), 3)
			draw_circle(Vector2(r.end.x - 60, ground - 74), 8, Color("6c757d"))
			var on_air: bool = not Game.project.is_empty() and not Game.project["done"]
			var air_rect = Rect2(r.end.x - 92, r.position.y + 44, 90, 32)
			draw_rect(air_rect, Color("ff006e") if on_air else Color("3a0ca3").darkened(0.5))
			draw_string(_font, air_rect.position + Vector2(9, 26), "ON AIR", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE if on_air else Color(1, 1, 1, 0.3))
		"empty":
			var center = r.get_center()
			draw_line(center - Vector2(18, 0), center + Vector2(18, 0), Color(1, 1, 1, 0.25), 4)
			draw_line(center - Vector2(0, 18), center + Vector2(0, 18), Color(1, 1, 1, 0.25), 4)


# --- workers --------------------------------------------------------------------

func _on_state_loaded() -> void:
	for principal in principals.values(): principal.queue_free()
	principals.clear()
	for id in ["producer", "alice"]:
		var actor: Worker = WORKER_SCENE.instantiate()
		workers_root.add_child(actor)
		actor.setup(self, id, Game.producer_name if id == "producer" else Game.assistant_portrait()["name"], Color.WHITE)
		actor.configure_art(Game.player_character if id == "producer" else Game.assistant_portrait()["art_id"], true)
		actor.place(0, SHAFT_W + (80 if id == "producer" else 170))
		principals[id] = actor
	_refresh_rooms()
	for id in workers:
		workers[id].queue_free()
	workers.clear()
	for a in Game.staff:
		var w = _spawn(a)
		w.place(randi() % floor_count(), random_x())
	_refresh_work_mode()
	queue_redraw()
	_frame_building()


func _sync_workers() -> void:
	var alive = {}
	for a in Game.staff:
		alive[a["id"]] = true
		if not workers.has(a["id"]):
			var w = _spawn(a)
			w.place(0, building_width() + 120.0)
			w.go_to(0, random_x_in_room(0))
	for id in workers.keys():
		if not alive.has(id):
			workers[id].leave()
			workers.erase(id)
	_refresh_work_mode()


func _spawn(artist: Dictionary) -> Worker:
	var w: Worker = WORKER_SCENE.instantiate()
	workers_root.add_child(w)
	w.setup(self, artist["id"], artist["name"], artist["color"])
	w.configure_art(Art.model_id(artist))
	workers[artist["id"]] = w
	return w


func spawn_visitor(color: Color, display_name: String, profile: Dictionary = {}) -> void:
	var w: Worker = WORKER_SCENE.instantiate()
	workers_root.add_child(w)
	w.setup(self, "", display_name, color)
	w.configure_art(Art.model_id(profile))
	w.is_visitor = true
	w.place(0, building_width() + 200.0)
	w.go_to(0, random_x_in_room(0))


func _on_project_changed() -> void:
	_refresh_work_mode()
	queue_redraw()


## Work mode: team members of an unfinished project walk to the studio and jam.
func _refresh_work_mode() -> void:
	var studios = find_rooms("studio")
	for id in workers:
		workers[id].visible = StudioLife.training(id).is_empty() and not StudioStars.busy(id)
		var session = Game.artist_project(id)
		var active = not StudioCity.fire_active() and not session.is_empty() and not session["done"]
		if active and not studios.is_empty(): workers[id].assigned_room = studios[int(session.get("room", 0)) % studios.size()]
		workers[id].set_working(active)
	for id in workers:
		workers[id].set_researching(Game.is_researching(id))
	for id in principals:
		principals[id].set_researching(Game.is_researching(id))
	var participants: Array = Game.idea_meeting.get("participants", [])
	var lounges = find_rooms("lounge")
	for index in participants.size():
		var id = participants[index]
		var actor: Worker = principals.get(id, workers.get(id))
		if actor and not lounges.is_empty():
			var room: Vector2i = lounges[0]
			actor.gathering = true
			actor.gather_room = room
			actor.go_to(room.x, SHAFT_W + room.y * ROOM_W + 20 + (index + 1) * (ROOM_W - 40) / (participants.size() + 1))
	for actor in workers.values() + principals.values():
		if actor.artist_id not in participants: actor.gathering = false


func _on_points_generated(artist_id: String, category: String, amount: int) -> void:
	var w: Worker = workers.get(artist_id)
	if w == null:
		return
	var label = Label.new()
	label.text = "+%d %s" % [amount, Data.POINT_TH[category]]
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Data.POINT_COLORS[category])
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	label.position = w.position + Vector2(-30, -80)
	fx_root.add_child(label)
	var tw = label.create_tween().set_parallel()
	tw.tween_property(label, "position:y", label.position.y - 30.0, 1.2)
	tw.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.4)
	tw.chain().tween_callback(label.queue_free)


# --- camera & clicks --------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not Game.running or Game.is_paused():
		_pressed = false
		return
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll_zoom(clampf(mb.factor, 0.1, 3.0))
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_zoom(-clampf(mb.factor, 0.1, 3.0))
		elif mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			if mb.pressed:
				_pressed = true
				_dragging = false
				_press_pos = mb.position
			else:
				if _pressed and not _dragging and mb.button_index == MOUSE_BUTTON_LEFT:
					_click(get_global_mouse_position())
				_pressed = false
	elif event is InputEventMouseMotion and _pressed:
		var mm = event as InputEventMouseMotion
		if not _dragging and mm.position.distance_to(_press_pos) > 8.0:
			_dragging = true
		if _dragging:
			camera.position -= mm.relative / camera.zoom.x
			_clamp_camera()


func _click(pos: Vector2) -> void:
	for child in workers_root.get_children():
		var w = child as Worker
		if w and not w.is_visitor and w.artist_id != "" and w.hit_test(pos):
			worker_clicked.emit(w.artist_id)
			return
	var c = floori((pos.x - SHAFT_W) / ROOM_W)
	var f = floori(-pos.y / FLOOR_H)
	if f >= 0 and f < floor_count() and c >= 0 and c < column_count():
		room_clicked.emit(f, c, Game.floors[f][c])


func _zoom(factor: float) -> void:
	_cancel_wheel_zoom()
	var steps = [0.5,1.0,2.0,3.0,4.0]
	var value = camera.zoom.x
	if factor > 1.0:
		for step in steps:
			if step > value + 0.01:
				value = step
				break
	else:
		for index in range(steps.size()-1,-1,-1):
			if steps[index] < value - 0.01:
				value = steps[index]
				break
	camera.zoom = Vector2.ONE * clampf(value,0.5,4.0)
	camera.position = camera.position.round()
	zoom_changed.emit(camera.zoom.x)

func _cancel_wheel_zoom() -> void:
	_wheel_active = false
	_wheel_velocity = 0.0

func _scroll_zoom(amount: float) -> void:
	if not _wheel_active:
		_wheel_target = log(camera.zoom.x)
		_wheel_velocity = 0.0
	_wheel_target = clampf(_wheel_target + amount * WHEEL_STEP, log(0.5), log(4.0))
	_wheel_active = true

func _tick_wheel_zoom(delta: float) -> void:
	if not _wheel_active: return
	# Exact critically damped integration in log space gives the same feel at any FPS.
	var error = log(camera.zoom.x) - _wheel_target
	var decay = exp(-ZOOM_DAMPING * delta)
	var travel = (_wheel_velocity + ZOOM_DAMPING * error) * delta
	var next_error = (error + travel) * decay
	_wheel_velocity = (_wheel_velocity - ZOOM_DAMPING * travel) * decay
	var value = clampf(exp(_wheel_target + next_error), 0.5, 4.0)
	if absf(next_error) < 0.0001 and absf(_wheel_velocity) < 0.001:
		value = exp(_wheel_target)
		_cancel_wheel_zoom()
	camera.zoom = Vector2.ONE * value
	zoom_changed.emit(value)


func _clamp_camera() -> void:
	var top = -floor_count() * FLOOR_H
	camera.position.x = clampf(camera.position.x, -300.0, building_width() + 300.0)
	camera.position.y = clampf(camera.position.y, top - 300.0, 200.0)


func _frame_building() -> void:
	_cancel_wheel_zoom()
	# Building + roof sign must fit between the HUD's top and bottom bars.
	var height = floor_count() * FLOOR_H + 130.0
	var fit = minf(1800.0 / building_width(), 780.0 / height)
	var z = clampf(floorf(fit) if fit >= 1.0 else floorf(fit * 2.0) / 2.0, 0.5, 2.0)
	camera.zoom = Vector2(z, z)
	zoom_changed.emit(z)
	camera.position = Vector2(building_width() * 0.5, -height * 0.5 + 30.0)

func _refresh_rooms() -> void:
	UIKit.clear(foreground)
	for f in floor_count():
		for c in column_count():
			var art = Art.room(Game.floors[f][c], true) if Game.floors[f][c] != "empty" else null
			if art:
				var sprite = Sprite2D.new()
				sprite.texture = art
				sprite.centered = false
				sprite.position = room_rect(f, c).position
				foreground.add_child(sprite)
	queue_redraw()

func _build_parallax() -> void:
	for i in 3:
		var parallax = Parallax2D.new()
		parallax.scroll_scale = Vector2([0.12, 0.32, 0.55][i], 1.0)
		parallax.repeat_size = Vector2(512, 0)
		parallax.repeat_times = 8
		parallax.z_index = -10 + i
		add_child(parallax)
		var sprite = Sprite2D.new()
		sprite.centered = false
		sprite.position = Vector2(-512, -288)
		sprite.texture = Art.texture("res://assets/lots/backgrounds/city-%s-16x9.png" % ["far", "mid", "trees"][i])
		parallax.add_child(sprite)


func meeting_ready() -> bool:
	if Game.idea_meeting.is_empty(): return false
	for id in Game.idea_meeting["participants"]:
		var actor: Worker = principals.get(id, workers.get(id))
		if actor == null or actor.state == Worker.State.WALK or not is_in_room(actor.position, actor.floor_index, "lounge"): return false
	return true
