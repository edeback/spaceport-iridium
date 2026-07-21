extends GutTest

## Unit tests for WI-31 health & disease: the pure DiseaseData/DiseaseStage
## definitions and registry - .tres parsing (including the typed
## Dictionary[StringName, int] stage maluses), stage helpers, station-tier unlock
## gating, and the outbreak selection pool. All read the shared static registry;
## none touch Global/SignalBus (the component behaviour is verified in-game).

# --- registry & .tres parsing -------------------------------------------------

func test_registry_loads_all_three_diseases() -> void:
	assert_not_null(DiseaseData.by_id(&"station_flu"), "station_flu loads")
	assert_not_null(DiseaseData.by_id(&"void_sickness"), "void_sickness loads")
	assert_not_null(DiseaseData.by_id(&"fervent_fever"), "fervent_fever loads")

func test_unknown_id_returns_null() -> void:
	assert_null(DiseaseData.by_id(&"not_a_disease"), "unknown disease id -> null")

func test_stages_parse_with_typed_malus_dict() -> void:
	var flu := DiseaseData.by_id(&"station_flu")
	assert_eq(flu.stage_count(), 2, "station flu has two stages")
	var stage0 := flu.get_stage(0)
	assert_not_null(stage0, "stage 0 parsed")
	# The Dictionary[StringName, int] survived .tres authoring.
	assert_eq(int(stage0.skill_maluses.get(&"social", 0)), 2, "stage 0 social malus = 2")
	assert_eq(int(stage0.skill_maluses.get(&"crafting", 0)), 2, "stage 0 crafting malus = 2")
	assert_almost_eq(stage0.health_drain_per_hour, 1.0, 0.001, "stage 0 drain")

func test_final_stage_drains_harder_than_first() -> void:
	var flu := DiseaseData.by_id(&"station_flu")
	assert_gt(flu.get_stage(1).health_drain_per_hour, flu.get_stage(0).health_drain_per_hour,
		"the later stage drains more health")

func test_fever_has_movement_speedup() -> void:
	var fever := DiseaseData.by_id(&"fervent_fever")
	assert_gt(fever.get_stage(0).move_speed_mult, 1.0, "Fervent Fever runs hot - faster movement")

# --- contagion & acquisition --------------------------------------------------

func test_flu_is_contagious_void_is_not() -> void:
	assert_true(DiseaseData.by_id(&"station_flu").is_contagious(), "station flu spreads")
	assert_false(DiseaseData.by_id(&"void_sickness").is_contagious(), "void sickness does not spread")

func test_void_sickness_is_space_acquired() -> void:
	assert_true(DiseaseData.by_id(&"void_sickness").has_acquisition(&"space"), "void sickness comes from the vacuum")
	assert_false(DiseaseData.by_id(&"void_sickness").has_acquisition(&"outbreak"), "void sickness is not an outbreak seed")

# --- stage index helpers ------------------------------------------------------

func test_is_final_stage() -> void:
	var flu := DiseaseData.by_id(&"station_flu")
	assert_false(flu.is_final_stage(0), "stage 0 is not final")
	assert_true(flu.is_final_stage(1), "stage 1 is the final stage")

func test_get_stage_clamps_out_of_range() -> void:
	var flu := DiseaseData.by_id(&"station_flu")
	assert_eq(flu.get_stage(99), flu.get_stage(1), "an over-range index clamps to the last stage")
	assert_eq(flu.get_stage(-5), flu.get_stage(0), "a negative index clamps to the first stage")

# --- station-tier unlock gating -----------------------------------------------

func test_no_disease_unlocked_at_tier_1() -> void:
	assert_eq(DiseaseData.unlocked_at_tier(1).size(), 0, "Tier-1 stations have no disease at all")

func test_tier_2_unlocks_flu_and_void_but_not_fever() -> void:
	var ids: Array[StringName] = []
	for d: DiseaseData in DiseaseData.unlocked_at_tier(2):
		ids.append(d.id)
	assert_true(ids.has(&"station_flu"), "station flu unlocks at tier 2")
	assert_true(ids.has(&"void_sickness"), "void sickness unlocks at tier 2")
	assert_false(ids.has(&"fervent_fever"), "fervent fever waits until tier 3")

func test_higher_tier_is_superset() -> void:
	assert_gte(DiseaseData.unlocked_at_tier(3).size(), DiseaseData.unlocked_at_tier(2).size(),
		"more diseases are possible at higher tiers")

# --- outbreak pool ------------------------------------------------------------

func test_outbreak_pool_empty_at_tier_1() -> void:
	assert_eq(DiseaseData.outbreak_pool(1).size(), 0, "no outbreak can fire with nothing unlocked")

func test_outbreak_pool_excludes_non_contagious() -> void:
	for d: DiseaseData in DiseaseData.outbreak_pool(5):
		assert_true(d.is_contagious(), "the outbreak pool only holds infectious diseases")
		assert_true(d.has_acquisition(&"outbreak"), "the outbreak pool only holds outbreak-tagged diseases")
	var ids: Array[StringName] = []
	for d: DiseaseData in DiseaseData.outbreak_pool(5):
		ids.append(d.id)
	assert_false(ids.has(&"void_sickness"), "Void Sickness is never chosen for an outbreak")
	assert_true(ids.has(&"station_flu"), "Station Flu is a valid outbreak seed")
