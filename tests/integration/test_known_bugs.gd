extends GutTest

## Open bugs pinned in their **current, broken** behaviour (WI-69 §4).
##
## Every test here asserts what the game does today, is named for its finding,
## and says what the fix changes. The suite stays green while each defect stays
## pinned. [[WI-70_Job_Ownership_Contract]] fixes all six and flips each
## assertion as it does. An *accidental* fix fails loudly here rather than
## passing unnoticed, and that failure is the signal to flip the test, not to
## weaken it.
##
## - **F38:** a save taken mid-deconstruction loses the refund.
## - **F25:** a builder interrupted mid-build strands the site in `Constructing`.
## - **F26:** a load re-posts a job its owner already has in flight: a site
##   mid-build, a manned processor mid-batch, a repair, and a pile being
##   collected.

## Sim-seconds to watch for the duplicate after a load. Every owner re-posts on
## its first frame or its first slow tick (a quarter sim-second).
const DUPLICATE_WINDOW: float = 2.0

var fx: StationFixture

func before_each() -> void:
	fx = StationFixture.new(self)
	await fx.boot()

func after_each() -> void:
	await fx.finish()

# --- F38: deconstruction across a save ----------------------------------------

## The control: a module torn down live refunds its whole cost. Kept beside the
## bug so a broken deconstruction path cannot make the F38 pin pass by accident.
func test_control_a_live_deconstruction_refunds_the_materials() -> void:
	var steel_before: int = fx.world_total(&"steel")
	var target: ModuleBase = fx.place(&"large_storage", Vector2i(26, 8))
	var refund: int = int(target.module_data.resource_costs[fx.resource(&"steel")])
	var construction: ConstructionComponent = _construction(target)
	construction.start_deconstruction()
	# The refund lands in the site's own OUTPUT bin. On the starter station there
	# is nowhere to haul it (the Command Center's pool is full), so the site stays
	# standing, Deconstructed, holding it - which is exactly what the world total
	# should count.
	var done: bool = await fx.tick_until(func() -> bool:
		return construction.current_state == ConstructionComponent.ConstructionState.Deconstructed, 120.0)
	assert_true(done, "a crew member walks out and finishes the teardown")
	assert_eq(fx.world_total(&"steel"), steel_before + refund, "the refund lands")

## F38 (known bug): the load collapses Deconstructing to Deconstructed, and only
## the live path deposits the refund. The reloaded site finds its bin empty and
## removes itself, and the materials never appear.
## WI-70 §5 flips this to `steel_before + refund`.
func test_f38_a_save_mid_deconstruction_loses_the_refund() -> void:
	var steel_before: int = fx.world_total(&"steel")
	var cell := Vector2i(26, 8)
	var target: ModuleBase = fx.place(&"large_storage", cell)
	var refund: int = int(target.module_data.resource_costs[fx.resource(&"steel")])
	assert_gt(refund, 0)
	_construction(target).start_deconstruction()
	assert_true(await fx.save_and_reload(), "saved in the frame the teardown started")
	var replaced: bool = await fx.tick_until(func() -> bool:
		var standing: ModuleBase = Global.world_manager.get_module_by_cell(WorldManager.StructureLayer.MODULE, cell)
		return standing != null and standing.module_data == Global.world_manager.replacement_module, 30.0)
	assert_true(replaced, "the reloaded site removes itself within seconds, backfilled with truss")
	assert_true(await fx.tick(30.0))
	assert_eq(fx.world_total(&"steel"), steel_before,
		"F38 (known bug): the %d steel refund is lost. WI-70 makes this %d." % [refund, steel_before + refund])

# --- F25: an interrupted builder ----------------------------------------------

