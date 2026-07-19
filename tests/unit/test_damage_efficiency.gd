extends GutTest

## WI-24 damage/breakdown efficiency math, exercised on the pure StatModifiers
## layer that ModuleBase._refresh_damage_modifier() / _apply_breakdown_modifier()
## write into. ModuleBase itself is a Node wired to Global and can't be unit-
## constructed, so these replicate the exact formulas and assert the effective
## stats the components would read - locking the numbers and the regression
## guarantee (full health is a byte-for-byte no-op).

const DAMAGE_SOURCE := &"damage"
const BREAKDOWN_SOURCE := &"breakdown"
const BREAKDOWN_EFFICIENCY := 0.5

var mods: StatModifiers

func before_each() -> void:
	mods = StatModifiers.new()

## Mirror of ModuleBase._refresh_damage_modifier().
func _apply_damage(frac: float, min_eff: float) -> void:
	if frac >= 1.0:
		mods.remove_source(DAMAGE_SOURCE)
		return
	var efficiency: float = maxf(lerpf(min_eff, 1.0, frac), 0.05)
	mods.set_single_modifier(&"power_output", StatModifiers.Op.MULT, efficiency, DAMAGE_SOURCE)
	mods.set_single_modifier(&"mining_rate", StatModifiers.Op.MULT, efficiency, DAMAGE_SOURCE)
	mods.set_single_modifier(&"traversal_speed_mult", StatModifiers.Op.MULT, efficiency, DAMAGE_SOURCE)
	mods.set_single_modifier(&"process_time", StatModifiers.Op.MULT, 1.0 / efficiency, DAMAGE_SOURCE)

## Mirror of ModuleBase._apply_breakdown_modifier().
func _apply_breakdown() -> void:
	mods.set_single_modifier(&"power_output", StatModifiers.Op.MULT, BREAKDOWN_EFFICIENCY, BREAKDOWN_SOURCE)
	mods.set_single_modifier(&"mining_rate", StatModifiers.Op.MULT, BREAKDOWN_EFFICIENCY, BREAKDOWN_SOURCE)
	mods.set_single_modifier(&"process_time", StatModifiers.Op.MULT, 1.0 / BREAKDOWN_EFFICIENCY, BREAKDOWN_SOURCE)

# --- regression: undamaged is a no-op ----------------------------------------

func test_full_health_leaves_stats_at_base() -> void:
	_apply_damage(1.0, 0.25)
	assert_eq(mods.get_effective(&"power_output", 100.0), 100.0)
	assert_eq(mods.get_effective(&"process_time", 10.0), 10.0)
	assert_eq(mods.get_effective(&"mining_rate", 1.0), 1.0)
	assert_false(mods.has_modifiers(&"power_output"), "no damage source lingers at full HP")

func test_repair_to_full_clears_a_prior_hit() -> void:
	_apply_damage(0.5, 0.25)
	assert_almost_eq(mods.get_effective(&"power_output", 100.0), 62.5, 0.001)
	_apply_damage(1.0, 0.25) # healed back to full
	assert_eq(mods.get_effective(&"power_output", 100.0), 100.0)

# --- the efficiency curve ----------------------------------------------------

func test_half_health_output_scales_by_efficiency() -> void:
	# efficiency = lerp(0.25, 1.0, 0.5) = 0.625
	_apply_damage(0.5, 0.25)
	assert_almost_eq(mods.get_effective(&"power_output", 100.0), 62.5, 0.001)
	assert_almost_eq(mods.get_effective(&"mining_rate", 1.0), 0.625, 0.001)

func test_process_time_scales_inversely_with_damage() -> void:
	# a hurt machine is SLOWER: process_time multiplies by 1/efficiency
	_apply_damage(0.5, 0.25)
	assert_almost_eq(mods.get_effective(&"process_time", 10.0), 16.0, 0.001)

func test_zero_hp_lands_on_min_efficiency() -> void:
	# truss wreckage: frac 0 -> efficiency = min_eff (0.1) for heavy EVA cost
	_apply_damage(0.0, 0.1)
	assert_almost_eq(mods.get_effective(&"traversal_speed_mult", 1.0), 0.1, 0.001)

func test_structural_min_eff_one_never_degrades_output() -> void:
	# min_damaged_efficiency 1.0 = damage is cosmetic only (decor/structure)
	_apply_damage(0.2, 1.0)
	assert_almost_eq(mods.get_effective(&"power_output", 100.0), 100.0, 0.001)

func test_updating_damage_replaces_rather_than_compounds() -> void:
	_apply_damage(0.5, 0.25) # eff 0.625
	_apply_damage(0.25, 0.25) # eff 0.4375
	assert_almost_eq(mods.get_effective(&"power_output", 100.0), 43.75, 0.001)
	assert_eq(mods.tier_count(&"power_output", DAMAGE_SOURCE), 1, "one damage modifier, not two")

# --- damage + breakdown compound multiplicatively ----------------------------

func test_breakdown_alone_halves_output_and_doubles_time() -> void:
	_apply_breakdown()
	assert_almost_eq(mods.get_effective(&"power_output", 100.0), 50.0, 0.001)
	assert_almost_eq(mods.get_effective(&"process_time", 10.0), 20.0, 0.001)

func test_damage_and_breakdown_stack_independently() -> void:
	# frac 0.42 -> eff 0.565; power = 100 * 0.565 * 0.5
	_apply_damage(0.42, 0.25)
	_apply_breakdown()
	assert_almost_eq(mods.get_effective(&"power_output", 100.0), 28.25, 0.01)
	# process_time = 10 / 0.565 / 0.5
	assert_almost_eq(mods.get_effective(&"process_time", 10.0), 35.398, 0.01)

func test_clearing_breakdown_leaves_damage_intact() -> void:
	_apply_damage(0.5, 0.25)
	_apply_breakdown()
	mods.remove_source(BREAKDOWN_SOURCE)
	# only the damage 0.625 remains
	assert_almost_eq(mods.get_effective(&"power_output", 100.0), 62.5, 0.001)
