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
## - StorageData's job-tracking fields (import_job, deposit_jobs, etc) are
##   hard-typed to Job_GetResource, which a pile-collection job isn't, so
##   reservation here is a small bit of pile-local bookkeeping instead of
##   reusing that machinery.
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
## ResourceData -> amount currently claimed by an in-flight Job_CollectPile,
## so two pawns can't both walk over to collect the same last few units.
var reserved: Dictionary[ResourceData, int] = {}
## ResourceData -> the Job_CollectPile currently responsible for it, so
## add_stacks() doesn't spam the job board with a fresh job every time more
## material lands on an already-being-collected pile.
var active_jobs: Dictionary[ResourceData, Job_CollectPile] = {}

## Null = free-floating in space. Set = sitting inside this module (e.g. a
## corridor overflow pile); collection jobs path to the module itself, not
## to this node's exact position.
var parent_module: ModuleBase = null

## Stable save id (WI-21), assigned by spawn(). Lets a Job_CollectPile persist
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
	$ClickArea.input_event.connect(_on_click_area_input_event)

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
## being dumped or ejected same as it survives a normal storage deposit).
func add_stacks(resource: ResourceData, stacks: Array[ResourceStack]) -> void:
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
	_ensure_collection_job(resource)

func add_amount(resource: ResourceData, amount: int) -> void:
	if resource == null or amount <= 0:
		return
	var stack := ResourceStack.new()
	stack.resource_data = resource
	stack.amount = amount
	add_stacks(resource, [stack])

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

func _ensure_collection_job(resource: ResourceData) -> void:
	var existing: Job_CollectPile = active_jobs.get(resource)
	if existing != null and existing.is_valid():
		return
	var job := Job_CollectPile.new()
	job.setup(self, resource)
	active_jobs[resource] = job
	job.job_end.connect(_on_job_end.bind(resource, job))
	Global.job_manager.add_job(job)

func _on_job_end(resource: ResourceData, job: Job_CollectPile) -> void:
	if active_jobs.get(resource) == job:
		active_jobs.erase(resource)
	# Job may have only cleared a partial trip (carrying capacity, or the
	# storage it found only had room for some) - re-post for the remainder,
	# same "next trip picks up the rest" pattern Job_GetResource uses.
	if get_available(resource) > 0:
		_ensure_collection_job(resource)

func _despawn() -> void:
	despawning.emit()
	if is_instance_valid(parent_module) and parent_module.overflow_pile == self:
		parent_module.overflow_pile = null
	remove_from_group(Groups.RESOURCE_DEBRIS)
	queue_free()

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
