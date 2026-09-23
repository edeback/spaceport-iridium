class_name EconomyManager
extends Node

## Recurring economic sinks (WI-25): crew wages, per-module upkeep, the ARC levy
## (an income skim plus a periodic flat fee), player loans, and the bankruptcy
## arc. Registers as Global.economy_manager after ResourceManager/MarketManager
## in main.tscn's Managers node.
##
## All three cost streams start OFF and stay off until WI-26's first ARC
## inspection flips them on; a debug toggle (Cheats.set_economy_costs) covers the
## gap while WI-26 is unbuilt. Income is ALWAYS recorded in the ledger regardless
## of the toggles, so the economy page has data to show from cycle 1.
##
## Charge order on cycle_changed is fixed and documented so the ledger reads
## deterministically: loan -> wages -> upkeep -> levy fee. Insolvency is measured
## AFTER every charge, so a loan draft that itself drives the balance negative is
## judged against the true end-of-cycle balance (WI-25 edge case).
##
## The ledger is the single source of truth for the UI: every income skim and
## every charge writes it, and the economy page is a pure view over it.

## Who the Comms log says the money messages are from (WI-57). Shared with
## [InspectionRunner] so ARC is one correspondent in the feed rather than two.
const ARC_SENDER: String = InspectionRunner.ARC_SENDER

# --- ledger categories (WI-68 F4) ---------------------------------------------
# A category is declared or it does not exist - the same rule as Groups, UIType
# and StoryFlags. The Finance tab used to keep its own display lists and summed
# only what they named, so a cost booked under anything else vanished from "Net"
# although it had really left the balance - and trade purchases, raid payoffs and
# hire fees weren't booked at all. These lists are the display order too.

## Costs, in the order the Finance tab lists them. The first four are the
## settlement streams (loan -> wages -> upkeep -> levy fee, the charge order).
const COST_CATEGORIES: Array[StringName] = [
	&"loan_payment", &"wages", &"upkeep", &"levy_fee", &"levy_skim", &"severance",
	&"hiring", &"trade_purchases", &"raid_payoff", &"penalty", &"event",
]
## Income, in display order. `event` is in both lists: a windfall and a loss.
const INCOME_CATEGORIES: Array[StringName] = [
	&"trade", &"contract", &"shops", &"hotels", &"dining", &"refunds", &"event",
]
## Every declared category's display name. Ids are what the saved ledger history
## stores, so an id never changes - only its label may (`trade` reads "Sales"
## now that purchases have a line of their own).
const CATEGORY_LABELS: Dictionary[StringName, String] = {
	&"loan_payment": "Loan",
	&"wages": "Wages",
	&"upkeep": "Upkeep",
	&"levy_fee": "ARC fee",
	&"levy_skim": "ARC levy",
	&"severance": "Severance",
	&"hiring": "Hiring",
	&"trade_purchases": "Purchases",
	&"raid_payoff": "Pirate ransom",
	&"penalty": "Penalty",
	&"event": "Event",
	&"trade": "Sales",
	&"contract": "Contracts",
	# Visitor economy (WI-33): shop sales, hotel nights, and paid meals.
	&"shops": "Shops",
	&"hotels": "Hotels",
	&"dining": "Dining",
	&"refunds": "Refunds",
}
## Income booked when money spent earlier comes back (a hire whose bay vanished
## before the shuttle landed). Income rather than a negative cost: a refund can
## land cycles after its charge, and a negative cost line would read as nonsense.
const REFUND_CATEGORY: StringName = &"refunds"
## Record keys for the balance at either end of a cycle, which is what lets the
## Finance tab show the real change beside the operating net (WI-68 F4). Optional:
## a record from a save that predates them simply has neither.
const OPENING_BALANCE: String = "opening_balance"
const CLOSING_BALANCE: String = "closing_balance"

# --- cost toggles (flipped on by WI-26's first ARC inspection) -----------------
var wages_enabled: bool = false
var upkeep_enabled: bool = false
var levy_enabled: bool = false

