extends GutTest

## Unit tests for WI-55's trade arithmetic: [TradeOffer]'s caps, prices and
## totals, plus the station-wide `AVAIL` accessor the sell cap is built on.
##
## The caps are the part that must not regress - they are what
## `trader_screen._build_rows()` did inline, mixed into node construction, where
## nothing could reach them. The `AVAIL` half is asserted against real
## [StorageComponent]s rather than a stub, because "excludes reserved_withdraw"
## is a claim about the reservation bookkeeping, not about a sum.
##
## Throughout: a line's amount counts **goods**, positive buying in and negative
## selling out, while its credits run the other way. Several assertions below
## exist only to pin that down, because WI-55 shipped it inverted.

func _resource(id: StringName, resource_name: String = "") -> ResourceData:
	var resource := ResourceData.new()
	resource.id = id
	resource.name = resource_name if resource_name != "" else String(id)
	return resource

## A storage component holding `stored` of `resource`, with `reserved` of it
## already claimed for withdrawal. Registered with the resource, the way
## `ready_constructed` does it.
func _storage(resource: ResourceData, stored: int, reserved: int = 0) -> StorageComponent:
	var component: StorageComponent = autofree(StorageComponent.new())
	component.max_stored = 9999
	var data := StorageData.new()
	data.resource_data = resource
	data.deposit(stored, false)
	if reserved > 0:
		data.take_claim(ClaimSpec.Kind.STORAGE_WITHDRAW, reserved)
	component.storage_data[resource] = data
	resource.register_component(component)
	return component

func _line(amount: int, buy: int, sell: int) -> TradeOffer.Line:
	return TradeOffer.Line.of(_resource(&"line_res"), amount, buy, sell)

# --- sell limit ---------------------------------------------------------------

func test_sell_is_capped_by_unreserved_available_not_by_held() -> void:
	# 100 held, 40 of it already claimed by a hauler: 60 is sellable.
	assert_eq(TradeOffer.sell_limit(60, 0, TradeOffer.ORDER_CAP), 60,
		"the cap is what is unreserved, not what is stored")

func test_sell_limit_adds_the_line_back_so_an_order_cannot_ratchet_itself_down() -> void:
	# The order's own hauls are what reserved the stock, so a line already selling
	# 60 (which is -60) against 40 unreserved must still be allowed to sell 60.
	assert_eq(TradeOffer.sell_limit(40, -60, TradeOffer.ORDER_CAP), 100,
		"a line's own reservations do not count against it")

func test_sell_limit_does_not_add_a_buy_line_back() -> void:
	# The add-back is for the sell this line already causes. A line buying 60 has
	# reserved nothing, so it gets the bare available figure.
	assert_eq(TradeOffer.sell_limit(40, 60, TradeOffer.ORDER_CAP), 40,
		"a positive line is a buy and reserves no stock")

func test_sell_limit_still_falls_when_someone_else_claims_the_stock() -> void:
	# Same line of 60, but a construction site has taken 30 more: the cap drops
	# below the line and the panel has to clamp.
	var limit: int = TradeOffer.sell_limit(10, -60, TradeOffer.ORDER_CAP)
	assert_eq(limit, 70, "the third party's claim comes off the top")
	assert_eq(TradeOffer.clamp_amount(-80, 0, limit), -70, "and the line clamps to it")

func test_sell_limit_is_capped_by_the_traders_remaining_hold() -> void:
	assert_eq(TradeOffer.sell_limit(500, 0, 40), 40, "cargo space wins when it is smaller")
	assert_eq(TradeOffer.sell_limit(30, 0, 40), 30, "available wins when it is smaller")

func test_sell_limit_never_goes_negative() -> void:
	assert_eq(TradeOffer.sell_limit(-5, 0, TradeOffer.ORDER_CAP), 0, "negative available reads as none")
	assert_eq(TradeOffer.sell_limit(100, 0, 0), 0, "a full hold sells nothing")

# --- buy limit ----------------------------------------------------------------

func test_buy_is_capped_by_trader_stock() -> void:
	assert_eq(TradeOffer.buy_limit(12, 100000, 5, 9999), 12, "cannot buy more than they carry")

func test_buy_is_capped_by_credits() -> void:
	# 100 credits at 30 each buys three, not the four they have in stock.
	assert_eq(TradeOffer.buy_limit(4, 100, 30, 9999), 3, "affordability truncates rather than rounds")

