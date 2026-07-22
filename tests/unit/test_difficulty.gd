extends GutTest

## Unit tests for WI-37's difficulty layer. Everything here is pure: the shipped
## DifficultyData .tres set (loaded through the class's own static registry), the
## cost-scaling helper on EconomyManager, and SaveManager's static difficulty
## read-back off a parsed envelope. Nothing touches Global, SignalBus, or a live
## manager - the three consumption points are wired in code the suite can't reach
## headlessly, so what's tested is the maths and the data they consume.

const EXPECTED_IDS: Array[StringName] = [&"peaceful", &"easy", &"normal", &"hard"]

# --- the shipped data set -----------------------------------------------------

func test_all_four_levels_are_authored() -> void:
	var found: Array[StringName] = []
	for difficulty: DifficultyData in DifficultyData.all():
		found.append(difficulty.id)
	for id: StringName in EXPECTED_IDS:
		assert_true(found.has(id), "a %s.tres exists in data/difficulty/" % id)

func test_levels_are_ordered_easiest_first() -> void:
	var ordered: Array[StringName] = []
	for difficulty: DifficultyData in DifficultyData.all():
		ordered.append(difficulty.id)
	assert_eq(ordered, EXPECTED_IDS, "sort_order runs peaceful -> hard")

func test_normal_changes_nothing() -> void:
	var normal: DifficultyData = DifficultyData.by_id(&"normal")
	assert_not_null(normal, "normal.tres loads")
	assert_almost_eq(normal.upkeep_multiplier, 1.0, 0.001, "Normal is the baseline cost rate")
	assert_true(normal.raids_enabled, "Normal keeps raids")
	assert_almost_eq(normal.mood_offset, 0.0, 0.001, "Normal applies no mood offset")

func test_only_peaceful_disables_raids() -> void:
	for difficulty: DifficultyData in DifficultyData.all():
		if difficulty.id == &"peaceful":
			assert_false(difficulty.raids_enabled, "Peaceful is the no-raids level")
		else:
			assert_true(difficulty.raids_enabled, "%s keeps raids" % difficulty.id)

func test_costs_rise_monotonically_with_difficulty() -> void:
	var previous: float = -1.0
	for difficulty: DifficultyData in DifficultyData.all():
		assert_gt(difficulty.upkeep_multiplier, previous,
			"%s costs more to run than the level before it" % difficulty.id)
		previous = difficulty.upkeep_multiplier

func test_mood_offsets_fall_monotonically_with_difficulty() -> void:
	var previous: float = INF
	for difficulty: DifficultyData in DifficultyData.all():
		assert_lt(difficulty.mood_offset, previous,
			"%s crew are unhappier than the level before it" % difficulty.id)
		previous = difficulty.mood_offset

## The WI-37 balance floor: no level's flat offset may on its own carry a fresh
## crew member (who starts near full happiness) under the resignation threshold,
## or a Hard station would haemorrhage crew on cycle 1 through no fault of play.
func test_no_mood_offset_can_trigger_resignation_alone() -> void:
	var needs := PawnNeedsComponent.new()
	var threshold: float = needs.resignation_threshold
	needs.free()
	for difficulty: DifficultyData in DifficultyData.all():
		assert_gt(1.0 + difficulty.mood_offset, threshold,
			"%s leaves a fully-satisfied pawn above the resignation threshold" % difficulty.id)

# --- effect_summary -----------------------------------------------------------

func test_summary_reports_every_active_dial() -> void:
	var difficulty := DifficultyData.new()
	difficulty.upkeep_multiplier = 1.35
	difficulty.raids_enabled = false
	difficulty.mood_offset = -0.05
	var summary: String = difficulty.effect_summary()
	assert_string_contains(summary, "+35%", "the cost multiplier reads as a percentage delta")
	assert_string_contains(summary, "no pirate raids", "the raid gate is called out")
	assert_string_contains(summary, "-5%", "the mood offset reads as a percentage delta")

func test_summary_of_a_neutral_level_says_so() -> void:
	var difficulty := DifficultyData.new()
	assert_string_contains(difficulty.effect_summary(), "no adjustments",
		"a level with every dial neutral doesn't render an empty effect list")

# --- resolve ------------------------------------------------------------------

func test_resolve_returns_the_named_level() -> void:
	var resolved: DifficultyData = DifficultyData.resolve(&"hard")
	assert_not_null(resolved)
	assert_eq(resolved.id, &"hard")

