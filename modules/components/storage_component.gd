class_name StorageComponent
extends ComponentBase

@export var priority: int = 1
@export var max_stored: int = 10
@export var power_consumption_component: PowerConsumptionComponent

@export var include_in_stats: bool = true

@export var accepts_imports: bool = true
@export var accepts_exports: bool = true

## Can we store anything in here if we want?
@export var allow_any_resource: bool = false
@export var storage_data: Dictionary[ResourceData, StorageData] = {}

#@export var stored_resources: Array[ResourceData]
#@export var cur_stored: Dictionary[ResourceData, float] = {}
#@export var cur_reserved_withdraw: Dictionary[ResourceData, float] = {}
#@export var cur_reserved_deposit: Dictionary[ResourceData, float] = {}
#@export var default_import_jobs: Dictionary[ResourceData, Job_GetResource] = {}

@export var display_info_panel_ui: bool = true
@export var storage_ui: ProgressBar
@export var display_storage_ui: bool = true:
	set(new_display):
		if new_display != display_storage_ui:
			display_storage_ui = new_display
			storage_ui.visible = display_storage_ui
@export var player_configurable: bool = false
@export var construction_storage: bool = false

#var stock_reserved: Dictionary[ResourceData, float] = {}
#var space_reserved: Dictionary[ResourceData, float] = {}

var export_jobs: Array[Job_GetResource] = []
var import_jobs: Array[Job_GetResource] = []

const SMALL_FLOAT: float = 0.000001

var storage_value_changed: bool = true
## Whether the import/export job-posting scan runs; tracks the same lifecycle
## states set_process used to gate (blueprint construction storage, or
## constructed regular storage).
var _posting_active: bool = false
signal storage_changed(resource: ResourceData, new_value: int)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super()
	# Posting scans run on the sim slow tick, not per frame, so they pause and
	# fast-forward with the game. (Connections auto-clean when this is freed.)
	Global.time_manager.slow_tick.connect(_on_slow_tick)
	# Editor-set StorageData are shared scene subresources; runtime mutates
	# them (stored counts, stack arrays), which leaks state across scene
	# reloads - reloading main.tscn mid-session (loading a save) would re-run
	# this setup on already-mutated data and duplicate stock. Work on deep
	# private copies so the authored resource stays pristine.
	for resource: ResourceData in storage_data.keys():
		storage_data[resource] = storage_data[resource].duplicate(true)
	# Set up storage data that was set in the editor
	for storage: StorageData in storage_data.values():
		var num_to_create: int = storage.stored
		if num_to_create > 0:
			storage.stored = 0
			storage.deposit(num_to_create, false)
		if accepts_imports:
			storage.desired = max_stored
		
func empty_all() -> void:
	for resource: ResourceData in storage_data:
		resource.needs_recalc = true
	storage_data.clear()
	storage_changed.emit()

func ready_preview() -> void:
	set_process(false)
	_posting_active = false

func ready_blueprint() -> void:
	if construction_storage:
		display_info_panel_ui = true
		add_to_group(Groups.RESOURCE_STORAGE)
		set_process(true)
		_posting_active = true
	else:
		display_info_panel_ui = false
		set_process(false)
		_posting_active = false

func ready_constructed() -> void:
	if construction_storage:
		display_info_panel_ui = false
		remove_from_group(Groups.RESOURCE_STORAGE)
		set_process(false)
		_posting_active = false
	else:
		display_info_panel_ui = true
		add_to_group(Groups.RESOURCE_STORAGE)
		set_process(true)
		_posting_active = true
		if include_in_stats:
			for resource: ResourceData in storage_data:
				resource.register_component(self)

func add_stored_resource(resource: ResourceData) -> void:
	if not storage_data.has(resource):
		var new_data := StorageData.new()
		new_data.resource_data = resource
		new_data.desired = max_stored
		storage_data[resource] = new_data
		if include_in_stats:
			resource.register_component(self)
			
