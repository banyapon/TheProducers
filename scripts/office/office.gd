class_name Office
extends Node2D
## Side-view office tower (SimTower style). Draws floors and rooms, spawns one 1:1 square per
## signed artist, shows point popups from the studio, and handles camera pan/zoom and clicks.

signal room_clicked(floor_index: int, column: int, room_type: String)
signal worker_clicked(artist_id: String)
signal quest_visitor_clicked(quest_id: String)
signal zoom_changed(value: float)

const ROOM_W := 640.0
const FLOOR_H := 360.0
const SHAFT_W := 120.0
const SLAB := 40.0
const WORKER_SCENE := preload("res://scenes/office/worker.tscn")
const BACKGROUND_TIME_SHADER := preload("res://scripts/art/background_time.gdshader")
const BACKGROUND_CYCLE_SECONDS := 120.0
var _background_elapsed := 0.0
var _background_materials: Dictionary = {}
var _background_shades: Array[Sprite2D] = []

@onready var workers_root: Node2D = $Workers
@onready var fx_root: Node2D = $FX
@onready var camera: Camera2D = $Camera2D

var principals = {}
var foreground: Node2D
var decoration: Node2D
var room_labels: Array[Label] = []
var vip_actor: Worker
var quest_visitor: Worker
var vip_chat_time := 0.0
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
	decoration = Node2D.new()
	decoration.name = "SceneProps"
	add_child(decoration)
	move_child(decoration, 0)
	_build_parallax()
	$Sky/SkyGradient.material = _background_material("Sky")
	_set_background_daylight(_background_daylight())
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
				overlay.draw_texture_rect_region(tex, Rect2(room.position + Vector2(18 + i * 69, 10) * 2.5, Vector2(240, 320)), Rect2(frame * 48, 0, 48, 64))
		overlay.draw_string(_font, room.position + Vector2(10, 30), Locale.text("city_damage", [int(damage["until"]) - Game.day]), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("ffe0a0"))


func _process(delta: float) -> void:
	_tick_background_time(delta)
	_layout_names()
	for label in room_labels:
		var t = get_global_transform_with_canvas()
		label.scale = Vector2(1.0 / maxf(t.x.length(), 0.001), 1.0 / maxf(t.y.length(), 0.001))
	_tick_vip(delta)
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
		# Square treads, dark risers, and a recessed shadow behind the flight.
		for step in range(12):
			var sx = 8.0 + step * 8.0
			var sy = y + FLOOR_H - SLAB - (step + 1) * 25.0
			draw_rect(Rect2(sx + 4, sy + 5, SHAFT_W - sx - 4, 25), Color("151d2a"))
			draw_rect(Rect2(sx, sy, SHAFT_W - sx - 8, 25), Color("465064"))
			draw_rect(Rect2(sx, sy, SHAFT_W - sx - 8, 4), Color("9b9ca6"))
			draw_rect(Rect2(sx, sy + 4, 2, 21), Color("676f80"))
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
	if is_instance_valid(vip_actor): vip_actor.queue_free()
	vip_actor = null
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
	if is_instance_valid(quest_visitor):
		quest_visitor.queue_free()
		quest_visitor = null
	var pending = StoryQuests.pending_visitor()
	if pending != "": spawn_quest_visitor(pending)


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


func spawn_quest_visitor(quest_id: String) -> void:
	var q = StoryQuests.definition(quest_id)
	if q.is_empty(): return
	if is_instance_valid(quest_visitor):
		quest_visitor.queue_free()
		quest_visitor = null
	var npc: Dictionary = q["npc"]
	var w: Worker = WORKER_SCENE.instantiate()
	workers_root.add_child(w)
	w.setup(self, "", StoryQuests.text(npc["name"]), Color("e7b76a"))
	w.configure_art(str(npc["art_id"]))
	w.is_visitor = true
	w.quest_id = quest_id
	w.place(0, building_width() + 220.0)
	var host: Worker = principals.get("producer")
	var x = host.position.x + 84.0 if is_instance_valid(host) else random_x_in_room(0)
	w.go_to(0, clampf(x, shaft_x() + 36.0, building_width() - 36.0))
	quest_visitor = w


