class_name Job_GetResource
extends JobBase

@export var resource_data: ResourceData
@export var amount: int = 1

var origin: Vector2i
var destination: ModuleBase
var requester: Node
var pawn: PawnBase

var export_storage: StorageComponent
var deposit_storage: StorageComponent

enum ResourceJobState { Start, GoToResource, GatherResource, ReturnWithResource, DepositResource, Finished, Failed }
var job_state: ResourceJobState = ResourceJobState.Start:
	set(new_state):
		if job_state != new_state:
			job_state = new_state
			subtask_changed.emit()

func get_job_description() -> String:
	return "Get resource"

func get_subtask_description() -> String:
	match job_state:
		ResourceJobState.GoToResource:
			return "Going to resource"
		ResourceJobState.GatherResource:
			return "Gathering resource"
		ResourceJobState.ReturnWithResource:
			return "Returning with resource"
		ResourceJobState.DepositResource:
			return "Depositing resource"
	return ""

## A job sits on the board either "pull" (deposit_storage known, still
## hunting for a source) or "push" (export_storage known, still hunting for a
## destination). Either origin is enough to keep it alive while unclaimed.
func is_valid() -> bool:
	return requester != null and resource_data != null and (export_storage != null or deposit_storage != null)

func can_do_job(_pawn: PawnBase) -> bool:
	if _pawn.inventory_component != null and _pawn.inventory_component.space_available() <= 0:
		return false
	if deposit_storage != null and export_storage == null:
		# Pull: deposit side is fixed, need a reachable source with any stock.
		return Global.path_manager.is_reachable(_pawn, deposit_storage.owner_module) \
			and _find_export_storage(_pawn) != null
	if export_storage != null and deposit_storage == null:
		# Push: source side is fixed, need a reachable destination with room.
		return Global.path_manager.is_reachable(_pawn, export_storage.owner_module) \
			and _find_deposit_storage(_pawn) != null
	if export_storage != null and deposit_storage != null:
		# Fully specified (e.g. hand-authored) - just confirm both are reachable.
		return Global.path_manager.is_reachable(_pawn, export_storage.owner_module) \
			and Global.path_manager.is_reachable(_pawn, deposit_storage.owner_module)
	return false

func start_job(_pawn: PawnBase) -> void:
	pawn = _pawn
	job_start()
			
func is_finished() -> bool:
	return job_state == ResourceJobState.Finished
	
func is_failed() -> bool:
	return job_state == ResourceJobState.Failed
		
func cancel(as_failed: bool) -> void:
	if as_failed:
		job_state = ResourceJobState.Failed
	else:
		job_state = ResourceJobState.Finished
	# Deliberately don't touch pawn.movement here. If it's mid-ride, let it
	# finish on its own terms — the next job will retarget once it's free.
	if export_storage:
		export_storage.cancel_withdraw_job(self)
	if deposit_storage:
		deposit_storage.cancel_deposit_job(self)
		
			
func job_start() -> void:
	if deposit_storage != null and export_storage == null:
		export_storage = _find_export_storage(pawn)
	elif export_storage != null and deposit_storage == null:
		deposit_storage = _find_deposit_storage(pawn)
	if export_storage == null or deposit_storage == null:
		cancel(true)
		return
	# Narrow amount down to what this specific trip can actually move: capped
	# by what the pawn can carry and by what the source actually has right
	# now. Later trips (a fresh job next _process() tick) pick up any
	# remainder - this just makes sure we don't fail a job outright because
	# nowhere reachable happens to have the *entire* original request.
	var trip_cap: int = amount
	if pawn.inventory_component != null:
		trip_cap = mini(trip_cap, pawn.inventory_component.space_available())
	amount = mini(trip_cap, export_storage.total_stored_by_resource(resource_data))
	if amount <= 0:
		cancel(true)
		return
	destination = export_storage.owner_module
	export_storage.add_withdraw_job(self)
	deposit_storage.add_deposit_job(self)
	move_to_export_storage()

