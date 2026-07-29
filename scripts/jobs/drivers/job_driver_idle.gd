class_name JobDriver_Idle
extends JobDriver

## Standing around (WI-44) - the replacement for Job_Idle. The last-resort
## fallback for a pawn that cannot even wander (nowhere reachable, or boxed in).
##
## One waiting step in the idle pose. Not saveable, for the same reason as
## wandering: this is where a pawn ends up anyway.

const IDLE_SECONDS: float = 5.0

func make_actions(_job: Job) -> Array[ActionBase]:
	return [Action_Wait.new(IDLE_SECONDS, &"idle")] as Array[ActionBase]
