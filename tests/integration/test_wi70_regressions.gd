extends GutTest

## WI-70's four bugs, each pinned broken by WI-69 as `test_known_bugs.gd` and
## flipped here as its fix landed. A regression fails the test named for it.
##
## - **F38:** a save taken mid-deconstruction lost the refund. The load collapsed
##   Deconstructing to Deconstructed, and only the live transition deposits.
## - **F25:** a builder interrupted mid-build stranded the site in `Constructing`,
##   because its handler re-posted on FAILED and an interruption is not a failure.
## - **F26:** a load re-posted every job its owner already had in flight: a site
##   mid-build, a manned processor mid-batch, a repair, a pile being collected.
##
## Plus the two WI-70 §Verification adds: a teardown that stalls for want of an
## airlock keeps its refund promise across a save, and after a load no owner holds
## a second job beside the one it had in flight.

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
## fix so a broken deconstruction path cannot make the F38 test pass by accident.
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

## F38: a teardown saved in progress comes back in progress, with the work it had
## left, and finishes - refund and all.
func test_f38_a_save_mid_deconstruction_keeps_the_refund() -> void:
	var steel_before: int = fx.world_total(&"steel")
	var cell := Vector2i(26, 8)
	var target: ModuleBase = fx.place(&"large_storage", cell)
	var refund: int = int(target.module_data.resource_costs[fx.resource(&"steel")])
	assert_gt(refund, 0)
	var construction: ConstructionComponent = _construction(target)
	construction.start_deconstruction()
	var work_left: float = construction.work_seconds_done
	assert_true(await fx.save_and_reload(), "saved in the frame the teardown started")
	var restored: ConstructionComponent = _construction_at(cell)
	assert_not_null(restored, "the site is still standing after the load")
	if restored == null:
		return
	assert_eq(restored.current_state, ConstructionComponent.ConstructionState.Deconstructing,
		"still being taken apart, not collapsed to Deconstructed")
	assert_almost_eq(restored.work_seconds_done, work_left, 0.001, "with the work it had left")
	var done: bool = await fx.tick_until(func() -> bool:
		var site: ConstructionComponent = _construction_at(cell)
		return site == null or site.current_state == ConstructionComponent.ConstructionState.Deconstructed, 120.0)
	assert_true(done, "a crew member walks out and finishes the teardown")
	assert_eq(fx.world_total(&"steel"), steel_before + refund,
		"the %d steel refund lands, where F38 lost it" % refund)

## Nobody can go outside, so the teardown waits on the board. A save in that
## state must keep the site standing and the refund still owed - the window F38
## made wider than it looked - and a way out afterwards must still pay it.
func test_a_stalled_teardown_keeps_its_refund_promise_across_a_save() -> void:
	var steel_before: int = fx.world_total(&"steel")
	var cell := Vector2i(26, 8)
	var target: ModuleBase = fx.place(&"large_storage", cell)
	var refund: int = int(target.module_data.resource_costs[fx.resource(&"steel")])
	var airlock_cells: Array[Vector2i] = _remove_airlocks()
	assert_gt(airlock_cells.size(), 0, "the starter station had an airlock to take away")
	for pawn: PawnBase in fx.pawns():
		assert_false(Global.path_manager.is_space_reachable(pawn), "%s cannot get outside" % pawn.pawn_name)
	var construction: ConstructionComponent = _construction(target)
	construction.start_deconstruction()
	var work_left: float = construction.work_seconds_done
	assert_true(await fx.tick(10.0))
	assert_almost_eq(construction.work_seconds_done, work_left, 0.001, "nobody has touched it")
	assert_true(await fx.save_and_reload())
	var restored: ConstructionComponent = _construction_at(cell)
	assert_not_null(restored, "the stalled site survives the load")
	if restored == null:
		return
	assert_eq(restored.current_state, ConstructionComponent.ConstructionState.Deconstructing)
	assert_almost_eq(restored.work_seconds_done, work_left, 0.001, "none of the teardown is skipped")
	assert_true(await fx.tick(10.0))
	assert_not_null(_construction_at(cell), "and it is still standing ten seconds on")
	assert_eq(fx.live_jobs(&"deconstruct_module", restored).size(), 1,
		"with exactly one teardown job waiting for a way out")
	for airlock_cell: Vector2i in airlock_cells:
		fx.place(Global.world_manager.module_airlock.id, airlock_cell, true, true)
	var done: bool = await fx.tick_until(func() -> bool:
		var site: ConstructionComponent = _construction_at(cell)
		return site == null or site.current_state == ConstructionComponent.ConstructionState.Deconstructed, 180.0)
	assert_true(done, "with an airlock back, a crew member finishes it")
	assert_eq(fx.world_total(&"steel"), steel_before + refund, "and the refund lands")

