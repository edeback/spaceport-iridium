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

# --- ledger categories (WI-68 F4) -------------------------------------------------

func test_every_declared_category_has_a_label() -> void:
	for category: StringName in EconomyManager.COST_CATEGORIES + EconomyManager.INCOME_CATEGORIES:
		assert_true(EconomyManager.CATEGORY_LABELS.has(category), "%s is declared but has no label" % category)

func test_every_label_belongs_to_a_declared_category() -> void:
	# A label with no list is a category the Finance tab can never show.
	for category: StringName in EconomyManager.CATEGORY_LABELS:
		assert_true(EconomyManager.is_declared(category, true) or EconomyManager.is_declared(category, false),
			"%s has a label but is in neither list" % category)

func test_no_category_is_listed_twice_on_one_side() -> void:
	for side: Array[StringName] in [EconomyManager.COST_CATEGORIES, EconomyManager.INCOME_CATEGORIES]:
		for category: StringName in side:
			assert_eq(side.count(category), 1, "%s appears once" % category)

func test_only_event_sits_on_both_sides() -> void:
	# A windfall and a loss; anything else on both sides is a mistake.
	for category: StringName in EconomyManager.COST_CATEGORIES:
		if EconomyManager.is_declared(category, false):
			assert_eq(category, &"event", "%s is both a cost and income" % category)

func test_the_formerly_unbooked_spends_are_declared_costs() -> void:
	for category: StringName in [&"trade_purchases", &"raid_payoff", &"hiring"]:
		assert_true(EconomyManager.is_declared(category, true), "%s is a declared cost" % category)
	assert_true(EconomyManager.is_declared(EconomyManager.REFUND_CATEGORY, false), "refunds are income")

func test_sales_and_purchases_read_as_a_pair() -> void:
	assert_eq(EconomyManager.category_label(&"trade"), "Sales")
	assert_eq(EconomyManager.category_label(&"trade_purchases"), "Purchases")

# --- records ------------------------------------------------------------------------

func _record() -> Dictionary:
	return {"cycle": 3, "income": {}, "costs": {}}

func test_add_to_record_accumulates_per_category() -> void:
	var record: Dictionary = _record()
	EconomyManager.add_to_record(record, "costs", &"wages", 40)
	EconomyManager.add_to_record(record, "costs", &"wages", 15)
	EconomyManager.add_to_record(record, "income", &"trade", 250)
	assert_eq(record["costs"][&"wages"], 55)
	assert_eq(record["income"][&"trade"], 250)

func test_an_undeclared_category_is_reported_but_still_booked() -> void:
	# Refusing it would recreate the bug: the money really moved, so the books
	# must still see it. The error is what catches the authoring mistake.
	var record: Dictionary = _record()
	EconomyManager.add_to_record(record, "costs", &"mystery_fee", 30)
	assert_push_error("undeclared", "a new category that skipped the list is loud")
	assert_eq(EconomyManager.record_net(record), -30, "and still counts against the net")

func test_record_net_counts_every_category() -> void:
	var record: Dictionary = _record()
	EconomyManager.add_to_record(record, "income", &"trade", 250)
	EconomyManager.add_to_record(record, "costs", &"trade_purchases", 6000)
	EconomyManager.add_to_record(record, "costs", &"hiring", 800)
	assert_eq(EconomyManager.record_net(record), 250 - 6000 - 800,
		"the audit's example: buying 6000 and selling 250 is not a +250 cycle")

func test_a_refunded_hire_nets_to_zero() -> void:
	var record: Dictionary = _record()
	EconomyManager.add_to_record(record, "costs", &"hiring", 883)
	EconomyManager.add_to_record(record, "income", EconomyManager.REFUND_CATEGORY, 883)
	assert_eq(EconomyManager.record_net(record), 0, "a hire paid and refunded in one cycle cost nothing")

func test_an_empty_record_nets_to_zero() -> void:
	assert_eq(EconomyManager.record_net({}), 0)

# --- balance change -------------------------------------------------------------------

func test_the_cycle_in_progress_measures_against_the_live_balance() -> void:
	var record: Dictionary = _record()
	record[EconomyManager.OPENING_BALANCE] = 1000
	assert_true(EconomyManager.knows_balance_change(record))
	assert_eq(EconomyManager.balance_change(record, 800), -200)

func test_a_closed_cycle_measures_against_its_closing_balance() -> void:
	var record: Dictionary = _record()
	record[EconomyManager.OPENING_BALANCE] = 1000
	record[EconomyManager.CLOSING_BALANCE] = 700
	assert_eq(EconomyManager.balance_change(record, 99999), -300, "the live balance is irrelevant once a cycle closed")

func test_a_record_without_an_opening_balance_knows_no_change() -> void:
	# A pre-WI-68 record: hidden on the tab, never guessed.
	assert_false(EconomyManager.knows_balance_change(_record()))

# --- save round trip -----------------------------------------------------------------

func test_a_record_round_trips_through_json_with_its_balances() -> void:
	var record: Dictionary = _record()
	EconomyManager.add_to_record(record, "income", &"trade", 250)
	EconomyManager.add_to_record(record, "costs", &"raid_payoff", 1200)
	record[EconomyManager.OPENING_BALANCE] = 5000
	record[EconomyManager.CLOSING_BALANCE] = 4050
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(EconomyManager.record_to_save(record))) as Dictionary
	var restored: Dictionary = EconomyManager.record_from_save(parsed, 0)
	assert_eq(restored["cycle"], 3)
	assert_eq(restored["income"][&"trade"], 250, "category keys come back as StringName")
	assert_eq(restored["costs"][&"raid_payoff"], 1200)
	assert_eq(restored[EconomyManager.OPENING_BALANCE], 5000)
	assert_eq(restored[EconomyManager.CLOSING_BALANCE], 4050)
	assert_eq(EconomyManager.balance_change(restored, 0), -950)

func test_a_pre_wi68_record_loads_without_invented_balances() -> void:
	var restored: Dictionary = EconomyManager.record_from_save({"cycle": 2, "income": {}, "costs": {"wages": 40}}, 0)
	assert_false(restored.has(EconomyManager.OPENING_BALANCE), "absent stays absent")
	assert_false(restored.has(EconomyManager.CLOSING_BALANCE))
	assert_eq(restored["costs"][&"wages"], 40)
