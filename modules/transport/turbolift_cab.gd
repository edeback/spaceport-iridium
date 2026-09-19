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
enum CabState { WAITING, IDLE, MOVING, DOORS_OPEN }
var state: CabState = CabState.IDLE
var assigned_locations: Dictionary[Marker2D, RideRequest] = {}
var current_turbolift: ModuleTurbolift = null

# Destination floor when moving
var destination_module: ModuleTurbolift

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
		CabState.WAITING:
			pass
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
			# On arrival at a floor that's in `stops`: state = State.DOORS_OPEN.
			var dist_to_move: float = speed * Global.CELL_SIZE.y * sim_delta
			var dist_left: float = destination_module.global_position.y - get_apparent_position().y
			# Probably want to recheck where we're going and stopping to pick up people on the way?
			#var next_floor: ModuleTurbolift = shaft.get_floor_module(Global.world_to_cell(global_position).y + signf(dist_left))
			
			if dist_to_move >= absf(dist_left):
				set_apparent_position_y(destination_module.global_position.y)
				state = CabState.DOORS_OPEN
			else:
				global_position.y += dist_to_move * signf(dist_left)
			current_turbolift = shaft.get_floor_module(Global.world_to_cell(global_position).y)
		CabState.DOORS_OPEN:
			if current_turbolift != null:
				state = CabState.WAITING
				await current_turbolift.set_door(false)
				unload_passengers(current_turbolift)
				await pickup_passengers(current_turbolift)
				if onboard.size() > 0:
					destination_module = onboard[0].to_floor
					state = CabState.MOVING
				else:
					state = CabState.IDLE
			else:
				state = CabState.IDLE
			# Drop off onboard requests whose to_floor == current floor -> request.arrived.emit().
			# Pick up waiting requests at this floor, up to capacity -> onboard.append(...).
			# After a short timer: state = State.IDLE.
			pass


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
	#SignalBus.module_removed.connect(module_removed)
	for marker in standing_locations:
		assigned_locations[marker] = null

#func module_removed(removed_module: ModuleBase) -> void:
	#for ride in pickup_requests:
		#if ride.to_floor == removed_module:
			## Cancel
			#ride.pawn.current_module = ride.from_floor
			#pickup_requests.erase(ride)
			#ride.finished.emit(false)
	#if destination_module == removed_module:
		#destination_module = null
	#recheck_requests()
		

func add_pickup_request(request: RideRequest) -> void:
	pickup_requests.append(request)
	
func pickup_passengers(cur_module: ModuleTurbolift) -> void:
	var entering_passengers: Array[RideRequest] = []
	for ride in pickup_requests:
		if ride.from_floor == cur_module:
			entering_passengers.append(ride)
			
	for ride in entering_passengers:
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
		if free_marker != null:
			assigned_locations[free_marker] = ride
			ride.stand_position = free_marker
			# Walk from the waiting spot into the cab, one pawn at a time
			# (WI-16) - the doors stay open (cab is WAITING) while we board.
			await ride.pawn.walk_straight_to(free_marker.global_position)
			if ride.cancelled or not is_instance_valid(ride.pawn):
				# Cancelled mid-boarding (floor toggled, cab destroyed): the
				# cancel path already emitted finished - don't board a dead ride.
				assigned_locations[free_marker] = null
				continue
		pickup_requests.erase(ride)
		onboard.append(ride)
		ride.pawn.reparent(self)
		# Boarding complete: the cab owns the pawn's position from here (WI-20).
		# finished(true) ends the awaited part of request_ride - the ride itself
		# is cab-driven and resolved via exit_conveyed at drop-off.
		ride.pawn.movement_component.enter_conveyed(self)
		ride.finished.emit(true)

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

func cancel_request(request: RideRequest) -> bool:
	request.cancelled = true
	if pickup_requests.has(request):
		pickup_requests.erase(request)          # never picked up — just drop it
		request.release_queue_anchor()
		request.pawn.current_module = request.from_floor
		request.finished.emit(false)
		return true
	if onboard.has(request):
		request.to_floor = null       # already riding — don't yank them out mid-shaft;
		return true                   # drop at whatever floor we next open doors at
	return false

# Unload all passengers that want to exit at this floor
func unload_passengers(cur_module: ModuleTurbolift) -> void:
	for request: RideRequest in onboard.duplicate():
		if request.to_floor == cur_module or request.to_floor == null:
			onboard.erase(request)
			assigned_locations[request.stand_position] = null
			if not is_instance_valid(request.pawn):
				continue
			request.actual_dropoff_floor = cur_module
			request.pawn.current_module = cur_module
			request.pawn.reparent(cur_module.get_parent())
			# Normal arrival and a cancelled ride's next-stop drop are the same
			# handoff (WI-20): exit_conveyed repaths from this floor, so a
			# diverted drop-off self-corrects and a dead target just fails.
			request.pawn.movement_component.exit_conveyed()
			
			
func get_onboard_request_for(pawn: PawnBase) -> RideRequest:
	for request in onboard:
		if request.pawn == pawn:
			return request
	return null

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
		if not is_instance_valid(request.pawn):
			continue
		# Dump into hallway if it exists, will fallback to space automatically.
		# No finished emit - boarding already resolved it (WI-20).
		request.pawn.current_module = Global.world_manager.get_module_by_cell(WorldManager.StructureLayer.CORRIDOR, Global.world_to_cell(global_position))
		if request.pawn.get_parent() == self:
			# The module-change setter only reparents on a layer change; force
			# the pawn out regardless - it must not be freed with the cab.
			request.pawn.reparent(Global.world_manager.get_canvas_for_layer(request.pawn.current_layer))
		request.pawn.movement_component.exit_conveyed()
	onboard.clear()
	for request in pickup_requests:
		request.release_queue_anchor()
		request.pawn.current_module = request.from_floor
		request.cancelled = true
		request.finished.emit(false)
	pickup_requests.clear()
	shaft = null
	queue_free()
