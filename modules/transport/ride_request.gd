## One pawn's turbolift trip. Lifecycle (WI-20): request -> queue walk ->
## boarding, after which the pawn is Conveyed and the cab drives it - the ride
## itself is never awaited; the cab calls exit_conveyed() at drop-off.
##
## Serialization contract (WI-21 pre-work): rides are not saved. A Conveyed
## pawn saves as standing at the cab's current floor (SaveManager, WI-15
## degradation formalized); `to_floor` is the module ref to record if ride
## state ever does get serialized - never a mid-shaft position.
class_name RideRequest
extends RefCounted

var pawn: PawnBase
var from_floor: ModuleTurbolift
var to_floor: ModuleBase           ## null once cancelled — "get off wherever, don't hold this stop"
var stand_position: Marker2D
var actual_dropoff_floor: ModuleBase = null
var cancelled: bool = false
## QUEUE anchor the pawn waits on in the corridor behind from_floor (WI-16).
var queue_anchor: AnchorDef = null
var queue_path: PathComponent = null
## Resolves the BOARDING phase only (WI-20): true = the pawn is onboard and
## Conveyed, false = the request died before boarding. Nothing fires it after
## boarding - arrival is delivered via exit_conveyed, not a signal.
signal finished(success: bool)

## Idempotent; called on board, on every cancel path, and as a backstop when
## the ride resolves - queue spots must never leak (same rule as storage
## reservations).
func release_queue_anchor() -> void:
	if queue_path != null and is_instance_valid(queue_path):
		queue_path.release_anchor(self)
	queue_path = null
	queue_anchor = null
