class_name TitleLayout
extends RefCounted
## Title-screen spacing loaded from res://config/title_layout.cfg.
## Every value has a default, so a missing or partial file still lays out cleanly.

const PATH := "res://config/title_layout.cfg"
const DEFAULTS := {
	"column": {"left": 0.73, "logo_left": 0.68, "right_margin": 28, "top_margin": 26},
	"gaps": {"logo_to_toolbar": 8, "toolbar_to_menu": 14, "menu_to_tagline": 14, "tagline_to_services": 10,
		"footer_clearance": 16, "menu_padding": 6, "menu_item_gap": 8, "toolbar_gap": 12},
	"sizes": {"logo_height": 230, "min_logo_height": 150, "toolbar_height": 60, "footer_height": 50,
		"tagline_title": 36, "tagline_body": 26, "services_text": 30},
}

var _cfg := ConfigFile.new()
var _stamp := -1


func _init() -> void:
	reload()


func reload() -> void:
	_cfg = ConfigFile.new()
	_cfg.load(PATH)
	_stamp = FileAccess.get_modified_time(PATH)


## True once when the file on disk changed since the last load (live tuning).
func changed_on_disk() -> bool:
	var stamp := FileAccess.get_modified_time(PATH)
	if stamp == _stamp: return false
	reload()
	return true


func value(section: String, key: String) -> float:
	return float(_cfg.get_value(section, key, DEFAULTS[section][key]))


func px(section: String, key: String) -> int:
	return int(round(value(section, key)))


## Stacks the right column top-to-bottom; shrinks the logo first when space runs out.
## blocks: ordered [Control, gap_before] pairs (logo first). Returns the used bottom edge.
func stack(screen: Vector2, logo: Control, blocks: Array) -> float:
	var col_x := screen.x * value("column", "left")
	var col_w := screen.x - px("column", "right_margin") - col_x
	var floor_y := screen.y - px("sizes", "footer_height") - px("gaps", "footer_clearance")
	var content := 0.0
	for block in blocks:
		var node: Control = block[0]
		node.size.x = col_w
		content += float(block[1]) + node.get_combined_minimum_size().y
	var room := floor_y - px("column", "top_margin") - content
	var logo_h := clampf(room, px("sizes", "min_logo_height"), px("sizes", "logo_height"))
	var logo_x := screen.x * value("column", "logo_left")
	_place(logo, Vector2(logo_x, px("column", "top_margin")), Vector2(screen.x - px("column", "right_margin") * 0.5 - logo_x, logo_h))
	var y := px("column", "top_margin") + logo_h
	for block in blocks:
		var node: Control = block[0]
		y += float(block[1])
		var h := node.get_combined_minimum_size().y
		_place(node, Vector2(col_x, y), Vector2(col_w, h))
		y += h
	return y


static func _place(node: Control, pos: Vector2, size: Vector2) -> void:
	node.anchor_left = 0
	node.anchor_top = 0
	node.anchor_right = 0
	node.anchor_bottom = 0
	node.position = pos.round()
	node.size = size.round()
