class_name ScheduleDay
extends Button
var job_id := ""
var start_day := 0
signal moved(job: String, day: int)
func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("schedule_job", "") == job_id and start_day > Game.day
func _drop_data(_position: Vector2, data: Variant) -> void:
	moved.emit(str(data["schedule_job"]),start_day)
