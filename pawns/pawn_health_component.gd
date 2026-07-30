class_name PawnHealthComponent
extends PawnComponentBase

## Health: the inverted, job-less need (WI-05). It regenerates passively
## instead of decaying; starvation (hunger at 0) *replaces* regen with decay -
## the two never apply in the same tick. Deliberately its own component rather
## than a block in PawnNeedsComponent: it will interact with combat injuries
## and disease later, systems the decaying needs never touch. Happiness still
## reads it via sibling lookup (see PawnNeedsComponent._recompute_happiness).
##
## Health at 0 does nothing yet - there is no pawn death system (WI-07+
## territory); the value clamps and the tanked happiness is the consequence.

@export var health_max: float = 100
@export var health_value: float = 100:
	set(new_health):
		new_health = clampf(new_health, 0, health_max)
		if health_value != new_health:
			health_value = new_health
			health_changed.emit(health_value)
signal health_changed(new_health: float)

## Passive self-healing, in health points per game-hour.
@export var regen_per_hour: float = 1.0
## Applied INSTEAD of regen while the pawn's hunger sits at 0.
@export var starvation_decay_per_hour: float = 3.0
## Applied INSTEAD of regen while suffocating (WI-17) - much faster than
## starvation; thin air is an emergency. Stacks with starvation decay.
@export var suffocation_decay_per_hour: float = 25.0
## Alert threshold - higher than the decaying needs' 5% so the player gets
## warning while there is still time to fix the cause.
@export var percent_critical: float = 25.0

## Edge-detect latch for the critical-health alert; not saved (WI-45 A7). It
## re-derives from the restored health_value on the first tick after a load -
## which costs one repeat alert for a crew member who is genuinely still critical.
var _was_critical: bool = false
## Sibling lookups cached lazily - component _ready order isn't guaranteed.
var _needs: PawnNeedsComponent = null
var _breathing: PawnBreathingComponent = null
var _disease: PawnDiseaseComponent = null

func _process(delta: float) -> void:
	var sim_hours: float = Global.time_manager.scale(delta) / TimeManager.SECONDS_PER_HOUR
	if sim_hours <= 0.0:
		return
	if _needs == null:
		_needs = owner_pawn.get_component_by_type(PawnNeedsComponent) as PawnNeedsComponent
	if _breathing == null:
		_breathing = owner_pawn.get_component_by_type(PawnBreathingComponent) as PawnBreathingComponent
	if _disease == null:
		_disease = owner_pawn.get_component_by_type(PawnDiseaseComponent) as PawnDiseaseComponent
	var starving: bool = _needs != null and _needs.has_hunger_need and _needs.hunger_value <= 0.0
	var suffocating: bool = _breathing != null and _breathing.is_suffocating
	# Disease drain (WI-31) joins starvation/suffocation as a third decay source;
	# it stacks with them and, like them, suppresses passive regen while active.
	# The Medical Bay treatment job restores health directly on top of this, so a
	# treated patient still nets positive despite the suppressed passive regen.
	var disease_drain: float = _disease.total_health_drain_per_hour() if _disease != null else 0.0
	if starving or suffocating or disease_drain > 0.0:
		# Multiple sources at once stack their decay; regen never applies while any
		# is active (the exclusivity rule, extended for disease in WI-31).
		var decay: float = disease_drain
		if starving:
			decay += starvation_decay_per_hour
		if suffocating:
			decay += suffocation_decay_per_hour
		# Traits scale incoming damage (Hardy tougher, Weak frailer); 1.0 for
		# pawns without a traits component (WI-22).
		var traits: PawnTraitsComponent = owner_pawn.get_traits_component()
		if traits != null:
			decay *= traits.damage_multiplier()
		health_value -= decay * sim_hours
	elif health_value < health_max:
		health_value += regen_per_hour * sim_hours
	var percent: float = health_value / health_max * 100.0
	if percent < percent_critical:
		if not _was_critical:
			_was_critical = true
			SignalBus.pawn_critical_need.emit(owner_pawn, &"health")
	elif _was_critical:
		_was_critical = false

func health_percent01() -> float:
	return clampf(health_value / health_max, 0.0, 1.0)

# --- persistence -------------------------------------------------------------

func get_save_data() -> Dictionary:
	return {"health": health_value}

func load_save_data(data: Dictionary) -> void:
	health_value = float(data.get("health", health_value))
