class_name TurboliftCab
extends Node2D

@export var capacity: int = 6
# Movement speed (cells per second)
@export var speed: float = 1.2
# Reference to the sprite/visual representation
@export var cab_sprite: Sprite2D
@export var standing_locations: Array[Marker2D]
@export var offset: Vector2 = Vector2(21, 46)

var shaft: TurboliftShaft
var onboard: Array[RideRequest] = []
var pickup_requests: Array[RideRequest] = []
## What the cab is doing (WI-75 §5). A stop used to be a coroutine: DOORS_OPEN
## awaited the floor's door, unloaded, then awaited each boarding pawn's walk in
## turn with the cab parked in a WAITING state that meant "suspended". Each of
## those waits is a state of its own now, and a save carries the cab through all
## of them.
## - IDLE: nothing to do; picks a destination when there is one.
## - MOVING: travelling to destination_module.
## - ARRIVED: just stopped at a floor; asks its door open.
## - DOORS_OPENING: waiting out the door, `_door_left` sim-seconds.
## - BOARDING: passengers for this floor are off; the ones waiting here walk in,
##   one at a time, each a straight walk the cab watches for.
## The doors are not waited shut before moving off - they never were: the floor's
## door closes itself behind the cab.
enum CabState { IDLE, MOVING, ARRIVED, DOORS_OPENING, BOARDING }
var state: CabState = CabState.IDLE
var assigned_locations: Dictionary[Marker2D, RideRequest] = {}
var current_turbolift: ModuleTurbolift = null

# Destination floor when moving
var destination_module: ModuleTurbolift

## Sim-seconds until the floor's door is open, while DOORS_OPENING.
var _door_left: float = 0.0
## The rides that were waiting at this floor when the doors opened, still to
## board, in order. A snapshot, as the old loop's was: a pawn who reaches the
## queue after the doors open waits for the next visit.
var _boarding_queue: Array[RideRequest] = []
## The ride walking in right now, or null.
var _boarding: RideRequest = null
## The order the save had the cab's rides in, by pawn id, until each ride is put
## back (see restore_request). Rides restore pawn by pawn, in the pawn section's
## order, and the cab's lists have to come back in theirs.
var _saved_order: Dictionary = {}

# This is the grid-aligned position for use in cell calculation
# as opposed to the visual position (which is centered at global_position)
# When the cab is "in position" at a turbolift, this ends up pointing to the
# top-left corner of that cell.
func get_apparent_position() -> Vector2:
	return	global_position - offset

func set_apparent_position(new_pos: Vector2) -> void:
	global_position = new_pos + offset

func set_apparent_position_y(new_y: float) -> void:
	global_position.y = new_y + offset.y

func _process(delta: float) -> void:
	var sim_delta: float = Global.time_manager.scale(delta)
	if sim_delta <= 0.0:
		return
	match state:
		CabState.IDLE:
			if shaft != null and shaft.try_consume_pending_removal(self):
				return
			destination_module = null
			if not onboard.is_empty():
				for request in onboard:
					if request.to_floor != null:
						destination_module = request.to_floor
				if destination_module == null:
					destination_module = get_closest_exit()
			elif not pickup_requests.is_empty():
				destination_module = pickup_requests[0].from_floor
			if destination_module != null:
				state = CabState.MOVING
		CabState.MOVING:
			if destination_module == null:
				destination_module = get_closest_exit()
			if destination_module == null:
				state = CabState.IDLE
				return
			# lerp global_position.y toward the next target floor's y at cab speed;
			# also update global_position for every request in `onboard` to follow the cab.
			# On arrival at a floor that's in `stops`: state = CabState.ARRIVED.
			var dist_to_move: float = speed * Global.CELL_SIZE.y * sim_delta
			var dist_left: float = destination_module.global_position.y - get_apparent_position().y
			# Probably want to recheck where we're going and stopping to pick up people on the way?

			if dist_to_move >= absf(dist_left):
				set_apparent_position_y(destination_module.global_position.y)
				state = CabState.ARRIVED
			else:
				global_position.y += dist_to_move * signf(dist_left)
			current_turbolift = shaft.get_floor_module(Global.world_to_cell(global_position).y)
		CabState.ARRIVED:
			_arrive()
		CabState.DOORS_OPENING:
			_door_left -= sim_delta
			if _door_left <= 0.0:
				_door_left = 0.0
				_doors_opened()
		CabState.BOARDING:
			_watch_boarding()

