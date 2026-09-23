extends GutTest

## WI-74 on a running station.
##
## - **§1, one `start_job`.** Four copies became one template in PawnBase with five
##   hooks. The risk was in the orderings, so each row of the WI's table is an
##   assertion here, one pawn kind at a time, driven into each gate. A test calls
##   `start_job()` itself on a pawn it has cleared, rather than ticking and hoping
##   the pick it wants comes up.
## - **§3, clicks through the bus.** A world object no longer calls the HUD; the
##   inspector still opens on every kind of click.
## - **§4, F34.** A blueprint cancelled before it is finished refunds its whole fee,
##   however much work was done; a finished deconstruction refunds it too; a
##   demolition refunds nothing; and nothing the game placed for free pays out.
## - **§6, F37.** The five countdowns moved onto the slow tick still fire within a
##   tick of when they did, each measured against its own configured duration.

## A cell clear of the starter station, the same one WI-70's deconstruction tests
## use: crew reach it on foot through the airlock.
const FAR_CELL := Vector2i(26, 8)
## Next to the starter station, where F25's builder test puts its blueprint.
const NEAR_CELL := Vector2i(14, 8)
## A countdown on the slow tick may run up to one tick late or early against the
## per-frame clock it replaced, and the measurement itself is good to a frame at
## each end.
const TIMING_SLACK: float = TimeManager.SLOW_TICK_INTERVAL \
	+ 2.0 * StationFixture.FRAME_SECONDS * StationFixture.DEFAULT_SPEED

var fx: StationFixture

func before_each() -> void:
	fx = StationFixture.new(self)
	await fx.boot()

func after_each() -> void:
	await fx.finish()

# --- §1: robots ---------------------------------------------------------------

## Rows 1-2 for a robot: at zero energy the gate takes the pick before the restored
## job is even looked at - and once charged, the restored job is still first.
func test_a_drained_robot_recharges_before_its_restored_job() -> void:
	fx.build_production_line()
	assert_true(await fx.tick_until(_a_drone_is_mining, 40.0), "a drone is out mining")
	assert_true(await fx.save_and_reload())
	var drone: MiningDronePawn = _drone_awaiting_resume()
	assert_not_null(drone, "a drone comes back with its trip waiting to resume")
	if drone == null:
		return
	var restored: Job = drone.job_queue[0]
	var recharge: Job = Job.of(&"recharge")
	drone.queue_job(recharge)
	drone.power_component.energy = 0.0
	drone.start_job()
	assert_ne(drone.current_job, restored, "a drained robot does not resume its trip")
	assert_true(drone.current_job == null or drone.current_job == recharge,
		"it recharges or holds position, and nothing else")
	assert_true(drone.job_queue.has(restored) and restored.awaits_resume(),
		"the trip is still waiting, untouched")
	_stop(drone)
	drone.power_component.energy = drone.power_component.energy_max
	drone.start_job()
	assert_eq(drone.current_job, restored, "charged, the restored trip is the first thing it does")

## Rows 4-7 for a robot: below the threshold it still runs its queue - which is
## where its recharge would be - but takes no new work, and it never wanders.
func test_a_low_robot_runs_its_queue_and_takes_no_new_work() -> void:
	fx.build_production_line()
	assert_true(await fx.tick_until(func() -> bool: return _drone() != null, 20.0), "the bay builds a drone")
	var drone: MiningDronePawn = _drone()
	if drone == null:
		return
	_clear(drone)
	_empty_hands(drone)
	drone.power_component.energy = drone.power_component.energy_max * 0.2
	assert_true(drone.power_component.wants_recharge() and not drone.power_component.must_recharge(),
		"low, but not drained")
	var queued: Job = Job.of(&"wait").with_count(1)
	drone.queue_job(queued)
	drone.start_job()
	assert_eq(drone.current_job, queued, "the queue runs ahead of the low-energy gate")
	_stop(drone)
	drone.start_job()
	assert_null(drone.current_job, "then nothing: no bay work below the threshold, and no wander")
	drone.power_component.energy = drone.power_component.energy_max
	drone.start_job()
	assert_not_null(drone.current_job, "charged, it takes work again")
	if drone.current_job != null:
		assert_true(drone.current_job.is_type(&"mine_asteroid"), "its own bay's work, not the board's")

