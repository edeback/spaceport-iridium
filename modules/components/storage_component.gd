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

@export var display_info_panel_ui: bool = true
@export var storage_ui: ProgressBar
@export var display_storage_ui: bool = true:
	set(new_display):
		if new_display != display_storage_ui:
			display_storage_ui = new_display
			storage_ui.visible = display_storage_ui
@export var player_configurable: bool = false
@export var construction_storage: bool = false

var export_jobs: Array[Job] = []
var import_jobs: Array[Job] = []

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
			# A pull: the destination is known (this bin), the source is hunted for
			# by the driver's first action.
			var new_job: Job = Job.of(&"haul_resource")
			new_job.target_b = JobTarget.of_component(self)
			new_job.resource = resource
			new_job.count = request_amount
			new_job.priority = priority
			data.import_job = new_job
			new_job.job_end.connect(_on_posted_job_end.bind(data, true), CONNECT_ONE_SHOT)
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
			# A push: the source is known (this bin), the destination is hunted for.
			var new_job: Job = Job.of(&"haul_resource")
			new_job.target_a = JobTarget.of_component(self)
			new_job.resource = resource
			new_job.count = surplus
			new_job.priority = priority
			data.export_job = new_job
			new_job.job_end.connect(_on_posted_job_end.bind(data, false), CONNECT_ONE_SHOT)
			Global.job_manager.add_job(new_job)

## Clears the posted-job pointer when a board job this bin posted ends, so the
## next scan can post a replacement. The pointer used to be cleared by the job
## reaching back into its requester; a WI-44 job does not know who posted it, so
## the poster listens instead - which also means a job ending for ANY reason
## (cancelled, failed, pawn deleted) frees the slot, where the old path only
## cleared it on the routes that remembered to.
func _on_posted_job_end(data: StorageData, was_import: bool) -> void:
	if was_import:
		data.import_job = null
	else:
		data.export_job = null

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
		#for job: the haul job in default_import_jobs.values():
			#job.priority = priority

## Which station systems eat `resource`, as player-facing phrases; empty when
## nothing does (WI-56).
##
## Autodump *destroys* stock, and the standing rule is that the player never
## loses resources without an explicit action that loses them. Enabling it on a
## resource the galley or a reactor is living on is exactly such an action - so
## the confirmation names what will starve, which WI-12 called a kindness and
## skipped. It stays a *warning*, not a block: venting surplus biomass while the
## hydroponics bay runs flat out is a legitimate thing to want.
##
## A live query rather than a cached set: reactors get built and galleys get
## deconstructed, and a stale answer here would understate the cost.
func resource_consumers(resource: ResourceData) -> Array[String]:
	var consumers: Array[String] = []
	if resource == null or not is_inside_tree():
		return consumers
	for node: Node in get_tree().get_nodes_in_group(Groups.SUSTENANCE_COMPONENT):
		var sustenance := node as SustenanceComponent
		if sustenance != null and sustenance.sustenance_resource == resource:
			consumers.append("crew meals")
			break
	# Generators are a PowerManager registry rather than a group (WI-39), which is
	# also the only list guaranteed to hold just the constructed ones.
	if Global.power_manager != null:
		for generator: PowerGenerationComponent in Global.power_manager.power_generators:
			if is_instance_valid(generator) and generator.resource_consumed == resource:
				consumers.append("power generation")
				break
	return consumers

## "" when venting `resource` costs the station nothing it is relying on;
## otherwise the sentence the dump confirmation adds.
func autodump_warning(resource: ResourceData) -> String:
	var consumers: Array[String] = resource_consumers(resource)
	if consumers.is_empty():
		return ""
	return "%s is consumed by %s. Auto-dumping it destroys stock the station is using." % [
		resource.name, " and ".join(consumers)]


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

	
	
	
func total_stored_by_resource(resource: ResourceData) -> int:
	var data: StorageData = storage_data.get(resource)
	if data:
		return data.stored
	return 0

## What this bin holds that nobody has claimed a withdrawal against (WI-55).
## Zero for a resource this storage does not handle, same as
## [method total_stored_by_resource].
func available_to_withdraw(resource: ResourceData) -> int:
	var data: StorageData = storage_data.get(resource)
	if data:
		return data.available_to_withdraw()
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
## count - e.g. the cargo sweep returning carried resources to storage.
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
	
	
	
	
# --- persistence ------------------------------------------------------------
# Reservations and import/export jobs are deliberately NOT saved: jobs aren't
# persisted, so on load the posting scan re-derives them from stored/desired.

## Shape (WI-45 A4): {"priority": int, "resources": {<id>: {...}}}. The pre-WI-45
## shape was the bare resource map with no room for a component-level field;
## load_save_data still reads it, keyed off the absence of "resources" (no
## ResourceData id is "resources", so the discriminator can't collide).
## After construction and processor, both of which reconfigure which bins exist
## and what they accept; this block then fills them.
func save_order() -> int:
	return 40

func save_key() -> StringName:
	return &"storage"

## The one component a module can carry several of - a processor has an Input bin
## and an Output bin - so the blocks nest under "storage" keyed by node path.
func saves_per_instance() -> bool:
	return true

func get_save_data() -> Dictionary:
	var resources: Dictionary = {}
	for resource: ResourceData in storage_data:
		if resource.id == &"":
			push_warning("Resource without save id in storage not saved: " + resource.name)
			continue
		var data: StorageData = storage_data[resource]
		resources[String(resource.id)] = {
			"desired": data.desired,
			"stacks": SaveManager.stacks_to_dicts(data.stacks),
			"autodump": data.autodump,
		}
	# Priority is a player setting (the panel's spinbox is live on every bin, not
	# just player_configurable ones) and it IS the routing language - a hand-tuned
	# station that reloads at scene defaults silently re-routes every haul.
	return {"priority": priority, "resources": resources}

## Restores contents on top of whatever the ready pass configured. Adds
## resource slots as needed; deposits bypass room/reserve checks (the state
## was legal when it was saved).
func load_save_data(data: Dictionary) -> void:
	# Legacy (pre-WI-45) blocks are the resource map itself; new ones nest it.
	var resources: Dictionary = data["resources"] if data.has("resources") else data
	if data.has("priority"):
		# update_priority, not a field write: it re-prices jobs this bin already
		# posted during the ready pass. Runs first so restored contents post at the
		# right priority. Overwrites TradeComponent's ready_constructed default by
		# design - the save is the later authority on a bay the player re-tuned.
		update_priority(int(data["priority"]))
	for id_str: String in resources:
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
		var entry: Dictionary = resources[id_str]
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