func remove_stored_resource(resource: ResourceData) -> void:
	var data: StorageData = storage_data.get(resource)
	if data:
		data.end_all_jobs()
		storage_data.erase(resource)
		if include_in_stats:
			resource.unregister_component(self)
		
	#if stored_resources.has(resource):
		#stored_resources.erase(resource)
		#cur_stored.erase(resource)
		#cur_reserved_deposit.erase(resource)
		#cur_reserved_withdraw.erase(resource)
		#if include_in_stats:
			#Global.resource_manager.unregister_component(resource, self)
		#if default_import_jobs.has(resource):
			#default_import_jobs[resource].cancel(true)
			#default_import_jobs.erase(resource)
		#var jobs_to_keep: Array[Job_GetResource] = []
		#for job: Job_GetResource in export_jobs:
			#if job.resource_data == resource:
				#job.cancel(true)
			#else:
				#jobs_to_keep.append(job)
		#export_jobs = jobs_to_keep
		#jobs_to_keep = []
		#for job: Job_GetResource in import_jobs:
			#if job.resource_data == resource:
				#job.cancel(true)
			#else:
				#jobs_to_keep.append(job)
		#import_jobs = jobs_to_keep
			

# UI-only per-frame work; the posting scan lives in _on_slow_tick.
func _process(_delta: float) -> void:
	# Move to only when changed
	if display_storage_ui and storage_value_changed:
		storage_value_changed = false
		update_storage_ui()

func _on_slow_tick(_interval: float) -> void:
	if not _posting_active:
		return
	if power_consumption_component and not power_consumption_component.powered:
		last_error = "No power!"
		return
	last_error = ""
	# Autodump destroys extra resources (in case you are just overwhelmed with them)
	for resource: ResourceData in storage_data.keys():
		var data: StorageData = storage_data[resource]
		if data.autodump:
			var dump_amount: int = data.autodump_amount()
			if dump_amount > 0:
				destroy_resource(resource, dump_amount)
	if accepts_imports:
		# Shared budget across resources so several under-desired resources in
		# the same bin don't each request up to the bin's full free space and
		# jointly overcommit it before any pawn has actually moved anything.
		var import_budget: int = space_available(true)
		for resource: ResourceData in storage_data:
			if import_budget <= 0:
				break
			var data := storage_data[resource]
			if data.import_job != null:
				continue
			# Positive when we're short of desired once already-incoming
			# deposits count as "here" and already-reserved withdrawals count
			# as "gone" - same accounting the trigger below used to use.
			var deficit: int = data.desired - data.stored - data.reserved_deposit + data.reserved_withdraw
			if deficit <= 0:
				continue
			var request_amount: int = mini(deficit, import_budget)
			var new_job: Job_GetResource = Job_GetResource.new()
			new_job.requester = self
			new_job.resource_data = resource
			new_job.deposit_storage = self
			new_job.priority = priority
			new_job.amount = request_amount
			data.import_job = new_job
			Global.job_manager.add_job(new_job)
			import_budget -= request_amount
	if accepts_exports:
		for resource: ResourceData in storage_data:
			var data := storage_data[resource]
			if data.export_job != null:
				continue
			var surplus: int = data.stored - data.reserved_withdraw - data.desired
			if surplus <= 0:
				continue
			var new_job: Job_GetResource = Job_GetResource.new()
			new_job.requester = self
			new_job.resource_data = resource
			new_job.export_storage = self
			new_job.priority = priority
			new_job.amount = surplus
			data.export_job = new_job
			Global.job_manager.add_job(new_job)

func update_storage_ui() -> void:
	var filled_space := max_stored - space_available()
	storage_ui.value = float(filled_space) / max_stored

func _exit_tree() -> void:
	if include_in_stats:
		for resource: ResourceData in storage_data:
			resource.unregister_component(self)
	for data: StorageData in storage_data.values():
		data.end_all_jobs()
			
## Drains every resource this component holds into `pile` (preserving
## instance_data), for module destruction/ejection. Bypasses the normal
## deposit_jobs/reserved bookkeeping entirely - this is an immediate,
## unconditional dump, not a job-mediated transfer.
func dump_all_to_pile(pile: ResourcePile) -> void:
	for resource: ResourceData in storage_data.keys():
		var data: StorageData = storage_data[resource]
		if data.stored <= 0:
			continue
		var stacks: Array[ResourceStack] = data.withdraw_stacks(data.stored)
		pile.add_stacks(resource, stacks)
		storage_value_changed = true
		storage_changed.emit(resource, data.stored)
		resource.needs_recalc = true
	
func destroy_resource(resource: ResourceData, amount: int) -> void:
	var data: StorageData = storage_data[resource]
	data.withdraw_stacks(amount, ResourceStackContainer.WithdrawStrategy.FIFO)
	storage_value_changed = true
	storage_changed.emit(resource, data.stored)
	resource.needs_recalc = true
	
