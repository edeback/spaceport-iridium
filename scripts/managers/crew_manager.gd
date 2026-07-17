class_name CrewManager
extends Node

## Crew lifecycle (WI-07): owns starting-crew spawn, hiring (with shuttle
## arrivals), resignation departures, and the lose condition. Registers as
## Global.crew_manager; sits after the world/job managers in main.tscn's
## Managers node (tree order = ready order).
##
## The roster is a live query over the "pawn" group (drones excluded) rather
## than a stored array - pawns enter via spawn_crew()/save-load and leave via
## queue_free, and a query can't drift out of sync with either.

@export var crew_pawn_scene: PackedScene
@export var shuttle_scene: PackedScene
@export var starting_crew: int = 2
@export var hire_cost: int = 500
@export var arrival_delay_hours: float = 4.0
## How far off to the side of the bay the shuttle spawns and exits, in px.
@export var shuttle_approach_distance: float = 1200.0

## Pending hires: {"remaining": sim-hours left, "bay": module ref Dictionary
## (layer+cell, JSON-safe - resolved at arrival so a deconstructed bay can
## refund instead of dangling)}.
var _pending_hires: Array[Dictionary] = []
var _game_over_fired: bool = false

func _ready() -> void:
	Global.crew_manager = self
	SignalBus.crew_resigned.connect(_on_crew_resigned)
	# The starting station is spawned by WorldManager at runtime, AFTER any
	# fixed number of deferred hops - so react to the module actually
	# appearing instead of guessing at ordering.
	SignalBus.module_added.connect(_on_module_added_for_start)

var _starting_crew_spawned: bool = false

func _on_module_added_for_start(module: ModuleBase) -> void:
	if _starting_crew_spawned:
		return
	# Loaded games restore their crew from the save's pawn section instead.
	if SaveManager.is_loading() or SaveManager.has_pending_load():
		_starting_crew_spawned = true
		SignalBus.module_added.disconnect(_on_module_added_for_start)
		Global.time_manager.slow_tick.connect(_on_slow_tick)
		return
	if module.module_data == null or module.module_data.id != &"starting_module_mdata":
		return
	_starting_crew_spawned = true
	SignalBus.module_added.disconnect(_on_module_added_for_start)
	Global.time_manager.slow_tick.connect(_on_slow_tick)
	# Deferred one tick: module_added fires before on_place() assigns the
	# module's cell, and spawn positions derive from it.
	_spawn_starting_crew.call_deferred(module)

func _spawn_starting_crew(home: ModuleBase) -> void:
	if not is_instance_valid(home):
		return
	for i: int in starting_crew:
		spawn_crew(home)

# --- roster -------------------------------------------------------------------

## All living organic crew. include_leaving = false filters out pawns that
## have already resigned and are walking to the bay.
func get_crew(include_leaving: bool = true) -> Array[PawnBase]:
	var crew: Array[PawnBase] = []
	for node: Node in get_tree().get_nodes_in_group("pawn"):
		var pawn: PawnBase = node as PawnBase
		if pawn == null or pawn is MiningDronePawn or pawn.is_queued_for_deletion():
			continue
		if not include_leaving:
			var needs: PawnNeedsComponent = pawn.get_component_by_type(PawnNeedsComponent) as PawnNeedsComponent
			if needs != null and needs.resigned:
				continue
		crew.append(pawn)
	return crew

func crew_count(include_leaving: bool = true) -> int:
	return get_crew(include_leaving).size()

## Total sleeping slots across constructed pods - the housing capacity gate.
func sleep_capacity() -> int:
	var total: int = 0
	for node: Node in get_tree().get_nodes_in_group("sleep_component"):
		total += (node as SleepComponent).capacity
	return total

func pending_hire_count() -> int:
	return _pending_hires.size()

# --- hiring -------------------------------------------------------------------

## "" means a hire is currently allowed; otherwise a player-facing reason.
func hire_block_reason() -> String:
	if crew_count() + _pending_hires.size() >= sleep_capacity():
		return "No free sleeping pods"
	if Global.resource_manager.credit_resource.get_total() < hire_cost:
		return "Not enough credits"
	return ""

func request_hire(bay: ModuleBase) -> bool:
	if bay == null or hire_block_reason() != "":
		return false
	Global.resource_manager.credit_resource.force_withdraw(hire_cost)
	_pending_hires.append({"remaining": arrival_delay_hours, "bay": SaveManager.module_ref(bay)})
	return true

