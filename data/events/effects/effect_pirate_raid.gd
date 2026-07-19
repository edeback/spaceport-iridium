class_name EventEffectPirateRaid
extends EventEffect

## The "refuse" outcome of the pirate extortion event (WI-24): raiders strafe the
## station, dealing heavy damage to a handful of random built modules and tearing
## hull breaches in some of them. Reuses the same apply_damage + breach machinery
## everything else does, so destruction, debris, truss replacement, atmosphere
## venting, and the resulting repair/breach-repair jobs all fall out for free.
## WI-32's real ship combat replaces/expands this placeholder.

@export var min_targets: int = 2
@export var max_targets: int = 4
## Damage dealt to each target, as a fraction of that module's max HP.
@export var damage_fraction_min: float = 0.35
@export var damage_fraction_max: float = 0.7
## Chance a struck module also takes a hull breach.
@export var breach_chance: float = 0.6
@export var breach_duration_hours: float = 2.0

func apply(_event: EventData) -> void:
	var world: WorldManager = Global.world_manager
	if world == null:
		return
	var candidates: Array[ModuleBase] = world.get_built_modules()
	if candidates.is_empty():
		return
	candidates.shuffle()
	var count: int = clampi(randi_range(min_targets, max_targets), 0, candidates.size())
	SignalBus.station_alert.emit("Raiders open fire on the station!")
	for i: int in count:
		var module: ModuleBase = candidates[i]
		if not is_instance_valid(module):
			continue
		var damage: float = module.max_hp() * randf_range(damage_fraction_min, damage_fraction_max)
		module.apply_damage(damage, &"pirate_raid")
		# The strike can destroy the module (freed) - re-check before breaching.
		if is_instance_valid(module) and randf() < breach_chance:
			var atmo: AtmosphereComponent = module.get_atmosphere()
			if atmo != null:
				atmo.start_breach(breach_duration_hours)

func describe() -> String:
	return "Raiders damage and breach several modules"