# --- §1: guests, the inspector and crew ----------------------------------------

## A guest runs its queue and otherwise wanders - and the board, which it could
## perfectly well serve, is never its to take.
func test_a_guest_never_takes_board_work() -> void:
	var guest: VisitorPawn = Global.visitor_manager.spawn_visitor_at(_home(), 120, 30.0)
	assert_not_null(guest, "a guest arrives")
	if guest == null:
		return
	guest._departure_reported = true
	_clear(guest)
	var posted: Job = _post_wait()
	assert_true(posted.can_do_job(guest), "the guest could do the posted job, so refusing it is the rule")
	guest.start_job()
	assert_ne(guest.current_job, posted, "a guest does not take board work")
	assert_true(Global.job_manager.get_board_snapshot().has(posted), "the job is still on the board")
	assert_true(guest.current_job == null or guest.current_job.is_type(&"idle_wander"),
		"it wanders instead, as crew do off the clock")
	_clear(guest)
	var queued: Job = Job.of(&"wait").with_count(1)
	guest.queue_job(queued)
	guest.start_job()
	assert_eq(guest.current_job, queued, "a queued job is still the guest's to run")
	_unpost(posted)

## The inspector runs its queue and nothing else: no sweep of what it carries, no
## board, no wander.
func test_the_inspector_runs_only_its_queue() -> void:
	var steel: ResourceData = fx.resource(&"steel")
	_stock_a_storeroom(steel)
	var inspector: InspectorPawn = (load("res://pawns/inspector_pawn.tscn") as PackedScene).instantiate() as InspectorPawn
	Global.world_manager.get_canvas_for_layer(WorldManager.StructureLayer.SPACE).add_child(inspector)
	inspector.current_module = _home()
	_clear(inspector)
	inspector.inventory_component.add(steel, 2)
	assert_true(Job.of(&"store_inventory").can_do_job(inspector), "the steel has somewhere to go")
	var posted: Job = _post_wait()
	inspector.start_job()
	assert_null(inspector.current_job, "no sweep, no board, no wander: it holds position")
	assert_eq(inspector.inventory_component.get_carried_amount(steel), 2, "still carrying the steel")
	assert_true(Global.job_manager.get_board_snapshot().has(posted), "and the board job is untouched")
	var queued: Job = Job.of(&"wait").with_count(1)
	inspector.queue_job(queued)
	inspector.start_job()
	assert_eq(inspector.current_job, queued, "what the runner queues, it runs")
	_unpost(posted)
	inspector.inventory_component.withdraw(steel, 2)
	inspector.queue_free()

## Crew, rows 3-6: carried leftovers go first, then the queue, then the board.
func test_crew_sweep_their_cargo_then_run_their_queue_then_take_the_board() -> void:
	var steel: ResourceData = fx.resource(&"steel")
	_stock_a_storeroom(steel)
	var crew: PawnBase = Global.crew_manager.get_crew()[0]
	_clear(crew)
	crew.inventory_component.add(steel, 2)
	var queued: Job = Job.of(&"wait").with_count(1)
	crew.queue_job(queued)
	var posted: Job = _post_wait()
	crew.start_job()
	assert_not_null(crew.current_job)
	if crew.current_job == null:
		return
	assert_true(crew.current_job.is_type(&"store_inventory"), "the cargo sweep comes first")
	assert_true(crew.job_queue.has(queued), "and the queue waits its turn")
	_stop(crew)
	crew.inventory_component.withdraw(steel, 2)
	crew.start_job()
	assert_eq(crew.current_job, queued, "then the queue, ahead of the board")
	_clear(crew)
	crew.start_job()
	assert_not_null(crew.current_job, "then the board")
	if crew.current_job != null:
		assert_false(crew.current_job.is_idle_type(), "work, not a wander, while the board holds a job this pawn can do")
	_unpost(posted)

# --- §3: world clicks go through the bus ---------------------------------------

