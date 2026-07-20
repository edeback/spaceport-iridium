extends GutTest

## Unit tests for the WI-26 station-tier pure logic (WI-19 followup): the
## per-node tier gate (UnlockData.available_at_tier) and the promotion-goal check
## (TierData.goals_reached). Both are pure - constructed directly, no Global.

# --- tier gate (UnlockData.available_at_tier) ---------------------------------

func test_min_tier_defaults_to_one() -> void:
	var unlock := UnlockData.new()
	assert_eq(unlock.min_tier, 1, "unlisted nodes are available from tier 1")

func test_tier_gate_blocks_below_min_tier() -> void:
	var unlock := UnlockData.new()
	unlock.min_tier = 3
	assert_false(unlock.available_at_tier(1), "locked at tier 1")
	assert_false(unlock.available_at_tier(2), "still locked at tier 2")

func test_tier_gate_opens_at_and_above_min_tier() -> void:
	var unlock := UnlockData.new()
	unlock.min_tier = 3
	assert_true(unlock.available_at_tier(3), "opens exactly at its min tier")
	assert_true(unlock.available_at_tier(5), "stays open above its min tier")

# --- promotion goals (TierData.goals_reached) ---------------------------------

func _tier(goals: Dictionary, tags: Array) -> TierData:
	var data := TierData.new()
	var typed_goals: Dictionary[StringName, int] = {}
	for key: StringName in goals:
		typed_goals[key] = int(goals[key])
	data.export_goals = typed_goals
	var typed_tags: Array[String] = []
	typed_tags.assign(tags)
	data.inspection_tags = typed_tags
	return data

func test_goals_unmet_when_export_short() -> void:
	var data := _tier({&"iron_ore": 50}, ["Industrial"])
	var progress := {&"iron_ore": 49}
	var tag_counts := {"Industrial": 1}
	assert_false(data.goals_reached(progress, tag_counts), "one unit short is not met")

func test_goals_met_when_export_reached() -> void:
	var data := _tier({&"iron_ore": 50}, ["Industrial"])
	assert_true(data.goals_reached({&"iron_ore": 50}, {"Industrial": 1}), "exact target counts as met")

func test_goals_met_with_overflow() -> void:
	# Overflow past a goal (one big sale) is still met - accumulation is additive.
	var data := _tier({&"iron_ore": 50}, [])
	assert_true(data.goals_reached({&"iron_ore": 999}, {}), "exceeding the goal is met")

func test_goals_unmet_when_checklist_facility_missing() -> void:
	# Every export goal met, but no built module for a checklist tag -> not met
	# (the "build a facility first" edge case, so accept can't instant-fail).
	var data := _tier({&"steel": 10}, ["Crew", "Power"])
	var progress := {&"steel": 10}
	assert_false(data.goals_reached(progress, {"Crew": 1, "Power": 0}), "missing Power facility blocks")
	assert_true(data.goals_reached(progress, {"Crew": 1, "Power": 2}), "both facilities present passes")

func test_goals_require_every_resource() -> void:
	var data := _tier({&"steel": 60, &"iron_ore": 40}, [])
	assert_false(data.goals_reached({&"steel": 60}, {}), "missing second resource entirely -> not met")
	assert_false(data.goals_reached({&"steel": 60, &"iron_ore": 39}, {}), "second resource short -> not met")
	assert_true(data.goals_reached({&"steel": 60, &"iron_ore": 40}, {}), "both resources met -> met")

func test_cap_tier_never_reached() -> void:
	# The top tier has empty goals; goals_reached is vacuously false so no further
	# advancement is ever offered.
	var data := _tier({}, [])
	assert_true(data.is_max_goal())
	assert_false(data.goals_reached({}, {}), "cap tier is never 'reached'")
