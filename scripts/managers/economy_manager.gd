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

# --- cost toggles (flipped on by WI-26's first ARC inspection) -----------------
var wages_enabled: bool = false
var upkeep_enabled: bool = false
var levy_enabled: bool = false

# --- wages --------------------------------------------------------------------
## Per-cycle wage for a crew pawn = its hire_price * this. Drones/robots (no
## needs, excluded by CrewManager.get_crew) never draw a wage.
@export var wage_fraction: float = 0.1
## One-time severance when firing a pawn = its hire_price * this. Only charged
## while wages are active (no economy yet = firing is free).
@export var severance_fraction: float = 0.5

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
	_current = _new_record(Global.time_manager.cycle)
	Global.time_manager.cycle_changed.connect(_on_cycle_changed)

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

# --- income routing (called by trade/contract payouts) ------------------------

## Records `amount` of gross income under `category`, skims the ARC levy if
## active, and returns the NET the caller should credit. Levy-disabled games get
## the gross back untouched. Call sites MUST credit the return value, never
## re-read the gross (WI-25 edge case).
func record_income(amount: int, category: StringName) -> int:
	if amount <= 0:
		return amount
	_current["income"][category] = int(_current["income"].get(category, 0)) + amount
	var skim: int = skim_for(amount, levy_fraction) if levy_enabled else 0
	if skim > 0:
		_add_cost(&"levy_skim", skim)
	_emit_changed()
	return amount - skim

## Records a cost the caller has ALREADY applied to the credit balance (contract
## penalties, event credit deltas) so it shows on the economy page. Unlike a
## levy charge this never touches credits and never refunds levy (losses aren't
## negative income - WI-25 edge case).
func record_external_cost(amount: int, category: StringName) -> void:
	if amount <= 0:
		return
	_add_cost(category, amount)
	_emit_changed()

## Books an event's credit swing (EventEffectCreditDelta) on the ledger without
## touching the levy either way: a loss is an &"event" cost, a windfall is
## &"event" income, but neither is levy-eligible (WI-25 edge case). The caller
## has already applied the delta to the balance.
func record_event_delta(amount: int) -> void:
	if amount < 0:
		_add_cost(&"event", -amount)
	elif amount > 0:
		_current["income"][&"event"] = int(_current["income"].get(&"event", 0)) + amount
	_emit_changed()

# --- per-cycle settlement -----------------------------------------------------

## Ends the just-completed cycle: charges the fixed cost streams in the
## documented order (loan -> wages -> upkeep -> levy fee), rolls the ledger, then
## re-evaluates insolvency against the resulting balance. Suppressed while a save
## loads - TimeManager.load_save_data replays cycle_changed, which must not
## re-charge a cycle that already settled before the save.
func _on_cycle_changed(new_cycle: int) -> void:
	if SaveManager.is_loading():
		return
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

func _charge_wages() -> void:
	if not wages_enabled:
		return
	var total: int = 0
	# include_leaving = false: a fired/resigned pawn walking to the bay stops
	# costing from the next cycle tick (WI-25 fire flow).
	for pawn: PawnBase in Global.crew_manager.get_crew(false):
		total += wage_for(pawn.hire_price, wage_fraction)
	if total > 0:
		_charge(&"wages", total)

func _charge_upkeep() -> void:
	if not upkeep_enabled:
		return
	var total: int = 0
	for node: Node in get_tree().get_nodes_in_group("module"):
		var module: ModuleBase = node as ModuleBase
		# Built modules only - blueprints and truss placeholders are free.
		if module == null or module.module_data == null or not module.is_complete():
			continue
		total += module.module_data.upkeep_per_cycle
	if total > 0:
		_charge(&"upkeep", total)

func _charge_levy_fee(cycle: int) -> void:
	if not levy_enabled or levy_fee_cycles <= 0:
		return
	if cycle % levy_fee_cycles != 0:
		return
	if levy_fee_amount > 0:
		_charge(&"levy_fee", levy_fee_amount)

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
	SignalBus.station_alert.emit("ARC settlement: -%d cr (%s)" % [total, ", ".join(parts)])

func _finalize_current(new_cycle: int) -> void:
	_history.append(_current)
	while _history.size() > ledger_history:
		_history.pop_front()
	_current = _new_record(new_cycle)
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
			SignalBus.station_alert.emit(
				"ARC DEMANDS PAYMENT: clear your debt within %d cycles or the station is repossessed." % grace_cycles)
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
	SignalBus.station_alert.emit("ARC loan approved: +%d cr now, repaying %d cr over %d cycles." %
		[principal, loan_remaining, loan_payments_left])
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
	SignalBus.station_alert.emit("ARC loan repaid in full (-%d cr)." % owed)
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
func fire_pawn(pawn: PawnBase) -> void:
	if pawn == null or not is_instance_valid(pawn):
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
func wage_breakdown() -> Dictionary:
	var out: Dictionary = {}
	for pawn: PawnBase in Global.crew_manager.get_crew(false):
		out[pawn] = wage_for(pawn.hire_price, wage_fraction)
	return out

## Upkeep the built station would draw next cycle: {module: upkeep} for display.
func upkeep_breakdown() -> Dictionary:
	var out: Dictionary = {}
	for node: Node in get_tree().get_nodes_in_group("module"):
		var module: ModuleBase = node as ModuleBase
		if module == null or module.module_data == null or not module.is_complete():
			continue
		if module.module_data.upkeep_per_cycle > 0:
			out[module] = module.module_data.upkeep_per_cycle
	return out

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
	_current["costs"][category] = int(_current["costs"].get(category, 0)) + amount

func _emit_changed() -> void:
	SignalBus.economy_changed.emit()

## Human-readable category names shared by the settlement alert and the UI.
static func category_label(category: StringName) -> String:
	match category:
		&"wages": return "Wages"
		&"upkeep": return "Upkeep"
		&"levy_fee": return "ARC fee"
		&"levy_skim": return "ARC levy"
		&"loan_payment": return "Loan"
		&"severance": return "Severance"
		&"penalty": return "Penalty"
		&"event": return "Event"
		&"trade": return "Trade"
		&"contract": return "Contracts"
		_: return String(category).capitalize()

func _category_label(category: StringName) -> String:
	return category_label(category)

# --- persistence --------------------------------------------------------------

func get_save_data() -> Dictionary:
	return {
		"wages_enabled": wages_enabled,
		"upkeep_enabled": upkeep_enabled,
		"levy_enabled": levy_enabled,
		"current": _record_to_save(_current),
		"history": _history.map(_record_to_save),
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
	_current = _record_from_save(data.get("current", {}), Global.time_manager.cycle)
	_history.clear()
	for entry: Dictionary in data.get("history", []):
		_history.append(_record_from_save(entry, 0))
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
## String, so convert on the way in and out.
func _record_to_save(record: Dictionary) -> Dictionary:
	return {
		"cycle": int(record.get("cycle", 0)),
		"income": _string_keys(record.get("income", {})),
		"costs": _string_keys(record.get("costs", {})),
	}

func _record_from_save(data: Dictionary, fallback_cycle: int) -> Dictionary:
	return {
		"cycle": int(data.get("cycle", fallback_cycle)),
		"income": _stringname_keys(data.get("income", {})),
		"costs": _stringname_keys(data.get("costs", {})),
	}

func _string_keys(source: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in source:
		out[String(key)] = int(source[key])
	return out

func _stringname_keys(source: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in source:
		out[StringName(String(key))] = int(source[key])
	return out
