class_name Job_CollectPile
extends JobBase

## Walks a pawn to a ResourcePile (either sitting inside a module, or
## free-floating in space), picks up one resource type, and carries it to
## the nearest reachable storage that will take it.
##
## Deliberately does NOT reserve space in deposit_storage ahead of time -
## same tradeoff Job_MineAsteroid.deposit_material() already makes.
## Reserving would mean touching StorageData's job-tracking arrays, which
## are hard-typed to Job_GetResource. Instead, whatever doesn't fit when we
## get there stays on the pawn and gets swept up by Job_StoreInventory on
## the next idle tick - the same fallback used everywhere else a deposit
## can fail after the trip's already been made.

var pawn: PawnBase
var pile: ResourcePile
var resource_data: ResourceData
var amount: int = 0
var deposit_storage: StorageComponent

enum CollectPileState { Starting, MovingToPile, GatherFromPile, ReturningToModule, DepositResource, Finished, Failed }
var state: CollectPileState = CollectPileState.Starting:
	set(new_state):
		if new_state != state:
			state = new_state
			subtask_changed.emit()

func get_category() -> Category:
	return Category.HAUL

func get_job_description() -> String:
	return "Collect Resource Pile"

func get_subtask_description() -> String:
	match state:
		CollectPileState.MovingToPile:
			return "Moving to resource pile"
		CollectPileState.GatherFromPile:
			return "Gathering from pile"
		CollectPileState.ReturningToModule:
			return "Returning with resources"
		CollectPileState.DepositResource:
			return "Depositing resources"
	return ""

## Called once by ResourcePile._ensure_collection_job() right after the job
## is constructed - not a general-purpose setter, always call before adding
## to the job board.
func setup(_pile: ResourcePile, _resource_data: ResourceData) -> void:
	pile = _pile
	resource_data = _resource_data
	pile.despawning.connect(_pile_despawned)

func is_valid() -> bool:
	return is_instance_valid(pile) and resource_data != null and pile.get_available(resource_data) > 0

func can_do_job(_pawn: PawnBase) -> bool:
	if _pawn.inventory_component != null and _pawn.inventory_component.space_available() <= 0:
		return false
	if not is_instance_valid(pile) or pile.get_available(resource_data) <= 0:
		return false
	if pile.parent_module != null:
		if not is_instance_valid(pile.parent_module) or not Global.path_manager.is_reachable(_pawn, pile.parent_module):
			return false
	elif not Global.path_manager.is_space_reachable(_pawn):
		return false
	return _find_deposit_storage(_pawn) != null

func start_job(_pawn: PawnBase) -> void:
	pawn = _pawn
	job_start()

func is_finished() -> bool:
	return state == CollectPileState.Finished

func is_failed() -> bool:
	return state == CollectPileState.Failed

# The pile reservation is NOT idempotent to release (plain counter), so the
# base class's _ended guard mattering here is exactly why the lifecycle
# contract exists: _on_cancel runs at most once.
func _on_cancel(as_failed: bool) -> void:
	if as_failed:
		state = CollectPileState.Failed
	else:
		state = CollectPileState.Finished
	if is_instance_valid(pile) and amount > 0:
		pile.cancel_reservation(resource_data, amount)

func job_start() -> void:
	if not is_instance_valid(pile):
		cancel(true)
		return
	deposit_storage = _find_deposit_storage(pawn)
	if deposit_storage == null:
		cancel(true)
		return
	# Narrow amount down to what this trip can actually move: capped by
	# what's left in the pile, what the pawn can carry, and what the
	# storage we found currently has room for. Mirrors the trip_cap logic
	# in Job_GetResource.job_start().
	var trip_cap: int = pile.get_available(resource_data)
	if pawn.inventory_component != null:
		trip_cap = mini(trip_cap, pawn.inventory_component.space_available())
	trip_cap = mini(trip_cap, deposit_storage.space_available())
	amount = trip_cap
	if amount <= 0:
		cancel(true)
		return
	if not pile.reserve(resource_data, amount):
		cancel(true)
		return
	move_to_pile()

