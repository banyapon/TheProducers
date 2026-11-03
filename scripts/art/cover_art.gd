class_name CoverArt
extends RefCounted
## Assigned-cast 1:1 covers; the original procedural generator remains for legacy saves.

const SIZE := 256
const ALBUM_SIZE := 512

static func cast_for(song: Dictionary) -> Array:
	# Snapshot on release: staff leaving or a new career cannot change the cover.
	if song.has("cover_cast"): return song["cover_cast"]
	var cast: Array = []
	for id in song.get("team", []):
		var member = Game.get_artist(str(id))
		if not member.is_empty(): cast.append({"id": id, "name": member.get("name", ""), "art_id": Art.model_id(member)})
	song["cover_cast"] = cast
	return cast

static func build_song_canvas(song: Dictionary) -> Control:
	var canvas = Control.new()
	canvas.size = Vector2(ALBUM_SIZE, ALBUM_SIZE)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var background = ColorRect.new()
	background.color = Color("172335")
	background.size = canvas.size
	canvas.add_child(background)
	var cast = cast_for(song)
	var rows = maxi(1, int(round(sqrt(cast.size()))))
	var index = 0
	for row in rows:
		var count = ceili(float(cast.size() - index) / (rows - row))
		for col in count:
			var cell = Control.new()
			cell.position = Vector2(float(col) * ALBUM_SIZE / count, float(row) * ALBUM_SIZE / rows)
			cell.size = Vector2(float(ALBUM_SIZE) / count, float(ALBUM_SIZE) / rows)
			cell.clip_contents = true
			canvas.add_child(cell)
			var tint = ColorRect.new()
			tint.color = Color.from_hsv(fmod(float(int(song.get("cover_seed", 0)) % 360) / 360.0 + index * 0.13, 1.0), 0.45, 0.45)
			tint.size = cell.size
			cell.add_child(tint)
			var portrait = TextureRect.new()
			portrait.name = "CastPortrait%d" % index
			portrait.texture = Art.portrait(str(cast[index]["art_id"]), 0)
			portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			portrait.size = cell.size
			cell.add_child(portrait)
			index += 1
	var title_back = ColorRect.new()
	title_back.color = Color(0.025, 0.035, 0.065, 0.58)
	title_back.position = Vector2(0, 326)
	title_back.size = Vector2(ALBUM_SIZE, 186)
	canvas.add_child(title_back)
	var title = Label.new()
	title.name = "CoverTitle"
	title.text = str(song.get("title", ""))
	title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	title.position = Vector2(24, 338)
	title.size = Vector2(464, 160)
	title.add_theme_font_override("font", UIKit.readable_font())
	title.add_theme_color_override("font_color", Color("fff1d6"))
	title.add_theme_color_override("font_outline_color", Color("101622"))
	title.add_theme_constant_override("outline_size", 4)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.max_lines_visible = 3
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.clip_text = true
	canvas.add_child(title)
	for font_size in range(52, 17, -2):
		title.add_theme_font_size_override("font_size", font_size)
		if title.get_line_count() <= 3 and title.get_line_height() * mini(3, title.get_line_count()) <= 160: break
	return canvas

static func generate_song(song: Dictionary, owner: Node) -> Image:
	var viewport = SubViewport.new()
	viewport.size = Vector2i(ALBUM_SIZE, ALBUM_SIZE)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	owner.add_child(viewport)
	viewport.add_child(build_song_canvas(song))
	await RenderingServer.frame_post_draw
	var result = viewport.get_texture().get_image()
	viewport.queue_free()
	return result


static func generate(colors: Array, seed_value: int) -> Image:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	var palette: Array = colors.duplicate()
	while palette.size() < 3:
		palette.append(Color.from_hsv(rng.randf(), rng.randf_range(0.5, 0.9), rng.randf_range(0.7, 1.0)))
	palette.shuffle()
	var img = Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var top: Color = (palette[0] as Color).darkened(0.7)
	var bottom: Color = (palette[1] as Color).darkened(0.2)
	for y in SIZE:
		img.fill_rect(Rect2i(0, y, SIZE, 1), top.lerp(bottom, float(y) / SIZE))
	match rng.randi() % 4:
		0:
			_circles(img, rng, palette)
		1:
			_stripes(img, rng, palette)
		2:
			_squares(img, rng, palette)
		_:
			_sunset(img, rng, palette)
	_grain(img, rng)
	return img


static func _blend(img: Image, x: int, y: int, color: Color, alpha: float) -> void:
	if x < 0 or y < 0 or x >= SIZE or y >= SIZE:
		return
	img.set_pixel(x, y, img.get_pixel(x, y).lerp(color, alpha))


static func _disc(img: Image, center: Vector2, radius: float, color: Color, alpha: float) -> void:
	for y in range(int(center.y - radius), int(center.y + radius) + 1):
		for x in range(int(center.x - radius), int(center.x + radius) + 1):
			if Vector2(x, y).distance_to(center) <= radius:
				_blend(img, x, y, color, alpha)


static func _circles(img: Image, rng: RandomNumberGenerator, palette: Array) -> void:
	for i in rng.randi_range(3, 7):
		var center = Vector2(rng.randf_range(0, SIZE), rng.randf_range(0, SIZE))
		_disc(img, center, rng.randf_range(20.0, 90.0), palette[rng.randi() % palette.size()], 0.55)


static func _stripes(img: Image, rng: RandomNumberGenerator, palette: Array) -> void:
	var width = rng.randi_range(10, 28)
	var slope = rng.randf_range(-1.5, 1.5)
	var color: Color = palette[2]
	for y in SIZE:
		for x in SIZE:
			if int(floor((x + y * slope) / width)) % 2 == 0:
				_blend(img, x, y, color, 0.35)


static func _squares(img: Image, rng: RandomNumberGenerator, palette: Array) -> void:
	var cell: int = [16, 32, 64][rng.randi() % 3]
	for gy in range(0, SIZE, cell):
		for gx in range(0, SIZE, cell):
			if rng.randf() < 0.35:
				var c: Color = palette[rng.randi() % palette.size()]
				img.fill_rect(Rect2i(gx + 2, gy + 2, cell - 4, cell - 4), c)
	var big = rng.randi_range(70, 120)
	var o = (SIZE - big) / 2
	img.fill_rect(Rect2i(o, o, big, big), (palette[0] as Color).lightened(0.3))


static func _sunset(img: Image, rng: RandomNumberGenerator, palette: Array) -> void:
	var sun: Color = (palette[2] as Color).lightened(0.3)
	var horizon = rng.randi_range(150, 190)
	_disc(img, Vector2(SIZE / 2.0, horizon), rng.randf_range(55.0, 85.0), sun, 0.95)
	for y in range(horizon - 40, horizon, 7):
		img.fill_rect(Rect2i(0, y, SIZE, 3), (palette[0] as Color).darkened(0.6))
	img.fill_rect(Rect2i(0, horizon, SIZE, SIZE - horizon), (palette[0] as Color).darkened(0.8))
	var line: Color = palette[1]
	var y = horizon + 4
	var gap = 4
	while y < SIZE:
		img.fill_rect(Rect2i(0, y, SIZE, 1), line)
		y += gap
		gap += 3


static func _grain(img: Image, rng: RandomNumberGenerator) -> void:
	for i in 5000:
		var x = rng.randi() % SIZE
		var y = rng.randi() % SIZE
		var c = img.get_pixel(x, y)
		img.set_pixel(x, y, c.lightened(0.08) if rng.randf() < 0.5 else c.darkened(0.08))
