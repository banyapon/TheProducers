extends Node
## Locale owns language/preferences and JSON presentation data. No gameplay state lives here.
signal language_changed(language: String)
signal relationship_mode_changed
const SETTINGS_PATH := "user://preferences.cfg"
const CONSENT_VERSION := "2026-10-31"
var language = "en"
var relationship_mode := "different_gender"
var _catalogues: Dictionary = {}
var _source_keys: Dictionary = {}
var _settings = ConfigFile.new()

func _ready() -> void:
	_settings.load(SETTINGS_PATH)
	relationship_mode = str(_settings.get_value("gameplay", "relationship_mode", "different_gender"))
	if relationship_mode not in ["different_gender", "all_genders"]: relationship_mode = "different_gender"
	language = str(_settings.get_value("ui", "language", "en"))
	if language not in ["en", "th"]:
		language = "en"
	for lang in ["en", "th"]:
		var catalogue: Dictionary = {}
		for file in DirAccess.get_files_at("res://data/" + lang):
			if not file.ends_with(".json"):
				continue
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/%s/%s" % [lang, file]))
			if parsed is Dictionary:
				catalogue.merge(parsed, true)
		_catalogues[lang] = catalogue
	for key in _catalogues.get("th", {}):
		var source: Variant = _catalogues["th"][key]
		if source is String:
			_source_keys[source] = key
	for key in _catalogues.get("en", {}):
		var source: Variant = _catalogues["en"][key]
		if source is String: _source_keys[source] = key
	for lang in ["en", "th"]:
		var translation = Translation.new()
		translation.locale = lang
		for source in _source_keys:
			var value: Variant = _catalogues[lang].get(_source_keys[source], source)
			if value is String:
				translation.add_message(source, value)
		TranslationServer.add_translation(translation)
	TranslationServer.set_locale(language)

func set_language(value: String) -> void:
	if value not in ["en", "th"] or value == language:
		return
	language = value
	_settings.set_value("ui", "language", language)
	_settings.save(SETTINGS_PATH)
	TranslationServer.set_locale(language)
	language_changed.emit(language)

func set_relationship_mode(value: String) -> void:
	if value not in ["different_gender", "all_genders"]: return
	relationship_mode = value
	_settings.set_value("gameplay", "relationship_mode", value)
	_settings.save(SETTINGS_PATH)
	relationship_mode_changed.emit()

var _assistant_rendered: Dictionary = {}

func _assistant_key(value: String) -> String:
	return Game.producer_name + "\n" + value

func text(key: String, args: Array = []) -> String:
	var value = str(_catalogues.get(language, {}).get(key, _catalogues.get("en", {}).get(key, key)))
	if key.begins_with("play_as_hint_"):
		if key.ends_with("alice"):
			return "เล่นเป็น Alice โดยมี Producer เป็นผู้ช่วยของเธอ" if language == "th" else "Play as Alice. Producer will be your assistant."
		return "เล่นเป็น Producer โดยมี Alice เป็นผู้ช่วยของคุณ" if language == "th" else "Play as Producer. Alice will be your assistant."
	if is_instance_valid(Game) and Game.player_character == "alice":
		if key == "relationship_mode_different": return "ชาย (Male)" if language == "th" else "Male"
		if key == "relationship_mode_help":
			return "Male: เลือกผู้ชายไป City ส่วน All Gender: เลือกได้ทุกเพศ คู่ที่คบกันอยู่จะยังคงเดิม" if language == "th" else "Male: choose male City companions. All Gender: choose any gender. Existing couples stay together."
		# Adapt authored templates before inserting player-entered names or song titles.
		value = value.replace("Alice", "Producer").replace("ALICE", "PRODUCER")
		if value.begins_with("พี่") or key.begins_with("alice_") or key.begins_with("tutorial_") or key.begins_with("intro_"):
			value = assistant_line(value)
	var rendered = display_game_text(value % args) if not args.is_empty() else value
	if is_instance_valid(Game) and _assistant_rendered.has(_assistant_key(value)):
		_assistant_rendered[_assistant_key(rendered)] = true
	return rendered

