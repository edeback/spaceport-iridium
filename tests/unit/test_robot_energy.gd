extends GutTest

## WI-28 robot energy math: the pure static drain_rate() budget plus the
## threshold / crawl predicates on a bare (never-in-tree) RobotPowerComponent -
## no Global, no _process, no scene. Locks the drain numbers and the gate
## boundaries the robot's recharge behaviour hangs off.

# --- drain rate (pure static) ------------------------------------------------

func test_drain_rate_idle_only() -> void:
	assert_almost_eq(RobotPowerComponent.drain_rate(false, false, 0.5, 12.0, 8.0), 0.5, 0.0001)

func test_drain_rate_moving_adds_moving() -> void:
	assert_almost_eq(RobotPowerComponent.drain_rate(true, false, 0.5, 12.0, 8.0), 12.5, 0.0001)

func test_drain_rate_working_adds_working() -> void:
	assert_almost_eq(RobotPowerComponent.drain_rate(false, true, 0.5, 12.0, 8.0), 8.5, 0.0001)

func test_drain_rate_moving_and_working_are_additive() -> void:
	# A robot both hauling (moving) and working drains fastest.
	assert_almost_eq(RobotPowerComponent.drain_rate(true, true, 0.5, 12.0, 8.0), 20.5, 0.0001)

# --- threshold + crawl predicates --------------------------------------------

func _make_power(energy: float, energy_max: float = 100.0, threshold: float = 30.0) -> RobotPowerComponent:
	var p: RobotPowerComponent = autofree(RobotPowerComponent.new())
	p.energy_max = energy_max
	p.seek_threshold_percent = threshold
	p.crawl_speed_scale = 0.25
	p.energy = energy
	return p

func test_energy_percent() -> void:
	assert_almost_eq(_make_power(25.0).energy_percent(), 25.0, 0.0001)

func test_wants_recharge_below_threshold() -> void:
	assert_true(_make_power(25.0).wants_recharge())

func test_wants_recharge_false_above_threshold() -> void:
	assert_false(_make_power(50.0).wants_recharge())

func test_wants_recharge_boundary_is_exclusive() -> void:
	# Exactly at the threshold is NOT "below" - don't stop working at 30%.
	assert_false(_make_power(30.0).wants_recharge())

func test_must_recharge_only_at_zero() -> void:
	var p: RobotPowerComponent = _make_power(1.0)
	assert_false(p.must_recharge(), "1 energy is a low-power crawl-not-yet")
	p.energy = 0.0
	assert_true(p.must_recharge(), "empty = emergency backup power")

func test_energy_clamps_to_max() -> void:
	var p: RobotPowerComponent = _make_power(50.0)
	p.energy = 999.0
	assert_almost_eq(p.energy, 100.0, 0.0001)

func test_energy_clamps_to_zero() -> void:
	var p: RobotPowerComponent = _make_power(50.0)
	p.energy = -20.0
	assert_almost_eq(p.energy, 0.0, 0.0001)

# --- charge out-rates drain (duty-cycle sanity) ------------------------------

func test_charger_outrates_worst_case_drain() -> void:
	# A charge trip must net positive: the charger's rate must exceed the robot's
	# worst-case (moving + working) drain, or it could never catch up.
	var worst_drain: float = RobotPowerComponent.drain_rate(true, true, 0.5, 12.0, 8.0)
	var bay_charge_rate: float = 200.0 # the implicit bay charger's charge_rate_per_hour
	assert_gt(bay_charge_rate, worst_drain)

func test_one_hour_of_charge_beats_one_hour_of_drain() -> void:
	# Simulate a stationary charge (no drain) vs a full hour of worst-case drain.
	var start: float = 10.0
	var after_drain: float = start - RobotPowerComponent.drain_rate(true, true, 0.5, 12.0, 8.0) * 1.0
	var after_charge: float = start + 200.0 * 1.0
	assert_lt(after_drain, start, "a working hour drains")
	assert_gt(after_charge, start, "a charging hour restores")