func dismiss_quest_visitor() -> void:
	if not is_instance_valid(quest_visitor): return
	var w = quest_visitor
	quest_visitor = null
	w.quest_id = ""
	w.leave()


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
		var guest = child as Worker
		if guest and guest.quest_id != "" and guest.hit_test(pos):
			quest_visitor_clicked.emit(guest.quest_id)
			return
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
	var steps = [0.25,0.5,1.0,2.0,3.0,4.0]
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
	camera.zoom = Vector2.ONE * clampf(value,0.25,4.0)
	camera.position = camera.position.round()
	zoom_changed.emit(camera.zoom.x)

func _cancel_wheel_zoom() -> void:
	_wheel_active = false
	_wheel_velocity = 0.0

func _scroll_zoom(amount: float) -> void:
	if not _wheel_active:
		_wheel_target = log(camera.zoom.x)
		_wheel_velocity = 0.0
	_wheel_target = clampf(_wheel_target + amount * WHEEL_STEP, log(0.25), log(4.0))
	_wheel_active = true

func _tick_wheel_zoom(delta: float) -> void:
	if not _wheel_active: return
	# Exact critically damped integration in log space gives the same feel at any FPS.
	var error = log(camera.zoom.x) - _wheel_target
	var decay = exp(-ZOOM_DAMPING * delta)
	var travel = (_wheel_velocity + ZOOM_DAMPING * error) * delta
	var next_error = (error + travel) * decay
	_wheel_velocity = (_wheel_velocity - ZOOM_DAMPING * travel) * decay
	var value = clampf(exp(_wheel_target + next_error), 0.25, 4.0)
	if absf(next_error) < 0.0001 and absf(_wheel_velocity) < 0.001:
		value = exp(_wheel_target)
		_cancel_wheel_zoom()
	camera.zoom = Vector2.ONE * value
	zoom_changed.emit(value)


func _clamp_camera() -> void:
	var top = -floor_count() * FLOOR_H
	camera.position.x = clampf(camera.position.x, -600.0, building_width() + 600.0)
	camera.position.y = clampf(camera.position.y, top - 300.0, 200.0)


func _frame_building() -> void:
	_cancel_wheel_zoom()
	# Building + roof sign must fit between the HUD's top and bottom bars.
	var height = floor_count() * FLOOR_H + 130.0
	var fit = minf(1800.0 / building_width(), 780.0 / height)
	var z = clampf(floorf(fit * 20.0) / 20.0, 0.25, 2.0)
	camera.zoom = Vector2(z, z)
	zoom_changed.emit(z)
	camera.position = Vector2(building_width() * 0.5, -height * 0.5 + 30.0)

func _refresh_rooms() -> void:
	for label in room_labels: label.queue_free()
	room_labels.clear()
	UIKit.clear(foreground)
	for f in floor_count():
		for c in column_count():
			var label = Label.new()
			label.text = Data.ROOM_TYPES[Game.floors[f][c]]["name"]
			label.position = room_rect(f, c).position + Vector2(16, 16)
			label.add_theme_font_size_override("font_size", 36)
			label.add_theme_color_override("font_outline_color", Color("101823"))
			label.add_theme_constant_override("outline_size", 6)
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.z_index = 21
			add_child(label)
			room_labels.append(label)
			var art = Art.room(Game.floors[f][c], true) if Game.floors[f][c] != "empty" else null
			if art:
				var sprite = Sprite2D.new()
				sprite.texture = art
				sprite.centered = false
				sprite.scale = Vector2(ROOM_W, FLOOR_H) / art.get_size()
				sprite.position = room_rect(f, c).position
				foreground.add_child(sprite)
	_refresh_props()
	queue_redraw()

func _build_parallax() -> void:
	# A 512px strip becomes one seamless 2048-world-unit repeat at 4x pixel scale.
	# Keep the skyline grounded vertically; horizontal camera travel adds depth.
	_add_background_layer("Buildings 4", 0.10, 2.0, -330.0, -14)
	var distant = _add_background_layer("Buildings 3", 0.20, 3.5, -210.0, -13)
	_add_background_sprite(distant, "Shade 3", Vector2(0, -210))
	var middle = _add_background_layer("Buildings 2", 0.34, 5.0, -90.0, -12)
	_add_background_sprite(middle, "Shade 2", Vector2(0, -90))
	_add_background_layer("Buildings 1", 0.50, 7.0, 0.0, -11)
	var clouds = _add_background_layer("Tiny Cloud", 0.06, 9.0, -1000.0, -15)
	clouds.scroll_scale.y = 0.65
	_add_background_sprite(clouds, "Tiny Cloud 2", Vector2(720, -860))
	_add_background_sprite(clouds, "Tiny Cloud", Vector2(1400, -1120))
	_resize_background_repeats()
	get_viewport().size_changed.connect(_resize_background_repeats)


