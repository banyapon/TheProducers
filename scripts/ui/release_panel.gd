extends UIPanel
## Shown when recording finishes: score breakdown, 4 critics (Game Dev Story style review),
## then the player picks a marketing campaign which releases the song.

signal released(song: Dictionary)

@onready var title_label: Label = %TitleLabel
@onready var breakdown: Label = %Breakdown
@onready var critics_box: HBoxContainer = %Critics
@onready var total_label: Label = %Total
@onready var marketing_box: GridContainer = %MarketingBox


func refresh() -> void:
	$Window/Scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var p = Game.project
	if p.is_empty() or not p["done"]:
		return
	var ev: Dictionary = p["eval"]
	var job = Game.get_job(p["job_id"])
	title_label.text = Locale.display_game_text(Locale.text("legacy_287") % p["title"])
	breakdown.text = Locale.text("legacy_288") % [
		ev["closeness"] * 100, ev["mastery"] * 100, ev["craft"] * 100,
		Data.roles_text(ev["missing"]) if not ev["missing"].is_empty() else Locale.text("legacy_289"),
		Data.mix_text(job.get("mix", {})), Data.mix_text(p["mix"])]

	clear(critics_box)
	var i = 0
	for critic in ev["critics"]:
		var card = VBoxContainer.new()
		card.custom_minimum_size = Vector2(250, 0)
		card.alignment = BoxContainer.ALIGNMENT_CENTER
		var square = PanelContainer.new()
		square.theme_type_variation = "InsetPanel"
		square.custom_minimum_size = Vector2(88, 88)
		square.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var score = Label.new()
		score.text = str(critic["score"])
		score.add_theme_font_size_override("font_size", 64)
		score.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		score.add_theme_color_override("font_color", Color("ffdd87"))
		square.add_child(score)
		card.add_child(square)
		for text in [critic["name"], "\"%s\"" % critic["comment"]]:
			var label = Label.new()
			label.text = text
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			card.add_child(label)
		critics_box.add_child(card)
		card.modulate.a = 0.0
		card.create_tween().tween_property(card, "modulate:a", 1.0, 0.4).set_delay(0.5 * i)
		i += 1
	total_label.text = Locale.text("legacy_290") % ev["total"]

	clear(marketing_box)
	for index in Data.MARKETING.size():
		var plan: Dictionary = Data.MARKETING[index]
		var b = Button.new()
		b.text = "%s — %s  (Hype x%.1f)" % [plan["name"], Data.money(plan["cost"]), plan["hype"]]
		b.theme_type_variation = "ConfirmButton"
		b.disabled = int(plan["cost"]) > 0 and Game.money < int(plan["cost"])
		b.pressed.connect(_on_marketing_chosen.bind(index))
		marketing_box.add_child(b)


func _on_marketing_chosen(index: int) -> void:
	var song = Game.release_project(index)
	close()
	released.emit(song)
