class_name ConveyorComponent
extends ComponentBase

## Moves chosen resources between chosen adjacent storages on rate-limited internal
## buffers (WI-27). A conveyor runs one or more independent lanes (ConveyorLane):
## each lane is its own (source, destination, resource, buffer) link. A fresh
## conveyor has one lane; the "Extra Belt" local upgrade (STAT_CONVEYOR_LANES) adds
## more, up to MAX_LANES, so a single conveyor can shuttle several resources
## between several storage pairs at once.
##
## Every lane is direct storage-to-storage: no jobs, no board, no reservations held
## across ticks - the goods physically live in the lane's buffer between hops, so an
## unpowered conveyor holds them and a removed conveyor dumps them as a pile. Moving
## stock before the storage's deficit/surplus posting sees it naturally reduces
## haul-job churn without ever touching the priority bands.
##
## Endpoints are adjacent modules' StorageComponents (eligibility mirrors the WI-12
## import/export flags) or adjacent ConveyorComponents - a conveyor's buffers act as
## storage-like endpoints, so chains form through the buffer_* shim below (keyed by
## resource, so each lane chains to the matching lane on the neighbour).

## Hard cap on lanes regardless of how many upgrade tiers exist.
const MAX_LANES: int = 4

@export var power_consumer: PowerConsumptionComponent
## Units each lane's buffer can hold. Intake stalls when full.
@export var buffer_size: int = 20
## Units moved per game-hour per lane (the per-tick intake cap). Sub-1-unit-per-tick
## rates still flow via each lane's fractional intake_credit carryover.
@export var rate_per_hour: float = 60.0
## Lanes on a fresh (un-upgraded) conveyor.
@export var base_lanes: int = 1

## Stat key (WI-27) read through owner_module.get_effective_stat so the Extra Belt
## upgrade raises the lane count non-destructively.
const STAT_CONVEYOR_LANES := &"conveyor_lanes"

var lanes: Array[ConveyorLane] = []
## Only true once constructed - gates the transfer scan like storage gates posting.
var _transfer_active: bool = false

## Emitted when the lane count changes (upgrade purchased / restored), so the UI
## rebuilds its per-lane rows.
signal lanes_changed

const NEIGHBOR_OFFSETS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]

func _ready() -> void:
	super()
	Global.time_manager.slow_tick.connect(_on_slow_tick)
	_sync_lanes()

func ready_preview() -> void:
	_transfer_active = false

func ready_blueprint() -> void:
	_transfer_active = false

func ready_constructed() -> void:
	_transfer_active = true
	if not SignalBus.module_upgraded.is_connected(_on_module_upgraded):
		SignalBus.module_upgraded.connect(_on_module_upgraded)
	_sync_lanes()

## Effective lane count after upgrades, clamped to [1, MAX_LANES].
func effective_max_lanes() -> int:
	var n: int = base_lanes
	if owner_module != null:
		n = int(owner_module.get_effective_stat(STAT_CONVEYOR_LANES, float(base_lanes)))
	return clampi(n, 1, MAX_LANES)

## Grows the lane list to the effective count (never shrinks - the cap only ever
## rises via upgrades, and a configured lane must never be discarded).
func _sync_lanes() -> void:
	var target: int = effective_max_lanes()
	var changed: bool = false
	while lanes.size() < target:
		lanes.append(ConveyorLane.new())
		changed = true
	if changed:
		lanes_changed.emit()

func _on_module_upgraded(module: ModuleBase) -> void:
	if module == owner_module:
		_sync_lanes()

# --- neighbour discovery (shared by all lanes) ------------------------------

## Adjacent (4-neighbour) MODULE-layer modules, deduped (a 2x2 neighbour occupies
## two of our neighbour cells but should appear once).
func adjacent_modules() -> Array[ModuleBase]:
	var out: Array[ModuleBase] = []
	if owner_module == null or Global.world_manager == null:
		return out
	var seen: Dictionary[ModuleBase, bool] = {}
	for offset: Vector2i in NEIGHBOR_OFFSETS:
		var m: ModuleBase = Global.world_manager.get_module_by_cell(WorldManager.StructureLayer.MODULE, owner_module.module_cell + offset)
		if m != null and m != owner_module and not seen.has(m):
			seen[m] = true
			out.append(m)
	return out