# --- wages --------------------------------------------------------------------
## Per-cycle wage for a crew pawn = its hire_price * this. Drones/robots (no
## needs, excluded by CrewManager.get_crew) never draw a wage.
##
## A const as well as an export because WI-59's New Game setup screen quotes each
## candidate's wage on its card, and it runs in the menu scene where no
## EconomyManager exists to read the export off. main.tscn does not override the
## export, so the const is the truth; anything that tunes it should tune the
## const so both sides move together.
const DEFAULT_WAGE_FRACTION: float = 0.05
@export var wage_fraction: float = DEFAULT_WAGE_FRACTION
## One-time severance when firing a pawn = its hire_price * this. Only charged
## while wages are active (no economy yet = firing is free).
@export var severance_fraction: float = 0.2

# --- ARC levy -----------------------------------------------------------------
## Fraction of every recorded income ARC skims immediately (0.1 = 10% off the
## top). The player only ever receives the net; the skim is never credited.
@export var levy_fraction: float = 0.1
## A flat ARC fee lands every this-many cycles (charged when cycle % this == 0).
@export var levy_fee_cycles: int = 4
@export var levy_fee_amount: int = 200

# --- loans --------------------------------------------------------------------
## Selectable principal tiers on the economy page / insolvency card.
@export var loan_principal_tiers: Array[int] = [1000, 2500, 5000]
## Total interest as a fraction of principal (0.2 = repay 120% of principal).
@export var loan_interest_fraction: float = 0.2
## Cycles the auto-drafted repayment is spread across.
@export var loan_term_cycles: int = 10

# --- bankruptcy ---------------------------------------------------------------
## Consecutive insolvent (balance < 0) cycles before ARC issues its repossession
## warning + loan-offer card.
@export var warning_cycles: int = 3
## Cycles between the warning and repossession (game over) if still insolvent.
@export var grace_cycles: int = 3
## The insolvency warning card fired when the warning lands (weight-0 event, so
## it only ever fires here, never on a natural roll).
@export var insolvency_event_id: StringName = &"insolvency_warning"

# --- ledger -------------------------------------------------------------------
## How many finalized past-cycle records to retain for the economy page.
@export var ledger_history: int = 12

## The cycle currently accumulating income/skims; costs are written into it at
## its settlement (the cycle_changed that ends it). See _new_record.
var _current: Dictionary = {}
## Finalized past cycles, chronological (oldest first). last() = most recent.
var _history: Array[Dictionary] = []
## True once a save has supplied _current, so the bootstrap stamp leaves it be:
## a record from a pre-WI-68 save has no opening balance and must stay without
## one rather than be stamped "since the load", which would be a lie.
var _record_restored: bool = false

# --- loan runtime state -------------------------------------------------------
var loan_active: bool = false
var loan_remaining: int = 0     # credits still owed (principal + interest)
var loan_payment: int = 0       # per-cycle auto-draft
var loan_payments_left: int = 0

# --- bankruptcy runtime state -------------------------------------------------
var insolvent_cycles: int = 0
var warning_issued: bool = false
var _game_over_fired: bool = false

func _ready() -> void:
	Global.economy_manager = self
	# After resources: the ledger/loan/insolvency counters restore against the
	# restored balances. No phantom settlement fires - time's restore above
	# announces the calendar rather than replaying cycle_changed (WI-38 A3).
	SaveManager.register_section(&"economy", SaveManager.SECTION_ORDER[&"economy"], get_save_data, load_save_data)
	_current = _new_record(Global.time_manager.cycle)
	Global.time_manager.cycle_changed.connect(_on_cycle_changed)
	SignalBus.game_bootstrapped.connect(_on_game_bootstrapped)