## Every kind of world object reaches the inspector through
## `SignalBus.world_object_clicked`, and none of them names the HUD to do it.
func test_every_kind_of_world_click_reaches_the_inspector() -> void:
	var inspector: InspectorPanel = Global.ui_main.inspector
	var crew: PawnBase = Global.crew_manager.get_crew()[0]
	SignalBus.world_object_clicked.emit(crew)
	assert_eq(inspector.selected_subject(), crew, "a pawn")
	var canvas: CanvasLayer = Global.world_manager.get_canvas_for_layer(WorldManager.StructureLayer.MODULE)
	var pile := ResourcePile.spawn(canvas, Global.cell_to_world(Vector2i(16, 9), true))
	pile.add_amount(fx.resource(&"steel"), 1)
	SignalBus.world_object_clicked.emit(pile)
	assert_eq(inspector.selected_subject(), pile, "a pile")
	var rocks: Array[Node] = get_tree().get_nodes_in_group(Groups.ASTEROID)
	if not rocks.is_empty():
		var rock: AsteroidBase = rocks[0] as AsteroidBase
		SignalBus.world_object_clicked.emit(rock)
		assert_eq(inspector.selected_subject(), rock, "an asteroid")
	SignalBus.world_object_clicked.emit(_home())
	assert_eq(inspector.selected_subject(), _home(), "a module, through the click cycler")
	var stray := Node2D.new()
	SignalBus.world_object_clicked.emit(stray)
	assert_eq(inspector.selected_subject(), _home(), "and a click on something with no page leaves the selection alone")
	stray.free()
	inspector.clear()

# --- §4: F34, credits and cancelling -------------------------------------------

## A blueprint cancelled the moment it lands costs nothing: the misclick case.
func test_f34_a_blueprint_cancelled_at_once_refunds_its_whole_fee() -> void:
	var before: int = fx.world_total(&"credits")
	var refunds_before: int = _refunds()
	var site: ModuleBase = await _buy(&"air_purifier_mdata", FAR_CELL)
	assert_not_null(site, "a blueprint is placed")
	if site == null:
		return
	var fee: int = site.module_data.credit_cost()
	assert_gt(fee, 0, "and it costs credits")
	assert_eq(fx.world_total(&"credits"), before - fee, "placing it charged the fee")
	assert_eq(site.credits_paid, fee, "and the module keeps the receipt")
	assert_true(Global.world_manager.remove_module(site), "right-click cancels it")
	assert_eq(fx.world_total(&"credits"), before, "the whole fee is back")
	assert_eq(_refunds() - refunds_before, fee, "booked as a refund in the ledger")

## However much work was done, a blueprint that is not finished refunds its whole
## fee - and the materials delivered to it come back as a pile.
func test_f34_a_blueprint_cancelled_mid_build_still_refunds_its_whole_fee() -> void:
	var credits_before: int = fx.world_total(&"credits")
	var steel_before: int = fx.world_total(&"steel")
	var site: ModuleBase = await _buy(&"air_purifier_mdata", NEAR_CELL)
	if site == null:
		return
	var construction: ConstructionComponent = _construction(site)
	var building: bool = await fx.tick_until(func() -> bool:
		return construction.current_state == ConstructionComponent.ConstructionState.Constructing \
			and construction.work_seconds_done > 0.0, 120.0)
	assert_true(building, "the site is resourced and a builder is at work")
	if not building:
		return
	assert_lt(construction.work_seconds_done, construction.work_seconds_to_complete, "and it is not finished")
	assert_true(Global.world_manager.remove_module(site), "right-click cancels it")
	assert_eq(fx.world_total(&"credits"), credits_before, "the whole fee is back")
	assert_eq(fx.world_total(&"steel"), steel_before, "and so is every unit of steel delivered to it")
	assert_true(await fx.tick(1.0), "and the builder lets go")

## A finished teardown refunds the fee, together with the materials - not before.
func test_f34_a_finished_deconstruction_refunds_the_fee() -> void:
	var site: ModuleBase = _buy_built(&"air_purifier_mdata", FAR_CELL)
	if site == null:
		return
	var fee: int = site.module_data.credit_cost()
	assert_eq(site.credits_paid, fee, "a module bought already built keeps its receipt too")
	var before: int = fx.world_total(&"credits")
	var construction: ConstructionComponent = _construction(site)
	construction.start_deconstruction()
	assert_eq(fx.world_total(&"credits"), before, "nothing comes back while it is still standing")
	# The site is removed once its refund is hauled away, so the wait allows for it
	# having gone - though the teardown is observed long before a hauler gets there.
	var done: bool = await fx.tick_until(func() -> bool:
		return not is_instance_valid(construction) \
			or construction.current_state == ConstructionComponent.ConstructionState.Deconstructed, 120.0)
	assert_true(done, "a crew member walks out and finishes the teardown")
	assert_eq(fx.world_total(&"credits"), before + fee, "the fee comes back as it finishes")
	if is_instance_valid(site):
		assert_eq(site.credits_paid, 0, "and the receipt is spent, so nothing pays twice")

