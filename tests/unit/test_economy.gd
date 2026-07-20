extends GutTest

## Unit tests for EconomyManager's pure arithmetic (WI-25/WI-19): the ARC levy
## skim, wage derivation, and loan schedule. These are the extracted static
## helpers so they need no Global/SignalBus - the instance methods call them.

# --- levy skim ----------------------------------------------------------------

func test_skim_takes_the_fraction() -> void:
	assert_eq(EconomyManager.skim_for(1000, 0.1), 100)
	assert_eq(EconomyManager.skim_for(250, 0.2), 50)

func test_skim_floors_partial_credits() -> void:
	# 105 * 0.1 = 10.5 -> the player keeps the half credit.
	assert_eq(EconomyManager.skim_for(105, 0.1), 10)

func test_skim_zero_when_disabled_or_nonpositive() -> void:
	assert_eq(EconomyManager.skim_for(1000, 0.0), 0)
	assert_eq(EconomyManager.skim_for(0, 0.1), 0)
	assert_eq(EconomyManager.skim_for(-500, 0.1), 0)

func test_net_income_is_gross_minus_skim() -> void:
	assert_eq(EconomyManager.net_income(1000, 0.1), 900)
	assert_eq(EconomyManager.net_income(1000, 0.0), 1000)

# --- wages --------------------------------------------------------------------

func test_wage_scales_from_hire_price() -> void:
	assert_eq(EconomyManager.wage_for(400, 0.1), 40)
	assert_eq(EconomyManager.wage_for(650, 0.1), 65)

func test_wage_rounds_to_nearest() -> void:
	# 405 * 0.1 = 40.5 -> rounds to 41 (round-half-up).
	assert_eq(EconomyManager.wage_for(405, 0.1), 41)

# --- loans --------------------------------------------------------------------

func test_loan_total_adds_interest() -> void:
	assert_eq(EconomyManager.loan_total(2500, 0.2), 3000)
	assert_eq(EconomyManager.loan_total(1000, 0.2), 1200)

func test_loan_schedule_sums_to_total() -> void:
	# The core guarantee: X payments summing exactly to principal * (1 + interest).
	for principal: int in [1000, 2500, 5000, 3333]:
		var schedule: Array[int] = EconomyManager.loan_schedule(principal, 0.2, 10)
		var sum: int = 0
		for pay: int in schedule:
			sum += pay
		assert_eq(sum, EconomyManager.loan_total(principal, 0.2),
			"schedule for %d sums to the total owed" % principal)

func test_loan_schedule_spans_the_term() -> void:
	var schedule: Array[int] = EconomyManager.loan_schedule(2500, 0.2, 10)
	assert_eq(schedule.size(), 10)
	for pay: int in schedule:
		assert_gt(pay, 0, "every drafted payment is positive")

func test_loan_schedule_shorter_when_principal_tiny() -> void:
	# A 5-credit loan over 10 cycles can't spread past a couple of cycles.
	var schedule: Array[int] = EconomyManager.loan_schedule(5, 0.2, 10)
	var sum: int = 0
	for pay: int in schedule:
		sum += pay
	assert_eq(sum, EconomyManager.loan_total(5, 0.2))
	assert_true(schedule.size() <= 10)
