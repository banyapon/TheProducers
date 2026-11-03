extends Node
## Static design data (genre tags, roles, rooms, items, name pools) and small text helpers.

const GENRES := ["Pop", "Rock", "Jazz", "HipHop", "EDM", "R&B", "Motown", "Metal", "Indie", "Lofi", "Classical", "Country"]

func migrate_legacy_genres(value: Variant) -> void:
	if value is Array:
		for item in value: migrate_legacy_genres(item)
	elif value is Dictionary:
		if value.has("Lukthung"):
			if not value.has("Motown"): value["Motown"] = value["Lukthung"]
			value.erase("Lukthung")
		for key in value:
			if key in ["genre", "research_hint", "band_genre"] and value[key] is String and value[key] == "Lukthung":
				value[key] = "Motown"
			else: migrate_legacy_genres(value[key])

const GENRE_COLORS := {
	"Pop": Color("ff6fb5"),
	"Rock": Color("e63946"),
	"Jazz": Color("e9c46a"),
	"HipHop": Color("f4a261"),
	"EDM": Color("4cc9f0"),
	"R&B": Color("9d4edd"),
	"Motown": Color("ffd60a"),
	"Metal": Color("6c757d"),
	"Indie": Color("80ed99"),
	"Lofi": Color("a3c4f3"),
	"Classical": Color("f1faee"),
	"Country": Color("bc6c25"),
}

const ROLES := ["Vocal", "Guitar", "Bass", "Drums", "Keys", "Producer"]
var ROLE_TH = {
	"Vocal": Locale.text("legacy_002"),
	"Guitar": Locale.text("legacy_003"),
	"Bass": Locale.text("legacy_004"),
	"Drums": Locale.text("legacy_005"),
	"Keys": Locale.text("legacy_006"),
	"Producer": Locale.text("legacy_007"),
}

## Production points (Game Dev Story style). Each role mostly produces these categories.
const POINT_CATS := ["Melody", "Lyrics", "Groove", "Sound"]
var POINT_TH = {"Melody": Locale.text("legacy_008"), "Lyrics": Locale.text("legacy_009"), "Groove": Locale.text("legacy_010"), "Sound": Locale.text("legacy_011")}
const POINT_COLORS := {
	"Melody": Color("ffd166"),
	"Lyrics": Color("06d6a0"),
	"Groove": Color("ef476f"),
	"Sound": Color("4cc9f0"),
}
const ROLE_POINTS := {
	"Vocal": ["Lyrics", "Melody"],
	"Guitar": ["Melody", "Sound"],
	"Bass": ["Groove"],
	"Drums": ["Groove", "Sound"],
	"Keys": ["Melody", "Sound"],
	"Producer": ["Sound", "Groove", "Lyrics"],
}

var ROOM_TYPES = {
	"lobby": {"name": "Lobby", "color": Color("5c677d"), "cost": 0, "desc": Locale.text("legacy_012")},
	"office": {"name": "Office", "color": Color("3d5a80"), "cost": 3000, "desc": Locale.text("legacy_013")},
	"lounge": {"name": "Lounge", "color": Color("6d597a"), "cost": 2000, "desc": Locale.text("legacy_014")},
	"studio": {"name": "Recording Studio", "color": Color("6a040f"), "cost": 8000, "desc": Locale.text("legacy_015")},
	"empty": {"name": "Empty", "color": Color("2a2a35"), "cost": 0, "desc": Locale.text("legacy_016")},
}
const BUILDABLE := ["studio", "office", "lounge", "meeting", "cafeteria", "storage"]
const FLOOR_COST := 10000
const COLUMN_COST := 6000
const MAX_FLOORS := 6
const MAX_COLUMNS := 8

var ITEMS = {
	"research": {"name": "Package Consult", "price": 800, "desc": Locale.text("legacy_017")},
	"energy": {"name": Locale.text("energy_name"), "price": 250, "desc": Locale.text("energy_desc")},
	"pizza": {"name": Locale.text("pizza_name"), "price": 600, "desc": Locale.text("pizza_desc")},
	"coffee": {"name": Locale.text("coffee_name"), "price": 150, "desc": Locale.text("coffee_desc")},
	"gift": {"name": Locale.text("legacy_018"), "price": 400, "desc": Locale.text("legacy_019")},
}

var MARKETING = [
	{"name": Locale.text("legacy_020"), "cost": 0, "hype": 1.0},
	{"name": Locale.text("legacy_021"), "cost": 500, "hype": 1.3},
	{"name": Locale.text("legacy_022"), "cost": 2000, "hype": 1.7},
	{"name": Locale.text("legacy_023"), "cost": 6000, "hype": 2.4},
]

var CRITICS = [
	{"name": Locale.text("legacy_024"), "color": Color("ffb703")},
	{"name": Locale.text("legacy_025"), "color": Color("219ebc")},
	{"name": Locale.text("legacy_026"), "color": Color("fb8500")},
	{"name": "Prof. Tempo", "color": Color("8ecae6")},
]
var CRITIC_COMMENTS = [
	Locale.text("legacy_027"),
	Locale.text("legacy_028"),
	Locale.text("legacy_029"),
	Locale.text("legacy_030"),
	Locale.text("legacy_031"),
]

