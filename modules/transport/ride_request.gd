## One pawn's turbolift trip, as an explicit lifecycle (WI-75 §5):
##
##   REQUESTED -> QUEUEING -> WAITING -> BOARDING -> ONBOARD -> DONE
##                        \          \_______________________ CANCELLED
##
## - QUEUEING: the pawn walks to a QUEUE spot in the corridor behind its floor.
## - WAITING: it stands there, on a cab's pickup list, until the cab comes.
## - BOARDING: the cab has opened its doors and the pawn walks in.
## - ONBOARD: the cab owns its position (Conveyed) until the drop-off floor.
##
## Everything before ONBOARD used to be a coroutine - the shaft awaited the queue
## walk and then `finished`, with the pawn's movement suspended inside the
## turbolift's path_exit the whole time. Each phase is now a state on this object
## and on the pawn's movement component, and a save carries every one of them: a
## pawn saved half way into a cab loads half way into that cab, which still has
## its doors open and the rest of its queue waiting (WI-75, §0.3 as the author
## settled it).
##
## Calling a ride off has two meanings, and the phase decides which. One not yet
## boarded (QUEUEING, WAITING) is dropped: the queue spot is freed, the pawn
## stands on its floor, and its movement fails or retargets from there. One that
## has started boarding is committed: the pawn rides to the cab's next stop and
## gets off there, never between floors.
class_name RideRequest
extends RefCounted

enum Phase { REQUESTED, QUEUEING, WAITING, BOARDING, ONBOARD, DONE, CANCELLED }

var phase: Phase = Phase.REQUESTED
var pawn: PawnBase
var from_floor: ModuleTurbolift
var to_floor: ModuleBase           ## null once called off — "get off wherever, don't hold this stop"
## The cab whose pickup list this ride is on, from WAITING on.
var cab: TurboliftCab = null
var stand_position: Marker2D
var actual_dropoff_floor: ModuleBase = null
var cancelled: bool = false
## QUEUE anchor the pawn waits on in the corridor behind from_floor (WI-16).
var queue_anchor: AnchorDef = null
var queue_path: PathComponent = null

## Not yet boarded: calling it off drops it.
func is_pending() -> bool:
	return phase == Phase.QUEUEING or phase == Phase.WAITING

## Boarding or aboard: calling it off rides to the next stop.
func is_committed() -> bool:
	return phase == Phase.BOARDING or phase == Phase.ONBOARD

## The pawn finished a walk this ride sent it on. The queue walk puts the ride on
## a cab; the boarding walk is the cab's to notice (TurboliftCab watches it).
func on_walk_finished() -> void:
	if phase != Phase.QUEUEING:
		return
	var shaft: TurboliftShaft = from_floor.shaft if is_instance_valid(from_floor) else null
	if shaft == null:
		fail()
		return
	shaft.dispatch(self)

## The ride is over before boarding - its floor went, no cab can take it, or its
## cab was destroyed. Frees the queue spot, stands the pawn back on its floor and
## fails its movement, which fails the job as a dead ride always has.
func fail() -> void:
	if phase == Phase.CANCELLED or phase == Phase.DONE:
		return
	_drop()
	if is_instance_valid(pawn):
		if is_instance_valid(from_floor):
			pawn.current_module = from_floor
		pawn.movement_component.ride_failed(self)

## The pawn let go of a ride it had not boarded - its job changed, or it is being
## freed. The same as fail() without telling the movement, which is the caller.
## `stand_on_floor` is false only for a pawn being freed, which must not be
## re-parented on its way out.
func abandon(stand_on_floor: bool = true) -> void:
	if phase == Phase.CANCELLED or phase == Phase.DONE:
		return
	_drop()
	if stand_on_floor and is_instance_valid(pawn) and is_instance_valid(from_floor):
		pawn.current_module = from_floor

## A committed ride stops at the cab's next floor instead of its destination.
func call_off() -> void:
	cancelled = true
	to_floor = null

func _drop() -> void:
	phase = Phase.CANCELLED
	cancelled = true
	release_queue_anchor()
	if is_instance_valid(cab):
		cab.drop_request(self)