func update_priority(new_priority: int) -> void:
	if priority != new_priority:
		priority = new_priority
		for data: StorageData in storage_data.values():
			data.set_job_priority(new_priority)
		#for job: Job_GetResource in default_import_jobs.values():
			#job.priority = priority
	
	
func can_store_resource(resource: ResourceData) -> bool:
	if allow_any_resource:
		return true
	return storage_data.has(resource)
	#var has_resource: bool = stored_resources.has(resource)
	#if resource.base_resource != null:
		#has_resource = has_resource or stored_resources.has(resource.base_resource)
	#return has_resource

func can_withdraw(resource: ResourceData, quantity: int, use_reserve: bool = false) -> bool:
	var data: StorageData = storage_data.get(resource)
	if data:
		return data.can_withdraw(quantity, use_reserve)
	return false
		
	#if can_store_resource(resource):
		#var available: float = cur_stored.get_or_add(resource, 0.0)
		#if not use_reserve:
			#available -= cur_reserved_withdraw.get_or_add(resource, 0)
		#return available + SMALL_FLOAT >= quantity
	
func withdraw(resource: ResourceData, quantity: int, use_reserve: bool = false) -> bool:
	var data: StorageData = storage_data.get(resource)
	if data:
		if data.try_withdraw(quantity, use_reserve):
			storage_value_changed = true
			storage_changed.emit(resource, data.stored)
			resource.needs_recalc = true
			return true
	return false
		
	#if can_withdraw(resource, quantity, use_reserve):
		#var new_value: float = max(cur_stored[resource] - quantity, 0)
		#cur_stored[resource] = new_value
		#if use_reserve:
			#cur_reserved_withdraw[resource] = max(cur_reserved_withdraw.get_or_add(resource, 0) - quantity, 0)
		#storage_changed.emit(resource, new_value)
		#return true
	#return false
	
func withdraw_up_to(resource: ResourceData, quantity: int, use_reserve: bool = false) -> int:
	var data: StorageData = storage_data.get(resource)
	if data:
		var withdrawn := data.withdraw_up_to(quantity, use_reserve)
		if withdrawn > 0:
			storage_value_changed = true
			storage_changed.emit(resource, data.stored)
			resource.needs_recalc = true
		return withdrawn
	return 0
	
	#if  cur_stored.has(resource):
		#var max_withdrawable: float = max(cur_stored.get_or_add(resource, 0), 0)
		#if not use_reserve:
			#max_withdrawable -= cur_reserved_withdraw.get_or_add(resource, 0)
		#var withdrawn: float = clampf(quantity, 0, max_withdrawable)
		#cur_stored[resource] -= withdrawn
		#if use_reserve:
			#cur_reserved_withdraw[resource] = max(cur_reserved_withdraw.get_or_add(resource, 0) - withdrawn, 0)
		#storage_changed.emit(resource, cur_stored[resource])
		#Global.resource_manager.queue_recalc_resource(resource)
		#return withdrawn
	#return 0
	
# --- WI-44 claim plumbing -----------------------------------------------------
#
# The claim TARGET is the per-resource StorageData (see its claimable contract),
# so these are just the lookups and the change notifications the component owns.

## The per-resource bin a claim should be taken against, or null when this
## storage doesn't handle `resource` at all.
func claim_target_for(resource: ResourceData) -> StorageData:
	return storage_data.get(resource)

## Withdraws against a reservation the caller already holds, emitting the same
## change notifications complete_withdraw_job() does.
func withdraw_reserved(resource: ResourceData, amount: int) -> Array[ResourceStack]:
	var data: StorageData = storage_data.get(resource)
	if data == null:
		return []
	var withdrawn: Array[ResourceStack] = data.withdraw_reserved(amount)
	if not withdrawn.is_empty():
		storage_value_changed = true
		storage_changed.emit(resource, data.stored)
	return withdrawn

## Deposits against a reservation the caller already holds.
func deposit_reserved(resource: ResourceData, stacks: Array[ResourceStack], amount: int) -> bool:
	var data: StorageData = storage_data.get(resource)
	if data == null or stacks.is_empty():
		return false
	data.deposit_reserved(stacks, amount)
	storage_value_changed = true
	storage_changed.emit(resource, data.stored)
	resource.needs_recalc = true
	return true

