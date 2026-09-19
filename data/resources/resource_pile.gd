class_name ResourcePile
extends ObjectBase

const RESOURCE_PILE = preload("uid://vw2q5so630yo")

## A stack of resources sitting in the world without being inside anyone's
## StorageComponent - overflow/dumped piles in a module's corridor, or
## free-floating debris from a wreck, destroyed module, or dead pawn.
##
## Deliberately NOT built on StorageComponent/StorageData:
## - no @export UI bindings, no per-frame _process(), no desired/import
##   budget accounting - piles are pure "stuff sitting here", posted to the
##   job board once when they're created or topped up, not polled every
##   frame the way StorageComponent's import/export search is.
## - reservation here is a small bit of pile-local bookkeeping rather than
##   StorageData's; PileStock is the claimable face over it (WI-44).
##
## If parent_module is null, the pile is free-floating and is only ever
## spliced into the pathing graph for the duration of a single pathfind
## (see ModuleGraph.pathfind_to_node_in_space) - the same trick
## AsteroidBase pathing already relies on. It never sits in the exterior
## clique at rest, so it costs nothing on pathfinds that don't target it.
## If parent_module is set, the pile isn't in the graph at all: reachability
## and movement both target the module itself, since anywhere inside a
## reachable module is already reachable - no new pathfinding concept
## needed for in-module piles.

## ResourceData -> ResourceStackContainer. Same shape as
## PawnInventoryComponent.carried, deliberately - same instance_data
## (ore richness etc) preservation semantics apply.
var contents: Dictionary[ResourceData, ResourceStackContainer] = {}
## ResourceData -> amount currently claimed by an in-flight the pile-collection job,
## so two pawns can't both walk over to collect the same last few units.
var reserved: Dictionary[ResourceData, int] = {}
## ResourceData -> the slot holding the collection job currently responsible for
## it, so add_stacks() doesn't spam the job board with a fresh job every time more
## material lands on an already-being-collected pile. Created on first use.
var _collect_slots: Dictionary[ResourceData, JobSlot] = {}
## ResourceData -> its claimable face (WI-44). Memoised because the ClaimRegistry
## matches claims by object identity, so a fresh PileStock per call would make
## every release miss.
var _claim_targets: Dictionary[ResourceData, PileStock] = {}

## Null = free-floating in space. Set = sitting inside this module (e.g. a
## corridor overflow pile); collection jobs path to the module itself, not
## to this node's exact position.
##
## Let go of automatically when the module leaves the tree (WI-68 F23). A
## module's own overflow pile was always released in ModuleBase.pre_delete, but
## plenty of other piles are tagged with a module - a manual dump, a pawn's
## dropped cargo, a cancelled sell order - and those kept a reference to the
## freed module, which made the next save write the pile section empty. What's
## left of a removed module is floating where it stood, which is exactly what
## null means here.
var parent_module: ModuleBase = null:
	set(value):
		if is_instance_valid(parent_module) and parent_module.tree_exiting.is_connected(_on_parent_module_exiting):
			parent_module.tree_exiting.disconnect(_on_parent_module_exiting)
		parent_module = value
		if is_instance_valid(value):
			value.tree_exiting.connect(_on_parent_module_exiting)

## Stable save id (WI-21), assigned by spawn(). Lets a the pile-collection job persist
## the pile it targets and re-resolve it on load. Static counter because spawn()
## is static (no instance to hang it on); SaveManager bumps it past every
## restored id on load so post-load piles never collide with saved ones.
static var _next_pile_id: int = 0
var pile_id: int = -1

signal despawning
signal pile_changed(resource: ResourceData, new_amount: int)
signal resource_pile_clicked(resource_pile: ResourcePile)

func _ready() -> void:
	add_to_group(Groups.RESOURCE_DEBRIS)
	($ClickArea as Area2D).input_event.connect(_on_click_area_input_event)

func _on_click_area_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event.is_action_pressed("build"):
		get_viewport().set_input_as_handled()
		resource_pile_clicked.emit(self)
		Global.ui_main.resource_pile_clicked(self)

func get_total(resource: ResourceData) -> int:
	var container: ResourceStackContainer = contents.get(resource)
	return container.stored if container != null else 0

func get_available(resource: ResourceData) -> int:
	return get_total(resource) - reserved.get(resource, 0)

func get_contained_resources() -> Array[ResourceData]:
	return contents.keys()

func is_empty() -> bool:
	for container: ResourceStackContainer in contents.values():
		if container.stored > 0:
			return false
	return true

## Adds real stacks (preserving instance_data - ore richness etc survives
## being dumped or ejected same as it survives a normal storage deposit), and
## posts a collection job for them.
##
## `post_job` false is the load path's (WI-70): a restored pile must not post
## before the pawn section has handed back the collect job a crew member was
## already on, or that job finds the slot taken and runs beside a duplicate
## (F26). SaveManager posts for it once the load is done - see
## ensure_collection_jobs.
func add_stacks(resource: ResourceData, stacks: Array[ResourceStack], post_job: bool = true) -> void:
	if resource == null or stacks.is_empty():
		return
	var container: ResourceStackContainer = contents.get(resource)
	if container == null:
		container = ResourceStackContainer.new()
		container.resource_data = resource
		contents[resource] = container
	for stack: ResourceStack in stacks:
		container.add_stack(stack)
	pile_changed.emit(resource, container.stored)
	if post_job:
		_ensure_collection_job(resource)

