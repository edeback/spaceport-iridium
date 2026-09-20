class_name StorageComponent
extends ComponentBase

## What this bin exports at, and what its GENERAL/INPUT slots import at. OUTPUT
## slots ignore it entirely (see [method export_priority]), which is what lets one
## component hold both roles and still show the player exactly one number.
@export var priority: int = 1
## Capacity shared by the GENERAL and INPUT slots. The two never coexist on one
## module in practice - a module either holds stock or consumes it.
@export var max_stored: int = 10
## Capacity for the OUTPUT slots, kept separate from `max_stored` so a backed-up
## output cannot starve the input side of the same bin (WI-65 §5). Deliberately
## ONE shared pool across every output: a multi-output recipe deposits
## atomically, so a blocked product stalling the run is correct behaviour and
## per-product caps would let a run proceed with only some of its outputs placed.
@export var output_capacity: int = 0
@export var power_consumption_component: PowerConsumptionComponent

@export var include_in_stats: bool = true

## The role a slot gets when nothing says otherwise - a catch-all bin's first
## deposit of a new resource, or a slot the save block restores. It is what makes
## "which side is this bin on?" answerable for a resource nobody has declared:
## the docking bay's arrivals are OUTPUT whatever turns up in them, and a
## deconstruction site's recovered materials restore as OUTPUT rather than as
## general stock that would be hauled straight back in.
@export var default_role: StorageData.Role = StorageData.Role.GENERAL

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
		# Every slot starts at the whole of the pool it draws on - the same thing
		# add_stored_resource() does, and the two must not disagree. For INPUT
		# this is what keeps a catch-all bin working once `desired` becomes a hard
		# cap (WI-65 §11): default it to 0 and every allow_any bin bricks at once.
		# For OUTPUT it is a display bound rather than a routing one (an output
		# slot ships everything it holds), but leaving it at 0 made a mining bay's
		# ore rows read "0 / 0", i.e. a bay that can hold nothing.
		if storage.role != StorageData.Role.EXCLUDED:
			storage.desired = pool_for(storage.role)

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

## A silently-zero output pool is a processor that never produces and a mining
## bay that never holds ore, with nothing on screen saying so - and it is exactly
## what a scene edit introduces without a crash. Cost one real defect in WI-65,
## caught by a screenshot rather than by any check; was an `assert`, which a
## release export strips (WI-72 §2, F31).
##
## Authored roles only, because that is all there is to read before the tree runs.
## A processor's product slots are derived from its recipe later, so the matching
## rule for those lives on [ProcessorComponent] - and catches them at `_ready`
## rather than depending on which component's ready pass ran first.
func wiring_fault() -> String:
	if output_capacity > 0:
		return ""
	if has_output_slots():
		return "it has OUTPUT slots but output_capacity is 0, so they can hold nothing"
	if default_role == StorageData.Role.OUTPUT:
		return "its default_role is OUTPUT but output_capacity is 0, so it can hold nothing at all"
	return ""

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

