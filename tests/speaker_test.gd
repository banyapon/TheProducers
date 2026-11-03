extends Node
func _ready() -> void:
	Locale.language = "th"
	var cases = [
		["ฉันพร้อมแล้วค่ะ", "male", "ผมพร้อมแล้วครับ"],
		["รอรายงานก่อนนะคะ", "male", "รอรายงานก่อนนะครับ"],
		["ผมพร้อมแล้วครับ", "female", "ฉันพร้อมแล้วค่ะ"],
		["ได้ไหมครับ?", "female", "ได้ไหมคะ?"],
		["สัญญาของผมหมดแล้วนะครับ", "female", "สัญญาของฉันหมดแล้วนะคะ"],
		["ทรงผมสวย คะเนราคา", "male", "ทรงผมสวย คะเนราคา"],
		["ทรงผมสวยครับ", "female", "ทรงผมสวยค่ะ"],
	]
	var errors = 0
	for item in cases:
		if Locale.speaker_line(item[0], item[1]) != item[2]:
			errors += 1
			push_error(item[0])
	Locale.language = "en"
	if Locale.speaker_line("I'm ready.", "female") != "I'm ready.": errors += 1
	print("SPEAKER: 8 checks, failures: ", errors)
	get_tree().quit(errors)