## Eligible source endpoints: adjacent storages that allow exports (WI-12), plus
## adjacent conveyors (their buffers can always export).
func get_source_options() -> Array[ComponentBase]:
	return _endpoint_options(true)

## Eligible destination endpoints: adjacent storages that allow imports, plus
## adjacent conveyors.
func get_destination_options() -> Array[ComponentBase]:
	return _endpoint_options(false)

func _endpoint_options(as_source: bool) -> Array[ComponentBase]:
	var out: Array[ComponentBase] = []
	for m: ModuleBase in adjacent_modules():
		for comp: ComponentBase in m.components:
			if comp is StorageComponent:
				var storage: StorageComponent = comp as StorageComponent
				# Since WI-65 direction is per-resource, but a belt endpoint is
				# picked before its resource is: a bin qualifies if it has ANY
				# slot facing the right way. Which resources that endpoint can
				# actually carry is get_resource_options_for()'s question.
				if (as_source and storage.has_output_or_general_slots()) 						or (not as_source and storage.has_intake_slots()):
					out.append(comp)
			elif comp is ConveyorComponent:
				out.append(comp)
	return out

## Resources a lane may move, derived from its chosen source. A storage offers what
## it's set up to hold (or every storable resource when it accepts anything); a
## conveyor source offers whatever resources its lanes carry.
func get_resource_options_for(lane: ConveyorLane) -> Array[ResourceData]:
	var out: Array[ResourceData] = []
	if lane.source is StorageComponent:
		var storage: StorageComponent = lane.source as StorageComponent
		if storage.allow_any_resource and storage.storage_data.is_empty():
			if Global.resource_manager != null:
				out.assign(Global.resource_manager.storable_resources)
		else:
			for res: ResourceData in storage.storage_data.keys():
				out.append(res)
	elif lane.source is ConveyorComponent:
		for src_lane: ConveyorLane in (lane.source as ConveyorComponent).lanes:
			if src_lane.resource != null and not out.has(src_lane.resource):
				out.append(src_lane.resource)
	elif Global.resource_manager != null:
		# No source yet - offer everything so the resource can be picked first.
		out.assign(Global.resource_manager.storable_resources)
	return out

# --- per-lane configuration (driven by the UI) ------------------------------

## Rejects a source equal to this lane's destination (WI-27 edge case); loops
## through longer chains are allowed (harmless, rate-limited cycling).
func set_lane_source(lane: ConveyorLane, endpoint: ComponentBase) -> void:
	if endpoint != null and endpoint == lane.destination:
		return
	lane.source = endpoint

func set_lane_destination(lane: ConveyorLane, endpoint: ComponentBase) -> void:
	if endpoint != null and endpoint == lane.source:
		return
	lane.destination = endpoint

## Switching a lane's resource dumps its buffered goods (they were the old type)
## as a pile, so a lane's buffer never mixes resources.
func set_lane_resource(lane: ConveyorLane, new_resource: ResourceData) -> void:
	if new_resource == lane.resource:
		return
	if not lane.buffer.is_empty():
		_dump_buffer_to_pile(lane.buffer, lane.resource)
	lane.resource = new_resource
	lane.buffer.resource_data = new_resource

# --- per-tick transfer ------------------------------------------------------

func _on_slow_tick(interval: float) -> void:
	if not _transfer_active:
		return
	if power_consumer != null and not power_consumer.powered:
		last_error = "No power!"
		return
	last_error = ""
	for lane: ConveyorLane in lanes:
		_tick_lane(lane, interval)