func add_stored_resource(resource: ResourceData,
		role: StorageData.Role = default_role) -> void:
	if not storage_data.has(resource):
		var new_data := StorageData.new()
		new_data.resource_data = resource
		new_data.role = role
		# The whole pool, for the same reason _ready() does it: an INPUT slot's
		# desired is a cap, and a slot created at 0 would refuse everything.
		# Callers that want a narrower cap (a recipe's run allocation, a sell
		# order's size) set it right after.
		new_data.desired = pool_for(role)
		storage_data[resource] = new_data
		if include_in_stats:
			resource.register_component(self)
	# An EXISTING slot keeps its role. This is load-bearing: the save block calls
	# this for every restored resource and would otherwise flip a processor's
	# carefully roled slots to `default_role` on every load. Whoever owns the
	# roles - _sync_storages for a processor, the order sheet for a bay - assigns
	# them explicitly after.
			
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
		if data.autodump_enabled():
			var dump_amount: int = data.autodump_amount()
			if dump_amount > 0:
				destroy_resource(resource, dump_amount)
	# Shared budget across resources so several under-desired resources in the
	# same bin don't each request up to the bin's full free space and jointly
	# overcommit it before any pawn has actually moved anything. The intake pool
	# is the only one that imports - OUTPUT slots never do (WI-65 §4) - so there
	# is one budget, not one per pool.
	var import_budget: int = space_available(true, StorageData.Role.GENERAL)
	for resource: ResourceData in storage_data:
		if import_budget <= 0:
			break
		var data := storage_data[resource]
		if not data.accepts_imports():
			continue
		if data.import_slot.is_live():
			continue
		# Positive when we're short of desired once already-incoming
		# deposits count as "here" and already-reserved withdrawals count
		# as "gone" - same accounting the trigger below used to use.
		var deficit: int = data.desired - data.stored - data.reserved_deposit + data.reserved_withdraw
		if deficit <= 0:
			continue
		# Both bounds (WI-65 §11): the role's shared pool AND this slot's own cap.
		# The deficit is already measured against `desired`, so for an INPUT slot
		# the second is implied - but saying it here keeps the posting scan honest
		# if `desired` ever stops being the cap.
		var request_amount: int = mini(mini(deficit, import_budget),
			slot_headroom(resource, true))
		if request_amount <= 0:
			continue
		# A pull: the destination is known (this bin), the source is hunted for
		# by the driver's first action. This bin posted it and is its target B, so
		# that is where a load hands it back (WI-70).
		var new_job: Job = Job.of(&"haul_resource").with_origin(JobData.Origin.TARGET_B)
		new_job.target_b = JobTarget.of_component(self)
		new_job.resource = resource
		new_job.count = request_amount
		new_job.priority = priority
		data.import_slot.post(new_job)
		Global.job_manager.add_job(new_job)
		import_budget -= request_amount
	for resource: ResourceData in storage_data:
		var data := storage_data[resource]
		if data.export_slot.is_live():
			continue
		# The role decides what "surplus" means (WI-65 §4): a GENERAL bin ships
		# what it holds over its target, an OUTPUT slot ships everything it has,
		# and INPUT/EXCLUDED ship nothing. An INPUT slot over its cap sheds to the
		# overflow pile instead (§12) - never through the board, because it would
		# post at a priority no ordinary storeroom can out-rank.
		var surplus: int = data.exportable_surplus()
		if surplus <= 0:
			continue
		# A push: the source is known (this bin), the destination is hunted for.
		var new_job: Job = Job.of(&"haul_resource").with_origin(JobData.Origin.TARGET_A)
		new_job.target_a = JobTarget.of_component(self)
		new_job.resource = resource
		new_job.count = surplus
		new_job.priority = export_priority(resource)
		data.export_slot.post(new_job)
		Global.job_manager.add_job(new_job)

## A haul this bin posted, restored from a save (WI-70 §3). Which slot it belongs
## in is the job's origin: posted as a pull, this bin is its target B and it fills
## the import slot; posted as a push, this bin is its target A and it empties the
## export one. A haul saved before origin existed carries the data default, NONE,
## is offered to nobody, and costs one duplicate trip on its first load.
func adopt_restored_job(job: Job) -> bool:
	if not job.is_type(&"haul_resource") or job.resource == null:
		return false
	var data: StorageData = storage_data.get(job.resource)
	if data == null:
		return false
	match job.origin:
		JobData.Origin.TARGET_B:
			return data.import_slot.adopt(job)
		JobData.Origin.TARGET_A:
			return data.export_slot.adopt(job)
	return false

func update_storage_ui() -> void:
	# Both pools, because the bar over the module is "how full is this thing" and
	# a refinery whose output bay is backed up is full in every sense a player
	# glancing at it cares about.
	var capacity: int = max_stored + output_capacity
	if capacity <= 0:
		storage_ui.value = 1.0
		return
	var free: int = space_available(false, StorageData.Role.GENERAL) 		+ space_available(false, StorageData.Role.OUTPUT)
	storage_ui.value = float(capacity - free) / capacity

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

func can_withdraw(resource: ResourceData, quantity: int, use_reserve: bool = false) -> bool:
	var data: StorageData = storage_data.get(resource)
	if data:
		return data.can_withdraw(quantity, use_reserve)
	return false
	
func withdraw(resource: ResourceData, quantity: int, use_reserve: bool = false) -> bool:
	var data: StorageData = storage_data.get(resource)
	if data:
		if data.try_withdraw(quantity, use_reserve):
			storage_value_changed = true
			storage_changed.emit(resource, data.stored)
			resource.needs_recalc = true
			return true
	return false
	
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
	