func test_buy_is_capped_by_import_bin_space() -> void:
	assert_eq(TradeOffer.buy_limit(50, 100000, 1, 8), 8, "the bin has room for eight")

func test_free_goods_are_not_capped_by_credits() -> void:
	# The fulfilment loop has the same `price <= 0` branch; this must not divide
	# by zero or silently cap at nothing.
	assert_eq(TradeOffer.buy_limit(7, 0, 0, 9999), 7, "a zero price is not an affordability limit")

func test_buy_limit_never_goes_negative() -> void:
	assert_eq(TradeOffer.buy_limit(10, -50, 5, 9999), 0, "a station in debt buys nothing")
	assert_eq(TradeOffer.buy_limit(-3, 1000, 1, 9999), 0, "negative stock reads as none")

# --- direction ----------------------------------------------------------------

func test_a_line_is_never_both_a_buy_and_a_sell() -> void:
	for amount: int in [-40, -1, 0, 1, 40]:
		assert_false(TradeOffer.is_buy(amount) and TradeOffer.is_sell(amount),
			"%d is at most one direction" % amount)

func test_positive_buys_in_and_negative_sells_out() -> void:
	# The sign counts goods, so it runs with HELD and AVAIL rather than with the
	# credits. Inverting this is the WI-55 defect these four lines exist to catch.
	assert_true(TradeOffer.is_buy(5), "positive is stock arriving")
	assert_true(TradeOffer.is_sell(-5), "negative is stock leaving")
	assert_false(TradeOffer.is_sell(5), "positive is not a sell")
	assert_false(TradeOffer.is_buy(-5), "negative is not a buy")

func test_zero_is_neither_direction() -> void:
	assert_false(TradeOffer.is_sell(0), "an unset line does not sell")
	assert_false(TradeOffer.is_buy(0), "an unset line does not buy")

func test_clamp_holds_both_ends() -> void:
	# clamp_amount(amount, buy, sell): the buy is the upper bound and the sell the
	# lower one, because buying is what adds stock.
	assert_eq(TradeOffer.clamp_amount(90, 10, 20), 10, "clamped to the buy end")
	assert_eq(TradeOffer.clamp_amount(-90, 10, 20), -20, "clamped to the sell end")
	assert_eq(TradeOffer.clamp_amount(5, 10, 20), 5, "left alone inside the range")
	assert_eq(TradeOffer.clamp_amount(0, 10, 20), 0, "zero survives any range")

# --- which number a line shows ------------------------------------------------
#
# The precedence behind the docked table's one editable number. It is a rule
# rather than a lookup because the docked stepper is a *proposal*: it is written
# nowhere until CONFIRM, and a refresh that could not see proposals read the line
# back off the orders it had not been written to and snatched it to zero - the
# docked table could not be edited at all.

func test_the_standing_sheet_is_the_whole_answer_while_undocked() -> void:
	var ore: ResourceData = _resource(&"ore")
	assert_eq(TradeOffer.displayed_amount(ore, false, {}, {}, {}, {ore: 20}, {}), -20,
		"the sheet's sell order comes back negative")
	assert_eq(TradeOffer.displayed_amount(ore, false, {}, {}, {}, {}, {ore: 20}), 20,
		"the sheet's buy order comes back positive")

func test_a_visit_only_number_is_ignored_while_undocked() -> void:
	var ore: ResourceData = _resource(&"ore")
	# Both belong to a visit; outside one they are not the table's business.
	assert_eq(TradeOffer.displayed_amount(ore, false, {ore: 60}, {ore: 45}, {}, {}, {}), 0,
		"neither a proposal nor a commitment survives the departure")

func test_a_proposal_survives_the_refresh_that_follows_it() -> void:
	# The regression. Docked, nothing has written -60 anywhere else - if `pending`
	# did not win here the player's own edit would undo itself on the next repaint.
	var ore: ResourceData = _resource(&"ore")
	assert_eq(TradeOffer.displayed_amount(ore, true, {ore: -60}, {}, {}, {}, {}), -60,
		"the line still reads what the player set")

func test_a_proposal_beats_the_commitment_and_the_sheet() -> void:
	var ore: ResourceData = _resource(&"ore")
	assert_eq(TradeOffer.displayed_amount(ore, true, {ore: -60}, {ore: 45}, {}, {ore: 10}, {}), -60,
		"the newest number the player touched is the one on screen")