## F25 (known bug): `_on_construction_job_end` resets the site only on FAILED,
## and an interrupted job ends INTERRUPTED - resignation, firing, or a Tier-2
## suit-up on the way. The site stays in `Constructing`, pointing at an ended job,
## and nothing re-posts. WI-70 §4 flips this: the site returns to `NotStarted`
## and a builder is posted again.
func test_f25_an_interrupted_builder_strands_the_site() -> void:
	var site: ModuleBase = fx.place(&"small_storage", Vector2i(14, 8), false)
	var builder: PawnBase = await _pawn_on(&"construct_module", func() -> Object: return _construction(site))
	assert_not_null(builder, "a crew member starts building")
	if builder == null:
		return
	var construction: ConstructionComponent = _construction(site)
	builder.interrupt_with_job(Job.of(&"idle"))
	assert_true(await fx.tick(30.0))
	assert_false(site.is_complete(), "F25 (known bug): the site is never finished")
	assert_eq(construction.current_state, ConstructionComponent.ConstructionState.Constructing,
		"F25 (known bug): it stays in Constructing. WI-70 returns it to NotStarted.")
	assert_true(construction.construction_job != null and construction.construction_job.is_ended(),
		"F25 (known bug): pointing at the interrupted job")
	assert_eq(fx.live_jobs(&"construct_module", construction).size(), 0,
		"F25 (known bug): and nothing re-posts it. WI-70 posts a builder again.")

# --- F26: duplicates after a load ----------------------------------------------

## F26 (known bug): the site restores as NotStarted with its materials, so it
## posts a second construct job beside the restored one. WI-70 §3 flips this to 1.
func test_f26_a_site_mid_build_gets_a_second_builder_after_a_load() -> void:
	var site: ModuleBase = fx.place(&"small_storage", Vector2i(14, 8), false)
	var builder: PawnBase = await _pawn_on(&"construct_module", func() -> Object: return _construction(site))
	assert_not_null(builder, "a crew member is building")
	if builder == null:
		return
	var cell: Vector2i = site.module_cell
	assert_eq(await _most_jobs_after_reload(&"construct_module", func() -> Object:
			return _construction(Global.world_manager.get_module_by_cell(WorldManager.StructureLayer.MODULE, cell))),
		2, "F26 (known bug): two construct jobs for one site. WI-70 makes this 1.")

## F26 (known bug): the processor's `_work_job` is null after the load, so it
## posts a second `work_processor` beside the operator's restored one; a second
## crew member walks to the machine and fails on the capacity-1 slot.
## WI-70 §3 flips this to 1.
func test_f26_a_manned_processor_gets_a_second_operator_job_after_a_load() -> void:
	var cell := Vector2i(13, 9)
	fx.place(&"ore_processor_mdata", cell)
	fx.place(&"debug_power", Vector2i(12, 9))
	fx.corridor(9, 12, 15)
	var processor: ProcessorComponent = _processor_at(cell)
	var ore: ResourceData = fx.resource(&"iron_ore")
	# The processor's own intake, not the module's first StorageComponent - that is
	# the construction bin.
	var intake: StorageComponent = processor.storage
	assert_gt(intake.room_for(ore), 0)
	intake.deposit(ore, intake.room_for(ore))
	var operator: PawnBase = await _pawn_on(&"work_processor", func() -> Object: return processor)
	assert_not_null(operator, "a crew member is working the processor")
	if operator == null:
		return
	assert_eq(await _most_jobs_after_reload(&"work_processor", func() -> Object: return _processor_at(cell)),
		2, "F26 (known bug): two operator jobs for one machine. WI-70 makes this 1.")

## F26 (known bug): `ModuleBase.adopt_repair_job()` exists for exactly this and
## has no caller, so the slow tick posts a second repair beside the restored one.
## WI-70 §3 flips this to 1.
func test_f26_a_repair_in_flight_gets_a_second_repair_job_after_a_load() -> void:
	var damaged: ModuleBase = fx.place(&"large_storage", Vector2i(12, 8))
	fx.corridor(9, 12, 15)
	damaged.apply_damage(damaged.max_hp() * 0.5)
	var repairer: PawnBase = await _pawn_on(&"repair_module", func() -> Object: return damaged)
	assert_not_null(repairer, "a crew member is repairing it")
	if repairer == null:
		return
	var cell: Vector2i = damaged.module_cell
	assert_eq(await _most_jobs_after_reload(&"repair_module", func() -> Object:
			return Global.world_manager.get_module_by_cell(WorldManager.StructureLayer.MODULE, cell)),
		2, "F26 (known bug): two repair jobs for one module. WI-70 makes this 1.")

