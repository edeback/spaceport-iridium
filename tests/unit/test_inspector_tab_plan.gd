extends GutTest

## Unit tests for WI-51's InspectorTabPlan: which tabs the inspector shows, in
## what order, under what names.
##
## "Which tabs" is a rule, and the program doc's risk list says a rule inside a
## panel is a rule nobody can test - so it lives in a pure static class and this
## is that class's suite. Nothing here mounts a panel or touches Global.

# --- module tab ordering -------------------------------------------------------

func _ids(tabs: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for tab: Dictionary in tabs:
		out.append(String(tab["text"]))
	return out

func test_bands_order_production_power_storage_then_upgrades() -> void:
	# Deliberately handed in the wrong order: scene order is whatever the module
	# author happened to do, and the plan is what fixes it.
	var tabs: Array[Dictionary] = InspectorTabPlan.module_tabs([
		InspectorTabPlan.SYNTHETIC_UPGRADES,
		"StorageComponent",
		"PowerConsumptionComponent",
		"ProcessorComponent",
	])
	assert_eq(_ids(tabs), ["Output", "Power", "Stores", "Upgrades"])

func test_upgrades_always_sorts_last() -> void:
	var tabs: Array[Dictionary] = InspectorTabPlan.module_tabs([
		InspectorTabPlan.SYNTHETIC_UPGRADES, "AtmosphereComponent",
	])
	assert_eq(_ids(tabs).back(), "Upgrades")

func test_unknown_component_sorts_after_the_known_bands_but_before_upgrades() -> void:
	var tabs: Array[Dictionary] = InspectorTabPlan.module_tabs([
		InspectorTabPlan.SYNTHETIC_UPGRADES, "SomeModdedComponent", "ProcessorComponent",
	])
	assert_eq(_ids(tabs), ["Output", "Some Modded", "Upgrades"])

func test_order_within_a_band_follows_the_component_walk() -> void:
	# Two production components: the module author's order is the tiebreak, so
	# rebuilding the strip cannot reshuffle them.
	var tabs: Array[Dictionary] = InspectorTabPlan.module_tabs([
		"MiningComponent", "ProcessorComponent",
	])
	assert_eq(_ids(tabs), ["Mining", "Output"])

func test_source_index_maps_a_tab_back_to_its_component() -> void:
	var tabs: Array[Dictionary] = InspectorTabPlan.module_tabs([
		"StorageComponent", "ProcessorComponent",
	])
	assert_eq(String(tabs[0]["text"]), "Output", "the processor sorted first")
	assert_eq(int(tabs[0]["source"]), 1, "...but it is still index 1 in the walk")
	assert_eq(int(tabs[1]["source"]), 0)

# --- labels --------------------------------------------------------------------

func test_known_components_get_their_short_label() -> void:
	assert_eq(_ids(InspectorTabPlan.module_tabs(["ProcessorComponent"])), ["Output"])
	assert_eq(_ids(InspectorTabPlan.module_tabs(["StorageComponent"])), ["Stores"])
	assert_eq(_ids(InspectorTabPlan.module_tabs(["ConstructionComponent"])), ["Build"])

func test_unknown_component_drops_its_component_suffix() -> void:
	assert_eq(InspectorTabPlan.fallback_label("HydroponicsComponent"), "Hydroponics")

func test_fallback_keeps_a_name_that_is_only_the_word_component() -> void:
	# Stripping here would leave an empty tab the player cannot aim at.
	assert_eq(InspectorTabPlan.fallback_label("Component"), "Component")

func test_empty_key_still_produces_an_aimable_tab() -> void:
	assert_eq(InspectorTabPlan.fallback_label(""), "Info")

func test_ids_are_derived_from_the_label() -> void:
	var tabs: Array[Dictionary] = InspectorTabPlan.module_tabs([InspectorTabPlan.SYNTHETIC_ENVIRONMENT])
	assert_eq(StringName(tabs[0]["id"]), &"environment")

# --- duplicates ----------------------------------------------------------------

func test_two_storages_both_appear_and_are_numbered() -> void:
	# A deconstruction site grows a second storage for its recovered materials.
	# Deduplicating would lose a bin the player can edit.
	var tabs: Array[Dictionary] = InspectorTabPlan.module_tabs([
		"StorageComponent", "StorageComponent",
	])
	assert_eq(_ids(tabs), ["Stores", "Stores 2"])

func test_duplicate_tabs_get_distinct_ids() -> void:
	var tabs: Array[Dictionary] = InspectorTabPlan.module_tabs([
		"StorageComponent", "StorageComponent",
	])
	assert_ne(StringName(tabs[0]["id"]), StringName(tabs[1]["id"]),
		"the strip selects by id, so two tabs sharing one would be unreachable")

func test_two_power_components_share_a_label_and_are_numbered() -> void:
	var tabs: Array[Dictionary] = InspectorTabPlan.module_tabs([
		"PowerGenerationComponent", "PowerConsumptionComponent",
	])
	assert_eq(_ids(tabs), ["Power", "Power 2"])

# --- empty ---------------------------------------------------------------------

func test_a_module_with_no_component_uis_gets_an_empty_strip() -> void:
	# Truss and a plain corridor. Must not error; the subject block carries
	# everything there is to say.
	var empty: Array[String] = []
	assert_eq(InspectorTabPlan.module_tabs(empty).size(), 0)

func test_strip_defs_carry_only_id_and_text() -> void:
	var defs: Array = InspectorTabPlan.to_strip_defs(
		InspectorTabPlan.module_tabs(["ProcessorComponent"]))
	assert_eq(defs.size(), 1)
	var def: Dictionary = defs[0]
	assert_true(def.has("id") and def.has("text"))
	assert_false(def.has("band"), "the strip has no business knowing how it was sorted")

# --- crew tabs -----------------------------------------------------------------

func _crew_ids(flags: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for tab: Dictionary in InspectorTabPlan.crew_tabs(flags):
		out.append(String(tab["text"]))
	return out

func test_full_crew_member_gets_all_six_tabs() -> void:
	assert_eq(_crew_ids({
		"needs": true, "skills": true, "inventory": true, "schedule": true, "social": true,
	}), ["Needs", "Job", "Skills", "Kit", "Schedule", "Social"])

func test_robot_gets_vitals_instead_of_needs_and_nothing_else() -> void:
	# A drone carries no needs, schedule, skills or socialize component, so the
	# component-derived set is exactly Vitals + Job.
	assert_eq(_crew_ids({"vitals": true, "inventory": true}), ["Vitals", "Job", "Kit"])

func test_needs_wins_over_vitals_when_a_pawn_somehow_has_both() -> void:
	# The two report the same thing under two names; showing both would be a
	## duplicate rather than extra information.
	assert_eq(_crew_ids({"needs": true, "vitals": true}), ["Needs", "Job"])

func test_visitor_has_needs_but_no_schedule_skills_or_social() -> void:
	assert_eq(_crew_ids({"needs": true, "inventory": true}), ["Needs", "Job", "Kit"])

func test_job_tab_is_always_present() -> void:
	# Every pawn has a job - PawnBase hands an idle one to a pawn with nothing to
	# do - so a pawn with no Job tab would be a pawn you cannot ask what it is
	# doing.
	assert_eq(_crew_ids({}), ["Job"])

func test_crew_tab_ids_are_the_plan_constants() -> void:
	var tabs: Array[Dictionary] = InspectorTabPlan.crew_tabs({"needs": true, "social": true})
	assert_eq(StringName(tabs[0]["id"]), InspectorTabPlan.TAB_NEEDS)
	assert_eq(StringName(tabs[1]["id"]), InspectorTabPlan.TAB_JOB)
	assert_eq(StringName(tabs[2]["id"]), InspectorTabPlan.TAB_SOCIAL)

# --- geometry ------------------------------------------------------------------

func test_inspector_never_climbs_into_the_readouts_above_it() -> void:
	var maximum: int = UIMetrics.inspector_max_height()
	var top: int = UIMetrics.inspector_top(maximum)
	assert_eq(top, UIMetrics.INSPECTOR_TOP_LIMIT,
		"a full-height inspector's top edge lands exactly on the limit")

func test_inspector_content_budget_excludes_its_own_header() -> void:
	assert_eq(UIMetrics.inspector_max_content_height(),
		UIMetrics.inspector_max_height() - UIMetrics.READOUT_HEADER_HEIGHT)

func test_inspector_bottom_sits_one_gutter_above_the_console() -> void:
	assert_eq(UIMetrics.inspector_bottom_offset(),
		UIMetrics.CONSOLE_HEIGHT + UIMetrics.SCREEN_GUTTER)

func test_a_taller_screen_gives_the_inspector_more_room() -> void:
	assert_gt(UIMetrics.inspector_max_height(1440), UIMetrics.inspector_max_height(1080))
