class_name TurboliftShaft
extends RefCounted

var group_id: StringName
# All turbolift modules in this shaft (by floor/cell)
var floors: Array[ModuleTurbolift] = []
var cabs: Array[TurboliftCab] = []
## Shaft-wide force shutdown (WI-11 panel): mirrors PowerConsumptionComponent
## force_off across every floor, and onto floors that join later.
var force_shutdown: bool = false
## Max number of cabs for this shaft. Calling a cab will create one if fewer than
## this exist, a cab idling will destroy if there are more than this
var max_cabs: int = 1


func clear() -> void:
	floors.clear()
	for cab in cabs:
		cab.destroy()
	
	
func create_new_cab(start_module: ModuleTurbolift = null) -> void:
	var new_cab: TurboliftCab = Global.turbolift_manager.default_cab.instantiate() as TurboliftCab
	Global.world_manager.get_canvas_for_layer(WorldManager.StructureLayer.TURBOLIFT).add_child(new_cab)
	add_cab(new_cab, start_module)
	
func add_cab(cab: TurboliftCab, start_module: ModuleTurbolift = null) -> void:
	cab.shaft = self
	Global.path_manager.change_vertex_group(cab, group_id) 
	cabs.append(cab)
	if cab.current_turbolift == null and floors.size() > 0:
		var cab_module := floors[0]
		if start_module != null and floors.has(start_module):
			cab_module = start_module
		cab.set_apparent_position(cab_module.global_position)
		cab.current_turbolift = cab_module

# Register a turbolift module as part of this shaft
func register_floor(module: ModuleTurbolift) -> void:
	floors.append(module)
	module.shaft = self
	Global.path_manager.change_vertex_group(module, group_id, 1)
	_apply_force_shutdown_to(module)
	# Keep floors sorted
	floors.sort_custom(func(a: ModuleTurbolift, b: ModuleTurbolift) -> bool: return a.module_cell.y < b.module_cell.y)

## A floor's enabled flag flipped: fail rides that depended on it and let
## moving cabs re-plan their destination.
func on_floor_toggled(_module: ModuleTurbolift) -> void:
	for cab in cabs:
		cab.recheck_requests()

## Starts a ride from `from_floor` to `to_floor` and hands the pawn to it
## (WI-75 §5): it claims a queue spot, sets the pawn walking there, and returns.
## Nothing awaits - the ride goes on as the phases of the returned request, and
## [method dispatch] puts it on a cab when the queue walk ends.
##
## An already-CANCELLED request comes back when a floor can't board or alight
## (switched off, or not this shaft's), so the caller fails the movement and the
## pawn re-plans, by the stairs if there are any.
func request_ride(pawn: PawnBase, from_floor: ModuleTurbolift, to_floor: ModuleTurbolift) -> RideRequest:
	var request := RideRequest.new()
	request.pawn = pawn
	request.from_floor = from_floor
	request.to_floor = to_floor
	if not is_floor_served(from_floor) or not is_floor_served(to_floor):
		request.phase = RideRequest.Phase.CANCELLED
		request.cancelled = true
		return request
	if cabs.size() < max_cabs:
		create_new_cab(from_floor)
	var queue_spot: Vector2 = from_floor.assign_waiting_slot(request)
	request.phase = RideRequest.Phase.QUEUEING
	pawn.movement_component.begin_ride(request, queue_spot)
	return request

## The pawn has reached its queue spot: put the ride on the best cab, or fail it
## if the floors stopped serving it on the way or no cab can take it - every cab
## full and none allowed to spawn. The queue walk used to end inside
## request_ride's coroutine; this is the rest of that function.
func dispatch(request: RideRequest) -> void:
	if not is_instance_valid(request.from_floor) or not is_floor_served(request.from_floor) \
			or not is_instance_valid(request.to_floor) or not is_floor_served(request.to_floor):
		request.fail()
		return
	var best_cab: TurboliftCab = _best_cab_for(request)
	if best_cab == null:
		request.fail()
		return
	request.phase = RideRequest.Phase.WAITING
	best_cab.add_pickup_request(request)

func _best_cab_for(request: RideRequest) -> TurboliftCab:
	# 1. idle cab nearest from_floor
	# 2. else, a moving cab already headed toward from_floor in the right direction
	# 3. else, the cab with the shortest current stop queue
	# Doesn't need to be optimal — O(cabs) per request, and a shaft has a handful at most.
	var best_cab: TurboliftCab = null
	for cab: TurboliftCab in cabs:
		if cab.is_idle() and cab.is_available() and (best_cab == null or request.from_floor.global_position.distance_squared_to(cab.get_apparent_position()) < request.from_floor.global_position.distance_squared_to(best_cab.get_apparent_position())):
			best_cab = cab
	if best_cab:
		return best_cab
	for cab: TurboliftCab in cabs:
		if cab.is_available() and (cab.moving_up() == (cab.get_apparent_position().y > request.from_floor.global_position.y)) and (best_cab == null or request.from_floor.global_position.distance_squared_to(cab.get_apparent_position()) < request.from_floor.global_position.distance_squared_to(best_cab.get_apparent_position())):
			best_cab = cab
	if best_cab:
		return best_cab
	# Most free capacity as a proxy for the shortest current stop queue.
	for cab: TurboliftCab in cabs:
		if cab.is_available() and (best_cab == null or cab.get_available_capacity() > best_cab.get_available_capacity()):
			best_cab = cab
	return best_cab