func _add_background_layer(asset: String, depth: float, speed: float, ground: float, order: int) -> Parallax2D:
	var parallax = Parallax2D.new()
	parallax.name = asset.replace(" ", "") + "Parallax"
	parallax.scroll_scale = Vector2(depth, 1.0)
	parallax.repeat_size = Vector2(2048, 0)
	parallax.autoscroll = Vector2(-speed, 0)
	parallax.z_index = order
	add_child(parallax)
	_add_background_sprite(parallax, asset, Vector2(0, ground))
	return parallax


func _add_background_sprite(layer: Parallax2D, asset: String, ground: Vector2) -> void:
	var texture = Art.texture("res://assets/props/outside/bg/%s.png" % asset)
	if texture == null: return
	var sprite = Sprite2D.new()
	sprite.centered = false
	sprite.texture = texture
	if asset.begins_with("Shade"):
		_background_shades.append(sprite)
	else:
		sprite.material = _background_material(asset)
	sprite.scale = Vector2.ONE * 4.0
	sprite.position = ground - Vector2(0, texture.get_height() * 4.0)
	layer.add_child(sprite)


func _background_material(asset: String) -> ShaderMaterial:
	if _background_materials.has(asset): return _background_materials[asset]
	var material = ShaderMaterial.new()
	material.shader = BACKGROUND_TIME_SHADER
	material.set_shader_parameter("day_texture", Art.texture("res://assets/props/outside/bg/day/%s.png" % asset))
	_background_materials[asset] = material
	return material


func _set_background_daylight(amount: float) -> void:
	for material in _background_materials.values():
		material.set_shader_parameter("daylight", amount)
	# The day pack has no haze strips; fade the night haze out with its skyline.
	for sprite in _background_shades:
		sprite.modulate.a = 1.0 - amount


func _tick_background_time(delta: float) -> void:
	if not Game.running or Game.is_paused() or Game.tutorial_gate: return
	# Ambient time is real play time: game speed does not shorten the two-minute cycle.
	_background_elapsed = fposmod(_background_elapsed + delta, BACKGROUND_CYCLE_SECONDS)
	_set_background_daylight(_background_daylight())


func _background_daylight() -> float:
	# Day 0–50s, sunset 50–60s, night 60–110s, sunrise 110–120s.
	if _background_elapsed < 50.0: return 1.0
	if _background_elapsed < 60.0: return 1.0 - smoothstep(50.0, 60.0, _background_elapsed)
	if _background_elapsed < 110.0: return 0.0
	return smoothstep(110.0, BACKGROUND_CYCLE_SECONDS, _background_elapsed)


func _resize_background_repeats() -> void:
	# Cover the widest view at the minimum supported zoom, including both edges.
	for child in get_children():
		if child is Parallax2D:
			child.repeat_times = ceili(get_viewport_rect().size.x / (0.25 * child.repeat_size.x)) + 2


func meeting_ready() -> bool:
	if Game.idea_meeting.is_empty(): return false
	for id in Game.idea_meeting["participants"]:
		var actor: Worker = principals.get(id, workers.get(id))
		if actor == null or actor.state == Worker.State.WALK or not is_in_room(actor.position, actor.floor_index, "lounge"): return false
	return true