var NICKNAMES = [Locale.text("legacy_032"), Locale.text("legacy_033"), Locale.text("legacy_034"), Locale.text("legacy_035"), Locale.text("legacy_036"), Locale.text("legacy_037"), Locale.text("legacy_038"), Locale.text("legacy_039"), Locale.text("legacy_040"), Locale.text("legacy_041"), Locale.text("legacy_042"), Locale.text("legacy_043"), Locale.text("legacy_044"), Locale.text("legacy_045"), Locale.text("legacy_046"), Locale.text("legacy_047"), Locale.text("legacy_048"), Locale.text("legacy_049"), Locale.text("legacy_050"), Locale.text("legacy_051"), Locale.text("legacy_052"), Locale.text("legacy_053"), Locale.text("legacy_054"), Locale.text("legacy_055")]
const STAGE_NAMES := ["Groove", "Nova", "Blue", "Wave", "Stone", "Echo", "Vibe", "Moon", "Spark", "Velvet", "Neon", "Riff"]

var CLIENTS = [
	{"name": "Smile Records", "type": Locale.text("legacy_056")},
	{"name": Locale.text("legacy_057"), "type": Locale.text("legacy_058")},
	{"name": Locale.text("legacy_059"), "type": Locale.text("legacy_060")},
	{"name": Locale.text("legacy_061"), "type": Locale.text("legacy_058")},
	{"name": "PixelPop Games", "type": Locale.text("legacy_058")},
	{"name": "FM 99 Radio", "type": Locale.text("legacy_056")},
	{"name": Locale.text("legacy_062"), "type": Locale.text("legacy_056")},
	{"name": "AdHub Agency", "type": Locale.text("legacy_058")},
	{"name": Locale.text("legacy_063"), "type": Locale.text("legacy_060")},
	{"name": "MegaMall", "type": Locale.text("legacy_058")},
	{"name": Locale.text("legacy_064"), "type": Locale.text("legacy_058")},
	{"name": Locale.text("legacy_065"), "type": Locale.text("legacy_060")},
]
var JOB_TITLES = [Locale.text("legacy_066"), "Theme Song", Locale.text("legacy_067"), Locale.text("legacy_068"), Locale.text("legacy_069"), Locale.text("legacy_070"), Locale.text("legacy_071"), Locale.text("legacy_072"), Locale.text("legacy_073")]
const TITLE_A := ["Midnight", "Neon", "Lost", "Golden", "Electric", "Summer", "Broken", "Velvet", "Bangkok", "Silent", "Crazy", "Paper"]
const TITLE_B := ["Heart", "City", "Dreams", "Rain", "Fever", "Lights", "Road", "Love", "Echo", "Sky", "Party", "Moon"]

var SMALL_TALK = [
	Locale.text("legacy_074"),
	Locale.text("legacy_075"),
	Locale.text("legacy_076"),
	Locale.text("legacy_077"),
]
var MORALE_LINES = [
	Locale.text("legacy_078"),
	Locale.text("legacy_079"),
	Locale.text("legacy_080"),
]


func money(value: int) -> String:
	var digits = str(absi(value))
	var out = ""
	while digits.length() > 3:
		out = "," + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return ("-$" if value < 0 else "$") + digits + out


func random_artist_name() -> String:
	return "%s %s" % [NICKNAMES.pick_random(), STAGE_NAMES.pick_random()]


func random_song_title() -> String:
	return "%s %s" % [TITLE_A.pick_random(), TITLE_B.pick_random()]


## Keys of a {tag: value} dictionary, highest value first.
func sorted_tags(values: Dictionary) -> Array:
	var keys = values.keys()
	keys.sort_custom(func(a, b): return values[a] > values[b])
	return keys


func skills_text(skills: Dictionary, count := 3) -> String:
	var parts = PackedStringArray()
	for tag in sorted_tags(skills).slice(0, count):
		parts.append("%s %d%%" % [tag, skills[tag]])
	return " | ".join(parts)


func mix_text(mix: Dictionary) -> String:
	return skills_text(mix, mix.size())


func roles_text(roles: Array) -> String:
	var parts = PackedStringArray()
	for role in roles:
		parts.append(ROLE_TH.get(role, role))
	return ", ".join(parts)


func colors_for_mix(mix: Dictionary) -> Array:
	var out = []
	for tag in sorted_tags(mix):
		out.append(GENRE_COLORS.get(tag, Color.WHITE))
	return out


func critic_comment(score: int) -> String:
	return CRITIC_COMMENTS[clampi((score - 1) / 2, 0, CRITIC_COMMENTS.size() - 1)]

var _original_text: Dictionary = {}
func _ready() -> void:
	for room in ["meeting", "cafeteria", "storage"]:
		ROOM_TYPES[room] = {"name": room.capitalize(), "color": Color("394664"), "cost": 2500, "desc": Locale.text("room_" + room)}
	for key in ["ROLE_TH", "POINT_TH", "ROOM_TYPES", "ITEMS", "MARKETING", "CRITICS", "CRITIC_COMMENTS", "NICKNAMES", "CLIENTS", "JOB_TITLES", "SMALL_TALK", "MORALE_LINES"]:
		_original_text[key] = get(key).duplicate(true)
	_apply_language()
	Locale.language_changed.connect(_apply_language.unbind(1))

func _apply_language() -> void:
	for key in _original_text:
		set(key, _translate_value(_original_text[key]))
	for room in ["meeting", "cafeteria", "storage"]:
		ROOM_TYPES[room]["desc"] = Locale.text("room_" + room)

func _translate_value(value: Variant) -> Variant:
	if value is String:
		return Locale.legacy(value)
	if value is Array:
		var out: Array = []
		for entry in value:
			out.append(_translate_value(entry))
		return out
	if value is Dictionary:
		var out: Dictionary = {}
		for key in value:
			out[key] = _translate_value(value[key])
		return out
	return value