# --- WI-44 claim plumbing -----------------------------------------------------
#
# The claim TARGET is the per-resource StorageData (see its claimable contract),
# so these are just the lookups and the change notifications the component owns.

## The per-resource bin a claim should be taken against, or null when this
## storage doesn't handle `resource` at all.
##
## `for_deposit` lets a catch-all bin grow the slot, exactly as deposit() and
## deposit_stacks() already do on arrival. A hauler reserves BEFORE it deposits,
## and without this the reservation found no slot to claim against: find_sink()
## accepts a catch-all bin for any resource (can_deposit allows it), so every push
## into a storeroom that had never held the resource failed at its sink
## reservation and re-posted forever. Latent since WI-44; it surfaced when the
## mining bay's ore finally had a storeroom to go to. Never on the withdraw side -
## an empty slot has nothing to reserve, and growing one there only litters the bin.
func claim_target_for(resource: ResourceData, for_deposit: bool = false) -> StorageData:
	var data: StorageData = storage_data.get(resource)
	if data == null and for_deposit and allow_any_resource:
		add_stored_resource(resource)
		data = storage_data.get(resource)
	return data

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
	
## Which capacity pool a role draws on (WI-65 §5). OUTPUT has its own so a
## backed-up output cannot starve the input side; everything else shares
## `max_stored`. EXCLUDED counts against whichever pool it was created in, which
## is the intake one - a frozen bin is a bin that was, or will be, receiving.
func pool_for(role: StorageData.Role) -> int:
	return output_capacity if role == StorageData.Role.OUTPUT else max_stored

func _is_output_pool(role: StorageData.Role) -> bool:
	return role == StorageData.Role.OUTPUT

## Free space in one role's pool. `role` defaults to the intake pool because
## that is what every pre-WI-65 caller meant.
func space_available(excluding_reserve: bool = false,
		role: StorageData.Role = StorageData.Role.GENERAL) -> int:
	var want_output: bool = _is_output_pool(role)
	var cur_stored_and_reserved: int = 0
	for data: StorageData in storage_data.values():
		if _is_output_pool(data.role) != want_output:
			continue
		cur_stored_and_reserved += data.stored
		if excluding_reserve:
			cur_stored_and_reserved += data.reserved_deposit
	return pool_for(role) - cur_stored_and_reserved

## Free space in the pool `resource`'s own slot draws on - the form every
## deposit path wants, since the slot already knows its role.
func space_available_for(resource: ResourceData, excluding_reserve: bool = false) -> int:
	return space_available(excluding_reserve, role_of(resource))

## The role `resource` is handled under. A resource with no slot resolves to
## GENERAL, which is also the role add_stored_resource() would give it.
func role_of(resource: ResourceData) -> StorageData.Role:
	var data: StorageData = storage_data.get(resource)
	return data.role if data != null else default_role

func can_deposit(resource: ResourceData, quantity: int, use_reserve: bool = false) -> bool:
	return room_for(resource, use_reserve) >= quantity

## How much of `resource` this bin can take right now: the free space in the pool
## its slot draws on, bounded by the slot's own cap. Zero for a resource it cannot
## hold. The amount form of [method can_deposit].
##
## Every "how much fits?" question about a specific resource belongs here.
## [method space_available] with no role answers for the GENERAL pool whatever the
## resource is - which is what stopped a mining bay (max_stored 0, its whole
## capacity in output_capacity) from taking a single unit of ore after WI-65.
##
## Anything that deposits WITHOUT holding a reservation - the cargo sweep, a belt,
## [method deposit_stacks] with only_if_room - asks with `excluding_reserve` true.
## A GENERAL or OUTPUT deposit claim is bookkeeping only, so these paths are the
## only thing standing between a reservation and a bin filled under it.
func room_for(resource: ResourceData, excluding_reserve: bool = false) -> int:
	if not can_store_resource(resource):
		return 0
	return maxi(mini(space_available_for(resource, excluding_reserve),
		slot_headroom(resource, excluding_reserve)), 0)