## Stopped at a floor: ask its door open. An open door (still held from the last
## stop here) lets everyone move in the same frame, as the old await on an
## already-open door did.
func _arrive() -> void:
	if current_turbolift == null:
		state = CabState.IDLE
		return
	_door_left = current_turbolift.open_door()
	state = CabState.DOORS_OPENING
	if _door_left <= 0.0:
		_door_left = 0.0
		_doors_opened()

## Drop off whoever is getting off here, then start boarding whoever is waiting.
func _doors_opened() -> void:
	unload_passengers(current_turbolift)
	_boarding_queue.clear()
	for ride: RideRequest in pickup_requests:
		if ride.from_floor == current_turbolift:
			_boarding_queue.append(ride)
	_boarding = null
	state = CabState.BOARDING
	_board_next()

## Starts the next waiting pawn walking in, or leaves when there is none.
func _board_next() -> void:
	while not _boarding_queue.is_empty():
		var ride: RideRequest = _boarding_queue.pop_front()
		if not pickup_requests.has(ride):
			continue  # dropped since the doors opened
		if not is_instance_valid(ride.pawn):
			pickup_requests.erase(ride)
			ride.release_queue_anchor()
			continue
		# Boarding frees the queue spot for the next caller (WI-16).
		ride.release_queue_anchor()
		var free_marker: Marker2D = null
		for marker in assigned_locations:
			if assigned_locations[marker] == null:
				free_marker = marker
				break
		if free_marker == null:
			# No spot to walk to: straight on, as the old loop did.
			ride.phase = RideRequest.Phase.BOARDING
			_finish_boarding(ride)
			continue
		assigned_locations[free_marker] = ride
		ride.stand_position = free_marker
		# Walk from the waiting spot into the cab, one pawn at a time (WI-16) -
		# the doors stay open (the cab is BOARDING) while we board.
		ride.phase = RideRequest.Phase.BOARDING
		ride.pawn.movement_component.walk_to(free_marker.global_position)
		_boarding = ride
		return
	_boarding = null
	if onboard.size() > 0:
		destination_module = onboard[0].to_floor
		state = CabState.MOVING
	else:
		state = CabState.IDLE

## The one boarding pawn: in when its walk is done, skipped if it was freed on the
## way.
func _watch_boarding() -> void:
	if _boarding == null:
		_board_next()
		return
	var ride: RideRequest = _boarding
	if not is_instance_valid(ride.pawn):
		if ride.stand_position != null:
			assigned_locations[ride.stand_position] = null
		pickup_requests.erase(ride)
		_boarding = null
		_board_next()
		return
	if ride.pawn.movement_component.is_holding_for(ride):
		_boarding = null
		_finish_boarding(ride)
		_board_next()

## Boarding complete: the cab owns the pawn's position from here (WI-20), and
## drives the ride until exit_conveyed at the drop-off.
func _finish_boarding(ride: RideRequest) -> void:
	pickup_requests.erase(ride)
	onboard.append(ride)
	ride.phase = RideRequest.Phase.ONBOARD
	ride.pawn.reparent(self)
	ride.pawn.movement_component.enter_conveyed(self)

func floor_has_requests(next_floor: ModuleTurbolift) -> bool:
	for ride in onboard:
		if ride.to_floor == next_floor:
			return true
	for ride in pickup_requests:
		if ride.from_floor == next_floor:
			return true
	return false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Registered here rather than in _init (WI-68 F12): _init runs on bare
	# instantiation, so anything that built a cab outside a running game - a
	# preview, a tool, a probe - errored on a null path_manager. The ordering is
	# still safe: TurboliftShaft.create_new_cab add_child()s the cab (running this)
	# before add_cab() moves its vertex into the shaft's group.
	Global.path_manager.add_vertex(self, true)
	for marker in standing_locations:
		assigned_locations[marker] = null


func add_pickup_request(request: RideRequest) -> void:
	request.cab = self
	pickup_requests.append(request)

