class_name Job_Wait
extends JobBase

## A stationary "stay put and look busy" job (WI-26). The ARC inspector runs one
## while dwelling at a checklist module: it plays the idle pose but, crucially,
## is NOT one of the idle job types PawnBreathingComponent treats as fleeable -
## so a dwelling inspector in a vented section takes O2 damage (the fail path)
## instead of wandering off to breathable air. Finishes on its own after
## `duration` sim-seconds; the runner also cancels it early to sequence the tour.

var pawn: PawnBase
var state: JobState = JobState.Starting
var duration: float = 10.0

func get_category() -> Category:
	return Category.MISC

func get_job_description() -> String:
	return "Waiting"

func player_cancelable() -> bool:
	return false

func is_valid() -> bool:
	return true

func can_do_job(_pawn: PawnBase) -> bool:
	return true

func start_job(_pawn: PawnBase) -> void:
	pawn = _pawn
	state = JobState.Working
	if pawn.animated_sprite != null:
		pawn.animated_sprite.play("idle")
	await Global.time_manager.sim_seconds(duration)
	# The await can outlive an early cancel() from the runner; the _ended latch
	# makes the second cancel a no-op, so this is safe either way.
	cancel(false)

func _on_cancel(as_failed: bool) -> void:
	state = JobState.Failed if as_failed else JobState.Finished

func is_failed() -> bool:
	return state == JobState.Failed

func is_finished() -> bool:
	return state == JobState.Finished