func test_a_proposal_of_zero_is_a_number_the_player_chose() -> void:
	var ore: ResourceData = _resource(&"ore")
	# Stepping a line back down to nothing must not fall through to the order it
	# was cancelling, or a line could never be cleared.
	assert_eq(TradeOffer.displayed_amount(ore, true, {ore: 0}, {ore: 45}, {}, {ore: 10}, {}), 0,
		"zero is set, not absent")

func test_a_proposal_may_reverse_the_line_it_is_replacing() -> void:
	# Sell 45 committed, and the player has since decided to buy 20 instead. One
	# signed number means the reversal needs no separate cancel step.
	var ore: ResourceData = _resource(&"ore")
	assert_eq(TradeOffer.displayed_amount(ore, true, {ore: 20}, {ore: 45}, {}, {}, {}), 20,
		"the proposal replaces the direction as well as the amount")

func test_an_untouched_docked_line_shows_the_visit_commitment() -> void:
	var ore: ResourceData = _resource(&"ore")
	assert_eq(TradeOffer.displayed_amount(ore, true, {}, {ore: 45}, {}, {ore: 10}, {}), -45,
		"what is committed beats what is merely wanted")
	assert_eq(TradeOffer.displayed_amount(ore, true, {}, {}, {ore: 45}, {ore: 10}, {}), 45,
		"a committed buy comes back positive")

func test_a_fully_fulfilled_commitment_falls_through_to_the_sheet() -> void:
	var ore: ResourceData = _resource(&"ore")
	# `_fulfill` erases a commitment the moment it is met, and the line then goes
	# back to reading the standing order it was raised from.
	assert_eq(TradeOffer.displayed_amount(ore, true, {}, {}, {}, {ore: 10}, {}), -10,
		"the sheet is what is left")

func test_a_line_nothing_holds_reads_zero() -> void:
	var ore: ResourceData = _resource(&"ore")
	assert_eq(TradeOffer.displayed_amount(ore, true, {}, {}, {}, {}, {}), 0, "docked")
	assert_eq(TradeOffer.displayed_amount(ore, false, {}, {}, {}, {}, {}), 0, "undocked")

func test_one_lines_number_never_leaks_into_another() -> void:
	var ore: ResourceData = _resource(&"ore")
	var steel: ResourceData = _resource(&"steel")
	assert_eq(TradeOffer.displayed_amount(steel, true, {ore: -60}, {ore: 45}, {}, {ore: 10}, {}), 0,
		"steel is untouched by the ore line")

func test_the_sell_half_is_read_before_the_buy_half() -> void:
	var ore: ResourceData = _resource(&"ore")
	# The two halves are meant to be mutually exclusive - one signed stepper makes
	# the contradiction unrepresentable - but a save or a mod could still present
	# both, and the answer must be deterministic rather than dictionary-ordered.
	assert_eq(TradeOffer.signed_order({ore: 7}, {ore: 3}, ore), -7, "the sell wins")

# --- pricing ------------------------------------------------------------------

func test_snapshot_prices_are_used_while_docked() -> void:
	var ore: ResourceData = _resource(&"ore")
	var snapshot: Dictionary = {ore: 42}
	assert_eq(TradeOffer.unit_price(ore, snapshot, 17, true), 42,
		"the visit's snapshot holds while docked")

func test_market_prices_are_used_while_undocked() -> void:
	var ore: ResourceData = _resource(&"ore")
	var snapshot: Dictionary = {ore: 42}
	assert_eq(TradeOffer.unit_price(ore, snapshot, 17, false), 17,
		"the order sheet projects at today's prices")

func test_a_resource_the_snapshot_never_saw_falls_back_to_the_market() -> void:
	var ore: ResourceData = _resource(&"ore")
	assert_eq(TradeOffer.unit_price(ore, {}, 17, true), 17,
		"a missing snapshot must not price the trade at zero")

# --- totals -------------------------------------------------------------------

func test_a_sell_line_earns_at_the_sell_price() -> void:
	# -10 goods out against +120 credits in: the two columns point opposite ways
	# on purpose, and this is the assertion that says so.
	assert_eq(TradeOffer.line_credits(_line(-10, 30, 12)), 120, "10 sold at 12")

func test_a_buy_line_costs_at_the_buy_price() -> void:
	assert_eq(TradeOffer.line_credits(_line(10, 30, 12)), -300, "10 bought at 30")

