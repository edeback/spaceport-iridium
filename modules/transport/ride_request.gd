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
signal finished(success: bool)

## Idempotent; called on board, on every cancel path, and as a backstop when
## the ride resolves - queue spots must never leak (same rule as storage
## reservations).
func release_queue_anchor() -> void:
	if queue_path != null and is_instance_valid(queue_path):
		queue_path.release_anchor(self)
	queue_path = null
	queue_anchor = null