## Picks a reachable source of resource_data for a *pull* job (deposit_storage
## already fixed). Prefers a single reachable source that can fill the whole
## trip; if none exists, falls back to whichever reachable source has the
## most stock, so each trip empties as much as possible rather than the
## least. Pure query - safe to call from can_do_job() without side effects.
func _find_export_storage(_pawn: PawnBase) -> StorageComponent:
	var trip_cap: int = amount
	if _pawn.inventory_component != null:
		trip_cap = mini(trip_cap, _pawn.inventory_component.space_available())
	var best_full: StorageComponent = null
	var best_full_dist: int = 0
	var best_partial: StorageComponent = null
	var best_partial_amount: int = 0
	var best_partial_dist: int = 0
	for node in requester.get_tree().get_nodes_in_group("resource_storage"):
		var storage: StorageComponent = node as StorageComponent
		if storage == null or not storage.accepts_exports or storage.priority >= deposit_storage.priority:
			continue
		var available: int = storage.total_stored_by_resource(resource_data)
		if available <= 0 or not Global.path_manager.is_reachable(_pawn, storage.owner_module):
			continue
		var dist: int = storage.owner_module.module_cell.distance_squared_to(Global.world_to_cell(_pawn.global_position))
		if available >= trip_cap:
			if best_full == null or dist < best_full_dist:
				best_full = storage
				best_full_dist = dist
		elif available > best_partial_amount or (available == best_partial_amount and (best_partial == null or dist < best_partial_dist)):
			best_partial = storage
			best_partial_amount = available
			best_partial_dist = dist
	return best_full if best_full != null else best_partial

## Picks a reachable destination for a *push* job (export_storage already
## fixed). Prefers the highest-priority reachable sink with room, so pushed
## resources move as directly "uphill" toward their eventual home as
## possible, then nearest among equal priority. Pure query, same as above.
func _find_deposit_storage(_pawn: PawnBase) -> StorageComponent:
	var best: StorageComponent = null
	var best_priority: int = 0
	var best_dist: int = 0
	for node in requester.get_tree().get_nodes_in_group("resource_storage"):
		var storage: StorageComponent = node as StorageComponent
		if storage == null or not storage.accepts_imports or storage.priority <= export_storage.priority:
			continue
		if not storage.can_deposit(resource_data, 1) or not Global.path_manager.is_reachable(_pawn, storage.owner_module):
			continue
		var dist: int = storage.owner_module.module_cell.distance_squared_to(Global.world_to_cell(_pawn.global_position))
		if best == null or storage.priority > best_priority or (storage.priority == best_priority and dist < best_dist):
			best = storage
			best_priority = storage.priority
			best_dist = dist
	return best
	
		
func move_to_export_storage() -> void:
	job_state = ResourceJobState.GoToResource
	pawn.movement_component.movement_ended.connect(gather_resource, CONNECT_ONE_SHOT)
	pawn.movement_component.move_to(export_storage.owner_module)
		
func gather_resource(prev_success: bool) -> void:
	if not prev_success:
		cancel(true)
		return
	job_state = ResourceJobState.GatherResource
	var withdrawn: Array[ResourceStack] = export_storage.complete_withdraw_job(self)
	if not withdrawn.is_empty():
		# Resource now physically lives on the pawn, stack data and all. If the
		# job is canceled anywhere from here on, it stays with them instead of
		# disappearing.
		var leftover: Array[ResourceStack] = pawn.inventory_component.add_stacks(resource_data, withdrawn)
		if not leftover.is_empty():
			# Shouldn't normally happen - can_do_job() already checked the pawn
			# had room - but if it does, hand it straight back rather than
			# losing it.
			export_storage.deposit_stacks(resource_data, leftover, false)
		move_to_import_storage()
	else:
		cancel(true)
		
func move_to_import_storage() -> void:
	job_state = ResourceJobState.ReturnWithResource
	pawn.movement_component.movement_ended.connect(deposit_resource, CONNECT_ONE_SHOT)
	pawn.movement_component.move_to(deposit_storage.owner_module)
		
func deposit_resource(prev_success: bool) -> void:
	job_state = ResourceJobState.DepositResource
	if not prev_success:
		cancel(true)
		return
	var carried_stacks: Array[ResourceStack] = pawn.inventory_component.withdraw_stacks(resource_data, amount)
	if carried_stacks.is_empty():
		cancel(true)
		return
	if deposit_storage.complete_deposit_job(self, carried_stacks):
		job_state = ResourceJobState.Finished
		# Resolve any followup right here, synchronously - a component's own
		# _process() (e.g. ConstructionComponent's) could run before or after
		# the pawn's on any given frame, so we can't wait for the pawn to ask
		# later and expect to win that race. This does.
		var followup: JobBase = get_followup_job(pawn)
		if followup != null:
			pawn.queue_job(followup, true)
	else:
		# Couldn't deposit — give it back so it isn't lost.
		pawn.inventory_component.add_stacks(resource_data, carried_stacks)
		cancel(true)

func get_followup_job(pawn: PawnBase) -> JobBase:
	if deposit_storage == null or not is_instance_valid(deposit_storage.owner_module):
		return null
	for component: ComponentBase in deposit_storage.owner_module.components:
		var offered: JobBase = component.offer_followup_job(pawn)
		if offered != null:
			return offered
	return null