func add_withdraw_job(job: Job_GetResource) -> bool:
	if (can_withdraw(job.resource_data, job.amount)):
		storage_data[job.resource_data].add_withdraw_job(job)
		return true
	return false
	
func cancel_withdraw_job(job: Job_GetResource) -> void:
	var data: StorageData = storage_data.get(job.resource_data)
	if data:
		data.cancel_withdraw_job(job)
	
func complete_withdraw_job(job: Job_GetResource) -> Array[ResourceStack]:
	var data: StorageData = storage_data.get(job.resource_data)
	if data:
		var withdrawn: Array[ResourceStack] = data.complete_withdraw_job(job)
		if not withdrawn.is_empty():
			storage_value_changed = true
			storage_changed.emit(job.resource_data, data.stored)
		return withdrawn
	return []
	
func total_stored_by_resource(resource: ResourceData) -> int:
	var data: StorageData = storage_data.get(resource)
	if data:
		return data.stored
	return 0
	
func is_empty() -> bool:
	for data: StorageData in storage_data.values():
		if data.stored > 0:
			return false
	return true
	
func space_available(excluding_reserve: bool = false) -> int:
	var cur_stored_and_reserved: int = 0
	for data: StorageData in storage_data.values():
		cur_stored_and_reserved += data.stored
		if excluding_reserve:
			cur_stored_and_reserved += data.reserved_deposit
	return max_stored - cur_stored_and_reserved

func can_deposit(resource: ResourceData, quantity: int, use_reserve: bool = false) -> bool:
	if allow_any_resource or storage_data.has(resource):
		return space_available(use_reserve) >= quantity
	return false

func deposit(resource: ResourceData, quantity: int, only_if_room: bool = false, use_reserve: bool = false) -> bool:
	var data: StorageData = storage_data.get(resource)
	if not data and allow_any_resource:
		add_stored_resource(resource)
		data = storage_data.get(resource)
	if data:
		var free_space := space_available(use_reserve)
		if only_if_room and free_space < quantity:
			return false
		var new_stored := data.deposit(quantity, use_reserve)
		storage_value_changed = true
		storage_changed.emit(resource, new_stored)
		resource.needs_recalc = true
		return true
	return false

## Stack-aware deposit that preserves instance_data (richness/quality/etc),
## for callers that are handing over real ResourceStacks rather than a plain
## count - e.g. Job_StoreInventory returning carried resources to storage.
## Same only_if_room semantics as deposit(). All-or-nothing: on failure,
## nothing in `stacks` is touched, so the caller still owns it.
func deposit_stacks(resource: ResourceData, stacks: Array[ResourceStack], only_if_room: bool = true) -> bool:
	if stacks.is_empty():
		return true
	var data: StorageData = storage_data.get(resource)
	if not data and allow_any_resource:
		add_stored_resource(resource)
		data = storage_data.get(resource)
	if data == null:
		return false
	var total: int = 0
	for stack: ResourceStack in stacks:
		total += stack.amount
	if only_if_room and space_available() < total:
		return false
	for stack: ResourceStack in stacks:
		data.add_stack(stack)
	storage_value_changed = true
	storage_changed.emit(resource, data.stored)
	resource.needs_recalc = true
	return true

## Stack-aware partial withdraw (WI-27): pulls up to `quantity` units, preserving
## instance_data, and returns however much was actually available - the stack-aware
## sibling of withdraw_up_to(), used by conveyors that move "up to rate" per tick.
func withdraw_stacks_up_to(resource: ResourceData, quantity: int, use_reserve: bool = false) -> Array[ResourceStack]:
	var data: StorageData = storage_data.get(resource)
	if data == null or quantity <= 0:
		return []
	var available: int = data.stored
	if not use_reserve:
		available -= data.reserved_withdraw
	var take: int = mini(quantity, available)
	if take <= 0:
		return []
	var withdrawn: Array[ResourceStack] = data.withdraw_stacks(take)
	if use_reserve:
		data.reserved_withdraw = maxi(data.reserved_withdraw - take, 0)
	if not withdrawn.is_empty():
		storage_value_changed = true
		storage_changed.emit(resource, data.stored)
		resource.needs_recalc = true
	return withdrawn

