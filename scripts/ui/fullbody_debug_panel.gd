class_name FullbodyDebugPanel
extends UIPanel
var selected_id := "producer"
var group := "All"
var characters: ItemList
var previews: Array[ModularCharacter] = []
var details: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	super()

func refresh() -> void:
	UIKit.clear(self)
	previews.clear()
	var body = UIKit.centered_window(self, 1810, 940)
	var header = HBoxContainer.new(); body.add_child(header)
	var title = UIKit.label("Full-body character preview | Ctrl+Shift+I", 36)
	title.size_flags_horizontal = SIZE_EXPAND_FILL; header.add_child(title)
	header.add_child(UIKit.button("Close (Esc / Ctrl+Shift+I)", close))
	var picker = OptionButton.new()
	for name in ["All", "Main", "NPC", "VIP"]: picker.add_item(name)
	picker.select(["All", "Main", "NPC", "VIP"].find(group))
	picker.item_selected.connect(func(index): group = ["All", "Main", "NPC", "VIP"][index]; refresh())
	body.add_child(picker)
	var content = HBoxContainer.new(); content.size_flags_vertical = SIZE_EXPAND_FILL; body.add_child(content)
	characters = ItemList.new(); characters.name = "CharacterList"
	characters.custom_minimum_size = Vector2(350, 610)
	characters.size_flags_vertical = SIZE_EXPAND_FILL
	characters.add_theme_font_size_override("font_size", 25)
	content.add_child(characters)
	var ids = ModularCharacter.catalogue()["characters"].keys()
	for id in ids:
		var category = "NPC" if id.begins_with("npc-") else ("VIP" if id.begins_with("super-") else "Main")
		if group != "All" and group != category: continue
		var index = characters.add_item(id)
		characters.set_item_metadata(index, id)
		if selected_id == id: characters.select(index)
	if characters.get_selected_items().is_empty() and characters.item_count > 0:
		characters.select(0); selected_id = characters.get_item_metadata(0)
	var right = VBoxContainer.new(); right.size_flags_horizontal = SIZE_EXPAND_FILL; content.add_child(right)
	var poses = HBoxContainer.new(); poses.size_flags_vertical = SIZE_EXPAND_FILL; right.add_child(poses)
	for state in ModularCharacter.catalogue()["rows"]:
		var column = VBoxContainer.new(); column.size_flags_horizontal = SIZE_EXPAND_FILL; poses.add_child(column)
		var label = UIKit.label(str(state).capitalize(), 32); label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; column.add_child(label)
		var stage = Control.new(); stage.custom_minimum_size = Vector2(320, 480); column.add_child(stage)
		var backdrop = ColorRect.new(); backdrop.color = Color("303a48"); backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); stage.add_child(backdrop)
		var actor = ModularCharacter.new(); stage.add_child(actor)
		actor.position = Vector2(160,440); actor.scale = Vector2.ONE
		previews.append(actor)
	details = UIKit.label("", 26); details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; right.add_child(details)
	characters.item_selected.connect(func(index): selected_id = characters.get_item_metadata(index); _show_character())
	_show_character()
	var footer = UIKit.label("Shared frame clock | New fullbody art | Saved outfit palettes", 26)
	body.add_child(footer)

func _show_character() -> void:
	for i in previews.size():
		previews[i].configure(selected_id)
		previews[i].play(ModularCharacter.catalogue()["rows"][i])
	var recipe: Dictionary = ModularCharacter.catalogue()["characters"][selected_id].duplicate(true)
	recipe.merge(Game.character_appearance.get(selected_id, {}), true)
	details.text = "%s\nOutfit: %s | Outer: %s | Inner: %s\nPants: %s | Shoes: %s\n%s" % [selected_id,recipe["body"],recipe["cloth_tint"],recipe.get("inner_tint","#ffffff"),recipe["pants_tint"],recipe["shoes_tint"],Game.character_parts_path()]