func test_an_unset_line_moves_nothing() -> void:
	assert_eq(TradeOffer.line_credits(_line(0, 30, 12)), 0, "a zero line is not a trade")

func test_net_across_a_mixed_order_including_a_zero_line() -> void:
	var lines: Array = [_line(-10, 30, 12), _line(4, 25, 9), _line(0, 99, 99), _line(-3, 8, 5)]
	# 10 out at 12 = +120, 4 in at 25 = -100, an unset line, 3 out at 5 = +15.
	assert_eq(TradeOffer.net_credits(lines), 35, "the order nets 35 credits")

func test_the_footer_counts_only_lines_that_were_set() -> void:
	var lines: Array = [_line(-10, 1, 1), _line(4, 1, 1), _line(0, 1, 1)]
	assert_eq(TradeOffer.count_sells(lines), 1, "one sell")
	assert_eq(TradeOffer.count_buys(lines), 1, "one buy")
	assert_string_contains(TradeOffer.summary_text(lines), "2 LINES SET")

func test_an_empty_order_summarises_as_nothing_set() -> void:
	assert_eq(TradeOffer.net_credits([]), 0, "no lines, no credits")
	assert_string_contains(TradeOffer.summary_text([]), "0 LINES SET")

# --- commit shape -------------------------------------------------------------

func test_orders_split_by_sign_as_positive_magnitudes_on_both_sides() -> void:
	var ore: ResourceData = _resource(&"ore")
	var steel: ResourceData = _resource(&"steel")
	var lines: Array = [
		TradeOffer.Line.of(ore, -20, 5, 3),  # 20 ore out
		TradeOffer.Line.of(steel, 8, 11, 6), # 8 steel in
	]
	var sells: Dictionary[ResourceData, int] = TradeOffer.sell_orders(lines)
	var buys: Dictionary[ResourceData, int] = TradeOffer.buy_orders(lines)
	# Both halves are magnitudes: the sign lived in the table, and the split into
	# two dictionaries is what carries the direction from here on.
	assert_eq(sells.get(ore, 0), 20, "the sell drops its sign")
	assert_eq(buys.get(steel, 0), 8, "the buy passes through")
	assert_false(sells.has(steel), "a buy never reaches the sell half")
	assert_false(buys.has(ore), "a sell never reaches the buy half")

func test_unset_lines_are_absent_from_both_halves() -> void:
	var ore: ResourceData = _resource(&"ore")
	var lines: Array = [TradeOffer.Line.of(ore, 0, 5, 3)]
	assert_eq(TradeOffer.sell_orders(lines).size(), 0, "nothing to sell")
	assert_eq(TradeOffer.buy_orders(lines).size(), 0, "nothing to buy")

# --- station-wide AVAIL -------------------------------------------------------

func test_available_sums_across_every_registered_storage() -> void:
	var ore: ResourceData = _resource(&"ore")
	_storage(ore, 30)
	_storage(ore, 12)
	assert_eq(ore.available_unreserved(), 42, "both bins count")

func test_available_excludes_reserved_withdrawals() -> void:
	var ore: ResourceData = _resource(&"ore")
	_storage(ore, 100, 40)
	assert_eq(ore.get_total(true), 100, "HELD is still everything stored")
	assert_eq(ore.available_unreserved(), 60, "AVAIL is what nobody has claimed")

func test_available_is_never_negative() -> void:
	var ore: ResourceData = _resource(&"ore")
	var component: StorageComponent = _storage(ore, 10)
	# A claim outliving the stock it was taken against: legal for a moment, and
	# it must not read as a debt.
	component.storage_data[ore].reserved_withdraw = 25
	assert_eq(ore.available_unreserved(), 0, "clamped at nothing spare")

func test_available_is_zero_for_a_resource_nothing_stores() -> void:
	var ore: ResourceData = _resource(&"ore")
	assert_eq(ore.available_unreserved(), 0, "no storage, nothing available")

func test_a_bins_own_available_matches_its_data() -> void:
	var ore: ResourceData = _resource(&"ore")
	var component: StorageComponent = _storage(ore, 50, 20)
	assert_eq(component.available_to_withdraw(ore), 30, "the component passes it through")
	assert_eq(component.available_to_withdraw(_resource(&"other")), 0,
		"a resource this bin does not handle has none")