func _refresh_props() -> void:
	if not is_instance_valid(decoration): return
	for child in decoration.get_children():
		decoration.remove_child(child)
		child.queue_free()
	var plants = ["plant-monstera", "plant-snake-plant", "plant-rubber-plant", "plant-areca-palm", "plant-lotus-pot", "plant-bonsai"]
	for f in floor_count():
		for col in column_count():
			var kind = str(Game.floors[f][col])
			if kind == "empty": continue
			var rng = RandomNumberGenerator.new()
			rng.seed = hash(str(Game.save_slot) + Game.studio_name + ":%d:%d:%s" % [f, col, kind])
			var origin = room_rect(f, col).position.x
			var floor_line = floor_y(f)
			_add_prop(plants[rng.randi_range(0, plants.size()-1)], Vector2(origin + 528, floor_line))
			if kind in ["lounge", "lobby"]:
				_add_prop(["arcade-fighter", "arcade-rhythm"][rng.randi_range(0,1)], Vector2(origin + 350, floor_line))
			elif kind == "cafeteria":
				_add_prop("wood-bar-front", Vector2(origin + 340, floor_line))
	var outside_rng = RandomNumberGenerator.new()
	outside_rng.seed = hash(str(Game.save_slot) + Game.studio_name + ":outside")
	_add_prop("thai-taxi-green-yellow", Vector2(-145, 0))
	_add_prop("8-12-convenience-store", Vector2(building_width()+180, 0))
	_add_prop("thai-power-pole", Vector2(-310, 0))
	var trees = ["rain-tree", "banana-tree", "coconut-palm"]
	_add_prop(trees[outside_rng.randi_range(0,2)], Vector2(-430, 0))
	_add_prop(trees[outside_rng.randi_range(0,2)], Vector2(building_width()+410, 0))

func _add_prop(id: String, ground: Vector2) -> void:
	var prop = SceneProp.new()
	if not prop.configure(id):
		prop.free()
		return
	prop.name = id.validate_node_name()
	prop.position = ground
	decoration.add_child(prop)


func _tick_vip(delta: float) -> void:
	if StudioCity.fire_active() or not Game.idea_meeting.is_empty() or Game.is_researching("producer"):
		_suspend_vip()
		return
	if not Game.running or Game.is_paused() or StudioCity.fire_active(): return
	var pending: Dictionary = Game.life.get("vip_appointment", {})
	if pending.is_empty(): return
	var client = Game.get_client(str(pending.get("client", "")))
	if client.is_empty():
		Game.life["vip_appointment"] = {}
		return
	var rooms = find_rooms("office") + find_rooms("meeting")
	if rooms.is_empty() or not Game.idea_meeting.is_empty() or Game.is_researching("producer"): return
	var host: Worker = principals.get("producer")
	if not is_instance_valid(host): return
	if not is_instance_valid(vip_actor):
		var room: Vector2i = rooms[0]
		vip_actor = WORKER_SCENE.instantiate()
		workers_root.add_child(vip_actor)
		vip_actor.setup(self, "", Game.client_contact(client), client.get("color", Color.WHITE))
		vip_actor.configure_art(Art.model_id(client))
		vip_actor.is_visitor = true
		vip_actor.appointment = true
		vip_actor.place(0, building_width() + 200.0)
		var x = room_rect(room.x, room.y).position.x + ROOM_W * 0.5
		vip_actor.go_to(room.x, x + 55)
		host.appointment = true
		host.go_to(room.x, x - 55)
		vip_chat_time = 0.0
	if vip_actor.state == Worker.State.WALK or host.state == Worker.State.WALK: return
	if vip_chat_time == 0.0:
		vip_actor.start_chat(20)
		host.start_chat(20)
	vip_chat_time += delta * Game.speed
	if vip_chat_time < 4.0: return
	VipOffice.complete()
	host.appointment = false
	host._end_chat()
	vip_actor.appointment = false
	vip_actor.leave()
	vip_actor = null

func _suspend_vip() -> void:
	if not is_instance_valid(vip_actor): return
	vip_actor.queue_free()
	vip_actor = null
	var host: Worker = principals.get("producer")
	if is_instance_valid(host): host.appointment = false
	vip_chat_time = 0.0

func _layout_names() -> void:
	var occupied: Array[Rect2] = []
	for actor in workers_root.get_children():
		if not actor is Worker or not actor.visible: continue
		actor.name_lane = 0
		actor._update_name_scale()
		for lane in range(8):
			actor.name_lane = lane
			actor._update_name_scale()
			var label: Label = actor.name_label
			var rect = label.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, label.size)
			var overlaps = false
			for other in occupied:
				if rect.intersects(other): overlaps = true; break
			if not overlaps:
				occupied.append(rect.grow(3))
				break