func _tick_lane(lane: ConveyorLane, interval: float) -> void:
	_validate_lane(lane)
	if lane.resource == null:
		lane.status = "Not configured"
		return
	if lane.source == null and lane.destination == null:
		lane.status = "No endpoints set"
		return
	# 1) Intake from the source into the buffer, rate-limited, unreserved stock only
	# (same rule as WI-12 venting - never touch reserved stock).
	lane.intake_credit += rate_per_hour * (interval / TimeManager.SECONDS_PER_HOUR)
	var to_move: int = int(floor(lane.intake_credit))
	lane.intake_credit -= to_move
	if lane.source != null and to_move > 0:
		var free: int = maxi(buffer_size - lane.buffer.stored, 0)
		var intake: int = mini(to_move, free)
		if intake > 0:
			for stack: ResourceStack in _endpoint_withdraw_up_to(lane.source, lane.resource, intake):
				lane.buffer.add_stack(stack)
	# 2) Push the buffer into the destination, up to whatever room it has now.
	if lane.destination != null and not lane.buffer.is_empty():
		var dest_space: int = _endpoint_space_for(lane.destination, lane.resource)
		var out_amount: int = mini(dest_space, lane.buffer.stored)
		if out_amount > 0:
			var out_stacks: Array[ResourceStack] = lane.buffer.withdraw_stacks(out_amount)
			if not _endpoint_deposit_stacks(lane.destination, lane.resource, out_stacks):
				# Lost the race for room - put the goods back in the buffer intact.
				for stack: ResourceStack in out_stacks:
					lane.buffer.add_stack(stack)
				lane.status = "Destination full"
			else:
				lane.status = ""
		else:
			lane.status = "Destination full"
	elif lane.buffer.is_empty():
		lane.status = ""

## Drops references to endpoints whose module was deconstructed out from under a
## lane (freed component). The lane half-clears and idles until reconfigured.
func _validate_lane(lane: ConveyorLane) -> void:
	if lane.source != null and not _endpoint_alive(lane.source):
		lane.source = null
		lane.status = "Source removed"
	if lane.destination != null and not _endpoint_alive(lane.destination):
		lane.destination = null
		lane.status = "Destination removed"

func _endpoint_alive(endpoint: ComponentBase) -> bool:
	return is_instance_valid(endpoint) and endpoint.owner_module != null and is_instance_valid(endpoint.owner_module)

# --- typed endpoint accessors (StorageComponent | ConveyorComponent) --------

func _endpoint_withdraw_up_to(endpoint: ComponentBase, res: ResourceData, amount: int) -> Array[ResourceStack]:
	if amount <= 0:
		return []
	if endpoint is StorageComponent:
		return (endpoint as StorageComponent).withdraw_stacks_up_to(res, amount, false)
	if endpoint is ConveyorComponent:
		return (endpoint as ConveyorComponent).buffer_withdraw_up_to(res, amount)
	return []

func _endpoint_space_for(endpoint: ComponentBase, res: ResourceData) -> int:
	if endpoint is StorageComponent:
		var storage: StorageComponent = endpoint as StorageComponent
		if not storage.can_store_resource(res):
			return 0
		return storage.space_available()
	if endpoint is ConveyorComponent:
		return (endpoint as ConveyorComponent).buffer_free_for(res)
	return 0

func _endpoint_deposit_stacks(endpoint: ComponentBase, res: ResourceData, stacks: Array[ResourceStack]) -> bool:
	if endpoint is StorageComponent:
		return (endpoint as StorageComponent).deposit_stacks(res, stacks, true)
	if endpoint is ConveyorComponent:
		return (endpoint as ConveyorComponent).buffer_deposit_stacks(res, stacks)
	return false

# --- buffer shim: lets an adjacent conveyor use THIS conveyor as an endpoint --
# Resource-keyed across lanes, so a neighbour chaining resource R reads/writes the
# lane carrying R (a conveyor never runs two lanes for the same resource in a chain
# - the first matching lane wins, which is what a player building a chain expects).

func _lane_for_resource(res: ResourceData) -> ConveyorLane:
	if res == null:
		return null
	for lane: ConveyorLane in lanes:
		if lane.resource == res:
			return lane
	return null

func buffer_withdraw_up_to(res: ResourceData, amount: int) -> Array[ResourceStack]:
	var lane: ConveyorLane = _lane_for_resource(res)
	if lane == null or amount <= 0:
		return []
	return lane.buffer.withdraw_stacks(mini(amount, lane.buffer.stored))

func buffer_free_for(res: ResourceData) -> int:
	var lane: ConveyorLane = _lane_for_resource(res)
	if lane == null:
		return 0
	return maxi(buffer_size - lane.buffer.stored, 0)

## All-or-nothing (the caller only ever offers what buffer_free_for allowed).
func buffer_deposit_stacks(res: ResourceData, stacks: Array[ResourceStack]) -> bool:
	var lane: ConveyorLane = _lane_for_resource(res)
	if lane == null:
		return false
	var total: int = 0
	for stack: ResourceStack in stacks:
		total += stack.amount
	if buffer_size - lane.buffer.stored < total:
		return false
	for stack: ResourceStack in stacks:
		lane.buffer.add_stack(stack)
	return true