func _process(delta: float) -> void:
	var sim_hours: float = Global.time_manager.scale(delta) / TimeManager.SECONDS_PER_HOUR
	if sim_hours <= 0.0:
		return
	for i: int in range(_pending_hires.size() - 1, -1, -1):
		_pending_hires[i]["remaining"] = float(_pending_hires[i]["remaining"]) - sim_hours
		if float(_pending_hires[i]["remaining"]) <= 0.0:
			var hire: Dictionary = _pending_hires[i]
			_pending_hires.remove_at(i)
			_arrive(hire)

func _arrive(hire: Dictionary) -> void:
	var bay: ModuleBase = SaveManager.resolve_module_ref(hire.get("bay", {}))
	if bay == null or not is_instance_valid(bay):
		_refund_hire()
		return
	if shuttle_scene == null:
		_deliver_crew(bay)
		return
	var shuttle: ArrivalShuttle = shuttle_scene.instantiate() as ArrivalShuttle
	Global.world_manager.pawn_layer.add_child(shuttle)
	var dock: Vector2 = DockingBay.dock_position_for(bay)
	shuttle.setup(dock, dock + Vector2(DockingBay.approach_sign_for(bay) * shuttle_approach_distance, 0.0))
	shuttle.docked.connect(_on_shuttle_docked.bind(shuttle, bay), CONNECT_ONE_SHOT)

## Bay deconstructed while the shuttle was inbound: refund (WI-07 edge case).
func _refund_hire() -> void:
	Global.resource_manager.credit_resource.change_global_total(hire_cost)
	SignalBus.station_alert.emit("Recruit had nowhere to dock — fee refunded")

func _on_shuttle_docked(shuttle: ArrivalShuttle, bay: ModuleBase) -> void:
	if is_instance_valid(bay):
		_deliver_crew(bay)
	else:
		_refund_hire()
	# Wait a little bit before flying away
	await Global.time_manager.sim_seconds(Global.time_manager.SECONDS_PER_HOUR)
	shuttle.depart()

func _deliver_crew(bay: ModuleBase) -> void:
	var pawn: PawnBase = spawn_crew(bay)
	SignalBus.crew_hired.emit(pawn)

## Spawns one crew pawn inside at_module. Shifts alternate with roster
## parity so hires keep covering the clock (WI-06).
func spawn_crew(at_module: ModuleBase) -> PawnBase:
	var pawn: PawnBase = crew_pawn_scene.instantiate() as PawnBase
	# First two keep their always-on schedule
	if pawn.schedule != null and crew_count() >= 2:
		if crew_count() % 2 == 1:
			pawn.schedule = ScheduleData.shift_a()
		else:
			pawn.schedule = ScheduleData.shift_b()
	# Add to tree BEFORE setting current_module: the setter reparents, which
	# needs a parent (this was the old PawnStorageComponent boot error).
	Global.world_manager.pawn_layer.add_child(pawn)
	pawn.current_module = at_module
	pawn.global_position = Global.cell_to_world(at_module.module_cell, true)
	return pawn

# --- departure & lose condition -------------------------------------------------

func _on_crew_resigned(pawn: PawnBase) -> void:
	# Graceful interrupt (WI-04): whatever they were doing cancels cleanly,
	# carried cargo stays with them and piles up at despawn.
	pawn.interrupt_with_job(Job_LeaveStation.new())

func _on_slow_tick(_interval: float) -> void:
	_check_lose_condition()

func _check_lose_condition() -> void:
	if _game_over_fired:
		return
	if crew_count() > 0 or not _pending_hires.is_empty():
		return
	# Roster empty AND can't afford a replacement - empty-but-solvent is
	# recoverable by hiring, so it's deliberately not game over.
	if Global.resource_manager.credit_resource.get_total() >= hire_cost:
		return
	_game_over_fired = true
	SignalBus.game_over.emit()

# --- persistence ---------------------------------------------------------------

func get_save_data() -> Dictionary:
	return {"pending_hires": _pending_hires.duplicate(true)}

func load_save_data(data: Dictionary) -> void:
	_pending_hires.clear()
	for entry in data.get("pending_hires", []):
		var hire: Dictionary = entry
		_pending_hires.append({
			"remaining": float(hire.get("remaining", 0.0)),
			"bay": hire.get("bay", {}),
		})
