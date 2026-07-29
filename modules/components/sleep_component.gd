class_name SleepComponent
extends ComponentBase

## Sleep slots on a pod module. the sleep job claims a slot at claim time (not on
## arrival) so two pawns never race for the same pod, and releases it in its
## _on_end - which runs on every termination path (WI-04 contract), so slots
## can't leak. Slots are runtime-only state: rebuilt empty on save/load.

@export var capacity: int = 1
## Restore-rate multiplier; 1.0 = an empty sleep bar refills (gross, before
## the pawn's own decay) in base_hours_to_full. Routed through the module's
## stat layer as &"sleep_quality" so a hotel's quality-tier upgrade can raise it.
@export var sleep_quality: float = 1.0
## Game-hours a quality-1 pod takes to gross-restore an empty sleep bar. Set
## below the intended night length: the pawn's sleep decay keeps ticking
## while asleep, so net restore is slower than this.
@export var base_hours_to_full: float = 6.0

## --- hotel (visitor lodging, WI-33) -----------------------------------------
## True on a hotel room: visitors ONLY sleep here, and crew never claim it (the
## mutual exclusion is enforced by accepts()). Crew quarters leave this false, so
## a visitor can't take a crew bunk either. This is the WI-07 housing pattern
## split by pawn kind.
@export var visitor_only: bool = false
## Credits a visitor pays on waking from a full night here (wallet -> station
## income "hotels", clamped to the wallet). 0 = free lodging / crew quarters.
## Routed through the stat layer as &"hotel_rate" so a pricier suite upgrade can
## raise it alongside the extra comfort.
@export var nightly_rate: int = 0
## Timed happiness lift a visitor takes from a comfortable night (a nicer room is
## more of a treat). Routed as &"hotel_mood". 0 = none (crew quarters).
@export var visitor_mood_bonus: float = 0.0
@export var visitor_mood_duration_hours: float = 8.0

## Adjacency tuning (WI-30). Nearby industrial vibration divides rest
## effectiveness by (1 + vibration * k); nearby greenery adds a small rest bonus
## and (more importantly) makes the bunk more desirable when picking one.
@export var vibration_penalty_k: float = 1.0
@export var greenery_rest_bonus_k: float = 0.15
@export var greenery_desirability_k: float = 1.0

## Occupancy for this component, and the object a job takes its SLOT claim
## against. Reach it through claim_pool(), which syncs capacity first.
var _slots := SlotPool.new()

## The object a WI-44 job takes its SLOT claim against. Capacity is re-synced on
## every call so a local upgrade that widens the component is picked up without
## anything having to notify this.
func claim_pool() -> SlotPool:
	_slots.capacity = capacity
	return _slots

func ready_constructed() -> void:
	add_to_group(Groups.SLEEP_COMPONENT)

func has_free_slot() -> bool:
	return claim_pool().has_free()

## How many slots are currently claimed (WI-33 visitor-capacity gate reads this).
## Reads the pool, not _claims, so occupants from EITHER job system are counted.
func claimed_count() -> int:
	return claim_pool().occupied


## Whether `pawn` is allowed to sleep here (WI-33): a hotel room takes visitors
## only, a crew pod takes crew only. The mutual exclusion that keeps crew out of
## paid rooms and guests out of the bunkhouse - the sleep job filters on this.
func accepts(pawn: PawnBase) -> bool:
	if pawn == null:
		return false
	if visitor_only:
		return pawn.is_visitor
	return not pawn.is_visitor

## Effective quality after any local upgrade (WI-33 hotel tiers). Falls back to the
## raw export before the component is attached to a module.
func effective_sleep_quality() -> float:
	if owner_module != null:
		return owner_module.get_effective_stat(&"sleep_quality", sleep_quality)
	return sleep_quality

## WI-44 adapter: the uniform name Action_RestoreNeed calls on every provider.
## Sleep's own rate function takes the pawn's sleep_max rather than the pawn, so
## this bridges the two.
func restore_rate_per_hour(pawn: PawnBase) -> float:
	if pawn == null:
		return 0.0
	var needs: PawnNeedsComponent = pawn.get_component_by_type(PawnNeedsComponent) as PawnNeedsComponent
	if needs == null:
		return 0.0
	return sleep_restored_per_hour(needs.sleep_max)

func sleep_restored_per_hour(sleep_max: float) -> float:
	return sleep_max / base_hours_to_full * effective_sleep_quality() * environment_rest_multiplier()

## Effective nightly charge after any suite upgrade.
func effective_nightly_rate() -> int:
	if owner_module != null:
		return int(round(owner_module.get_effective_stat(&"hotel_rate", float(nightly_rate))))
	return nightly_rate

## Called by the sleep job when a pawn wakes from a FULL night (never on an early
## cancel). For a visitor in a hotel room: bills the nightly rate to their wallet
## (clamped, income "hotels") and applies the room's comfort mood lift. No-op for
## crew and for a crew pod. Returns the amount actually billed (for alerts/tests).
func complete_stay(pawn: PawnBase) -> int:
	if pawn == null or not visitor_only or not pawn.is_visitor:
		return 0
	var mood: float = owner_module.get_effective_stat(&"hotel_mood", visitor_mood_bonus) if owner_module != null else visitor_mood_bonus
	if mood != 0.0:
		var needs: PawnNeedsComponent = pawn.get_component_by_type(PawnNeedsComponent) as PawnNeedsComponent
		if needs != null:
			needs.add_modifier(&"good_lodging", mood, visitor_mood_duration_hours)
	var rate: int = effective_nightly_rate()
	if rate <= 0:
		return 0
	var charge: int = mini(rate, pawn.personal_credits)
	if charge <= 0:
		return 0
	pawn.spend_credits(charge)
	if Global.economy_manager != null:
		# The station banks the net after the levy (WI-25 call-site contract).
		Global.resource_manager.credit_resource.change_global_total(Global.economy_manager.record_income(charge, &"hotels"))
	return charge

## Adjacency modifier on rest effectiveness (WI-30): vibration divides it,
## greenery gives a small bonus. 1.0 when nothing is nearby (or the manager
## isn't up yet), so an isolated pod restores exactly its authored rate.
func environment_rest_multiplier() -> float:
	if Global.adjacency_manager == null or owner_module == null:
		return 1.0
	var vibration: float = Global.adjacency_manager.get_field(owner_module, &"vibration")
	var greenery: float = Global.adjacency_manager.get_field(owner_module, &"greenery")
	return (1.0 / (1.0 + vibration * vibration_penalty_k)) * (1.0 + greenery * greenery_rest_bonus_k)

## Desirability score for choosing among free bunks (WI-30): greener is nicer,
## noisier is worse. Only a tie-break between comparably-close pods - see
## the old sleep job's _find_pod.
func desirability() -> float:
	if Global.adjacency_manager == null or owner_module == null:
		return 0.0
	var vibration: float = Global.adjacency_manager.get_field(owner_module, &"vibration")
	var greenery: float = Global.adjacency_manager.get_field(owner_module, &"greenery")
	return greenery * greenery_desirability_k - vibration * vibration_penalty_k
