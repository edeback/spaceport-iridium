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

func get_category() -> Category:
	return Category.HAUL

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
			and StorageQuery.find_source(_pawn, resource_data,
				StorageQuery.trip_cap(_pawn, amount), deposit_storage.priority) != null
	if export_storage != null and deposit_storage == null:
		# Push: source side is fixed, need a reachable destination with room.
		return Global.path_manager.is_reachable(_pawn, export_storage.owner_module) \
			and StorageQuery.find_sink(_pawn, resource_data, export_storage.priority) != null
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
		
func _on_cancel(as_failed: bool) -> void:
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
	# Narrow amount down to what this specific trip can actually move: capped
	# by what the pawn can carry and by what the source actually has right
	# now. Later trips (a fresh job next _process() tick) pick up any
	# remainder - this just makes sure we don't fail a job outright because
	# nowhere reachable happens to have the *entire* original request.
	var trip_cap: int = StorageQuery.trip_cap(pawn, amount)
	if deposit_storage != null and export_storage == null:
		export_storage = StorageQuery.find_source(pawn, resource_data, trip_cap, deposit_storage.priority)
	elif export_storage != null and deposit_storage == null:
		deposit_storage = StorageQuery.find_sink(pawn, resource_data, export_storage.priority)
	if export_storage == null or deposit_storage == null:
		cancel(true)
		return
	amount = mini(trip_cap, export_storage.total_stored_by_resource(resource_data))
	if amount <= 0:
		cancel(true)
		return
	destination = export_storage.owner_module
	export_storage.add_withdraw_job(self)
	deposit_storage.add_deposit_job(self)
	move_to_export_storage()

func move_to_export_storage() -> void:
	job_state = ResourceJobState.GoToResource
	pawn.movement_component.movement_ended.connect(gather_resource, CONNECT_ONE_SHOT)
	pawn.movement_component.move_to(export_storage.owner_module)
		
func gather_resource(prev_success: bool) -> void:
	if not prev_success or _ended:
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
	if not prev_success or _ended:
		cancel(true)
		return
	job_state = ResourceJobState.DepositResource
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

# --- persistence (WI-21) ------------------------------------------------------

## Both endpoints are recorded (a running haul has both); restore re-reserves
## against them through job_start()'s fully-specified branch. A pawn carrying
## cargo when saved sweeps it via Job_StoreInventory before this re-runs, so the
## re-withdraw doesn't duplicate. Reservations themselves are never saved.
func get_save_data() -> Dictionary:
	if resource_data == null or resource_data.id == &"":
		return {}
	return {
		"type": "get_resource",
		"resource": String(resource_data.id),
		"amount": amount,
		"export": SaveManager.component_ref(export_storage),
		"deposit": SaveManager.component_ref(deposit_storage),
	}

static func restore(data: Dictionary) -> JobBase:
	var resource: ResourceData = Global.save_manager.get_resource_by_id(StringName(String(data.get("resource", ""))))
	if resource == null:
		return null
	var export_component: StorageComponent = SaveManager.resolve_component_ref(data.get("export", {})) as StorageComponent
	var deposit_component: StorageComponent = SaveManager.resolve_component_ref(data.get("deposit", {})) as StorageComponent
	# Need at least one live endpoint; job_start() re-finds the other side if
	# only one survived, or cancels cleanly if neither works out on this tick.
	if export_component == null and deposit_component == null:
		return null
	var job := Job_GetResource.new()
	job.resource_data = resource
	job.amount = maxi(int(data.get("amount", 1)), 1)
	job.export_storage = export_component
	job.deposit_storage = deposit_component
	# requester drives is_valid() and the source/dest finders; the posting
	# storage isn't recorded, so anchor to a surviving endpoint component.
	job.requester = deposit_component if deposit_component != null else export_component
	return job
