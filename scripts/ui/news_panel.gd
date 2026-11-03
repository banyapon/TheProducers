class_name NewsPanel
extends UIPanel
var event: Dictionary = {}
var message := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	texture_filter = TEXTURE_FILTER_NEAREST
	super()
	Locale.language_changed.connect(_refresh_if_open.unbind(1))

func refresh() -> void:
	UIKit.clear(self)
	var body = UIKit.centered_window(self, 1500, 970)
	var title = UIKit.label("Hot News!", 64)
	title.modulate = Color("ff7777")
	body.add_child(title)
	var headline = UIKit.label(Locale.text("stars_headline_%d" % int(event["kind"]), [event["name"]]), 46)
	headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(headline)
	var art = TextureRect.new()
	art.texture = Art.texture("res://assets/story/hot-news.png")
	art.custom_minimum_size = Vector2(1000, 360)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	body.add_child(art)
	var report = UIKit.label(message if not message.is_empty() else Locale.text("stars_news_report"), 30)
	report.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(report)
	if not event in StudioStars.data()["news"]:
		body.add_child(UIKit.button(Locale.text("close"), close))
		return
	body.add_child(UIKit.label(Locale.text("news_evidence_%d" % int(event["kind"])), 28))
	for i in 3:
		body.add_child(UIKit.button(StudioStars.news_choice(event, i), func():
			message = StudioStars.resolve_news(event["id"], i)
			refresh()))
