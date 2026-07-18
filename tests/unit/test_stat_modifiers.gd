extends GutTest

## Unit tests for StatModifiers (modules/templates/stat_modifiers.gd) - the
## per-module runtime layer that upgrades feed. The whole contract is one
## formula: effective = base * (product of MULT) + (sum of ADD), with modifiers
## grouped by `source` so a whole upgrade (all its tiers) can be counted and
## removed together.

var mods: StatModifiers

func before_each() -> void:
	mods = StatModifiers.new()

# --- the effective-value formula ---------------------------------------------

func test_unknown_stat_returns_base_unchanged() -> void:
	assert_eq(mods.get_effective(&"output", 10.0), 10.0, "no modifiers -> base * 1 + 0")

func test_add_modifier_is_additive() -> void:
	mods.add_modifier(&"output", StatModifiers.Op.ADD, 5.0, &"upgrade_a")
	assert_eq(mods.get_effective(&"output", 10.0), 15.0)

func test_mult_modifier_is_multiplicative() -> void:
	mods.add_modifier(&"output", StatModifiers.Op.MULT, 2.0, &"upgrade_a")
	assert_eq(mods.get_effective(&"output", 10.0), 20.0)

func test_mult_applies_before_add() -> void:
	mods.add_modifier(&"output", StatModifiers.Op.MULT, 2.0, &"m")
	mods.add_modifier(&"output", StatModifiers.Op.ADD, 5.0, &"a")
	# base * mult + add = 10 * 2 + 5
	assert_eq(mods.get_effective(&"output", 10.0), 25.0)

func test_multiple_mults_stack_multiplicatively() -> void:
	mods.add_modifier(&"output", StatModifiers.Op.MULT, 2.0, &"a")
	mods.add_modifier(&"output", StatModifiers.Op.MULT, 3.0, &"b")
	assert_eq(mods.get_effective(&"output", 10.0), 60.0, "2x then 3x = 6x")

func test_multiple_adds_sum() -> void:
	mods.add_modifier(&"output", StatModifiers.Op.ADD, 2.0, &"a")
	mods.add_modifier(&"output", StatModifiers.Op.ADD, 3.0, &"b")
	assert_eq(mods.get_effective(&"output", 10.0), 15.0)

func test_modifiers_are_scoped_per_stat() -> void:
	mods.add_modifier(&"output", StatModifiers.Op.ADD, 5.0, &"a")
	assert_eq(mods.get_effective(&"speed", 10.0), 10.0, "a modifier on 'output' doesn't touch 'speed'")

# --- caching / dirtying ------------------------------------------------------

func test_adding_after_a_read_recomputes() -> void:
	assert_eq(mods.get_effective(&"output", 10.0), 10.0, "cache the clean value")
	mods.add_modifier(&"output", StatModifiers.Op.ADD, 4.0, &"a")
	assert_eq(mods.get_effective(&"output", 10.0), 14.0, "adding a modifier invalidates the cache")

# --- source grouping (tiers) -------------------------------------------------

func test_tier_count_counts_modifiers_from_a_source() -> void:
	assert_eq(mods.tier_count(&"output", &"upg"), 0, "nothing bought yet")
	mods.add_modifier(&"output", StatModifiers.Op.MULT, 1.1, &"upg")
	mods.add_modifier(&"output", StatModifiers.Op.MULT, 1.1, &"upg")
	assert_eq(mods.tier_count(&"output", &"upg"), 2, "two tiers of the same upgrade")

func test_has_modifiers_reflects_presence() -> void:
	assert_false(mods.has_modifiers(&"output"))
	mods.add_modifier(&"output", StatModifiers.Op.ADD, 1.0, &"a")
	assert_true(mods.has_modifiers(&"output"))

func test_remove_source_strips_all_its_contributions_across_stats() -> void:
	mods.add_modifier(&"output", StatModifiers.Op.ADD, 5.0, &"upg")
	mods.add_modifier(&"speed", StatModifiers.Op.MULT, 2.0, &"upg")
	mods.add_modifier(&"output", StatModifiers.Op.ADD, 1.0, &"other")
	mods.remove_source(&"upg")
	assert_eq(mods.get_effective(&"output", 10.0), 11.0, "only 'other' remains on output")
	assert_eq(mods.get_effective(&"speed", 10.0), 10.0, "the upg mult on speed is gone")
	assert_eq(mods.tier_count(&"output", &"upg"), 0, "no upg tiers left anywhere")

# --- change signal -----------------------------------------------------------

func test_changed_signal_fires_on_add() -> void:
	watch_signals(mods)
	mods.add_modifier(&"output", StatModifiers.Op.ADD, 1.0, &"a")
	assert_signal_emitted_with_parameters(mods, "changed", [&"output"])