## Hands the slot back (WI-71 §7). Godot 4.7 reports a freed object as `== null`,
## so the guards around the game already take their null branch after a Quit to
## Menu - but `is_instance_valid(Global.economy_manager)` and the debugger both lie until
## the slot is actually cleared. `== self` because a second scene can register
## before this one leaves.
func _exit_tree() -> void:
	if Global.economy_manager == self:
		Global.economy_manager = null

## A new game's first cycle opens with the starting balance. Stamped here and not
## in _ready: this manager readies before SaveManager resets the credit totals,
## so _ready would read 0 - or, after Quit to Menu, the previous run's balance.
func _on_game_bootstrapped() -> void:
	if not _record_restored and not _current.has(OPENING_BALANCE):
		_current[OPENING_BALANCE] = _balance()

# --- pure helpers (unit-tested without Global/SignalBus, WI-19) ----------------

## ARC's cut of a gross income amount. Floors so the player never loses more than
## the stated fraction to rounding.
static func skim_for(gross: int, levy_fraction_: float) -> int:
	if gross <= 0 or levy_fraction_ <= 0.0:
		return 0
	return int(floor(float(gross) * levy_fraction_))

## What the player actually banks from a gross income after the levy skim.
static func net_income(gross: int, levy_fraction_: float) -> int:
	return gross - skim_for(gross, levy_fraction_)

## One pawn's per-cycle wage from its hire price.
static func wage_for(hire_price: int, wage_fraction_: float) -> int:
	return int(round(float(hire_price) * wage_fraction_))

## A recurring charge scaled by the difficulty's upkeep multiplier (WI-37).
## Rounds, then floors at 1 credit so a merely-cheap multiplier (0.6x on a 1-credit
## upkeep) can't round a real cost away to nothing. A multiplier of exactly 0 is
## read as the deliberate "this stream is free here" and does return 0.
static func scaled_cost(amount: int, multiplier: float) -> int:
	if amount <= 0 or multiplier <= 0.0:
		return 0
	return maxi(int(round(float(amount) * multiplier)), 1)

## Total a loan repays: principal plus flat interest.
static func loan_total(principal: int, interest_fraction: float) -> int:
	return int(round(float(principal) * (1.0 + interest_fraction)))

## The per-cycle repayment schedule for a loan: a list of `term_cycles`-ish
## payments that sum EXACTLY to loan_total(principal, interest_fraction). Front
## payments take the ceil share; the final payment absorbs the rounding
## remainder so the sum is exact (the "totals principal x 1.2" guarantee).
static func loan_schedule(principal: int, interest_fraction: float, term_cycles: int) -> Array[int]:
	var out: Array[int] = []
	var total: int = loan_total(principal, interest_fraction)
	var term: int = maxi(term_cycles, 1)
	var base_pay: int = int(ceil(float(total) / float(term)))
	var remaining: int = total
	for i: int in term:
		var pay: int = mini(base_pay, remaining)
		if i == term - 1:
			pay = remaining  # last payment clears any rounding remainder
		out.append(pay)
		remaining -= pay
		if remaining <= 0:
			break
	return out

## Whether `category` is declared on the cost side (`costs` true) or the income
## side of the ledger.
static func is_declared(category: StringName, costs: bool) -> bool:
	return (COST_CATEGORIES if costs else INCOME_CATEGORIES).has(category)

## Adds `amount` under `category` to one side of a ledger record ("costs" or
## "income"). An undeclared category is an authoring error and says so - but is
## still booked, because the money really moved: refusing it would recreate the
## very bug the declaration exists to prevent (WI-68 F4).
static func add_to_record(record: Dictionary, side: String, category: StringName, amount: int) -> void:
	if not is_declared(category, side == "costs"):
		push_error("EconomyManager: undeclared %s category '%s' - add it to %s and CATEGORY_LABELS"
			% [side, category, "COST_CATEGORIES" if side == "costs" else "INCOME_CATEGORIES"])
	var bucket: Dictionary = record.get_or_add(side, {})
	bucket[category] = int(bucket.get(category, 0)) + amount

