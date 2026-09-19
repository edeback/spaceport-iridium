extends GutTest

## Two WI-68 fixes that only a live station can exercise (WI-69 §4), each first
## reproduced by a scratch-copy probe on the real quicksave:
##
## - **F22:** a hire whose docking bay is removed while the shuttle is inbound
##   was delivered into the truss backfilled onto the bay's cells, and the refund
##   never ran. Crew went 3 -> 4 with no bay; the fee was gone.
## - **F23:** a pile tagged with a module that was later removed made the next
##   save drop **every** pile on the station - silent resource loss, the most
##   serious finding of the first audit.

var fx: StationFixture

func before_each() -> void:
	fx = StationFixture.new(self)
	await fx.boot()

func after_each() -> void:
	await fx.finish()

func test_a_hire_whose_bay_is_removed_in_flight_is_refunded() -> void:
	# Bunks for the two founders and the recruit, and the credits to hire one, so
	# nothing but the bay can stand in the way.
	for x: int in [12, 13, 14]:
		fx.place(&"sleeping_pod_mdata", Vector2i(x, 9))
	var credits: ResourceData = Global.resource_manager.credit_resource
	credits.change_global_total(10000)
	var crew: CrewManager = Global.crew_manager
	var candidate: HireCandidate = crew.get_candidates()[0]
	var bay: ModuleBase = _docking_bay()
	assert_not_null(bay)
	var balance_before: int = credits.get_total(true)
	var crew_before: int = crew.crew_count()
	assert_eq(crew.hire_block_reason(candidate), "", "the hire is allowed")
	assert_true(crew.request_hire(bay, candidate), "hired")
	assert_eq(credits.get_total(true), balance_before - candidate.price, "the fee is charged")
	assert_true(Global.world_manager.remove_module(bay, false), "the bay is removed mid-flight")
	var settled: bool = await fx.tick_until(func() -> bool: return crew.pending_hire_count() == 0,
		(crew.arrival_delay_hours + 2.0) * TimeManager.SECONDS_PER_HOUR, 1.0)
	assert_true(settled, "the hire settles once its delay is up")
	assert_eq(crew.crew_count(), crew_before, "nobody is delivered into the truss")
	assert_eq(credits.get_total(true), balance_before, "and the fee is refunded")

func test_a_pile_tagged_with_a_removed_module_survives_the_next_save() -> void:
	var canvas: CanvasLayer = Global.world_manager.get_canvas_for_layer(WorldManager.StructureLayer.MODULE)
	var owner: ModuleBase = fx.place(&"small_storage", Vector2i(30, 4))
	var tagged := ResourcePile.spawn(canvas, Global.cell_to_world(Vector2i(30, 4), true), owner)
	tagged.add_amount(fx.resource(&"iron_ore"), 7)
	var untagged := ResourcePile.spawn(canvas, Global.cell_to_world(Vector2i(34, 4), true))
	untagged.add_amount(fx.resource(&"silicon_ore"), 5)
	var piles_before: int = fx.piles().size()
	assert_true(Global.world_manager.remove_module(owner, false))
	assert_null(tagged.parent_module, "the pile lets go of the module as it leaves the tree")
	assert_true(await fx.save_and_reload())
	assert_eq(fx.piles().size(), piles_before, "every pile survives the save")
	assert_eq(fx.world_total(&"iron_ore"), 7, "the tagged pile's contents")
	assert_eq(fx.world_total(&"silicon_ore"), 5, "and the untagged pile's")

func _docking_bay() -> ModuleBase:
	for module: ModuleBase in fx.modules():
		if module.module_data == Global.world_manager.docking_bay:
			return module
	return null