# --- F25: an interrupted builder ----------------------------------------------

## F25: an interrupted job ends INTERRUPTED - resignation, firing, or a Tier-2
## suit-up on the way - and the site's handler used to re-post only on FAILED.
## Now the site goes back to NotStarted, a builder is posted again, and it gets
## built.
func test_f25_an_interrupted_builder_no_longer_strands_the_site() -> void:
	var site: ModuleBase = fx.place(&"small_storage", Vector2i(14, 8), false)
	var builder: PawnBase = await _pawn_on(&"construct_module", func() -> Object: return _construction(site))
	assert_not_null(builder, "a crew member starts building")
	if builder == null:
		return
	var construction: ConstructionComponent = _construction(site)
	builder.interrupt_with_job(Job.of(&"idle"))
	assert_ne(construction.current_state, ConstructionComponent.ConstructionState.Constructing,
		"the interruption puts the site straight back to NotStarted")
	var reposted: bool = await fx.tick_until(func() -> bool:
		return fx.live_jobs(&"construct_module", construction).size() == 1, 5.0)
	assert_true(reposted, "and a builder is posted again")
	var built: bool = await fx.tick_until(func() -> bool:
		return is_instance_valid(site) and site.is_complete(), 180.0)
	assert_true(built, "and the site is finished")

# --- F26: duplicates after a load ----------------------------------------------

## F26: the site restores as NotStarted with its materials; the restored construct
## job is handed back to it, which puts it back to Constructing.
func test_f26_a_site_mid_build_keeps_one_builder_after_a_load() -> void:
	var site: ModuleBase = fx.place(&"small_storage", Vector2i(14, 8), false)
	var builder: PawnBase = await _pawn_on(&"construct_module", func() -> Object: return _construction(site))
	assert_not_null(builder, "a crew member is building")
	if builder == null:
		return
	var cell: Vector2i = site.module_cell
	assert_eq(await _most_jobs_after_reload(&"construct_module", func() -> Object:
			return _construction_at(cell)),
		1, "F26: one construct job for one site")
	var restored: ConstructionComponent = _construction_at(cell)
	if restored != null:
		assert_true(restored.current_state == ConstructionComponent.ConstructionState.Constructing
			or restored.current_state == ConstructionComponent.ConstructionState.Built,
			"the adopted job put the site back to Constructing")

## F26: the operator's restored job fills the processor's slot, so nobody else
## walks to the machine to fail on its one operator slot.
func test_f26_a_manned_processor_keeps_one_operator_job_after_a_load() -> void:
	# Three cells tall from row 7, so its door is on the corridor at row 9.
	var cell := Vector2i(13, 7)
	fx.place(&"silicon_furnace_mdata", cell)
	fx.place(&"debug_power", Vector2i(12, 9))
	fx.corridor(9, 12, 15)
	var processor: ProcessorComponent = _processor_at(cell)
	# The processor's own intake, not the module's first StorageComponent - that is
	# the construction bin. Every ingredient, or no batch starts and nobody works.
	var intake: StorageComponent = processor.storage
	for ingredient: ResourceData in processor.recipe.inputs:
		assert_gt(intake.room_for(ingredient), 0, "room for %s" % ingredient.id)
		intake.deposit(ingredient, intake.room_for(ingredient))
	var operator: PawnBase = await _pawn_on(&"work_processor", func() -> Object: return processor)
	assert_not_null(operator, "a crew member is working the processor")
	if operator == null:
		return
	assert_eq(await _most_jobs_after_reload(&"work_processor", func() -> Object: return _processor_at(cell)),
		1, "F26: one operator job for one machine")

## F26: `ModuleBase.adopt_repair_job()` existed for exactly this and had no
## caller. It is the module's adopt_restored_job now.
func test_f26_a_repair_in_flight_keeps_one_repair_job_after_a_load() -> void:
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
		1, "F26: one repair job for one module")

