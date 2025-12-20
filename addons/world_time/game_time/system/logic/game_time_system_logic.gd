## Handles core game time logic like validation, time progression, and date advancement.
class_name GameTimeSystemLogic
extends RefCounted

var _time_state : TimeState

func _init(p_time_state : TimeState):
	_time_state = p_time_state
	_validate()

## Advances time by the given seconds.
func progress_time(p_seconds : float) -> float:
	return _time_state.progress_time(p_seconds)

## Moves to the next day, optionally setting a specific time.
func go_to_next_day(p_desired_time : HoursTime = null) -> void:
	_time_state.go_to_next_date(p_desired_time)

## Checks if TimeState is valid for use.
func _validate() -> bool:
	var issues : Array[String] = []

	if _time_state == null:
		issues.append("TimeState is required.")

	if _time_state.date_time == null:
		issues.append("TimeState.date_time must be set.")

	for issue in issues:
		push_error(issue)

	return issues.is_empty()
