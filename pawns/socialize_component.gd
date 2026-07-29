class_name SocializeComponent
extends PawnComponentBase

## Passive ambient socializing (WI-05 step 8): sharing a module with other
## crew slowly restores recreation during whatever the pawn is doing - no job
## involved. Only pawns that carry this component count as company, which is
## what keeps drones out of the conversation, and a pawn in space
## (current_module null) never ticks.
##
## Balance guard (mandatory - see WI-05): passive restore stops hard at
## passive_cap_percent, so active recreation (the recreation job) stays the only
## way to fill the bar - and the only lever above half happiness from this
## need. The rate must modestly EXCEED the decay rate (~6.7/hr at the
## default 15h duration) or socializing would never visibly restore
## anything, only slow the slide.

## Gross recreation points per game-hour while at least one other
## socializer shares the module (net restore = this minus decay).
@export var passive_fun_per_hour: float = 9.0
## Passive restore never lifts recreation above this percent of max.
@export var passive_cap_percent: float = 50.0
## Company bonus: extra points per game-hour per additional socializer
## beyond the first, capped so a packed mess hall doesn't trivialize the need.
@export var fun_per_extra_pawn_per_hour: float = 0.5
@export var max_counted_company: int = 4

var _needs: PawnNeedsComponent = null

func _ready() -> void:
	super()
	# Cheap periodic check, not per-frame - this is exactly what slow_tick is
	# for. Connection dies with the node, no explicit disconnect needed.
	Global.time_manager.slow_tick.connect(_on_slow_tick)

func _on_slow_tick(interval: float) -> void:
	if owner_pawn == null or owner_pawn.current_module == null:
		return
	if _needs == null:
		_needs = owner_pawn.get_component_by_type(PawnNeedsComponent) as PawnNeedsComponent
	if _needs == null or not _needs.has_recreation_need:
		return
	# Trait hooks (WI-22): Introvert recharges while ALONE and gets nothing from
	# company; Extrovert gains faster and to a higher cap. No traits component
	# (or no relevant trait) leaves the original company-based behavior intact.
	var traits: PawnTraitsComponent = owner_pawn.get_traits_component()
	var solitary: bool = traits != null and traits.prefers_solitude()
	var social_mult: float = traits.passive_social_multiplier() if traits != null else 1.0
	var cap_bonus: float = traits.passive_social_cap_bonus() if traits != null else 0.0
	var cap: float = _needs.recreation_max * (passive_cap_percent + cap_bonus) / 100.0
	if _needs.recreation_value >= cap:
		return
	var company: int = _count_company()
	# counted drives the company-scaled rate; mult scales the whole gain.
	var counted: int
	var mult: float
	if solitary:
		if company > 0:
			return
		counted = 1
		mult = 1.0
	else:
		if company <= 0 or social_mult <= 0.0:
			return
		counted = company
		mult = social_mult
	# Each pawn's component restores only its own recreation; the partner's
	# component does the same for them symmetrically - "both tick up" without
	# anyone double-applying.
	var sim_hours: float = interval / TimeManager.SECONDS_PER_HOUR
	var rate: float = (passive_fun_per_hour + (mini(counted, max_counted_company) - 1) * fun_per_extra_pawn_per_hour) * mult
	# Never overshoot the cap: passive tops out, it doesn't fill.
	_needs.recreation_value = minf(_needs.recreation_value + rate * sim_hours, cap)

## Other pawns in this module that can hold up their end of a conversation
## (i.e. have a SocializeComponent of their own - drones don't).
func _count_company() -> int:
	var company: int = 0
	for node: Node in get_tree().get_nodes_in_group(Groups.PAWN):
		var other: PawnBase = node as PawnBase
		if other == null or other == owner_pawn or other.current_module != owner_pawn.current_module:
			continue
		if other.get_component_by_type(SocializeComponent) != null:
			company += 1
	return company