## F26: `_load_piles` re-added the pile's stock, which posted a fresh
## `collect_pile` before the pawn section could hand the restored one back. The
## pile now restores without posting and posts once the load is done.
func test_f26_a_pile_being_collected_keeps_one_collector_after_a_load() -> void:
	# Somewhere to take it. The Command Center takes a unit or two at a time, and a
	# storeroom holds nothing until its contents are chosen - so choose them.
	var ore: ResourceData = fx.resource(&"iron_ore")
	var store: ModuleBase = fx.place(&"large_storage", Vector2i(12, 8))
	fx.corridor(9, 12, 15)
	_stock_bin(store).add_stored_resource(ore)
	var canvas: CanvasLayer = Global.world_manager.get_canvas_for_layer(WorldManager.StructureLayer.MODULE)
	var pile := ResourcePile.spawn(canvas, Global.cell_to_world(Vector2i(16, 9), true))
	pile.add_amount(ore, 30)
	var pile_id: int = pile.pile_id
	var collector: PawnBase = await _pawn_on(&"collect_pile", func() -> Object: return pile)
	assert_not_null(collector, "a crew member is collecting the pile")
	if collector == null:
		return
	assert_eq(await _most_jobs_after_reload(&"collect_pile", func() -> Object: return _pile_by_id(pile_id)),
		1, "F26: one collect job for one pile")

# --- F40: a restored job resumes where it was saved ----------------------------

## F40, found by this item's scratch-copy run on the real quicksave. Two faults
## on one path: nothing called Job.resume_job(), so every restored job replayed
## from its first step, and the board's pickup gate - "is there room to carry?" -
## refused a pawn restored carrying a full load of the job's own cargo, so the job
## was cancelled and the cargo went to the sweep. Now the carry comes back on the
## step it was saved on and delivers to the sink the job had chosen.
func test_f40_a_full_load_restored_mid_carry_resumes_on_its_saved_step() -> void:
	var store: ModuleBase = fx.place(&"large_storage", Vector2i(12, 8))
	fx.corridor(9, 12, 15)
	var ore: ResourceData = fx.resource(&"iron_ore")
	# A trip is sized to its sink's room as well as to the pawn's hands, and left
	# alone the Command Center is the only sink, with room for one or two. A
	# storeroom stocking iron ore and out-ranking every other bin makes the trips
	# full loads. (A storeroom holds nothing until its contents are chosen.)
	var top: int = 0
	for storage: StorageComponent in fx.storages():
		top = maxi(top, storage.priority)
	var bin: StorageComponent = _stock_bin(store)
	bin.add_stored_resource(ore)
	bin.update_priority(top + 1)
	assert_gt(bin.room_for(ore, true), 10, "the storeroom takes iron ore now")
	var canvas: CanvasLayer = Global.world_manager.get_canvas_for_layer(WorldManager.StructureLayer.MODULE)
	ResourcePile.spawn(canvas, Global.cell_to_world(Vector2i(16, 9), true)).add_amount(ore, 30)
	var found: Array[PawnBase] = [null]
	var loaded: bool = await fx.tick_until(func() -> bool:
		for pawn: PawnBase in fx.pawns():
			var carrying: Job = pawn.current_job
			if carrying != null and carrying.is_type(&"collect_pile") and not carrying.is_ended() \
					and carrying.action_index() >= JobDriver_CollectPile.GOTO_SINK \
					and pawn.inventory_component.space_available() == 0:
				found[0] = pawn
				return true
		return false, 120.0, 0.05)
	assert_true(loaded, "a crew member is carrying a full load from the pile - the case the pickup gate refused")
	if not loaded:
		return
	var carrier: PawnBase = found[0]
	var saved_index: int = carrier.current_job.action_index()
	var carried: int = carrier.inventory_component.get_carried_amount(ore)
	var carrier_id: int = carrier.pawn_id
	var sink_cell: Vector2i = carrier.current_job.target_b.module().module_cell
	var stored_before: int = _stored(_module_at(sink_cell), ore)
	assert_true(await fx.save_and_reload())
	var restored_pawn: PawnBase = null
	for pawn: PawnBase in fx.pawns():
		if pawn.pawn_id == carrier_id:
			restored_pawn = pawn
	assert_not_null(restored_pawn)
	if restored_pawn == null or restored_pawn.job_queue.is_empty():
		return
	var job: Job = restored_pawn.job_queue[0]
	assert_true(job.is_type(&"collect_pile") and job.awaits_resume(), "the carry came back, awaiting resume")
	var restored_store: ModuleBase = _module_at(sink_cell)
	assert_eq(job.target_b.module() if job.target_b != null else null, restored_store,
		"bound for the storeroom it had chosen")
	var entered: Array[int] = [-1]
	# One shot: the first action it enters is the whole question, and a lasting
	# connection would hold the job alive through the lambda.
	job.subtask_changed.connect(func() -> void: entered[0] = job.action_index(), CONNECT_ONE_SHOT)
	var finished: bool = await fx.tick_until(func() -> bool: return job.is_ended(), 60.0)
	assert_true(finished, "and ended")
	assert_eq(entered[0], saved_index, "re-entered on the step it was saved on, not replayed from the top")
	assert_true(job.is_finished(), "and delivered, rather than being refused at the pawn")
	# Other crew may be fetching the rest of the pile into the same room.
	assert_true(_stored(restored_store, ore) >= stored_before + carried,
		"the %d it carried are in the storeroom" % carried)