# --- buffer dumping ---------------------------------------------------------

func lane_buffer_amount(lane: ConveyorLane) -> int:
	return lane.buffer.stored

func _dump_buffer_to_pile(buffer: ResourceStackContainer, res: ResourceData) -> void:
	if buffer.is_empty() or res == null:
		return
	if owner_module == null or not is_instance_valid(owner_module):
		return
	var pile: ResourcePile = owner_module.get_or_create_overflow_pile()
	pile.add_stacks(res, buffer.withdraw_stacks(buffer.stored))

## Every lane's buffer dumps only when the CONVEYOR itself is removed (not when an
## endpoint goes away). Guarded like PawnBase's PREDELETE dump so it's skipped
## during a save/load teardown, where the managers are already gone.
func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE:
		return
	if not is_instance_valid(Global.world_manager):
		return
	# The conveyor's module goes away with it, so the spill is free-floating
	# debris rather than that module's overflow: it belongs in space.
	var space: CanvasLayer = Global.world_manager.get_canvas_for_layer(
			WorldManager.StructureLayer.SPACE)
	if not is_instance_valid(space):
		return
	var pile: ResourcePile = null
	for lane: ConveyorLane in lanes:
		if lane.buffer.is_empty() or lane.resource == null:
			continue
		if pile == null:
			pile = ResourcePile.spawn(space, global_position, null)
		pile.add_stacks(lane.resource, lane.buffer.withdraw_stacks(lane.buffer.stored))

# --- persistence ------------------------------------------------------------

## Each lane saves its endpoints as component refs (module layer+cell + node path),
## resource as its id, and buffer as stacks. Restored by load_save_data after the
## world is rebuilt (endpoints resolve against already-placed modules).
## Endpoints resolve against modules already placed in the world load's first
## phase, so restoring anywhere in the second phase is safe. Stays before the
## upgrades block on purpose: load_save_data grows the lane array itself rather
## than depending on the Extra Belt upgrade having restored first.
func save_order() -> int:
	return 100

func save_key() -> StringName:
	return &"conveyor"

func get_save_data() -> Dictionary:
	var lane_dicts: Array = []
	for lane: ConveyorLane in lanes:
		var d: Dictionary = {}
		if lane.resource != null and lane.resource.id != &"":
			d["resource"] = String(lane.resource.id)
		if lane.source != null and is_instance_valid(lane.source):
			d["source"] = SaveManager.component_ref(lane.source)
		if lane.destination != null and is_instance_valid(lane.destination):
			d["destination"] = SaveManager.component_ref(lane.destination)
		if not lane.buffer.is_empty():
			d["buffer"] = SaveManager.stacks_to_dicts(lane.buffer.stacks)
		lane_dicts.append(d)
	return {"buffer_size": buffer_size, "lanes": lane_dicts}

func load_save_data(data: Dictionary) -> void:
	buffer_size = int(data.get("buffer_size", buffer_size))
	var lane_dicts: Array = data.get("lanes", [])
	# Ensure a lane per saved entry even if the lane-count upgrade restores after
	# this call (module_base loads upgrades near the end); lanes never shrink.
	while lanes.size() < lane_dicts.size():
		lanes.append(ConveyorLane.new())
	for i: int in lane_dicts.size():
		var d: Dictionary = lane_dicts[i]
		var lane: ConveyorLane = lanes[i]
		var res_id: String = String(d.get("resource", ""))
		if res_id != "":
			lane.resource = Global.save_manager.get_resource_by_id(StringName(res_id))
			lane.buffer.resource_data = lane.resource
		lane.source = SaveManager.resolve_component_ref(d.get("source", {}))
		lane.destination = SaveManager.resolve_component_ref(d.get("destination", {}))
		if lane.resource != null:
			for stack_dict: Dictionary in d.get("buffer", []):
				var stack: ResourceStack = SaveManager.stack_from_dict(lane.resource, stack_dict)
				if stack.amount > 0:
					lane.buffer.add_stack(stack)
	lanes_changed.emit()

func has_ui() -> bool:
	return true

func get_ui() -> ModuleComponentUI:
	var ui := ConveyorComponentUI.new()
	ui.set_conveyor(self)
	return ui