## Demolishing a built module loses its fee along with its materials.
func test_f34_demolishing_a_built_module_refunds_nothing() -> void:
	var site: ModuleBase = _buy_built(&"air_purifier_mdata", FAR_CELL)
	if site == null:
		return
	var before: int = fx.world_total(&"credits")
	var refunds_before: int = _refunds()
	assert_true(Global.world_manager.remove_module(site), "demolished")
	assert_eq(fx.world_total(&"credits"), before, "no credits come back")
	assert_eq(_refunds(), refunds_before, "and the ledger books no refund")

## The exploit the receipt exists to stop: a module the game placed for free - a
## truss backfill, a door's corridor, the starting station - refunds nothing, or
## tearing one down would print its price.
func test_f34_a_module_the_game_placed_for_free_refunds_nothing() -> void:
	var site: ModuleBase = fx.place(&"air_purifier_mdata", FAR_CELL, false)
	assert_true(await fx.tick(0.1))
	assert_eq(site.credits_paid, 0, "nobody paid for it")
	var before: int = fx.world_total(&"credits")
	assert_true(Global.world_manager.remove_module(site))
	assert_eq(fx.world_total(&"credits"), before, "a free blueprint cancelled refunds nothing")
	var truss: ModuleBase = Global.world_manager.get_module_by_cell(WorldManager.StructureLayer.MODULE, FAR_CELL)
	assert_not_null(truss, "the cells it left are backfilled with truss")
	if truss != null:
		assert_eq(truss.credits_paid, 0, "which nobody paid for either")

## The receipt is saved: a teardown saved part-way refunds once when it finishes,
## and a load after it has paid does not pay again.
func test_f34_a_refund_owed_across_a_save_is_paid_exactly_once() -> void:
	var site: ModuleBase = _buy_built(&"air_purifier_mdata", FAR_CELL)
	if site == null:
		return
	var fee: int = site.module_data.credit_cost()
	var before: int = fx.world_total(&"credits")
	_construction(site).start_deconstruction()
	assert_true(await fx.save_and_reload(), "saved in the frame the teardown started")
	var restored: ModuleBase = _module_at(FAR_CELL)
	assert_not_null(restored)
	if restored == null:
		return
	assert_eq(restored.credits_paid, fee, "the receipt survives the save")
	var data: ModuleData = restored.module_data
	var done: bool = await fx.tick_until(func() -> bool:
		# Gone once its refund is hauled away, and truss stands in its place.
		var standing: ModuleBase = _module_at(FAR_CELL)
		if standing == null or standing.module_data != data:
			return true
		return _construction(standing).current_state == ConstructionComponent.ConstructionState.Deconstructed, 120.0)
	assert_true(done, "the teardown finishes after the load")
	assert_eq(fx.world_total(&"credits"), before + fee, "and refunds the fee")
	assert_true(await fx.save_and_reload())
	assert_true(await fx.tick(5.0))
	assert_eq(fx.world_total(&"credits"), before + fee, "a load after it has paid does not pay it again")

## A blueprint saved before anyone built it still refunds when cancelled after
## the load.
func test_f34_a_blueprint_keeps_its_receipt_across_a_save() -> void:
	var before: int = fx.world_total(&"credits")
	var site: ModuleBase = await _buy(&"air_purifier_mdata", FAR_CELL)
	if site == null:
		return
	assert_true(await fx.save_and_reload())
	var restored: ModuleBase = _module_at(FAR_CELL)
	assert_not_null(restored)
	if restored == null:
		return
	assert_false(restored.is_complete(), "still a blueprint")
	assert_true(Global.world_manager.remove_module(restored), "cancelled after the load")
	assert_eq(fx.world_total(&"credits"), before, "and the whole fee is back")