func add_amount(resource: ResourceData, amount: int) -> void:
	if resource == null or amount <= 0:
		return
	var stack := ResourceStack.new()
	stack.resource_data = resource
	stack.amount = amount
	add_stacks(resource, [stack])

## The object a WI-44 job claims against for this resource. Both reservation
## paths land on the same `reserved` counter below, so a legacy the pile-collection job
## and a WI-44 collect job cannot double-book the same units.
func claim_target_for(for_resource: ResourceData) -> PileStock:
	if for_resource == null:
		return null
	var stock: PileStock = _claim_targets.get(for_resource)
	if stock == null:
		stock = PileStock.of(self, for_resource)
		_claim_targets[for_resource] = stock
	return stock

## Claims `amount` against a future withdrawal. Returns false (claiming
## nothing) if that much isn't actually available right now.
func reserve(resource: ResourceData, amount: int) -> bool:
	if amount <= 0 or get_available(resource) < amount:
		return false
	reserved[resource] = reserved.get(resource, 0) + amount
	return true

func cancel_reservation(resource: ResourceData, amount: int) -> void:
	reserved[resource] = maxi(reserved.get(resource, 0) - amount, 0)

## Withdraws real stacks (preserving instance_data). Despawns the pile once
## it's completely empty - safe to call this and then drop your reference.
func withdraw_stacks(resource: ResourceData, amount: int) -> Array[ResourceStack]:
	var container: ResourceStackContainer = contents.get(resource)
	if container == null or amount <= 0:
		return []
	var withdrawn: Array[ResourceStack] = container.withdraw_stacks(amount)
	var total: int = 0
	for stack: ResourceStack in withdrawn:
		total += stack.amount
	if total > 0:
		reserved[resource] = maxi(reserved.get(resource, 0) - total, 0)
		pile_changed.emit(resource, container.stored)
	if container.is_empty():
		contents.erase(resource)
		reserved.erase(resource)
	if is_empty():
		_despawn()
	return withdrawn

## Posts a collection job for every resource here that nobody is collecting. The
## load path's deferred half of add_stacks(..., false).
func ensure_collection_jobs() -> void:
	for resource: ResourceData in contents:
		if get_available(resource) > 0:
			_ensure_collection_job(resource)

## One live job per resource. The old check here also re-posted over a live job
## that had gone invalid, but a collect job waiting on the board is valid exactly
## while the pile has stock nobody has claimed - which is the only time anything
## calls this - and past its pile claim it is valid by construction. A job the
## board does find invalid is cancelled there, and the handler re-posts.
func _ensure_collection_job(resource: ResourceData) -> void:
	if not is_inside_tree() or Global.job_manager == null:
		return
	var slot: JobSlot = _slot_for(resource)
	if slot.is_live():
		return
	var job: Job = Job.of(&"collect_pile")
	job.target_a = JobTarget.of_pile(self)
	job.resource = resource
	slot.post(job)
	Global.job_manager.add_job(job)

func _slot_for(resource: ResourceData) -> JobSlot:
	var slot: JobSlot = _collect_slots.get(resource)
	if slot == null:
		slot = JobSlot.new(_on_collect_job_end)
		_collect_slots[resource] = slot
	return slot

## Whether a collection job for `resource` is live. For the tests.
func is_collecting(resource: ResourceData) -> bool:
	var slot: JobSlot = _collect_slots.get(resource)
	return slot != null and slot.is_live()

func _on_collect_job_end(job: Job, _completed: bool) -> void:
	# Job may have only cleared a partial trip (carrying capacity, or the
	# storage it found only had room for some) - re-post for the remainder,
	# same "next trip picks up the rest" pattern the haul job uses. Whatever
	# ended it: the check is only ever "is there anything left to fetch".
	if job.resource != null and get_available(job.resource) > 0:
		_ensure_collection_job(job.resource)

## The collect job a crew member was on when the save was written (WI-70 §3).
func adopt_restored_job(job: Job) -> bool:
	if not job.is_type(&"collect_pile") or job.resource == null:
		return false
	return _slot_for(job.resource).adopt(job)

func _despawn() -> void:
	despawning.emit()
	if is_instance_valid(parent_module) and parent_module.overflow_pile == self:
		parent_module.overflow_pile = null
	remove_from_group(Groups.RESOURCE_DEBRIS)
	queue_free()

func _on_parent_module_exiting() -> void:
	parent_module = null

## Convenience constructor: builds a pile, adds it under parent_node, and
## positions it. parent_node should be whatever canvas/layer the caller
## wants it rendered on (module overflow piles use the module's own parent
## so they survive the module being freed - see ModuleBase).
static func spawn(parent_node: Node, at_position: Vector2, owning_module: ModuleBase = null) -> ResourcePile:
	var pile := RESOURCE_PILE.instantiate() as ResourcePile
	pile.parent_module = owning_module
	pile.pile_id = _next_pile_id
	_next_pile_id += 1
	parent_node.add_child(pile)
	pile.global_position = at_position
	return pile