## Is this module a floor of this shaft that rides may start/end at?
func is_floor_served(floor_module: ModuleBase) -> bool:
	var lift := floor_module as ModuleTurbolift
	return lift != null and lift.shaft == self and lift.floor_enabled

## Buy an extra cab with credits (cost lives on TurboliftManager). Returns
## false (and charges nothing) if unaffordable.
func buy_cab() -> bool:
	var credits: ResourceData = Global.resource_manager.credit_resource
	var cost: int = Global.turbolift_manager.cab_cost
	if credits.get_total() < cost:
		return false
	credits.force_withdraw(cost)
	max_cabs += 1
	return true

## Remove one cab; no refund. Destroys an idle cab immediately, otherwise
## queues the removal for the next cab that goes idle.
func remove_cab() -> void:
	if max_cabs <= 0:
		return
	max_cabs -= 1
	if cabs.size() > max_cabs:
		for cab in cabs:
			if cab.is_idle() and cab.onboard.is_empty() and cab.pickup_requests.is_empty():
				cabs.erase(cab)
				cab.destroy()
				return

## Called by a cab entering IDLE; true = the cab consumed a queued removal
## and has been destroyed.
func try_consume_pending_removal(cab: TurboliftCab) -> bool:
	if cabs.size() <= max_cabs or not cabs.has(cab):
		return false
	cabs.erase(cab)
	cab.destroy()
	return true

func set_force_shutdown(shutdown: bool) -> void:
	force_shutdown = shutdown
	for lift in floors:
		_apply_force_shutdown_to(lift)

func _apply_force_shutdown_to(lift: ModuleTurbolift) -> void:
	var power := lift.get_component_by_type(PowerConsumptionComponent) as PowerConsumptionComponent
	if power != null:
		power.force_off = force_shutdown

func merge(other: TurboliftShaft) -> void:
	if self == other:
		return
	for turbolift: ModuleTurbolift in other.floors:
		Global.path_manager.change_vertex_group(turbolift, group_id, 1)
		turbolift.shaft = self
		# The surviving shaft's shutdown state wins; floor_enabled flags
		# travel with their modules untouched.
		_apply_force_shutdown_to(turbolift)
	floors.append_array(other.floors)
	floors.sort_custom(func(a: ModuleTurbolift, b: ModuleTurbolift) -> bool: return a.module_cell.y < b.module_cell.y)
	for cab: TurboliftCab in other.cabs:
		cab.shaft = self
	cabs.append_array(other.cabs)
	max_cabs += other.max_cabs
	# rebuild=false above means a single flush (see section 2) covers the whole merge.

func split_at(module: ModuleTurbolift) -> void:
	var floor_index: int = floors.find(module)
	if floor_index == -1:
		return
	for cab: TurboliftCab in cabs.duplicate():
		if cab.current_turbolift == module:
			cabs.erase(cab)
			cab.destroy()
	if floor_index == 0 or floor_index == floors.size() - 1:
		# Top or bottom, not splitting
		floors.erase(module)
		return
	if floor_index < floors.size() - floor_index - 1:
		# Top half moved to new shaft
		_transfer_floors(0, floor_index)
		# Only keep bottom half
		floors = floors.slice(floor_index + 1, floors.size())
	else:
		# Bottom half moved to new shaft
		_transfer_floors(floor_index + 1, floors.size())
		floors = floors.slice(0, floor_index)
	for cab in cabs:
		cab.recheck_requests()
		
func _transfer_floors(start: int, end: int) -> void:
	var new_shaft: TurboliftShaft = Global.turbolift_manager.create_new_shaft()
	new_shaft.force_shutdown = force_shutdown
	var dup_cabs: Array[TurboliftCab] = cabs.duplicate()
	for i in range(start, end):
		new_shaft.register_floor(floors[i])
		for cab in dup_cabs:
			if cab.current_turbolift == floors[i]:
				new_shaft.add_cab(cab)
				cabs.erase(cab)
				cab.recheck_requests()

## Get all cabs that are currently at a specific floor
#func get_cabs_at_floor(floor_cell: Vector2i) -> Array[TurboliftCab]:
	#var result: Array[TurboliftCab] = []
	#for cab: TurboliftCab in cabs:
		#if cab.current_floor == floor_cell:
			#result.append(cab)
	#return result

## Check if this shaft has a floor at the specified cell
#func has_floor(cell: Vector2i) -> bool:
	#return floors.has(cell)
#
# Get the module at a specific floor
func get_floor_module(cell_y: int) -> ModuleTurbolift:
	if not floors.is_empty():
		var dist_from_top: int = cell_y - floors[0].module_cell.y
		if dist_from_top >= 0 and dist_from_top < floors.size():
			return floors[dist_from_top]
	return null
