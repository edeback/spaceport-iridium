class_name Action_Wait
extends ActionBase

## Stand still for a fixed stretch of sim-time (WI-44).
##
## Replaces Job_Wait's `await Global.time_manager.sim_seconds(duration)`, which
## could outlive an early cancel and relied on the _ended latch to make the
## resulting second cancel harmless. A DURATION action can't outlive its job: the
## runner owns the clock, so cancelling stops the wait rather than racing it.
##
## It also gains something the await never had - the elapsed time is saved, so a
## wait interrupted by a save resumes with the remaining seconds rather than
## starting over.

## The pose matters for the ARC inspector (WI-26): a dwelling inspector must NOT
## read as one of the idle job types PawnBreathingComponent treats as fleeable, or
## it wanders off to breathable air instead of taking the O2 damage that fails the
## inspection. `animation` itself lives on ActionBase - the runner plays it.
func _init(seconds: float = 10.0, idle_animation: StringName = &"idle") -> void:
	duration = seconds
	animation = idle_animation
	complete_mode = CompleteMode.DURATION

func report(_job: Job) -> String:
	return "Waiting"