## Takes a ride that has not boarded off this cab's lists - the pawn let go of it,
## or it failed. Idempotent.
func drop_request(request: RideRequest) -> void:
	pickup_requests.erase(request)
	_boarding_queue.erase(request)
	if _boarding == request:
		_boarding = null
	if request.stand_position != null and assigned_locations.get(request.stand_position) == request:
		assigned_locations[request.stand_position] = null

func get_closest_exit() -> ModuleTurbolift:
	var best_lift: ModuleTurbolift = null
	var dist: float = -1
	for turbolift in shaft.floors:
		if turbolift.floor_enabled and turbolift.get_path_component().has_door_connected():
			if dist < 0 or turbolift.global_position.distance_squared_to(get_apparent_position()) < dist:
				dist = turbolift.global_position.distance_squared_to(get_apparent_position())
				best_lift = turbolift
	return best_lift

## Can rides still start/end at this floor? False for another shaft's floors
## (post-split) and for floors toggled off (WI-11).
func _floor_served(floor_module: ModuleBase) -> bool:
	return shaft != null and shaft.is_floor_served(floor_module)

func recheck_requests() -> void:
	for request: RideRequest in pickup_requests.duplicate():
		if request.from_floor and not _floor_served(request.from_floor):
			cancel_request(request)
		elif request.to_floor and not _floor_served(request.to_floor):
			cancel_request(request)
	for request in onboard:
		if request.to_floor and not _floor_served(request.to_floor):
			cancel_request(request)
	if not is_instance_valid(destination_module) or not _floor_served(destination_module):
		destination_module = null
	if destination_module == null and state == CabState.MOVING:
		for ride in onboard:
			if is_instance_valid(ride.to_floor):
				destination_module = ride.to_floor
				break
		if not destination_module:
			for ride in pickup_requests:
				if is_instance_valid(ride.from_floor):
					destination_module = ride.from_floor
					break
		if not destination_module:
			# Just go to the nearest floor then
			var best_lift: ModuleTurbolift = get_closest_exit()
			if best_lift != null:
				destination_module = best_lift
			else:
				state = CabState.IDLE

## A ride this cab holds can no longer be served as asked. One not yet boarded is
## dropped and its movement failed; one boarding or aboard is committed and gets
## off at the next stop instead - never between floors.
func cancel_request(request: RideRequest) -> bool:
	if not pickup_requests.has(request) and not onboard.has(request):
		return false
	if request.is_committed():
		request.call_off()
	else:
		request.fail()
	return true

# Unload all passengers that want to exit at this floor
func unload_passengers(cur_module: ModuleTurbolift) -> void:
	for request: RideRequest in onboard.duplicate():
		if request.to_floor == cur_module or request.to_floor == null:
			onboard.erase(request)
			if request.stand_position != null:
				assigned_locations[request.stand_position] = null
			if not is_instance_valid(request.pawn):
				continue
			request.actual_dropoff_floor = cur_module
			request.phase = RideRequest.Phase.DONE
			request.pawn.current_module = cur_module
			request.pawn.reparent(cur_module.get_parent())
			# Normal arrival and a cancelled ride's next-stop drop are the same
			# handoff (WI-20): exit_conveyed repaths from this floor, so a
			# diverted drop-off self-corrects and a dead target just fails.
			request.pawn.movement_component.exit_conveyed()


func is_idle() -> bool:
	return state == CabState.IDLE

# Only valid if actually moving
func moving_up() -> bool:
	if destination_module != null:
		return destination_module.global_position.y < get_apparent_position().y
	return false


# Check if the cab is available
func is_available() -> bool:
	return onboard.size() + pickup_requests.size() < capacity

# Get the number of available spots
func get_available_capacity() -> int:
	return capacity - (onboard.size() + pickup_requests.size())