## Room for a job that has already booked `booked` units of deposit here: every
## OTHER job's reservation counts against it, its own does not. What a hauler
## standing at the bin may actually put down, and how big a trip into it may be.
##
## Not `room_for(resource, true) + booked`: room_for clamps at zero first, so a
## pool something else over-filled (a restored save, a direct deposit) would read
## as exactly `booked` units of room and the haul would push it further over.
func room_for_booking(resource: ResourceData, booked: int) -> int:
	if not can_store_resource(resource):
		return 0
	return maxi(mini(space_available_for(resource, true), _headroom(resource, true)) + booked, 0)

## Room left under this slot's own cap, or a large number when the slot has no
## cap of its own (WI-65 §11).
##
## Only INPUT is capped: over-filling one ingredient starves another and
## deadlocks the module, which is a property of a bin whose contents are consumed
## in fixed proportions. A storeroom's `desired` stays a haul TARGET - stock over
## it is surplus with an export job already posted, and nothing is starved by
## holding it - and an OUTPUT slot is bounded by its pool alone.
func slot_headroom(resource: ResourceData, excluding_reserve: bool = false) -> int:
	return maxi(_headroom(resource, excluding_reserve), 0)

## slot_headroom() before the clamp - negative for a slot already over its cap,
## which room_for_booking() needs to see.
func _headroom(resource: ResourceData, excluding_reserve: bool) -> int:
	var data: StorageData = storage_data.get(resource)
	if data == null or data.role != StorageData.Role.INPUT:
		return 0x7FFFFFFF
	var taken: int = data.stored
	if excluding_reserve:
		taken += data.reserved_deposit
	return data.desired - taken

# --- haul routing (WI-65) -----------------------------------------------------
#
# StorageQuery asks these instead of reading `priority` and a pair of flags, so
# one component can pull one resource in while pushing another out. REFUSED is
# NOT an extreme priority: StorageQuery.ANY_PRIORITY deliberately skips the
# priority comparison (a pile or a carried-cargo sweep has no priority of its
# own), so a refusal expressed as a number would be ignored on exactly those
# paths. It has to be checked before the comparison, never inside it.

## "This bin will never move that resource in this direction."
const REFUSED: int = 0x7FFFFFFF

## The priority this bin will accept `resource` at, or REFUSED.
func import_priority(resource: ResourceData) -> int:
	match _routing_role(resource):
		StorageData.Role.GENERAL, StorageData.Role.INPUT:
			return priority
		_:
			return REFUSED

## The priority this bin will ship `resource` out at, or REFUSED.
##
## OUTPUT reports the floor rather than an offset from `priority`: an output bin
## is a temporary holding spot, so "anywhere but here" is the correct routing,
## and pinning it is what leaves the component exactly one editable number.
func export_priority(resource: ResourceData) -> int:
	match _routing_role(resource):
		StorageData.Role.GENERAL:
			return priority
		StorageData.Role.OUTPUT:
			return StoresModel.PRIORITY_MIN
		# INPUT refuses, same as EXCLUDED. A forge mid-recipe must not have its
		# ore hauled back out from under it, which is the whole reason the role
		# exists - grouping it with GENERAL here (as the import side legitimately
		# does) hands a storeroom the ingredients back.
		_:
			return REFUSED

## INPUT never posts an export in steady state, but an over-cap slot still has to
## be able to shed (WI-65 §12) - and that shed goes to the overflow pile, not
## through this. Kept as its own helper so the two questions ("will hauling take
## this out of here?" and "what role is it?") never get conflated.
func _routing_role(resource: ResourceData) -> StorageData.Role:
	var data: StorageData = storage_data.get(resource)
	if data != null:
		return data.role
	# A catch-all bin handles anything at its default role; anything else refuses
	# a resource it has no slot for.
	return default_role if allow_any_resource else StorageData.Role.EXCLUDED

## Does hauling ever move goods INTO this bin? Drives the UI's role sections and
## the "this module only exports" sentence, not the queries above.
func has_intake_slots() -> bool:
	# No intake pool means no intake side, ever - a mining bay's whole capacity is
	# its OUTPUT pool. This is the test rather than "are there INPUT slots?"
	# because slots come and go: an empty storeroom has none yet, and the docking
	# bay grows its staging slots only when the player places a sell order. Both
	# take deliveries; both would have lost their priority stepper to a
	# slot-counting rule, and the bay would have shown "its priority is still
	# yours" beside no control at all.
	if max_stored <= 0:
		return false
	for data: StorageData in storage_data.values():
		if data.accepts_imports():
			return true
	# It has room to receive but nothing declared to receive yet. That is only an
	# intake side if a slot can still appear - a catch-all bin, or one that has
	# not been configured at all.
	return storage_data.is_empty() or allow_any_resource