## Stack-aware withdraw that preserves instance_data. use_reserve mirrors
## withdraw()/withdraw_up_to(). Returns [] if there isn't enough available.
func withdraw_stacks(resource: ResourceData, quantity: int, use_reserve: bool = false) -> Array[ResourceStack]:
	var data: StorageData = storage_data.get(resource)
	if data == null or not data.can_withdraw(quantity, use_reserve):
		return []
	var withdrawn: Array[ResourceStack] = data.withdraw_stacks(quantity)
	if use_reserve:
		data.reserved_withdraw = maxi(data.reserved_withdraw - quantity, 0)
	if not withdrawn.is_empty():
		storage_value_changed = true
		storage_changed.emit(resource, data.stored)
		resource.needs_recalc = true
	return withdrawn
	
func add_deposit_job(job: Job_GetResource) -> bool:
	var data: StorageData = storage_data.get(job.resource_data)
	if data:
		data.add_deposit_job(job)
		return true
	return false
	
func cancel_deposit_job(job: Job_GetResource) -> void:
	var data: StorageData = storage_data.get(job.resource_data)
	if data:
		data.cancel_deposit_job(job)
	
func complete_deposit_job(job: Job_GetResource, incoming_stacks: Array[ResourceStack] = []) -> bool:
	var data: StorageData = storage_data.get(job.resource_data)
	if data:
		var did_deposit: bool = data.complete_deposit_job(job, incoming_stacks)
		if did_deposit:
			storage_value_changed = true
			storage_changed.emit(job.resource_data, data.stored)
		return did_deposit
	return false
	#if import_jobs.has(job):
		#if deposit(job.resource_data, job.amount, false, true):
			#import_jobs.erase(job)
			#default_import_jobs.erase(job.resource_data)
			#if job.resource_data.base_resource != null:
				#default_import_jobs.erase(job.resource_data.base_resource)
			#return true
	#return false
	
# --- persistence ------------------------------------------------------------
# Reservations and import/export jobs are deliberately NOT saved: jobs aren't
# persisted, so on load the posting scan re-derives them from stored/desired.

func get_save_data() -> Dictionary:
	var out: Dictionary = {}
	for resource: ResourceData in storage_data:
		if resource.id == &"":
			push_warning("Resource without save id in storage not saved: " + resource.name)
			continue
		var data: StorageData = storage_data[resource]
		out[String(resource.id)] = {
			"desired": data.desired,
			"stacks": SaveManager.stacks_to_dicts(data.stacks),
			"autodump": data.autodump,
		}
	return out

## Restores contents on top of whatever the ready pass configured. Adds
## resource slots as needed; deposits bypass room/reserve checks (the state
## was legal when it was saved).
func load_save_data(data: Dictionary) -> void:
	for id_str: String in data:
		var resource: ResourceData = Global.save_manager.get_resource_by_id(StringName(id_str))
		if resource == null:
			push_warning("Unknown resource id in saved storage, skipping: " + id_str)
			continue
		add_stored_resource(resource)
		var slot: StorageData = storage_data[resource]
		# The save is the full truth for this slot - drop any scene-authored
		# initial stock (e.g. the starting module's steel) before restoring,
		# or loading would add the two together.
		slot.stacks.clear()
		slot.stored = 0
		var entry: Dictionary = data[id_str]
		slot.desired = int(entry.get("desired", slot.desired))
		for stack_dict: Dictionary in entry.get("stacks", []):
			var stack: ResourceStack = SaveManager.stack_from_dict(resource, stack_dict)
			if stack.amount > 0:
				slot.add_stack(stack)
		slot.autodump = entry.get("autodump", false)
		storage_value_changed = true
		storage_changed.emit(resource, slot.stored)
		resource.needs_recalc = true

func has_ui() -> bool:
	return display_info_panel_ui

func get_ui() -> ModuleComponentUI:
	var panel_element: UIStorageComponent = ui_info_panel_element.instantiate() as UIStorageComponent
	panel_element.set_storage_component(self)
	return panel_element
			
#func reserve_stock_for_export(resource: ResourceData, quantity: float = 1.0) -> bool:
#	stock_reserved[resource] = stock_reserved.get_or_add(resource, 0) + quantity
#	return true
	
#func reserve_space_for_import(resource: ResourceData, quantity: float = 1.0) -> bool:
#	space_reserved[resource] = space_reserved.get_or_add(resource, 0) + quantity
#	return true
