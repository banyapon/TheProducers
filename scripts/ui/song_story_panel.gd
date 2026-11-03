class_name SongStoryPanel
extends UIPanel
var song: Dictionary = {}
var message := ""
func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	super()
func refresh() -> void:
	UIKit.clear(self)
	var body = UIKit.centered_window(self, 1450, 850)
	body.add_child(UIKit.label(song.get("title", ""), 36))
	var history = UIKit.label(CreativeJourney.history(song), 30)
	history.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(history)
	if CreativeJourney.available(song):
		var help = UIKit.label(Locale.text("rights_prompt", [int(song["rights_offer_until"])-Game.day]),30)
		help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(help)
		for choice in 3:
			var fee = 6000 + int(song["rating"])*100 if choice == 0 else 2500 + int(song["rating"])*50
			var text = Locale.text("rights_option_%d" % choice, [Data.money(fee)]) if choice < 2 else Locale.text("rights_option_2")
			var button = UIKit.button(text, func(): message = CreativeJourney.rights(song,choice); refresh())
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.custom_minimum_size.y = 100
			body.add_child(button)
	else:
		body.add_child(UIKit.label(Locale.text("rights_no_offer"),28))
	var result = UIKit.label(message,28)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(result)
	body.add_child(UIKit.button(Locale.text("close"),close))
