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

## --- Void Sickness / EVA accrual (WI-31) ------------------------------------
## The disease cumulative exterior (EVA) time can eventually inflict.
@export var eva_sickness_disease: StringName = &"void_sickness"
## Accumulated EVA game-hours before the per-hour sickness roll begins.
@export var eva_sickness_threshold_hours: float = 8.0
## Per-game-hour chance to catch the disease while outside past the threshold.
@export var eva_sickness_chance_per_hour: float = 0.05
## EVA hours drained back per game-hour spent inside the hull (partial recovery).
@export var eva_recovery_per_hour: float = 2.0

var is_suffocating: bool = false
var _flee_timer_hours: float = 0.0
## Cumulative exterior (in-suit) game-hours toward Void Sickness. Saved.
var _eva_hours: float = 0.0

func _ready() -> void:
	super()
	# The EVA sickness roll rides the calendar hour (one roll per game-hour of
	# exposure), so it can't fire while paused and stays cheap.
	if Global.time_manager != null:
		Global.time_manager.hour_changed.connect(_on_hour_changed)

func _process(delta: float) -> void:
	var sim_hours: float = Global.time_manager.scale(delta) / TimeManager.SECONDS_PER_HOUR
	if sim_hours <= 0.0:
		return
	# EVA accrual (WI-31): time outside the hull accumulates toward Void Sickness;
	# time inside drains it back down. Done before the suit-supply early return
	# below, since being outside (current_module == null) is exactly the EVA case.
	if owner_pawn.current_module == null:
		_eva_hours += sim_hours
	elif _eva_hours > 0.0:
		_eva_hours = maxf(0.0, _eva_hours - eva_recovery_per_hour * sim_hours)
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

# --- Void Sickness roll (WI-31) ----------------------------------------------

## Once per game-hour, a pawn currently outside past the EVA threshold rolls to
## catch Void Sickness. Gated on the disease's station-tier unlock so a Tier-1
## station never suffers it, and skipped for a pawn already infected or lacking a
## disease component.
func _on_hour_changed(_hour: int) -> void:
	if owner_pawn.current_module != null or _eva_hours < eva_sickness_threshold_hours:
		return
	var disease: DiseaseData = DiseaseData.by_id(eva_sickness_disease)
	if disease == null:
		return
	if Global.unlock_manager == null or Global.unlock_manager.current_tier < disease.min_station_tier:
		return
	var disease_component: PawnDiseaseComponent = owner_pawn.get_component_by_type(PawnDiseaseComponent) as PawnDiseaseComponent
	if disease_component == null or disease_component.has_disease(eva_sickness_disease):
		return
	if randf() < eva_sickness_chance_per_hour:
		disease_component.infect(eva_sickness_disease)

# --- persistence (WI-31) -----------------------------------------------------

func get_save_data() -> Dictionary:
	# Only written when nonzero, so a station of interior crew adds nothing.
	if _eva_hours <= 0.0:
		return {}
	return {"eva_hours": _eva_hours}

func load_save_data(data: Dictionary) -> void:
	_eva_hours = float(data.get("eva_hours", 0.0))