func test_resolve_falls_back_to_normal() -> void:
	# A renamed .tres, a hand-edited save, or a pre-WI-37 save with no id at all.
	assert_eq(DifficultyData.resolve(&"nonexistent").id, DifficultyData.DEFAULT_ID)
	assert_eq(DifficultyData.resolve(&"").id, DifficultyData.DEFAULT_ID)

# --- cost scaling (EconomyManager.scaled_cost) --------------------------------

func test_scaling_by_one_is_the_identity() -> void:
	assert_eq(EconomyManager.scaled_cost(250, 1.0), 250)

func test_scaling_applies_the_multiplier() -> void:
	assert_eq(EconomyManager.scaled_cost(200, 1.35), 270, "Hard's rate on a 200 cr bill")
	assert_eq(EconomyManager.scaled_cost(200, 0.6), 120, "Peaceful's rate on a 200 cr bill")

func test_scaling_rounds_to_nearest() -> void:
	assert_eq(EconomyManager.scaled_cost(7, 0.8), 6, "5.6 rounds to 6")
	assert_eq(EconomyManager.scaled_cost(3, 1.35), 4, "4.05 rounds to 4")

func test_a_cheap_multiplier_never_rounds_a_cost_away() -> void:
	# A 1-credit upkeep at 0.6x is 0.6, which would round to nothing. Discounted
	# is not free, so it floors at a credit.
	assert_eq(EconomyManager.scaled_cost(1, 0.6), 1)

func test_a_zero_multiplier_is_free() -> void:
	# Distinct from the floor above: 0 is a deliberate "this stream doesn't apply
	# at this difficulty", not a rounding artefact.
	assert_eq(EconomyManager.scaled_cost(500, 0.0), 0)

func test_scaling_leaves_nothing_to_charge_alone() -> void:
	assert_eq(EconomyManager.scaled_cost(0, 1.35), 0)
	assert_eq(EconomyManager.scaled_cost(-10, 1.35), 0, "negative amounts are never charges")

## Wage scaling and the pawn's wallet credit come from one call site, so the whole
## per-cycle bill scales exactly as advertised - the ledger check in WI-37's
## verification (Hard vs Easy on an identical station) rests on this.
func test_wage_scaling_composes_with_the_wage_fraction() -> void:
	var base: int = EconomyManager.wage_for(400, 0.1)
	assert_eq(base, 40, "10% of a 400 cr hire price")
	assert_eq(EconomyManager.scaled_cost(base, 1.35), 54, "Hard pays 54")
	assert_eq(EconomyManager.scaled_cost(base, 0.8), 32, "Easy pays 32")

# --- save round-trip (SaveManager.read_difficulty / summarize) ----------------

func _envelope(sections: Dictionary, meta: Dictionary = {}) -> Dictionary:
	var data: Dictionary = {
		"version": SaveManager.SAVE_VERSION,
		"timestamp": "2026-07-22T10:11:12",
		"sections": sections,
	}
	if not meta.is_empty():
		data["meta"] = meta
	return data

func test_difficulty_reads_from_the_sections_field() -> void:
	assert_eq(SaveManager.read_difficulty(_envelope({"difficulty": "hard"})), &"hard")

func test_sections_field_wins_over_meta() -> void:
	# meta is a display summary; the section is the authoritative field.
	var data: Dictionary = _envelope({"difficulty": "hard"}, {"difficulty": "peaceful"})
	assert_eq(SaveManager.read_difficulty(data), &"hard")

func test_difficulty_falls_back_to_meta() -> void:
	assert_eq(SaveManager.read_difficulty(_envelope({}, {"difficulty": "easy"})), &"easy")

func test_pre_wi37_saves_load_as_normal() -> void:
	# Neither key present anywhere - the migration default.
	assert_eq(SaveManager.read_difficulty(_envelope({"time": {"cycle": 3}})), DifficultyData.DEFAULT_ID)

func test_slot_summary_carries_the_difficulty() -> void:
	var info: Dictionary = SaveManager.summarize(_envelope({"difficulty": "peaceful"}), "alpha")
	assert_eq(String(info["difficulty"]), "peaceful")
	assert_string_contains(SaveManager.describe_slot(info), "Peaceful",
		"the slot subtitle names the difficulty it was played at")

func test_slot_summary_of_a_legacy_save_reads_normal() -> void:
	var info: Dictionary = SaveManager.summarize(_envelope({}), "legacy")
	assert_eq(String(info["difficulty"]), String(DifficultyData.DEFAULT_ID))

func test_difficulty_label_falls_back_to_the_raw_id() -> void:
	assert_eq(SaveManager.difficulty_label(&"hard"), "Hard")
	assert_eq(SaveManager.difficulty_label(&"brutal"), "Brutal",
		"an id with no surviving .tres still renders readably")