func has_output_slots() -> bool:
	for data: StorageData in storage_data.values():
		if data.role == StorageData.Role.OUTPUT:
			return true
	return false

## Does hauling ever take goods OUT of this bin? The mirror of
## [method has_intake_slots], and what a conveyor asks when picking a source
## endpoint - it chooses the endpoint before it chooses the resource.
func has_output_or_general_slots() -> bool:
	for data: StorageData in storage_data.values():
		if data.accepts_exports():
			return true
	# Same empty-bin rule as has_intake_slots().
	return storage_data.is_empty() \
		and (default_role == StorageData.Role.GENERAL or default_role == StorageData.Role.OUTPUT)

## Re-roles every slot at once - the construction lifecycle's freeze/thaw
## (WI-65 §7). Per-slot rather than a component flag, so a bin can be frozen with
## stock already in it.
func set_all_roles(role: StorageData.Role) -> void:
	for data: StorageData in storage_data.values():
		data.role = role

func deposit(resource: ResourceData, quantity: int, only_if_room: bool = false, use_reserve: bool = false) -> bool:
	var data: StorageData = storage_data.get(resource)
	if not data and allow_any_resource:
		add_stored_resource(resource)
		data = storage_data.get(resource)
	if data:
		var free_space := space_available_for(resource, use_reserve)
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
	# room_for, not the bare pool: an INPUT slot's cap binds here too, or a belt
	# or a cargo sweep tops a recipe ingredient past its share and starves the other.
	# Counting reservations, because nothing on this path holds one: room a hauler
	# has booked is room it will fill when it arrives, whatever lands here first.
	if only_if_room and room_for(resource, true) < total:
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
# Reservations and the board's import/export jobs are not saved in this block.
# That does NOT mean jobs aren't persisted (the old wording here, false since
# WI-21): a haul in flight is saved on the pawn carrying it and restored there
# by SaveManager._load_pawn_jobs, and reservations are re-taken as it resumes.
# The restored haul is handed back to this bin's slot by adopt_restored_job
# (WI-70). What is re-derived is the board side: a haul nobody had claimed is
# not saved, and the posting scan re-posts it from stored/desired.

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

## Blocks nest under "storage" keyed by node path. Since WI-65 a module carries
## at most one of these plus construction's, but a deconstruction site still grows
## a second one for its recovered materials, so the per-instance keying stays.
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
			"autodump_above": data.autodump_above,
		}
	# Roles are deliberately NOT saved (WI-65): a slot's role comes from whatever
	# configured the bin during the ready pass - the recipe for a processor, the
	# trade sheet for a bay, the build phase for construction - all of which run
	# before this block loads. Saving them would let a stale save fight the live
	# configuration, and a recipe that changed between builds would restore slots
	# roled for a recipe that no longer exists.
	#
	# Priority is a player setting and it IS the routing language - a hand-tuned
	# station that reloads at scene defaults silently re-routes every haul. Saved
	# on every bin, not just the editable ones: a construction site sits at +99 and
	# a processor bay at whatever its scene set, and those have to come back too.
	# (`player_configurable` gates the bin's *contents* - what it accepts, the
	# desired amounts, dumping - and never its priority; see
	# [method StoresModel.contents_editable]. That is a UI rule, not a save one.)
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
		# Legacy (pre-WI-65): a bare `autodump: true` meant "destroy everything over
		# `desired`", which is exactly `autodump_above = desired`.
		if entry.has("autodump_above"):
			slot.autodump_above = int(entry["autodump_above"])
		elif bool(entry.get("autodump", false)):
			slot.autodump_above = slot.desired
		storage_value_changed = true
		storage_changed.emit(resource, slot.stored)
		resource.needs_recalc = true

func has_ui() -> bool:
	return display_info_panel_ui

func get_ui() -> ModuleComponentUI:
	var panel_element: UIStorageComponent = ui_info_panel_element.instantiate() as UIStorageComponent
	panel_element.set_storage_component(self)
	return panel_element
			
