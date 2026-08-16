extends GutTest

## Unit tests for the hire-candidate pricing formula (WI-22),
## CandidateRoller.compute_price - the pure arithmetic extracted so it needs no
## Global. Base cost x skill premium x trait modifier. WI-59 moved it off
## CrewManager with the rest of the roll; the formula itself is unchanged.

const BASE: int = 500
const PREMIUM: float = 0.08

# --- formula ------------------------------------------------------------------

func test_zero_skill_no_traits_is_base_cost() -> void:
	assert_eq(CandidateRoller.compute_price(BASE, 0, 1.0, PREMIUM), BASE)

func test_skill_premium_scales_price() -> void:
	# 10 total levels -> 1 + 10*0.08 = 1.8x.
	assert_eq(CandidateRoller.compute_price(BASE, 10, 1.0, PREMIUM), 900)

func test_trait_modifier_scales_price() -> void:
	# a 1.2 (Hardy) modifier on the base.
	assert_eq(CandidateRoller.compute_price(BASE, 0, 1.2, PREMIUM), 600)
	# a 0.8 (Weak) modifier discounts.
	assert_eq(CandidateRoller.compute_price(BASE, 0, 0.8, PREMIUM), 400)

func test_skill_and_trait_compound() -> void:
	# 500 * (1 + 20*0.08) * 1.2 = 500 * 2.6 * 1.2 = 1560.
	assert_eq(CandidateRoller.compute_price(BASE, 20, 1.2, PREMIUM), 1560)

# --- monotonicity: the "no elite for free" guarantee --------------------------

func test_price_strictly_increases_with_total_skill() -> void:
	var prev: int = CandidateRoller.compute_price(BASE, 0, 1.0, PREMIUM)
	for total: int in range(1, 60):
		var cur: int = CandidateRoller.compute_price(BASE, total, 1.0, PREMIUM)
		assert_gt(cur, prev, "total %d costs more than %d" % [total, total - 1])
		prev = cur

func test_two_standouts_never_cheaper_than_one() -> void:
	# A candidate with more total skill can't undercut a lesser one at the same
	# trait modifier, whatever the standout split.
	var one_standout: int = CandidateRoller.compute_price(BASE, 9, 1.0, PREMIUM)
	var two_standouts: int = CandidateRoller.compute_price(BASE, 15, 1.0, PREMIUM)
	assert_gt(two_standouts, one_standout)
