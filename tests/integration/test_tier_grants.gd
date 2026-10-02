extends GutTest

## A station tier can license modules outright (2026-10-02): reaching Tier 2
## grants the Silicon Furnace with no research and no cost. The grant is derived
## from the tier rather than saved, so the load path has to rebuild it - which
## only a running station can show.
##
## Also the furnace itself, end to end: placed, fed and manned, it makes silicon.

const FURNACE: StringName = &"silicon_furnace_mdata"

var fx: StationFixture

func before_each() -> void:
	fx = StationFixture.new(self)
	await fx.boot()

func after_each() -> void:
	await fx.finish()

func _furnace() -> ModuleData:
	var data: ModuleData = Global.save_manager.get_module_data_by_id(FURNACE)
	assert_not_null(data, "the furnace is shipped")
	return data

func _promote() -> void:
	Global.unlock_manager.advance_tier()
	assert_eq(Global.unlock_manager.current_tier, 2, "promoted to Tier 2")

## The promotion transmission's body, or "" if none was sent.
func _promotion_body() -> String:
	var transmissions: TransmissionLog = Global.alert_manager.transmissions
	for entry: TransmissionData in transmissions.of_family(&"arc"):
		if entry.subject.begins_with("Station promoted"):
			return entry.body
	return ""

func test_a_new_station_cannot_build_the_furnace() -> void:
	var furnace: ModuleData = _furnace()
	if furnace == null:
		return
	assert_eq(Global.unlock_manager.current_tier, 1, "a new station is Tier 1")
	assert_false(furnace.is_unlocked(), "the furnace waits for Tier 2")

func test_promotion_licenses_the_furnace_and_says_so() -> void:
	var furnace: ModuleData = _furnace()
	if furnace == null:
		return
	_promote()
	assert_true(furnace.is_unlocked(), "Tier 2 grants it, with no research bought")
	assert_string_contains(_promotion_body(), "Silicon Furnace",
		"and the promotion transmission names it, since nothing else announces it")

func test_a_promoted_station_reloads_with_the_furnace_still_licensed() -> void:
	var furnace: ModuleData = _furnace()
	if furnace == null:
		return
	_promote()
	assert_true(await fx.save_and_reload())
	assert_eq(Global.unlock_manager.current_tier, 2, "the tier survives the load")
	assert_true(furnace.is_unlocked(), "and the grant is rebuilt from it")

func test_a_tier_one_station_reloads_with_the_furnace_still_locked() -> void:
	var furnace: ModuleData = _furnace()
	if furnace == null:
		return
	assert_true(await fx.save_and_reload())
	assert_false(furnace.is_unlocked(), "a load grants nothing the tier has not reached")

func test_a_manned_furnace_turns_silicates_and_carbon_into_silicon() -> void:
	# Three cells tall from row 7, so its door is on the corridor at row 9.
	var module: ModuleBase = fx.place(FURNACE, Vector2i(13, 7))
	fx.place(&"debug_power", Vector2i(12, 9))
	fx.corridor(9, 12, 15)
	if module == null:
		return
	var processor: ProcessorComponent = module.get_component_by_type(ProcessorComponent) as ProcessorComponent
	assert_not_null(processor, "the furnace is a processor")
	if processor == null:
		return
	assert_false(processor.misconfigured, "and is wired: %s" % processor.last_error)
	assert_false(processor.can_select_recipes(), "with one recipe, so no selector")
	assert_eq(processor.recipe.name, "Refine Silicon")
	var silicon_before: int = fx.world_total(&"silicon")
	var intake: StorageComponent = processor.storage
	for ingredient: ResourceData in processor.recipe.inputs:
		intake.deposit(ingredient, intake.room_for(ingredient))
	assert_true(await fx.tick_until(func() -> bool: return fx.world_total(&"silicon") > silicon_before,
		300.0), "a crew member runs it and silicon comes out")
	assert_eq(fx.invariants(), PackedStringArray())
