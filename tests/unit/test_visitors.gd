extends GutTest

## WI-33 visitor pacing + reputation pure logic (WI-19 followup):
## VisitorManager.expected_arrivals_per_cycle and reputation_after_departure. Both
## are static and pure - no Global, no scene tree.

# --- arrival pacing (expected_arrivals_per_cycle) -----------------------------

func _expected(rep: float, hotel: int, shops: int, tier_met: bool) -> float:
	# floor 0.6, per-reputation 3.0 (the manager's export defaults).
	return VisitorManager.expected_arrivals_per_cycle(rep, hotel, shops, tier_met, 0.6, 3.0)

func test_no_arrivals_below_tier() -> void:
	assert_eq(_expected(1.0, 4, 2, false), 0.0, "no guests until the visitor tier is met")

func test_no_arrivals_without_lodging() -> void:
	assert_eq(_expected(1.0, 0, 2, true), 0.0, "no bunks -> no guests (the hard capacity gate)")

func test_no_arrivals_without_shops() -> void:
	assert_eq(_expected(1.0, 4, 0, true), 0.0, "nowhere to spend -> no guests")

func test_floor_trickle_at_zero_reputation() -> void:
	# The anti-death-spiral floor: some brave guests arrive even at rock-bottom
	# reputation, as long as capacity exists.
	assert_almost_eq(_expected(0.0, 4, 2, true), 0.6, 0.0001, "floor arrivals with zero reputation")

func test_reputation_raises_arrivals() -> void:
	var low: float = _expected(0.2, 10, 4, true)
	var high: float = _expected(0.9, 10, 4, true)
	assert_gt(high, low, "higher reputation draws more guests")

func test_full_reputation_rate() -> void:
	# floor 0.6 + 3.0 * 1.0 = 3.6, and lodging (10) is not the binding cap.
	assert_almost_eq(_expected(1.0, 10, 4, true), 3.6, 0.0001, "floor + full reputation bonus")

func test_lodging_caps_demand() -> void:
	# Demand at full reputation is 3.6, but only 2 bunks exist -> capped at 2.
	assert_almost_eq(_expected(1.0, 2, 4, true), 2.0, 0.0001, "arrivals can't exceed hotel capacity")

func test_reputation_clamped_in_pacing() -> void:
	# An out-of-range reputation is clamped before scaling (defensive).
	assert_almost_eq(_expected(5.0, 10, 4, true), 3.6, 0.0001, "reputation > 1 clamps to full rate")

# --- reputation drift (reputation_after_departure) ----------------------------

func test_happy_departure_raises_reputation() -> void:
	assert_almost_eq(VisitorManager.reputation_after_departure(0.5, true, 0.04, 0.06), 0.54, 0.0001, "a happy guest lifts standing")

func test_unhappy_departure_lowers_reputation() -> void:
	assert_almost_eq(VisitorManager.reputation_after_departure(0.5, false, 0.04, 0.06), 0.44, 0.0001, "an unhappy guest sinks standing")

func test_reputation_clamps_at_ceiling() -> void:
	assert_eq(VisitorManager.reputation_after_departure(0.99, true, 0.04, 0.06), 1.0, "reputation never exceeds 1")

func test_reputation_clamps_at_floor() -> void:
	assert_eq(VisitorManager.reputation_after_departure(0.03, false, 0.04, 0.06), 0.0, "reputation never drops below 0")