## Income minus costs for one record, over EVERY category it holds, declared or
## not - so nothing booked can fall out of the total.
static func record_net(record: Dictionary) -> int:
	var net: int = 0
	var income: Dictionary = record.get("income", {})
	for category: Variant in income:
		net += int(income[category])
	var costs: Dictionary = record.get("costs", {})
	for category: Variant in costs:
		net -= int(costs[category])
	return net

## Whether a record knows the balance it opened with. A record from a save that
## predates WI-68, or the cycle in progress when such a save was loaded, doesn't.
static func knows_balance_change(record: Dictionary) -> bool:
	return record.has(OPENING_BALANCE)

## How far the balance moved across a record's cycle: its closing balance, or
## `live_balance` for the cycle still in progress, minus its opening balance.
## Unlike record_net this counts everything - building, research, upgrades and
## loans included - which is why the Finance tab shows both.
static func balance_change(record: Dictionary, live_balance: int) -> int:
	var closing: int = int(record.get(CLOSING_BALANCE, live_balance))
	return closing - int(record.get(OPENING_BALANCE, closing))

# --- cost activation (WI-26) --------------------------------------------------

## Switches on wages, upkeep, and the ARC levy together. Called by UnlockManager
## the first time the station passes an ARC inspection (tier 1 -> 2); the debug
## Cheats.set_economy_costs covers the same flip. Idempotent - a no-op once the
## streams are already live (a loaded higher-tier save restores them enabled).
func enable_recurring_costs() -> void:
	if wages_enabled and upkeep_enabled and levy_enabled:
		return
	wages_enabled = true
	upkeep_enabled = true
	levy_enabled = true
	AlertManager.transmit(&"levy_enabled", AlertData.Priority.HIGH, "ARC levy is now in force",
		"Wages, upkeep and a profit tax on your promoted station",
		&"finance", ARC_SENDER,
		("A promoted station carries its own weight. From this cycle we draft wages,"
			+ " module upkeep and %d%% of every credit you earn.")
			% int(round(levy_fraction * 100.0)),
		&"comms")
	_emit_changed()

# --- income routing (called by trade/contract payouts) ------------------------

## Records `amount` of gross income under `category`, skims the ARC levy if
## active, and returns the NET the caller should credit. Levy-disabled games get
## the gross back untouched. Call sites MUST credit the return value, never
## re-read the gross (WI-25 edge case).
func record_income(amount: int, category: StringName) -> int:
	if amount <= 0:
		return amount
	add_to_record(_current, "income", category, amount)
	var skim: int = skim_for(amount, levy_fraction) if levy_enabled else 0
	if skim > 0:
		_add_cost(&"levy_skim", skim)
	_emit_changed()
	return amount - skim

## Records a cost the caller has ALREADY applied to the credit balance (contract
## penalties, trade purchases, raid payoffs, hire fees) so it shows on the
## economy page. Unlike a levy charge this never touches credits and never
## refunds levy (losses aren't negative income - WI-25 edge case).
func record_external_cost(amount: int, category: StringName) -> void:
	if amount <= 0:
		return
	_add_cost(category, amount)
	_emit_changed()

## Books money coming back that was spent earlier - a hire refunded because its
## bay was gone before the shuttle landed (WI-68 F4). The caller has already
## credited the balance. Income, but never through record_income: the levy
## skims earnings, and a refund of the player's own money isn't one.
func record_refund(amount: int) -> void:
	if amount <= 0:
		return
	add_to_record(_current, "income", REFUND_CATEGORY, amount)
	_emit_changed()

## Books an event's credit swing (EventEffectCreditDelta) on the ledger without
## touching the levy either way: a loss is an &"event" cost, a windfall is
## &"event" income, but neither is levy-eligible (WI-25 edge case). The caller
## has already applied the delta to the balance.
func record_event_delta(amount: int) -> void:
	if amount < 0:
		_add_cost(&"event", -amount)
	elif amount > 0:
		add_to_record(_current, "income", &"event", amount)
	_emit_changed()

