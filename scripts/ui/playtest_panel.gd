class_name PlaytestPanel
extends UIPanel
signal launch(slot: String)
var selected_id := ""
var deleting := false
var message := ""
var can_launch := false

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	super()

func refresh() -> void:
	UIKit.clear(self)
	var body = UIKit.centered_window(self, 1550, 970)
	var head = HBoxContainer.new()
	body.add_child(head)
	var title = UIKit.label(Locale.text("pt_title"), 36)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UIKit.button(Locale.text("close"), close))
	var notice = UIKit.label(Locale.text("pt_notice"), 28)
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(notice)
	if can_launch:
		body.add_child(UIKit.button(Locale.text("pt_start"), func(): launch.emit(PlaytestLog.create_run()); close(), 400, "ConfirmButton"))
	var ids = PlaytestLog.data()["runs"].keys()
	if not selected_id in ids: selected_id = str(ids.back()) if not ids.is_empty() else ""
	var picker = OptionButton.new()
	for id in ids: picker.add_item(id)
	if not ids.is_empty(): picker.select(ids.find(selected_id))
	picker.item_selected.connect(func(index: int): selected_id = ids[index]; deleting = false; message = ""; refresh())
	body.add_child(picker)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	body.add_child(scroll)
	var report = UIKit.label(PlaytestLog.report(selected_id), 28)
	report.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	report.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(report)
	var controls = HBoxContainer.new()
	body.add_child(controls)
	if not selected_id.is_empty():
		if can_launch:
			controls.add_child(UIKit.button(Locale.text("pt_resume"), func(): launch.emit(selected_id); close()))
		controls.add_child(UIKit.button(Locale.text("pt_export"), func(): message = PlaytestLog.export_run(selected_id); refresh()))
		controls.add_child(UIKit.button(Locale.text("pt_delete_confirm" if deleting else "pt_delete"), func():
			if deleting: PlaytestLog.erase(selected_id); selected_id = ""; message = ""
			deleting = not deleting
			refresh()))
	var status = UIKit.label(message, 24)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(status)
