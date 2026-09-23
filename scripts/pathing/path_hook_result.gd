class_name PathHookResult
extends RefCounted

## What a module's path hook tells the pawn crossing it (WI-75 §1).
##
## [method ModuleBase.path_enter], [method ModuleBase.path_exit] and
## [method ModuleBase.traverse] used to be coroutines: a door awaited its own
## animation and the pawn's movement component sat suspended inside the call until
## it finished. A suspended coroutine cannot be saved, stepped or asserted, and one
## whose module was freed under it simply never resumed (F28). So a hook now starts
## whatever it starts and returns one of these, and [PawnMovementComponent] acts on
## it - the same shape as the job runner's [enum ActionBase.Status], which is the
## same problem solved in the same codebase.

enum Kind {
	CONTINUE,   ## carry on walking, this frame
	WAIT,       ## stand still for `seconds` sim-seconds, then carry on
	TAKEN_OVER, ## a carrier owns the pawn now (a turbolift ride); it hands it back
	FAIL,       ## this route cannot be finished - the movement fails
}

var kind: Kind = Kind.CONTINUE
## Sim-seconds, for WAIT.
var seconds: float = 0.0

static func proceed() -> PathHookResult:
	return PathHookResult.new()

## A wait of nothing is no wait, so a door that is already open answers CONTINUE
## rather than parking the pawn for a frame.
static func wait(wait_seconds: float) -> PathHookResult:
	var result := PathHookResult.new()
	if wait_seconds > 0.0:
		result.kind = Kind.WAIT
		result.seconds = wait_seconds
	return result

static func taken_over() -> PathHookResult:
	var result := PathHookResult.new()
	result.kind = Kind.TAKEN_OVER
	return result

static func fail() -> PathHookResult:
	var result := PathHookResult.new()
	result.kind = Kind.FAIL
	return result
