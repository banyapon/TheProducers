class_name ScheduleCard
extends PanelContainer
var job_id := ""
func _get_drag_data(_position: Vector2) -> Variant:
	set_drag_preview(UIKit.label(Locale.text("timeline_drag"),28))
	return {"schedule_job": job_id}