# --- §6: F37, the five countdowns on the slow tick --------------------------------

func test_f37_a_hire_launches_on_time() -> void:
	var bay: ModuleBase = Global.world_manager.get_module_by_cell(WorldManager.StructureLayer.MODULE, Vector2i(18, 8))
	assert_not_null(bay, "the starter docking bay")
	var candidate: HireCandidate = Global.crew_manager.get_candidates()[0]
	var delay_hours: float = 0.5
	var hire: Dictionary = Global.crew_manager._pending.add(SaveRefs.module_ref(bay), candidate.to_dict(), delay_hours)
	var elapsed: float = await _elapsed_until(func() -> bool: return bool(hire["launched"]), 30.0)
	assert_almost_eq(elapsed, delay_hours * TimeManager.SECONDS_PER_HOUR, TIMING_SLACK, "the shuttle launches on time")

func test_f37_a_trader_sets_off_on_time() -> void:
	var traders: TraderManager = Global.trader_manager
	assert_false(traders.visit_active or traders._inbound, "no visit under way")
	var delay_hours: float = 0.5
	traders.hours_to_next_visit = delay_hours
	var elapsed: float = await _elapsed_until(func() -> bool: return traders._inbound or traders.visit_active, 30.0)
	assert_almost_eq(elapsed, delay_hours * TimeManager.SECONDS_PER_HOUR, TIMING_SLACK, "the caravan sets off on time")

func test_f37_a_station_happiness_effect_expires_on_time() -> void:
	var events: EventManager = Global.event_manager
	var duration_hours: float = 0.5
	events.apply_station_happiness(&"meteor_lightshow", 0.05, duration_hours)
	var elapsed: float = await _elapsed_until(func() -> bool:
		return not events._happiness_effects.has(&"meteor_lightshow"), 30.0)
	assert_almost_eq(elapsed, duration_hours * TimeManager.SECONDS_PER_HOUR, TIMING_SLACK, "the effect lapses on time")

func test_f37_a_mining_bay_builds_its_drone_on_time() -> void:
	fx.build_production_line()
	var bay: MiningComponent = _mining_bay()
	assert_not_null(bay)
	if bay == null:
		return
	assert_true(await fx.tick_until(func() -> bool: return bay.power_consumer.powered, 5.0, 0.05), "the bay powers up")
	assert_eq(bay.drones.size(), 0, "with no drone yet")
	var elapsed: float = await _elapsed_until(func() -> bool: return not bay.drones.is_empty(), 20.0)
	assert_almost_eq(elapsed, bay.drone_respawn_seconds, TIMING_SLACK, "the first drone is built on time")

func test_f37_a_guest_leaves_on_time() -> void:
	var stay_hours: float = 0.5
	var guest: VisitorPawn = Global.visitor_manager.spawn_visitor_at(_home(), 120, stay_hours)
	assert_not_null(guest)
	if guest == null:
		return
	guest._departure_reported = true
	var elapsed: float = await _elapsed_until(func() -> bool: return guest._leaving, 30.0)
	assert_almost_eq(elapsed, stay_hours * TimeManager.SECONDS_PER_HOUR, TIMING_SLACK, "the stay ends on time")

# --- helpers --------------------------------------------------------------------

func _home() -> ModuleBase:
	return _module_at(Vector2i(15, 8))

static func _module_at(cell: Vector2i) -> ModuleBase:
	return Global.world_manager.get_module_by_cell(WorldManager.StructureLayer.MODULE, cell)

static func _construction(module: ModuleBase) -> ConstructionComponent:
	return module.get_component_by_type(ConstructionComponent) as ConstructionComponent

## Places `module_id` the way the player does - paid for, as a blueprint - and waits
## a frame for its deferred ready_blueprint, which is how long a player's
## right-click takes to follow a placement at the soonest.
func _buy(module_id: StringName, cell: Vector2i) -> ModuleBase:
	var data: ModuleData = Global.save_manager.get_module_data_by_id(module_id)
	Global.world_manager.purchase_and_add_module(data, cell)
	var site: ModuleBase = _module_at(cell)
	if site == null or site.module_data != data:
		fail_test("%s could not be bought at %s" % [module_id, cell])
		return null
	await fx.tick(0.05)
	return site