# --- per-cycle settlement -----------------------------------------------------

## Ends the just-completed cycle: charges the fixed cost streams in the
## documented order (loan -> wages -> upkeep -> levy fee), rolls the ledger, then
## re-evaluates insolvency against the resulting balance. No is_loading() guard is
## needed: TimeManager.load_save_data no longer replays cycle_changed (WI-38 A3),
## so a load can't re-charge a cycle that already settled before the save.
func _on_cycle_changed(new_cycle: int) -> void:
	var before: int = _balance()
	_charge_loan_payment()
	_charge_wages()
	_charge_upkeep()
	_charge_levy_fee(new_cycle)
	_announce_settlement(before)
	_finalize_current(new_cycle)
	_update_insolvency()

func _charge_loan_payment() -> void:
	if not loan_active:
		return
	var pay: int = loan_remaining if loan_payments_left <= 1 else mini(loan_payment, loan_remaining)
	if pay > 0:
		_charge(&"loan_payment", pay)
	loan_remaining -= pay
	loan_payments_left -= 1
	if loan_remaining <= 0 or loan_payments_left <= 0:
		_clear_loan()

## The difficulty's cost dial (WI-37), read lazily at charge time rather than
## cached in _ready: Global.difficulty is staged before the scene either way, but
## reading it here keeps this manager independent of Managers/ ready order.
func upkeep_multiplier() -> float:
	return Global.difficulty_upkeep_multiplier()

func _charge_wages() -> void:
	if not wages_enabled:
		return
	var total: int = 0
	# include_leaving = false: a fired/resigned pawn walking to the bay stops
	# costing from the next cycle tick (WI-25 fire flow).
	for pawn: PawnBase in Global.crew_manager.get_crew(false):
		var wage: int = wage_for_pawn(pawn)
		if wage > 0:
			# WI-33: the wage no longer vanishes - it lands in the pawn's wallet, to
			# be spent at shops (returning to income, taxed once at the register).
			# The station still pays it in full, so wages stay a real sink.
			pawn.earn_credits(wage)
			total += wage
	if total > 0:
		_charge(&"wages", total)

## One pawn's per-cycle wage at the current difficulty (WI-37). The single place
## the scaled figure is computed, so the charge, the pawn's wallet credit, and the
## economy page's breakdown can never disagree.
func wage_for_pawn(pawn: PawnBase) -> int:
	if pawn == null:
		return 0
	return scaled_cost(wage_for(pawn.hire_price, wage_fraction), upkeep_multiplier())

func _charge_upkeep() -> void:
	if not upkeep_enabled:
		return
	var total: int = 0
	for node: Node in get_tree().get_nodes_in_group(Groups.MODULE):
		var module: ModuleBase = node as ModuleBase
		# Built modules only - blueprints and truss placeholders are free.
		if module == null or module.module_data == null or not module.is_complete():
			continue
		total += module.module_data.upkeep_per_cycle
	# Scaled once on the total, not per module: rounding each module separately
	# would drift the station-wide bill away from the advertised multiplier.
	total = scaled_cost(total, upkeep_multiplier())
	if total > 0:
		_charge(&"upkeep", total)

func _charge_levy_fee(cycle: int) -> void:
	if not levy_enabled or levy_fee_cycles <= 0:
		return
	if cycle % levy_fee_cycles != 0:
		return
	var fee: int = scaled_cost(levy_fee_amount, upkeep_multiplier())
	if fee > 0:
		_charge(&"levy_fee", fee)

## Withdraws `amount` credits (driving the balance negative if need be - charges
## always apply in full) and records the cost against the current cycle.
func _charge(category: StringName, amount: int) -> void:
	if amount <= 0:
		return
	Global.resource_manager.credit_resource.change_global_total(-amount)
	_add_cost(category, amount)

