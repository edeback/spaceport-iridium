class_name PawnTemperatureComponent
extends PawnComponentBase

## How a pawn feels about the temperature of the room it is standing in (WI-60).
##
## Three exclusions the design asks for, and all three fall out of rules that
## already exist rather than adding a check:
##
##   - **Robots are immune** because RobotPawnBase does not carry this component.
##     "Carries the component = participates" is WI-48's rule and it stays exactly
##     one rule - there is no is_robot test anywhere in this file.
##   - **Pawns in space are immune** because current_module == null means suit
##     supply, which is precisely how PawnBreathingComponent already reads EVA.
##   - **Visitors are included** deliberately: they carry needs, and a guest
##     freezing in the lobby is feedback the player should get.
##
## Rides slow_tick rather than _process: this is an hours-scale effect and it has
## nothing to do per frame.

## Curve tuning. Exported as a block rather than read from HeatMath's defaults
## directly so a scene can make a pawn kind hardier without touching code; the
## defaults themselves come from the consts so the two cannot drift.
@export var habitable_low_f: float = HeatMath.DEFAULT_HABITABLE_LOW_F
@export var habitable_high_f: float = HeatMath.DEFAULT_HABITABLE_HIGH_F
@export var dangerous_low_f: float = HeatMath.DEFAULT_DANGEROUS_LOW_F
@export var dangerous_high_f: float = HeatMath.DEFAULT_DANGEROUS_HIGH_F
@export var max_mood_penalty: float = 0.12
@export var harm_per_hour_at_edge: float = 2.0
@export var harm_ramp_degrees: float = 40.0

## Health per game-hour this pawn is currently losing to temperature.
## PawnHealthComponent reads it as a fourth decay source, the same shape as
## PawnBreathingComponent.is_suffocating.
var damage_per_hour: float = 0.0

## The modifier id currently applied, so it can be lifted when the pawn moves.
## Exactly one is ever live - a pawn cannot be too cold and too hot at once.
var _active_mood_id: StringName = &""
## Edge-detect latch for the harm alert. Not saved (WI-45 A7): the latch only
## suppresses a repeat, so a load costs one duplicate warning about a crew member
## who is genuinely still freezing.
var _harm_alerted: bool = false

func _ready() -> void:
	super()
	if Global.time_manager != null:
		Global.time_manager.slow_tick.connect(_on_slow_tick)

func tuning() -> HeatMath.ComfortTuning:
	var out := HeatMath.ComfortTuning.new()
	out.habitable_low_f = habitable_low_f
	out.habitable_high_f = habitable_high_f
	out.dangerous_low_f = dangerous_low_f
	out.dangerous_high_f = dangerous_high_f
	out.max_mood_penalty = max_mood_penalty
	out.harm_per_hour_at_edge = harm_per_hour_at_edge
	out.harm_ramp_degrees = harm_ramp_degrees
	return out

## The temperature this pawn is experiencing, or NAN when it is in a suit (in
## space, riding a turbolift, mid-load) and therefore feels nothing.
func ambient_temperature() -> float:
	# A suit is suit supply exactly as being outside is (WI-67), and it lands on
	# the same NAN branch: mood cleared, no harm, no alert. One question, one place
	# - see PawnSuitComponent.on_suit_supply.
	if PawnSuitComponent.on_suit_supply(owner_pawn):
		return NAN
	var module: ModuleBase = owner_pawn.current_module
	if module == null or not is_instance_valid(module) or Global.heat_manager == null:
		return NAN
	var component: HeatComponent = Global.heat_manager.get_component(module)
	if component == null:
		return NAN
	return component.temperature_f

func current_band() -> HeatMath.Band:
	var temp: float = ambient_temperature()
	if is_nan(temp):
		return HeatMath.Band.COMFORTABLE
	return HeatMath.band(temp, tuning())

func _on_slow_tick(_interval: float) -> void:
	var temp: float = ambient_temperature()
	if is_nan(temp):
		# In a suit. Clearing here is the whole reason this branch exists: a pawn
		# who walks out of a freezer into the void must stop being cold, and
		# nothing else would ever lift the modifier.
		_clear()
		return
	var tune: HeatMath.ComfortTuning = tuning()
	_apply_mood(HeatMath.mood_id(temp, tune), HeatMath.mood_offset(temp, tune))
	damage_per_hour = HeatMath.harm_per_hour(temp, tune)
	_check_alert(temp)

## One INF-duration modifier at a time, replaced rather than stacked.
##
## Derived state, so it is NOT saved - it re-derives on the first tick after a
## load, exactly like the WI-48 &"company" modifier and the WI-30 field maluses.
## One id, recomputed, is what makes it impossible to leak when a pawn changes
## rooms.
func _apply_mood(id: StringName, offset: float) -> void:
	var needs: PawnNeedsComponent = owner_pawn.get_component_by_type(PawnNeedsComponent) as PawnNeedsComponent
	if needs == null:
		return
	if _active_mood_id != &"" and _active_mood_id != id:
		needs.remove_modifier(_active_mood_id)
		_active_mood_id = &""
	if id == &"":
		return
	needs.add_modifier(id, offset, INF)
	_active_mood_id = id

func _clear() -> void:
	damage_per_hour = 0.0
	_harm_alerted = false
	if _active_mood_id == &"":
		return
	var needs: PawnNeedsComponent = owner_pawn.get_component_by_type(PawnNeedsComponent) as PawnNeedsComponent
	if needs != null:
		needs.remove_modifier(_active_mood_id)
	_active_mood_id = &""

## The alert is raised from the PAWN side, not the module side, and that is the
## design decision rather than an implementation detail: a forge at 400 F is
## working as intended and must never light the strip, while a crew member being
## cooked is exactly "look at this now". HIGH, never CRITICAL - this does not
## pause the sim.
func _check_alert(temp: float) -> void:
	if damage_per_hour <= 0.0:
		_harm_alerted = false
		return
	if _harm_alerted:
		return
	_harm_alerted = true
	var freezing: bool = temp < dangerous_low_f
	AlertManager.raise_alert(AlertRules.make_id(&"pawn_temperature", owner_pawn),
		AlertData.Priority.HIGH,
		"Dangerously cold" if freezing else "Dangerously hot",
		"%s - %s" % [owner_pawn.pawn_name, HeatMath.format_temperature(temp)],
		owner_pawn, &"",
		# "people" rather than "crew" since WI-67: crew suit up before harm can
		# accumulate, so in practice the only pawns this alert can still reach are
		# visitors, who never wear a suit.
		"%d people are in dangerous temperatures")
