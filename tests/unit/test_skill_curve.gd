extends GutTest

## Unit tests for SkillData's pure curve math (data/skills/skill_data.gd) -
## the level->multiplier and xp->level constants jobs consult (WI-22). The
## static registry (all()/by_id()) is not touched; these build a SkillData
## directly with known constants.

func _skill() -> SkillData:
	var skill := SkillData.new()
	skill.id = &"test"
	skill.min_multiplier = 0.6
	skill.max_multiplier = 1.5
	skill.base_xp_to_level = 100.0
	skill.xp_growth = 1.4
	return skill

# --- multiplier curve ---------------------------------------------------------

func test_multiplier_endpoints() -> void:
	var skill := _skill()
	assert_almost_eq(skill.multiplier_for_level(0), 0.6, 0.0001, "level 0 = min")
	assert_almost_eq(skill.multiplier_for_level(SkillData.MAX_LEVEL), 1.5, 0.0001, "max level = max")

func test_multiplier_midpoint_is_lerp() -> void:
	# level 5 of 10 is halfway between 0.6 and 1.5.
	assert_almost_eq(_skill().multiplier_for_level(5), 1.05, 0.0001)

func test_multiplier_is_monotonic_increasing() -> void:
	var skill := _skill()
	var prev: float = skill.multiplier_for_level(0)
	for level: int in range(1, SkillData.MAX_LEVEL + 1):
		var cur: float = skill.multiplier_for_level(level)
		assert_gt(cur, prev, "level %d multiplier exceeds level %d" % [level, level - 1])
		prev = cur

func test_multiplier_clamps_out_of_band_levels() -> void:
	var skill := _skill()
	assert_almost_eq(skill.multiplier_for_level(-3), 0.6, 0.0001, "below 0 clamps to min")
	assert_almost_eq(skill.multiplier_for_level(99), 1.5, 0.0001, "above max clamps to max")

# --- xp curve -----------------------------------------------------------------

func test_xp_to_next_starts_at_base() -> void:
	assert_almost_eq(_skill().xp_to_next(0), 100.0, 0.0001)

func test_xp_to_next_grows_geometrically() -> void:
	var skill := _skill()
	assert_almost_eq(skill.xp_to_next(1), 140.0, 0.0001, "100 * 1.4^1")
	assert_almost_eq(skill.xp_to_next(2), 196.0, 0.0001, "100 * 1.4^2")

func test_xp_to_next_each_level_costs_more() -> void:
	var skill := _skill()
	for level: int in range(0, SkillData.MAX_LEVEL - 1):
		assert_gt(skill.xp_to_next(level + 1), skill.xp_to_next(level),
			"level %d costs more than %d" % [level + 1, level])

func test_xp_to_next_is_inf_at_and_above_cap() -> void:
	var skill := _skill()
	assert_eq(skill.xp_to_next(SkillData.MAX_LEVEL), INF, "no advancing past the cap")
	assert_eq(skill.xp_to_next(SkillData.MAX_LEVEL + 5), INF)
