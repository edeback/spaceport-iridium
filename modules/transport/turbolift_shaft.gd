class_name TurboliftShaft
extends RefCounted

var group_id: StringName
# All turbolift modules in this shaft (by floor/cell)
var floors: Array[ModuleTurbolift] = []
var cabs: Array[TurboliftCab] = []
var open_requests: Array[RideRequest] = []


	
func clear() -> void:
	floors.clear()
	for cab in cabs:
		cab.destroy()
	
func add_cab(cab: TurboliftCab) -> void:
	cab.shaft = self
	Global.world_manager.get_canvas_for_layer(WorldManager.StructureLayer.TURBOLIFT).add_child(cab)
	Global.path_manager.add_vertex(cab, true, group_id) 
	cabs.append(cab)
	if cab.current_turbolift == null and floors.size() > 0:
		cab.global_position = floors[0].global_position
		cab.current_turbolift = floors[0]

# Register a turbolift module as part of this shaft
func register_floor(module: ModuleTurbolift) -> void:
	Global.path_manager.graph.change_vertex_group(module, group_id, 1, false)
	floors.append(module)
	module.shaft = self
	# Keep floors sorted
	floors.sort_custom(func(a: ModuleTurbolift, b: ModuleTurbolift) -> bool: return a.module_cell.y < b.module_cell.y)
	if floors.size() == 1:
		# move cabs here
		for cab in cabs:
			cab.global_position = module.global_position

# Unregister a floor (when module is removed)
func unregister_floor(module: ModuleTurbolift) -> void:
	floors.erase(module.module_cell)
	# Was sorted, should continue to be sorted
	

func request_ride(pawn: PawnBase, from_floor: ModuleBase, to_floor: ModuleBase, cancel_signal: Signal) -> RideRequest:
	var request := RideRequest.new()
	request.pawn = pawn
	request.from_floor = from_floor
	request.to_floor = to_floor
	from_floor.assign_waiting_slot(pawn)
	var best_cab: TurboliftCab = _best_cab_for(request)
	if best_cab:
		best_cab.add_pickup_request(request)
	var on_cancel := func(): _cancel(request)
	cancel_signal.connect(on_cancel, CONNECT_ONE_SHOT)
	await request.finished
	if cancel_signal.is_connected(on_cancel):
		cancel_signal.disconnect(on_cancel)
	#_release_waiting_slot(from_floor, pawn)
	return request

func _cancel(request: RideRequest) -> void:
	if request.cancelled:
		return
	request.cancelled = true
	for cab in cabs:
		if cab.cancel_request(request):
			return

func _best_cab_for(request: RideRequest) -> TurboliftCab:
	# 1. idle cab nearest from_floor
	# 2. else, a moving cab already headed toward from_floor in the right direction
	# 3. else, the cab with the shortest current stop queue
	# Doesn't need to be optimal — O(cabs) per request, and a shaft has a handful at most.
	var best_cab: TurboliftCab = null
	for cab: TurboliftCab in cabs:
		if cab.is_idle() and cab.is_available() and (best_cab == null or request.from_floor.global_position.distance_squared_to(cab.global_position) < request.from_floor.global_position.distance_squared_to(best_cab.global_position)):
			best_cab = cab
	if best_cab:
		return best_cab
	for cab: TurboliftCab in cabs:
		if cab.is_available() and (cab.moving_up() == (cab.global_position.y > request.from_floor.global_position.y)) and (best_cab == null or request.from_floor.global_position.distance_squared_to(cab.global_position) < request.from_floor.global_position.distance_squared_to(best_cab.global_position)):
			best_cab = cab
	if best_cab:
		return best_cab
	for cab: TurboliftCab in cabs:
		if cab.is_available() and best_cab == null or cab.get_available_capacity() < best_cab.get_available_capacity():
			best_cab = cab
	return best_cab

func merge(other: TurboliftShaft) -> void:
	if self == other:
		return
	for turbolift: ModuleTurbolift in other.floors:
		Global.path_manager.graph.change_vertex_group(turbolift, group_id, 1, false)
		turbolift.shaft = self
	floors.append_array(other.floors)
	floors.sort_custom(func(a: ModuleTurbolift, b: ModuleTurbolift) -> bool: return a.module_cell.y < b.module_cell.y)
	for cab: TurboliftCab in other.cabs:
		cab.shaft = self
	cabs.append_array(other.cabs)
	# rebuild=false above means a single flush (see section 2) covers the whole merge.

func split_at(module: ModuleTurbolift) -> void:
	var floor_index: int = floors.find(module)
	if floor_index == -1:
		return
	for cab in cabs:
		if cab.current_turbolift == module:
			cab.destroy()
	if floor_index != -1 and floor_index == 0 or floor_index == floors.size() - 1:
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
		
func _transfer_floors(start: int, end: int) -> void:
	var new_shaft: TurboliftShaft = Global.turbolift_manager.create_new_shaft()
	var dup_cabs: Array[TurboliftCab] = cabs.duplicate()
	for i in range(start, end):
		new_shaft.register_floor(floors[i])
		for cab in dup_cabs:
			if cab.current_turbolift == floors[i]:
				new_shaft.add_cab(cab)
				cabs.erase(cab)

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