## Paid for and standing at once: the purchase path with the build skipped.
func _buy_built(module_id: StringName, cell: Vector2i) -> ModuleBase:
	var data: ModuleData = Global.save_manager.get_module_data_by_id(module_id)
	Global.world_manager.debug_build_anything = true
	Global.world_manager.purchase_and_add_module(data, cell)
	Global.world_manager.debug_build_anything = false
	var site: ModuleBase = _module_at(cell)
	if site == null or site.module_data != data or not site.is_complete():
		fail_test("%s could not be bought built at %s" % [module_id, cell])
		return null
	return site

func _refunds() -> int:
	var income: Dictionary = Global.economy_manager.current_record().get("income", {})
	return int(income.get(EconomyManager.REFUND_CATEGORY, 0))

## A storeroom that takes `resource`, joined to the station. A storeroom holds
## nothing until its contents are chosen.
func _stock_a_storeroom(resource: ResourceData) -> void:
	var store: ModuleBase = fx.place(&"large_storage", Vector2i(12, 8))
	fx.corridor(9, 12, 15)
	for component: ComponentBase in store.components:
		var storage: StorageComponent = component as StorageComponent
		if storage != null and not storage.construction_storage:
			storage.add_stored_resource(resource)
			return

## A one-second wait posted on the board: a MISC job any pawn can take, on or off
## shift, so it is the cleanest thing to put in front of a pawn that must refuse it.
func _post_wait() -> Job:
	var job: Job = Job.of(&"wait").with_count(1)
	Global.job_manager.add_job(job)
	return job

func _unpost(job: Job) -> void:
	Global.job_manager.remove_job(job)
	if not job.is_ended():
		job.cancel(true)

## Ends whatever `pawn` is doing, leaving its queue alone.
static func _stop(pawn: PawnBase) -> void:
	var running: Job = pawn.current_job
	pawn.current_job = null
	if running != null:
		running.cancel(true)

## Ends whatever `pawn` is doing and empties its queue, so the next start_job() is
## a clean pick. Bounded, because a need whose job is cancelled may queue another.
static func _clear(pawn: PawnBase) -> void:
	_stop(pawn)
	for _attempt: int in 8:
		if pawn.job_queue.is_empty():
			return
		var queued: Job = pawn.job_queue.pop_front()
		queued.cancel(true)

static func _empty_hands(pawn: PawnBase) -> void:
	for resource: ResourceData in pawn.inventory_component.get_carried_resources():
		pawn.inventory_component.withdraw(resource, pawn.inventory_component.get_carried_amount(resource))

func _drone() -> MiningDronePawn:
	for pawn: PawnBase in fx.pawns():
		if pawn is MiningDronePawn:
			return pawn as MiningDronePawn
	return null

func _a_drone_is_mining() -> bool:
	for pawn: PawnBase in fx.pawns():
		if pawn is MiningDronePawn and pawn.current_job != null \
				and pawn.current_job.is_type(&"mine_asteroid") and pawn.current_job.action_index() > 0:
			return true
	return false

## A drone restored with its trip at the head of its queue, marked to resume and
## not yet begun - the state a load leaves it in before its first pick.
func _drone_awaiting_resume() -> MiningDronePawn:
	for pawn: PawnBase in fx.pawns():
		var drone: MiningDronePawn = pawn as MiningDronePawn
		if drone == null or drone.current_job != null or drone.job_queue.is_empty():
			continue
		if drone._resume_first == drone.job_queue[0] and drone.job_queue[0].awaits_resume():
			return drone
	return null

func _mining_bay() -> MiningComponent:
	var module: ModuleBase = _module_at(Vector2i(8, 8))
	return module.get_component_by_type(MiningComponent) as MiningComponent if module != null else null

## Sim-seconds until `condition` holds, measured to a frame; -1 if it never does.
func _elapsed_until(condition: Callable, max_sim_seconds: float) -> float:
	var start: float = Global.time_manager.total_sim_seconds
	if not await fx.tick_until(condition, max_sim_seconds, 0.01):
		return -1.0
	return Global.time_manager.total_sim_seconds - start