## One combined settlement alert, never four (WI-25 edge case). Only fires when
## the cycle actually charged something.
func _announce_settlement(balance_before: int) -> void:
	var costs: Dictionary = _current["costs"]
	var total: int = 0
	var parts: Array[String] = []
	for category: StringName in [&"loan_payment", &"wages", &"upkeep", &"levy_fee"]:
		var value: int = int(costs.get(category, 0))
		if value > 0:
			total += value
			parts.append("%s %d" % [_category_label(category), value])
	if total <= 0:
		return
	# The settlement is the one recurring transmission, and it is the reason the log
	# has a cap: a station that runs for forty cycles gets forty of these, and they
	# are exactly what a bounded ring buffer is for.
	AlertManager.transmit(&"arc_settlement", AlertData.Priority.HIGH, "ARC settlement",
		"-%d cr · %s" % [total, ", ".join(parts)],
		&"finance", ARC_SENDER,
		"Drafted %d credits this cycle: %s. Balance after settlement: %d cr."
			% [total, ", ".join(parts), balance_before - total],
		&"comms")

func _finalize_current(new_cycle: int) -> void:
	# After the settlement charges, so the cycle that just ended closes on what
	# they left and the next one opens on the same figure.
	var balance_now: int = _balance()
	_current[CLOSING_BALANCE] = balance_now
	_history.append(_current)
	while _history.size() > ledger_history:
		_history.pop_front()
	_current = _new_record(new_cycle)
	_current[OPENING_BALANCE] = balance_now
	_emit_changed()

# --- bankruptcy ---------------------------------------------------------------

## Accrues insolvency while the balance is negative, warns (+ offers a loan) at
## warning_cycles, and repossesses the station at warning_cycles + grace_cycles.
## Recovering to a non-negative balance at any point resets the whole arc.
func _update_insolvency() -> void:
	if _game_over_fired:
		return
	if _balance() >= 0:
		if insolvent_cycles > 0 or warning_issued:
			insolvent_cycles = 0
			warning_issued = false
			_emit_changed()
		return
	insolvent_cycles += 1
	if not warning_issued:
		if insolvent_cycles >= warning_cycles:
			warning_issued = true
			# CRITICAL (WI-53): this is the step before `game_over`, and the whole
			# grace window can elapse while the player is doing something else.
			AlertManager.transmit(&"bankruptcy", AlertData.Priority.CRITICAL,
				"ARC demands payment",
				"Clear your debt within %d cycles or the station is repossessed" % grace_cycles,
				&"finance", ARC_SENDER,
				("Your account has been in arrears for %d cycles. Return it to credit within"
					+ " %d, or the Corporation exercises its right of repossession.")
					% [insolvent_cycles, grace_cycles],
				&"comms")
			_offer_insolvency_card()
	elif insolvent_cycles >= warning_cycles + grace_cycles:
		_game_over_fired = true
		SignalBus.game_over.emit("ARC has repossessed the station to recover its unpaid debts.")
	_emit_changed()

## Fires the insolvency warning/loan-offer card through EventManager. The event
## is weight 0 so it never turns up on a natural roll - this explicit fire is its
## only trigger. Guarded so a missing definition just falls back to the alert.
func _offer_insolvency_card() -> void:
	if Global.event_manager == null:
		return
	Global.event_manager.fire_event_by_id(insolvency_event_id)

# --- loans --------------------------------------------------------------------

## "" if a loan can be taken; otherwise a player-facing reason.
func loan_block_reason() -> String:
	return "A loan is already active" if loan_active else ""