## Nearest reachable storage that accepts this resource and has room.
## Pure query - safe to call from can_do_job() without side effects. Same
## shape as Job_GetResource._find_deposit_storage(), minus the priority
## comparison (a pile has no priority of its own to compare against).
func _find_deposit_storage(_pawn: PawnBase) -> StorageComponent:
	var best: StorageComponent = null
	var best_priority: int = 0
	var best_dist: int = 0
	for node in _pawn.get_tree().get_nodes_in_group("resource_storage"):
		var storage: StorageComponent = node as StorageComponent
		if storage == null or not storage.accepts_imports:
			continue
		if not storage.can_deposit(resource_data, 1) or not Global.path_manager.is_reachable(_pawn, storage.owner_module):
			continue
		var dist: int = storage.owner_module.module_cell.distance_squared_to(Global.world_to_cell(_pawn.global_position))
		if best == null or storage.priority > best_priority or (storage.priority == best_priority and dist < best_dist):
			best = storage
			best_priority = storage.priority
			best_dist = dist
	return best

func _pile_despawned() -> void:
	if state < CollectPileState.GatherFromPile:
		cancel(true)
	# else: we already have the goods in hand, nothing to do

func move_to_pile() -> void:
	state = CollectPileState.MovingToPile
	pawn.movement_component.movement_ended.connect(gather_from_pile, CONNECT_ONE_SHOT)
	if pile.parent_module != null:
		# Not a graph vertex - path to the module itself, same as pathing
		# to any other in-module target.
		pawn.movement_component.move_to(pile.parent_module, 1, false)
	else:
		# Splices in via ModuleGraph.pathfind_to_node_in_space for just this
		# one pathfind, same mechanism AsteroidBase pathing uses.
		pawn.movement_component.move_to(pile, 1, true)

func gather_from_pile(prev_success: bool) -> void:
	# _ended: a stale movement one-shot firing after an external cancel must
	# not withdraw from the pile - _on_cancel already released our reservation,
	# so a late withdraw would take stock reserved by someone else.
	if not prev_success or _ended:
		cancel(true)
		return
	state = CollectPileState.GatherFromPile
	var gathered: Array[ResourceStack] = pile.withdraw_stacks(resource_data, amount)
	if gathered.is_empty():
		cancel(true)
		return
	# withdraw_stacks consumed that much of our reservation; shrink `amount`
	# so a later cancel only releases the truly un-gathered remainder instead
	# of double-releasing (and eating another job's reservation).
	var gathered_total: int = 0
	for stack: ResourceStack in gathered:
		gathered_total += stack.amount
	amount = maxi(amount - gathered_total, 0)
	var leftover: Array[ResourceStack] = pawn.inventory_component.add_stacks(resource_data, gathered)
	if not leftover.is_empty():
		# Shouldn't normally happen - can_do_job()/job_start() already
		# checked the pawn had room - but if it does, hand it straight back
		# instead of losing it.
		pile.add_stacks(resource_data, leftover)
	move_to_deposit_storage()

func move_to_deposit_storage() -> void:
	state = CollectPileState.ReturningToModule
	pawn.movement_component.movement_ended.connect(deposit_resource, CONNECT_ONE_SHOT)
	pawn.movement_component.move_to(deposit_storage.owner_module)

func deposit_resource(prev_success: bool) -> void:
	# Guard BEFORE setting state: setting DepositResource on an already-ended
	# job would overwrite the terminal state with no way to correct it (the
	# _ended latch blocks re-cancel), leaving the pawn stuck forever.
	if not prev_success or _ended:
		cancel(true)
		return
	state = CollectPileState.DepositResource
	var carried_amount: int = pawn.inventory_component.get_carried_amount(resource_data)
	var deposit_amount: int = mini(carried_amount, deposit_storage.space_available())
	if deposit_amount <= 0:
		# Someone else filled it up while we were walking over - leave it on
		# the pawn, Job_StoreInventory will retry next idle tick.
		cancel(true)
		return
	var withdrawn: Array[ResourceStack] = pawn.inventory_component.withdraw_stacks(resource_data, deposit_amount)
	if not withdrawn.is_empty() and deposit_storage.deposit_stacks(resource_data, withdrawn):
		state = CollectPileState.Finished
	else:
		if not withdrawn.is_empty():
			pawn.inventory_component.add_stacks(resource_data, withdrawn)
		cancel(true)