## F40's second face, found on the second pass of the same scratch-copy run. A
## collection on its walk TO the pile is valid only while it holds its pile claim,
## and claims are never saved - so asking is_valid() before the resume read it as
## invalid and cancelled it. It resumes on the walk now, re-takes the claim, and
## collects.
func test_f40_a_collector_restored_on_its_way_to_the_pile_resumes() -> void:
	var ore: ResourceData = fx.resource(&"iron_ore")
	# Somewhere to take it: a storeroom holds nothing until its contents are chosen.
	var store: ModuleBase = fx.place(&"large_storage", Vector2i(12, 8))
	fx.corridor(9, 12, 15)
	_stock_bin(store).add_stored_resource(ore)
	var canvas: CanvasLayer = Global.world_manager.get_canvas_for_layer(WorldManager.StructureLayer.MODULE)
	var pile := ResourcePile.spawn(canvas, Global.cell_to_world(Vector2i(16, 9), true))
	pile.add_amount(ore, 30)
	var pile_id: int = pile.pile_id
	var found: Array[PawnBase] = [null]
	var walking: bool = await fx.tick_until(func() -> bool:
		for pawn: PawnBase in fx.pawns():
			var job: Job = pawn.current_job
			if job != null and job.is_type(&"collect_pile") and not job.is_ended() \
					and job.action_index() == JobDriver_CollectPile.GOTO_PILE:
				found[0] = pawn
				return true
		return false, 120.0, 0.05)
	assert_true(walking, "a crew member is on the way to the pile, holding its pile claim")
	if not walking:
		return
	var walker_id: int = found[0].pawn_id
	assert_true(await fx.save_and_reload())
	var job: Job = null
	for pawn: PawnBase in fx.pawns():
		if pawn.pawn_id == walker_id and not pawn.job_queue.is_empty():
			job = pawn.job_queue[0]
	assert_true(job != null and job.is_type(&"collect_pile") and job.awaits_resume(),
		"the walk came back, awaiting resume")
	if job == null:
		return
	var entered: Array[int] = [-1]
	job.subtask_changed.connect(func() -> void: entered[0] = job.action_index(), CONNECT_ONE_SHOT)
	var finished: bool = await fx.tick_until(func() -> bool: return job.is_ended(), 60.0)
	assert_true(finished, "and ended")
	assert_eq(entered[0], JobDriver_CollectPile.GOTO_PILE, "re-entered on the walk to the pile")
	assert_true(job.is_finished(), "and collected, rather than being cancelled as invalid")
	var restored_pile: ResourcePile = _pile_by_id(pile_id)
	assert_true(restored_pile == null or restored_pile.get_total(ore) < 30, "the pile is smaller for it")

## Every owner at once, on a working station: hauls in both directions, an
## operator, crew needs. After a load, no owner holds two live jobs - the general
## form of the four tests above, asked of whatever happened to be in flight.
func test_no_owner_has_a_second_job_after_a_load() -> void:
	fx.build_production_line()
	var canvas: CanvasLayer = Global.world_manager.get_canvas_for_layer(WorldManager.StructureLayer.MODULE)
	# Both of the furnace's ingredients, so its operator has a batch to run.
	var pile := ResourcePile.spawn(canvas, Global.cell_to_world(Vector2i(14, 9), true))
	pile.add_amount(fx.resource(&"silicon_ore"), 20)
	pile.add_amount(fx.resource(&"carbon"), 10)
	assert_true(await fx.tick(40.0), "the line runs for a while")
	assert_eq(_owners_holding_two(), PackedStringArray(), "the control: no duplicates before the save")
	var restored_before: int = _restored_owned_jobs()
	assert_true(await fx.save_and_reload())
	assert_eq(_restored_owned_jobs(), restored_before,
		"every owned job in flight at the save came back")
	var seen: PackedStringArray = []
	await fx.tick_until(func() -> bool:
		for problem: String in _owners_holding_two():
			if not seen.has(problem):
				seen.append(problem)
		return false, DUPLICATE_WINDOW, 0.05)
	assert_eq(seen, PackedStringArray(), "no owner posted a second job beside its restored one")

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