## Takes a loan: credits the principal now and schedules the +interest repayment
## across loan_term_cycles, auto-drafted ahead of other costs each cycle. One
## loan at a time. Returns false (unchanged) if a loan is already active.
func take_loan(principal: int) -> bool:
	if loan_active or principal <= 0:
		return false
	loan_active = true
	loan_remaining = loan_total(principal, loan_interest_fraction)
	loan_payments_left = maxi(loan_term_cycles, 1)
	loan_payment = int(ceil(float(loan_remaining) / float(loan_payments_left)))
	Global.resource_manager.credit_resource.change_global_total(principal)
	AlertManager.transmit(&"loan_approved", AlertData.Priority.HIGH, "ARC loan approved",
		"+%d cr now · repaying %d cr over %d cycles" % [principal, loan_remaining, loan_payments_left],
		&"finance", ARC_SENDER,
		("%d credits advanced against the station. We draft %d a cycle for %d cycles;"
			+ " the schedule is not negotiable.")
			% [principal, loan_payment, loan_payments_left],
		&"comms")
	_emit_changed()
	return true

## Clears the whole outstanding balance immediately (may drive credits negative).
func repay_loan_early() -> bool:
	if not loan_active:
		return false
	var owed: int = loan_remaining
	if owed > 0:
		_charge(&"loan_payment", owed)
	_clear_loan()
	AlertManager.transmit(&"loan_repaid", AlertData.Priority.HIGH, "ARC loan repaid",
		"Cleared in full · -%d cr" % owed,
		&"finance", ARC_SENDER,
		"Your account is settled. %d credits cleared the outstanding balance." % owed,
		&"comms")
	_emit_changed()
	return true

func _clear_loan() -> void:
	loan_active = false
	loan_remaining = 0
	loan_payment = 0
	loan_payments_left = 0

# --- firing -------------------------------------------------------------------

## The severance owed to fire `pawn` right now (0 when wages are inactive).
func severance_for(pawn: PawnBase) -> int:
	if not wages_enabled or pawn == null:
		return 0
	return int(round(float(pawn.hire_price) * severance_fraction))

## Fires `pawn`: charges severance (if any) then routes the departure through
## CrewManager's non-morale fire flow. Fired pawns stop drawing wages next cycle.
##
## The one caller is the inspector's FIRE confirmation, which checks the pawn it
## captured before the dialog opened - the discipline a captured reference owes
## a typed parameter (WI-71 §2c).
func fire_pawn(pawn: PawnBase) -> void:
	if pawn == null:
		return
	var severance: int = severance_for(pawn)
	if severance > 0:
		_charge(&"severance", severance)
		_emit_changed()
	Global.crew_manager.fire_crew(pawn)

# --- ledger access (for the economy page) -------------------------------------

func current_record() -> Dictionary:
	return _current

func last_record() -> Dictionary:
	return _history.back() if not _history.is_empty() else {}

func history() -> Array[Dictionary]:
	return _history

func balance() -> int:
	return _balance()

## Wages the current roster would draw next cycle: {pawn: wage} for display.
## Difficulty-scaled, matching what _charge_wages will actually take.
func wage_breakdown() -> Dictionary:
	var out: Dictionary = {}
	for pawn: PawnBase in Global.crew_manager.get_crew(false):
		out[pawn] = wage_for_pawn(pawn)
	return out

## Upkeep the built station would draw next cycle: {module: upkeep} for display.
## Per-module rows stay at their base cost - the difficulty multiplier applies to
## the bill as a whole (see _charge_upkeep), so it belongs on the total rather
## than smeared across rows that would no longer sum to it.
func upkeep_breakdown() -> Dictionary:
	var out: Dictionary = {}
	for node: Node in get_tree().get_nodes_in_group(Groups.MODULE):
		var module: ModuleBase = node as ModuleBase
		if module == null or module.module_data == null or not module.is_complete():
			continue
		if module.module_data.upkeep_per_cycle > 0:
			out[module] = module.module_data.upkeep_per_cycle
	return out

## What the whole upkeep bill comes to next cycle at the current difficulty - the
## figure the economy page should show as the row total for upkeep_breakdown().
func upkeep_total() -> int:
	var base: int = 0
	var rows: Dictionary = upkeep_breakdown()
	for module: Variant in rows:
		base += int(rows[module])
	return scaled_cost(base, upkeep_multiplier())