func destroy() -> void:
	# queue_free only deletes at end of frame; without this, _process can run
	# once more after shaft is nulled below and crash on shaft.get_floor_module.
	set_process(false)
	Global.path_manager.remove_vertex(self)
	assigned_locations.clear()
	for request in onboard:
		request.cancelled = true
		request.phase = RideRequest.Phase.DONE
		if not is_instance_valid(request.pawn):
			continue
		# Dump into hallway if it exists, will fallback to space automatically.
		request.pawn.current_module = Global.world_manager.get_module_by_cell(WorldManager.StructureLayer.CORRIDOR, Global.world_to_cell(global_position))
		if request.pawn.get_parent() == self:
			# The module-change setter only reparents on a layer change; force
			# the pawn out regardless - it must not be freed with the cab.
			request.pawn.reparent(Global.world_manager.get_canvas_for_layer(request.pawn.current_layer))
		request.pawn.movement_component.exit_conveyed()
	onboard.clear()
	# Everyone not yet aboard - waiting, or part way through walking in - is
	# dropped where they stand, and their movement fails (WI-75: a destroyed cab
	# mid-boarding leaves the pawn in the corridor).
	var not_aboard: Array[RideRequest] = pickup_requests.duplicate()
	pickup_requests.clear()
	_boarding_queue.clear()
	_boarding = null
	for request in not_aboard:
		request.cab = null
		request.fail()
	shaft = null
	queue_free()

# --- persistence (WI-75) ----------------------------------------------------------
#
# Written per shaft by TurboliftManager, in the turbolifts section - which loads
# before the pawns, so the cab is standing where it was, doing what it was doing,
# before any ride is put back on it. The rides themselves are in their pawns'
# movement blocks; the cab keeps only the order they stand in, by pawn id.

func to_dict() -> Dictionary:
	var out: Dictionary = {
		"position": [global_position.x, global_position.y],
		"state": int(state),
	}
	if current_turbolift != null:
		out["at"] = SaveRefs.module_ref(current_turbolift)
	if destination_module != null:
		out["to"] = SaveRefs.module_ref(destination_module)
	if _door_left > 0.0:
		out["door"] = _door_left
	var pickup: Array = _pawn_ids(pickup_requests)
	if not pickup.is_empty():
		out["pickup"] = pickup
	var aboard: Array = _pawn_ids(onboard)
	if not aboard.is_empty():
		out["onboard"] = aboard
	var boarding: Array = _pawn_ids(_boarding_queue)
	if not boarding.is_empty():
		out["boarding"] = boarding
	return out

func load_dict(data: Dictionary) -> void:
	var at: Array = data.get("position", [])
	if at.size() == 2:
		global_position = Vector2(float(at[0]), float(at[1]))
	state = int(data.get("state", CabState.IDLE)) as CabState
	current_turbolift = SaveRefs.resolve_module_ref(data.get("at", {})) as ModuleTurbolift
	destination_module = SaveRefs.resolve_module_ref(data.get("to", {})) as ModuleTurbolift
	_door_left = maxf(float(data.get("door", 0.0)), 0.0)
	_saved_order = {}
	for key: String in ["pickup", "onboard", "boarding"]:
		var ids: Array[int] = []
		for id: Variant in data.get(key, []):
			ids.append(int(id))
		_saved_order[key] = ids

## Puts one restored ride back on this cab's lists, where the save had it
## (RideRequest.restore calls this, once per pawn).
func restore_request(request: RideRequest) -> void:
	match request.phase:
		RideRequest.Phase.WAITING, RideRequest.Phase.BOARDING:
			_insert_in_saved_order(pickup_requests, request, "pickup")
			var queued: Array[int] = _saved_order.get("boarding", [] as Array[int])
			if queued.has(request.pawn.pawn_id):
				_insert_in_saved_order(_boarding_queue, request, "boarding")
			if request.phase == RideRequest.Phase.BOARDING:
				_boarding = request
		RideRequest.Phase.ONBOARD:
			_insert_in_saved_order(onboard, request, "onboard")
	if request.stand_position != null:
		assigned_locations[request.stand_position] = request

func _insert_in_saved_order(list: Array[RideRequest], request: RideRequest, key: String) -> void:
	var order: Array[int] = _saved_order.get(key, [] as Array[int])
	var rank: int = order.find(request.pawn.pawn_id)
	var at: int = list.size()
	if rank >= 0:
		for index: int in list.size():
			var other: int = order.find(list[index].pawn.pawn_id) if is_instance_valid(list[index].pawn) else -1
			if other > rank:
				at = index
				break
	list.insert(at, request)

static func _pawn_ids(rides: Array[RideRequest]) -> Array:
	var out: Array = []
	for ride: RideRequest in rides:
		if is_instance_valid(ride.pawn):
			out.append(ride.pawn.pawn_id)
	return out