## Idempotent; called on board, on every cancel path, and as a backstop when
## the ride resolves - queue spots must never leak (same rule as storage
## reservations).
func release_queue_anchor() -> void:
	if queue_path != null and is_instance_valid(queue_path):
		queue_path.release_anchor(self)
	queue_path = null
	queue_anchor = null

# --- persistence (WI-75) ----------------------------------------------------------
#
# Written inside the pawn's "movement" block, since every ride has exactly one
# pawn; the cab writes only the order its rides stand in (TurboliftCab.to_dict).
# Restored in the pawn section's second pass, when every pawn, floor and cab is
# back.

func to_dict() -> Dictionary:
	var out: Dictionary = {"phase": int(phase), "from": SaveRefs.module_ref(from_floor)}
	if is_instance_valid(to_floor):
		out["to"] = SaveRefs.module_ref(to_floor)
	if cancelled:
		out["cancelled"] = true
	if is_instance_valid(cab) and Global.turbolift_manager != null:
		out["cab"] = Global.turbolift_manager.cab_ref(cab)
		if stand_position != null:
			out["marker"] = cab.standing_locations.find(stand_position)
	if queue_anchor != null and is_instance_valid(queue_path):
		out["queue"] = {"module": SaveRefs.module_ref(queue_path.owner_module),
			"anchor": queue_path.anchor_ref(queue_anchor)}
	# The corridor a queued or boarding pawn is parented to (assign_waiting_slot
	# reparents it there), so it draws in the same place after a load.
	if not is_committed() or phase == Phase.BOARDING:
		var corridor: ModuleBase = pawn.get_parent() as ModuleBase if is_instance_valid(pawn) else null
		if corridor != null:
			out["corridor"] = SaveRefs.module_ref(corridor)
	return out

## Puts a saved ride back: re-takes its queue spot, re-parents its pawn and puts
## it back on its cab's lists in the order the cab saved. Null when the ride can
## no longer exist - its floor or cab did not come back - and nothing has been
## changed in that case.
static func restore(data: Dictionary, ride_pawn: PawnBase) -> RideRequest:
	var request := RideRequest.new()
	request.pawn = ride_pawn
	request.phase = int(data.get("phase", Phase.REQUESTED)) as Phase
	request.from_floor = SaveRefs.resolve_module_ref(data.get("from", {})) as ModuleTurbolift
	request.to_floor = SaveRefs.resolve_module_ref(data.get("to", {}))
	request.cancelled = bool(data.get("cancelled", false))
	if request.from_floor == null or request.from_floor.shaft == null:
		return null
	if not request.is_pending() and not request.is_committed():
		return null
	if data.has("cab") and Global.turbolift_manager != null:
		request.cab = Global.turbolift_manager.resolve_cab_ref(data["cab"])
	if request.phase != Phase.QUEUEING and request.cab == null:
		return null
	var marker: Marker2D = null
	var marker_index: int = int(data.get("marker", -1))
	if request.cab != null and marker_index >= 0 and marker_index < request.cab.standing_locations.size():
		marker = request.cab.standing_locations[marker_index]
	# Nothing can have claimed the queue spot since the load began - claims are
	# never saved, and no job has run yet - so this is the spot it stood on.
	var queue: Dictionary = data.get("queue", {})
	var corridor_module: ModuleBase = SaveRefs.resolve_module_ref(queue.get("module", {}))
	if corridor_module != null and corridor_module.get_path_component() != null:
		var path_component: PathComponent = corridor_module.get_path_component()
		var anchor: AnchorDef = path_component.resolve_anchor_ref(queue.get("anchor", {}))
		if anchor != null and path_component.claim_specific_anchor(anchor, request):
			request.queue_anchor = anchor
			request.queue_path = path_component
	var parent: ModuleBase = SaveRefs.resolve_module_ref(data.get("corridor", {}))
	if parent != null:
		ride_pawn.reparent(parent)
	if request.cab != null:
		request.stand_position = marker
		request.cab.restore_request(request)
		if request.phase == Phase.ONBOARD:
			ride_pawn.reparent(request.cab)
	return request