# --- internals ----------------------------------------------------------------

func _balance() -> int:
	return Global.resource_manager.credit_resource.get_total()

func _new_record(cycle: int) -> Dictionary:
	return {
		"cycle": cycle,
		"income": {} as Dictionary,
		"costs": {} as Dictionary,
	}

func _add_cost(category: StringName, amount: int) -> void:
	add_to_record(_current, "costs", category, amount)

func _emit_changed() -> void:
	SignalBus.economy_changed.emit()

## Human-readable category names shared by the settlement alert and the UI. The
## capitalised fallback only ever shows for an undeclared category, which
## add_to_record has already reported.
static func category_label(category: StringName) -> String:
	return CATEGORY_LABELS.get(category, String(category).capitalize())

func _category_label(category: StringName) -> String:
	return category_label(category)

# --- persistence --------------------------------------------------------------

func get_save_data() -> Dictionary:
	return {
		"wages_enabled": wages_enabled,
		"upkeep_enabled": upkeep_enabled,
		"levy_enabled": levy_enabled,
		"current": record_to_save(_current),
		"history": _history.map(record_to_save),
		"loan": {
			"active": loan_active,
			"remaining": loan_remaining,
			"payment": loan_payment,
			"payments_left": loan_payments_left,
		},
		"insolvent_cycles": insolvent_cycles,
		"warning_issued": warning_issued,
		"game_over_fired": _game_over_fired,
	}

func load_save_data(data: Dictionary) -> void:
	wages_enabled = bool(data.get("wages_enabled", false))
	upkeep_enabled = bool(data.get("upkeep_enabled", false))
	levy_enabled = bool(data.get("levy_enabled", false))
	_current = record_from_save(data.get("current", {}), Global.time_manager.cycle)
	_record_restored = true
	_history.clear()
	for entry: Dictionary in data.get("history", []):
		_history.append(record_from_save(entry, 0))
	var loan: Dictionary = data.get("loan", {})
	loan_active = bool(loan.get("active", false))
	loan_remaining = int(loan.get("remaining", 0))
	loan_payment = int(loan.get("payment", 0))
	loan_payments_left = int(loan.get("payments_left", 0))
	insolvent_cycles = int(data.get("insolvent_cycles", 0))
	# Restore the warned state WITHOUT re-firing the card (WI-25 edge case:
	# save/load mid-grace shouldn't re-pop the warning).
	warning_issued = bool(data.get("warning_issued", false))
	_game_over_fired = bool(data.get("game_over_fired", false))
	_emit_changed()

## Ledger records store category keys as StringName; JSON round-trips them as
## String, so convert on the way in and out. Static (and pure) so the round trip
## is testable. The two balance stamps are optional: absent stays absent, which
## is what keeps a pre-WI-68 record from growing a made-up opening balance.
static func record_to_save(record: Dictionary) -> Dictionary:
	var out: Dictionary = {
		"cycle": int(record.get("cycle", 0)),
		"income": _string_keys(record.get("income", {})),
		"costs": _string_keys(record.get("costs", {})),
	}
	for key: String in [OPENING_BALANCE, CLOSING_BALANCE]:
		if record.has(key):
			out[key] = int(record[key])
	return out

static func record_from_save(data: Dictionary, fallback_cycle: int) -> Dictionary:
	var out: Dictionary = {
		"cycle": int(data.get("cycle", fallback_cycle)),
		"income": _stringname_keys(data.get("income", {})),
		"costs": _stringname_keys(data.get("costs", {})),
	}
	for key: String in [OPENING_BALANCE, CLOSING_BALANCE]:
		if data.has(key):
			out[key] = int(data[key])
	return out

static func _string_keys(source: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in source:
		out[String(key)] = int(source[key])
	return out

static func _stringname_keys(source: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in source:
		out[StringName(String(key))] = int(source[key])
	return out
