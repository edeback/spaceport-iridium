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
	match state:
		CabState.WAITING:
			pass
		CabState.IDLE:
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
			var dist_to_move: float = speed * Global.CELL_SIZE.y * delta
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
				pickup_passengers(current_turbolift)
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

func _init() -> void:
	Global.path_manager.add_vertex(self, true) 

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
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
		for marker in assigned_locations:
			if assigned_locations[marker] == null:
				assigned_locations[marker] = ride
				ride.stand_position = marker
				ride.pawn.global_position = marker.global_position
				break
		ride.pawn.path_position_override = self
		pickup_requests.erase(ride)
		onboard.append(ride)
		ride.pawn.reparent(self)

func get_closest_exit() -> ModuleTurbolift:
	var best_lift: ModuleTurbolift = null
	var dist: float = -1
	for turbolift in shaft.floors:
		if turbolift.get_path_component().has_door_connected():
			if dist < 0 or turbolift.global_position.distance_squared_to(get_apparent_position()) < dist:
				dist = turbolift.global_position.distance_squared_to(get_apparent_position())
				best_lift = turbolift
	return best_lift

func recheck_requests() -> void:
	for request in pickup_requests.duplicate():
		if request.from_floor and request.from_floor.shaft != shaft:
			cancel_request(request)
	for request in onboard:
		if request.to_floor and request.to_floor.shaft != shaft:
			cancel_request(request)
	if not is_instance_valid(destination_module) or destination_module.shaft != shaft:
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
		request.pawn.current_module = request.from_floor
		request.finished.emit(false)
		return true
	if onboard.has(request):
		request.to_floor = null       # already riding — don't yank them out mid-shaft;
		return true                   # drop at whatever floor we next open doors at
	return false

# Unload all passengers that want to exit at this floor
func unload_passengers(cur_module: ModuleTurbolift) -> void:
	for request in onboard.duplicate():
		if request.to_floor == cur_module or request.to_floor == null:
			onboard.erase(request)
			assigned_locations[request.stand_position] = null
			request.actual_dropoff_floor = cur_module
			request.pawn.current_module = cur_module
			request.pawn.path_position_override = null
			request.pawn.reparent(cur_module.get_parent())
			request.finished.emit(request.to_floor != null)
			
			
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
	assigned_locations.clear()
	for request in onboard:
		request.pawn.path_position_override = null
		# Dump into hallway if it exists, will fallback to space automatically
		request.pawn.current_module = Global.world_manager.get_module_by_cell(WorldManager.StructureLayer.CORRIDOR, Global.world_to_cell(global_position))
		request.cancelled = true
		request.finished.emit(false)
	onboard.clear()
	for request in pickup_requests:
		request.pawn.current_module = request.from_floor
		request.cancelled = true
		request.finished.emit(false)
	pickup_requests.clear()
	shaft = null
	queue_free()
