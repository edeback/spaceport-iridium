class_name PawnBreathingComponent
extends PawnComponentBase

## Crew respiration (WI-17): converts a trickle of O2 into CO2 in whatever
## module the pawn currently occupies. Only the crew scene carries this
## component - drones/robots don't breathe. A pawn with no current module
## (EVA, shuttle transit) or in a module without atmosphere is assumed to be
## on suit supply and neither breathes nor suffocates.
##
## Suffocation is exposed as a flag that PawnHealthComponent consumes (same
## shape as its starvation check); flee behavior only ever preempts *idle*
## jobs - working crew finish what they're doing, that's the player's problem
## to notice (WI-17 design decision).

## O2 units converted to CO2 per game-hour.
@export var breathing_per_hour: float = 5.0
## Below this local O2 partial the pawn is suffocating (health decays).
@export var damage_o2_partial: float = 25.0
## Below this local O2 partial, idle crew leave for breathable air.
@export var flee_o2_partial: float = 35.0
## Game-hours between flee checks (and retry delay when nowhere is safe).
@export var flee_check_hours: float = 0.1
@export var flee_retry_hours: float = 0.5

var is_suffocating: bool = false
var _flee_timer_hours: float = 0.0

func _process(delta: float) -> void:
	var sim_hours: float = Global.time_manager.scale(delta) / TimeManager.SECONDS_PER_HOUR
	if sim_hours <= 0.0:
		return
	var atmosphere: AtmosphereComponent = _current_atmosphere()
	if atmosphere == null:
		# Suit supply: no O2 drain and no harm in space/atmosphereless modules.
		is_suffocating = false
		return
	atmosphere.breathe(breathing_per_hour * sim_hours)
	is_suffocating = atmosphere.o2_partial() < damage_o2_partial
	_flee_timer_hours -= sim_hours
	if _flee_timer_hours <= 0.0:
		_flee_timer_hours = flee_check_hours
		if atmosphere.o2_partial() < flee_o2_partial:
			_try_flee()

func _current_atmosphere() -> AtmosphereComponent:
	var module: ModuleBase = owner_pawn.current_module
	if module == null:
		return null
	return module.get_component_by_type(AtmosphereComponent) as AtmosphereComponent

## Is `module` breathable enough for `pawn` to idle in? Modules without
## atmosphere count as safe (suit assumption). Also consulted by
## Job_IdleWander so idle crew don't wander INTO a module they'd flee.
static func is_module_safe_for(pawn: PawnBase, module: ModuleBase) -> bool:
	var breathing: PawnBreathingComponent = pawn.get_component_by_type(PawnBreathingComponent) as PawnBreathingComponent
	if breathing == null or module == null:
		return true
	var atmosphere: AtmosphereComponent = module.get_component_by_type(AtmosphereComponent) as AtmosphereComponent
	if atmosphere == null:
		return true
	return atmosphere.o2_partial() >= breathing.flee_o2_partial

func _is_idle() -> bool:
	return owner_pawn.current_job == null \
		or owner_pawn.current_job is Job_IdleWander \
		or owner_pawn.current_job is Job_Idle

## Idle crew walk to the nearest breathable module. Pathfinding only runs
## from here (throttled by _flee_timer_hours), never per frame; when nothing
## breathable is reachable we stay put and retry on a longer cooldown - no
## thrashing (WI-17 edge case).
func _try_flee() -> void:
	if not _is_idle():
		return
	var path: Array[ModuleGraph.PathPoint] = Global.path_manager.run_pathfinding_by_func(
		owner_pawn,
		func(vertex: ModuleGraphVertex) -> bool:
			var module: ModuleBase = vertex.node as ModuleBase
			if module == null or vertex.is_exterior:
				return false
			var atmosphere: AtmosphereComponent = module.get_component_by_type(AtmosphereComponent) as AtmosphereComponent
			return atmosphere != null and atmosphere.o2_partial() >= flee_o2_partial)
	if path.is_empty():
		_flee_timer_hours = flee_retry_hours
		return
	var destination: ModuleBase = path.back().node as ModuleBase
	if destination == null or destination == owner_pawn.current_module:
		_flee_timer_hours = flee_retry_hours
		return
	var flee_job: Job_MoveToLocation = Job_MoveToLocation.new()
	flee_job.destination_module = destination
	owner_pawn.interrupt_with_job(flee_job)