## Every live job whose owner remembers it, keyed by that owner - the thing a
## JobSlot holds one of. One sentence per key held twice.
func _owners_holding_two() -> PackedStringArray:
	var by_owner: Dictionary[String, int] = {}
	for entry: Array in _owned_jobs():
		var key: String = entry[1]
		by_owner[key] = by_owner.get(key, 0) + 1
	var out: PackedStringArray = []
	for key: String in by_owner:
		if by_owner[key] > 1:
			out.append("%s holds %d live jobs" % [key, by_owner[key]])
	return out

## How many owned jobs are held by pawns - the ones a save restores.
func _restored_owned_jobs() -> int:
	var count: int = 0
	for entry: Array in _owned_jobs():
		if (entry[0] as Job).pawn != null or _queued(entry[0] as Job):
			count += 1
	return count

## [job, owner key] for every live job anywhere that declares an owner.
func _owned_jobs() -> Array[Array]:
	var out: Array[Array] = []
	var seen: Dictionary[int, bool] = {}
	var holders: Dictionary[int, PawnBase] = {}
	var candidates: Array[Job] = Global.job_manager.get_board_snapshot()
	for pawn: PawnBase in fx.pawns():
		for job: Job in [pawn.current_job] + pawn.job_queue:
			if job != null:
				candidates.append(job)
				holders[job.get_instance_id()] = pawn
	for job: Job in candidates:
		if job.is_ended() or job.origin == JobData.Origin.NONE or seen.has(job.get_instance_id()):
			continue
		seen[job.get_instance_id()] = true
		var owner: Object = null
		match job.origin:
			JobData.Origin.PAWN:
				owner = holders.get(job.get_instance_id())
			JobData.Origin.TARGET_A:
				owner = job.target_a.object() if job.target_a != null else null
			JobData.Origin.TARGET_B:
				owner = job.target_b.object() if job.target_b != null else null
		var owner_name: String = str(owner.get_instance_id()) if owner != null else "nobody"
		if owner is PawnBase:
			owner_name = (owner as PawnBase).pawn_name
		elif owner is ComponentBase:
			owner_name = StationFixture.describe_storage(owner as StorageComponent) \
				if owner is StorageComponent else String((owner as ComponentBase).owner_module.name)
		# A haul is its bin's per resource and per direction; a recreation need is
		# one slot for two job types.
		var about: String = String(job.resource.id) if job.resource != null else ""
		var kind: String = "recreation" if job.is_type(&"shop") or job.is_type(&"recreate") else String(job.data.id)
		out.append([job, "%s %s(%s) %s" % [owner_name, kind, about, JobData.Origin.keys()[job.origin]]])
	return out

## A module's own stock bin - not its first StorageComponent, which is the
## construction bin.
static func _stock_bin(module: ModuleBase) -> StorageComponent:
	for component: ComponentBase in module.components:
		var storage: StorageComponent = component as StorageComponent
		if storage != null and not storage.construction_storage:
			return storage
	return null

static func _module_at(cell: Vector2i) -> ModuleBase:
	return Global.world_manager.get_module_by_cell(WorldManager.StructureLayer.MODULE, cell)

## How much of `resource` a module's storages hold between them.
static func _stored(module: ModuleBase, resource: ResourceData) -> int:
	var total: int = 0
	if module == null:
		return total
	for component: ComponentBase in module.components:
		var storage: StorageComponent = component as StorageComponent
		if storage != null and storage.storage_data.has(resource):
			total += storage.storage_data[resource].stored
	return total

func _queued(job: Job) -> bool:
	for pawn: PawnBase in fx.pawns():
		if pawn.job_queue.has(job):
			return true
	return false

## Takes every airlock off the station and returns the cells they stood on.
func _remove_airlocks() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for module: ModuleBase in fx.modules():
		if module.is_in_group(Groups.AIRLOCK):
			cells.append(module.module_cell)
			Global.world_manager.remove_module(module, false)
	return cells

static func _construction(module: ModuleBase) -> ConstructionComponent:
	if module == null or not is_instance_valid(module):
		return null
	return module.get_component_by_type(ConstructionComponent) as ConstructionComponent

static func _construction_at(cell: Vector2i) -> ConstructionComponent:
	return _construction(Global.world_manager.get_module_by_cell(WorldManager.StructureLayer.MODULE, cell))

func _processor_at(cell: Vector2i) -> ProcessorComponent:
	var module: ModuleBase = Global.world_manager.get_module_by_cell(WorldManager.StructureLayer.MODULE, cell)
	return module.get_component_by_type(ProcessorComponent) as ProcessorComponent if module != null else null

func _pile_by_id(pile_id: int) -> ResourcePile:
	for pile: ResourcePile in fx.piles():
		if pile.pile_id == pile_id:
			return pile
	return null
