class_name RelationshipOptions
extends RefCounted

static func gender_of(person: Dictionary) -> String:
	return str(person.get("gender", Art.gender(Art.model_id(person))))

static func allows_city_companion(person: Dictionary) -> bool:
	if person.is_empty(): return false
	var gender = gender_of(person)
	var preferred_gender = "male" if Game.player_character == "alice" else "female"
	return gender in ["male", "female"] if Locale.relationship_mode == "all_genders" else gender == preferred_gender

static func allows_pair(a: Dictionary, b: Dictionary) -> bool:
	if Locale.relationship_mode == "all_genders": return true
	var first = gender_of(a)
	var second = gender_of(b)
	return (first == "male" and second == "female") or (first == "female" and second == "male")

static func add_controls(body: Container) -> void:
	var row = HBoxContainer.new()
	body.add_child(row)
	var title = UIKit.label(Locale.text("relationship_mode_title"), 28)
	title.custom_minimum_size.x = 210
	row.add_child(title)
	var mode = OptionButton.new()
	mode.name = "RelationshipMode"
	mode.add_theme_font_size_override("font_size", 28)
	mode.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode.add_item(Locale.text("relationship_mode_different"))
	mode.add_item(Locale.text("relationship_mode_all"))
	mode.select(1 if Locale.relationship_mode == "all_genders" else 0)
	mode.tooltip_text = Locale.text("relationship_mode_help")
	mode.item_selected.connect(func(index: int): Locale.set_relationship_mode("all_genders" if index == 1 else "different_gender"))
	row.add_child(mode)
