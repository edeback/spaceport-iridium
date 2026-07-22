class_name Job_Shop
extends JobBase

## Paid recreation (WI-33): a pawn with a recreation need AND a wallet visits a
## reachable open shop it can afford, pays the register once (wallet -> station
## income "shops", levy applies), then restores recreation over the visit like
## Job_Recreate. Personal-queue NEEDS job, never on the shared board. Used by both
## crew (spending routed wages) and visitors (spending their arrival funds).
##
## Mirrors Job_Recreate's provider-fallback structure, but gathers from the "shop"
## group with an affordability gate so a customer never walks somewhere it can't
## pay. If the chosen shop fills up / closes / becomes unreachable before commit,
## it falls back to the rest of the affordable pool before failing.

var pawn: PawnBase
var shop: ShopComponent
var stay_hours: float = 0.0
## The price rolled for this visit, charged on arrival (clamped to the wallet so a
## customer that dipped below it still completes - going broke is not a failure).
var _price: int = 0
var _paid: bool = false
## Leave even if not fully restored, so a customer doesn't camp the store all cycle.
@export var max_stay_hours: float = 3.0

var _tried: Array[ShopComponent] = []

enum ShopState { Starting, Moving, Shopping, Finished, Failed }
var state: ShopState = ShopState.Starting:
	set(new_state):
		if new_state != state:
			state = new_state
			subtask_changed.emit()

func get_category() -> Category:
	return Category.NEEDS

func get_job_description() -> String:
	return "Visiting the shops"

func get_subtask_description() -> String:
	match state:
		ShopState.Moving:
			return "Heading to a shop"
		ShopState.Shopping:
			return "Shopping"
	return ""

func can_do_job(_pawn: PawnBase) -> bool:
	return not _gather_candidates(_pawn).is_empty()

func start_job(_pawn: PawnBase) -> void:
	pawn = _pawn
	SignalBus.module_removed.connect(_module_removed)
	_try_next_shop()

func _try_next_shop() -> void:
	var candidates: Array[ShopComponent] = _gather_candidates(pawn)
	for tried: ShopComponent in _tried:
		candidates.erase(tried)
	if candidates.is_empty():
		cancel(true)
		return
	shop = candidates.pick_random()
	_tried.append(shop)
	if not shop.claim_slot(self):
		_try_next_shop()
		return
	# Roll the price now so the walk commits to a known charge; the affordability
	# gate in _gather_candidates used the type's floor, this is the actual bill.
	_price = shop.roll_visit_price()
	state = ShopState.Moving
	pawn.movement_component.movement_ended.connect(_arrived, CONNECT_ONE_SHOT)
	pawn.movement_component.move_to(shop.owner_module)

func _arrived(prev_success: bool) -> void:
	# _ended: a stale movement one-shot firing after an external cancel must not
	# overwrite the terminal state (WI-04 lifecycle rule).
	if _ended:
		return
	if not prev_success or not is_instance_valid(shop) or not shop.is_open():
		if is_instance_valid(shop):
			shop.release_slot(self)
		_try_next_shop()
		return
	_pay()
	state = ShopState.Shopping

## Charge the register once. Clamp to the wallet so a customer just short of the
## rolled price still buys (spending their last credits); the amount actually paid
## is what gets booked as station income.
func _pay() -> void:
	if _paid:
		return
	_paid = true
	var charge: int = mini(_price, pawn.personal_credits)
	if charge <= 0:
		return
	pawn.spend_credits(charge)
	shop.record_sale(charge)
	# A satisfying visit lifts mood a little (WI-33), nudging reputation for
	# visitors and just cheering crew. Timed, so it fades like a good meal.
	if shop.shop_type != null and shop.shop_type.visit_mood_bonus != 0.0:
		var needs: PawnNeedsComponent = pawn.get_component_by_type(PawnNeedsComponent) as PawnNeedsComponent
		if needs != null:
			needs.add_modifier(&"good_shopping", shop.shop_type.visit_mood_bonus, shop.shop_type.visit_mood_duration_hours)

func process_job(delta: float) -> void:
	if state != ShopState.Shopping:
		return
	var needs: PawnNeedsComponent = pawn.get_component_by_type(PawnNeedsComponent) as PawnNeedsComponent
	if needs == null or not is_instance_valid(shop):
		cancel(true)
		return
	var rate: float = shop.recreation_per_hour(pawn)
	if rate <= 0.0:
		# Shop closed mid-visit (power died) - leave gracefully; the paid charge
		# stands (they got some browsing in), the need re-queues if still low.
		cancel(false)
		return
	# delta arrives sim-scaled from PawnBase._process.
	var sim_hours: float = delta / TimeManager.SECONDS_PER_HOUR
	stay_hours += sim_hours
	needs.recreation_value += rate * sim_hours
	if needs.recreation_value >= needs.recreation_max or stay_hours >= max_stay_hours:
		state = ShopState.Finished

func _module_removed(module: ModuleBase) -> void:
	if shop != null and module == shop.owner_module:
		cancel(true)

func _on_cancel(as_failed: bool) -> void:
	if as_failed:
		state = ShopState.Failed
	else:
		state = ShopState.Finished

func _on_end() -> void:
	if SignalBus.module_removed.is_connected(_module_removed):
		SignalBus.module_removed.disconnect(_module_removed)
	if is_instance_valid(shop):
		shop.release_slot(self)

func is_failed() -> bool:
	return state == ShopState.Failed

func is_finished() -> bool:
	return state == ShopState.Finished

# --- persistence (WI-21/WI-33) ------------------------------------------------

## No target ref: start_job() re-gathers affordable reachable shops and re-claims a
## slot on load (mirrors Job_Recreate). Persisting lets a customer resume a session
## already above the need threshold. Not saving _paid means a save taken mid-visit
## and reloaded re-charges on the fresh arrival - so payment persistence is
## deliberately part of the (re-)commit, not stored (a visit that was already paid
## and is resumed pays again is an accepted v1 edge; the resume re-walks and re-pays
## like a new visit). SaveManager re-links it to the recreation need.
func get_save_data() -> Dictionary:
	return {"type": "shop"}

static func restore(_data: Dictionary) -> JobBase:
	return Job_Shop.new()

## All reachable open shops with a free slot the pawn can afford (by the type's
## price floor) and a nonzero rate. Pure query - safe from can_do_job. Static
## variant powers PawnNeedsComponent's "shop vs. free recreation" choice.
func _gather_candidates(_pawn: PawnBase) -> Array[ShopComponent]:
	return gather_affordable_shops(_pawn)

static func gather_affordable_shops(_pawn: PawnBase) -> Array[ShopComponent]:
	var out: Array[ShopComponent] = []
	for node: Node in _pawn.get_tree().get_nodes_in_group("shop"):
		var candidate: ShopComponent = node as ShopComponent
		if candidate == null or not candidate.is_open() or not candidate.has_free_slot():
			continue
		if _pawn.personal_credits < candidate.min_visit_price():
			continue
		if candidate.recreation_per_hour(_pawn) <= 0.0:
			continue
		if not Global.path_manager.is_reachable(_pawn, candidate.owner_module):
			continue
		out.append(candidate)
	return out

## True when the pawn could shop right now (wallet + a reachable affordable shop).
## PawnNeedsComponent uses this to prefer a paid visit over free recreation.
static func has_affordable_shop(_pawn: PawnBase) -> bool:
	return not gather_affordable_shops(_pawn).is_empty()