## F26 (known bug): `_load_piles` re-adds the pile's stock, which posts a fresh
## `collect_pile` while the restored one resumes. WI-70 §3 flips this to 1.
func test_f26_a_pile_being_collected_gets_a_second_collector_after_a_load() -> void:
	# Somewhere to take it: the Command Center's pool is full and holds only its
	# own four resources.
	fx.place(&"large_storage", Vector2i(12, 8))
	fx.corridor(9, 12, 15)
	var canvas: CanvasLayer = Global.world_manager.get_canvas_for_layer(WorldManager.StructureLayer.MODULE)
	var pile := ResourcePile.spawn(canvas, Global.cell_to_world(Vector2i(16, 9), true))
	pile.add_amount(fx.resource(&"iron_ore"), 30)
	var pile_id: int = pile.pile_id
	var collector: PawnBase = await _pawn_on(&"collect_pile", func() -> Object: return pile)
	assert_not_null(collector, "a crew member is collecting the pile")
	if collector == null:
		return
	assert_eq(await _most_jobs_after_reload(&"collect_pile", func() -> Object: return _pile_by_id(pile_id)),
		2, "F26 (known bug): two collect jobs for one pile. WI-70 makes this 1.")

# --- helpers ------------------------------------------------------------------

## Ticks until some pawn is running a `type_id` job aimed at `target.call()`, past
## its first action (so the save records it as in flight). Returns the pawn.
func _pawn_on(type_id: StringName, target: Callable, within: float = 120.0) -> PawnBase:
	var found: Array[PawnBase] = [null]
	await fx.tick_until(func() -> bool:
		var aimed_at: Object = target.call()
		for pawn: PawnBase in fx.pawns():
			var job: Job = pawn.current_job
			if job != null and job.is_type(type_id) and not job.is_ended() and job.action_index() > 0 \
					and fx.live_jobs(type_id, aimed_at).has(job):
				found[0] = pawn
				return true
		return false, within, 0.1)
	return found[0]

## Saves and reloads, checks the in-flight job came back, then returns the most
## live `type_id` jobs aimed at `target.call()` seen over the next
## [constant DUPLICATE_WINDOW] sim-seconds.
func _most_jobs_after_reload(type_id: StringName, target: Callable) -> int:
	assert_eq(fx.live_jobs(type_id, target.call()).size(), 1, "one %s job before the save" % type_id)
	if not await fx.save_and_reload():
		return -1
	assert_gt(fx.live_jobs(type_id, target.call()).size(), 0, "the in-flight %s job was restored" % type_id)
	var most: Array[int] = [0]
	await fx.tick_until(func() -> bool:
		most[0] = maxi(most[0], fx.live_jobs(type_id, target.call()).size())
		return false, DUPLICATE_WINDOW, 0.05)
	return most[0]

static func _construction(module: ModuleBase) -> ConstructionComponent:
	if module == null or not is_instance_valid(module):
		return null
	return module.get_component_by_type(ConstructionComponent) as ConstructionComponent

func _processor_at(cell: Vector2i) -> ProcessorComponent:
	var module: ModuleBase = Global.world_manager.get_module_by_cell(WorldManager.StructureLayer.MODULE, cell)
	return module.get_component_by_type(ProcessorComponent) as ProcessorComponent if module != null else null

func _pile_by_id(pile_id: int) -> ResourcePile:
	for pile: ResourcePile in fx.piles():
		if pile.pile_id == pile_id:
			return pile
	return null