func assistant_line(value: String) -> String:
	if Game.player_character != "alice": return speaker_line(value, "female")
	if language != "th": return value
	# Templates may pass through both Locale.text and DialogBox. Do not rewrite
	# the assistant's new first-person พี่ as a player address a second time.
	if _assistant_rendered.has(_assistant_key(value)): return value
	var name_token = "\u0001PLAYER\u0001"
	value = value.replace("พี่{producer}", name_token).replace("พี่" + Game.producer_name, name_token)
	value = value.replace(Game.producer_name, name_token)
	value = value.replace("{producer}", name_token).replace("พี่", name_token).replace("เธอ", name_token)
	value = value.replace("คุณชวน", name_token + "ชวน")
	value = value.replace("ดิฉัน", "พี่").replace("ฉัน", "พี่")
	value = value.replace("นะคะ", "นะ").replace("ค่ะ", "ครับ").replace("คะ", "ครับ")
	value = value.replace(name_token, Game.producer_name)
	_assistant_rendered[_assistant_key(value)] = true
	return value

func display_game_text(value: String) -> String:
	# Translate saved built-in names without changing dictionary IDs or player names.
	var other = "th" if language == "en" else "en"
	var keys = ["legacy_057", "legacy_059", "legacy_061", "legacy_062", "legacy_063", "legacy_064", "legacy_065"]
	for n in range(66, 74): keys.append("legacy_%03d" % n)
	for key in keys:
		var source = str(_catalogues.get(other, {}).get(key, ""))
		var target = str(_catalogues.get(language, {}).get(key, ""))
		if not source.is_empty() and not target.is_empty(): value = value.replace(source, target)
	# Both bundled pixel fonts map U+00B7 to the Thai letter tho thahan.
	# Normalize old save text too, without replacing actual Thai U+0E17.
	return value.replace("\u00c3\u201a\u00c2\u00b7", "|").replace("\u00c2\u00b7", "|").replace("\u00b7", "|")

func line(key: String, variables: Dictionary = {}) -> String:
	var source = text(key)
	var rendered = source.format(variables)
	if _assistant_rendered.has(_assistant_key(source)): _assistant_rendered[_assistant_key(rendered)] = true
	return rendered

func values(key: String) -> Array:
	var value: Variant = _catalogues.get(language, {}).get(key, [])
	return value.duplicate(true) if value is Array else []

func legacy(source: String) -> String:
	source = display_game_text(source)
	if _catalogues.get(language, {}).has(source):
		return text(source)
	return text(str(_source_keys[source])) if _source_keys.has(source) else source

func has_consent(identity: String) -> bool:
	return str(_settings.get_value("consent", identity.sha256_text(), "")) == CONSENT_VERSION

func record_consent(identity: String) -> void:
	_settings.set_value("consent", identity.sha256_text(), CONSENT_VERSION)
	_settings.set_value("consent_time", identity.sha256_text(), Time.get_datetime_string_from_system(true))
	_settings.save(SETTINGS_PATH)

func female_line(value: String, gender: String) -> String:
	return speaker_line(value, gender)

func speaker_line(value: String, gender: String) -> String:
	if language != "th" or gender not in ["male", "female"]: return value
	var pronoun = RegEx.new()
	# Match first-person forms, not embedded words such as hairstyle (ทรงผม).
	pronoun.compile("(?<![ก-๙])(?:ดิฉัน|ฉัน|หนู)" if gender == "male" else "(?<![ก-๙])ผม")
	value = pronoun.sub(value, "ผม" if gender == "male" else "ฉัน", true)
	if gender == "female":
		for prefix in ["ของ", "ให้", "กับ", "ส่วน", "สำหรับ"]:
			value = value.replace(prefix + "ผม", prefix + "ฉัน")
	var ending = RegEx.new()
	if gender == "male":
		ending.compile("(?:ค่ะ|คะ)(?=$|[\\s!?.,…ฯ\"”])")
		return ending.sub(value, "ครับ", true)
	value = value.replace("ครับผม", "ค่ะ")
	for question in ["นะ", "ไหม", "หรือ", "เหรอ", "อะไร", "ไหน", "อย่างไร", "เท่าไร", "หรือเปล่า", "บ้าง"]:
		value = value.replace(question + "ครับ", question + "คะ")
	ending.compile("ครับ(?=$|[\\s!?.,…ฯ\"”])")
	return ending.sub(value, "ค่ะ", true)
