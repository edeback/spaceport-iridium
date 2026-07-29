class_name PawnDiseaseComponent
extends PawnComponentBase

## Active diseases on one organic crew pawn (WI-31). Only the crew scene carries
## this - robots and drones never do, which is exactly what excludes them from
## transmission (an occupant without this component can't catch anything).
##
## Per sim-hour it advances each disease's stage timer; its staged effects reach
## the pawn three ways, all re-derived from state (never saved as modifiers, the
## WI-22 rule):
##   - health drain: PawnHealthComponent *queries* total_health_drain_per_hour()
##     each tick and folds it into the shared starvation/suffocation decay, so
##     regen is suppressed while any disease drains.
##   - skill maluses: pushed to PawnSkillsComponent as a level-reduction overlay.
##   - mood + move-speed: a happiness modifier per disease, plus move_speed_scale.
##
## Transmission is one roll site here (on hour_changed): a carrier rolls each
## co-located, uninfected organic pawn, scaled down by the module's purified_air
## adjacency field. Treatment seeking mirrors RobotIntegrityComponent - a single
## queued treatment job, promoted when critical, retried on a throttle.

## Fired when the set of diseases or their stages change (infect / cure / worsen /
## load) so the pawn panel's health tab can refresh without polling. Treatment
## progress ticks silently (no per-frame UI churn); the tab reads it on rebuild.
signal diseases_changed

## Below this health %, an otherwise-healthy pawn still seeks treatment (injury).
@export var treat_seek_health_percent: float = 40.0
## Health % (or a final-stage disease) at which treatment jumps the personal queue.
@export var critical_health_percent: float = 20.0
## How strongly a module's purified_air field suppresses spread: effective rate is
## divided by (1 + purified_air * k). Higher = cleaner air, rarer spread.
@export var purified_air_scaling_k: float = 3.0
## Sim-seconds between treatment retries when none can be serviced (no reachable
## powered Medical Bay with a free slot) - throttles pathfinding.
@export var retry_cooldown_seconds: float = 30.0

## disease_id -> {"stage": int, "stage_hours": float, "treat_progress": float}.
var _active: Dictionary[StringName, Dictionary] = {}

var _treatment_job: Job = null
var _retry_cooldown: float = 0.0
var _stranded_alerted: bool = false
## Cached sibling - component _ready order isn't guaranteed, resolve lazily.
var _needs: PawnNeedsComponent = null
var _health: PawnHealthComponent = null

func _ready() -> void:
	super()
	# Transmission runs on the calendar hour (WI-31), so it can't spread while
	# paused and stays cheap (once per game-hour, not per frame).
	if Global.time_manager != null:
		Global.time_manager.hour_changed.connect(_on_hour_changed)

func _process(delta: float) -> void:
	var sim_delta: float = Global.time_manager.scale(delta)
	if sim_delta <= 0.0:
		return
	if _retry_cooldown > 0.0:
		_retry_cooldown = maxf(0.0, _retry_cooldown - sim_delta)
	if not _active.is_empty():
		_advance_stages(sim_delta / TimeManager.SECONDS_PER_HOUR)
	# Cheap early-out inside when healthy and disease-free (the common case).
	_maybe_seek_treatment()

# --- stage progression --------------------------------------------------------

## Advance every active disease's stage timer; worsen to the next stage when a
## stage's duration elapses (the final stage is terminal - it just keeps draining).
func _advance_stages(sim_hours: float) -> void:
	var advanced: bool = false
	for disease_id: StringName in _active:
		var disease: DiseaseData = DiseaseData.by_id(disease_id)
		if disease == null:
			continue
		var state: Dictionary = _active[disease_id]
		var stage_idx: int = int(state["stage"])
		if disease.is_final_stage(stage_idx):
			continue
		var stage: DiseaseStage = disease.get_stage(stage_idx)
		state["stage_hours"] = float(state["stage_hours"]) + sim_hours
		if stage != null and float(state["stage_hours"]) >= stage.duration_hours:
			state["stage"] = stage_idx + 1
			state["stage_hours"] = 0.0
			advanced = true
			SignalBus.station_alert.emit("%s's %s has worsened" % [_pawn_label(), disease.display_name])
		_active[disease_id] = state
	if advanced:
		_refresh_effects()
		diseases_changed.emit()

# --- infection ----------------------------------------------------------------

## Infect this pawn with `disease_id` at stage 0. No-op (returns false) if already
## infected with it, if the disease is unknown, or if it has no stages authored.
## The single entry point: transmission, the outbreak effect, EVA accrual, the
## visitor hook (WI-33), and the infect cheat all route through here.
func infect(disease_id: StringName) -> bool:
	var disease: DiseaseData = DiseaseData.by_id(disease_id)
	if disease == null or disease.stages.is_empty() or _active.has(disease_id):
		return false
	_active[disease_id] = {"stage": 0, "stage_hours": 0.0, "treat_progress": 0.0}
	_refresh_effects()
	SignalBus.station_alert.emit("%s has caught %s" % [_pawn_label(), disease.display_name])
	diseases_changed.emit()
	_maybe_seek_treatment()
	return true

## Remove `disease_id` outright and re-derive effects. Called by the cure path and
## available for future scripted cures.
func cure(disease_id: StringName) -> void:
	if not _active.has(disease_id):
		return
	_active.erase(disease_id)
	_refresh_effects()
	diseases_changed.emit()

func has_active_disease() -> bool:
	return not _active.is_empty()

func has_disease(disease_id: StringName) -> bool:
	return _active.has(disease_id)

func active_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for disease_id: StringName in _active:
		out.append(disease_id)
	return out

func stage_of(disease_id: StringName) -> int:
	if not _active.has(disease_id):
		return -1
	return int(_active[disease_id]["stage"])

## Treatment progress toward clearing the current stage / cure, 0..1.
func treat_fraction(disease_id: StringName) -> float:
	var disease: DiseaseData = DiseaseData.by_id(disease_id)
	if disease == null or not _active.has(disease_id) or disease.treat_hours_base <= 0.0:
		return 0.0
	return clampf(float(_active[disease_id]["treat_progress"]) / disease.treat_hours_base, 0.0, 1.0)

# --- effect derivation (never saved as modifiers) -----------------------------

func total_health_drain_per_hour() -> float:
	var total: float = 0.0
	for disease_id: StringName in _active:
		var disease: DiseaseData = DiseaseData.by_id(disease_id)
		if disease == null:
			continue
		var stage: DiseaseStage = disease.get_stage(int(_active[disease_id]["stage"]))
		if stage != null:
			total += stage.health_drain_per_hour
	return total

## Recompute the three derived effects from the current active set. Called on any
## change to the set or a stage (infect/cure/worsen/treat regress/load).
func _refresh_effects() -> void:
	_refresh_skill_maluses()
	_refresh_mood_modifiers()
	_refresh_move_speed()

## Push the worst per-skill level reduction across all active diseases to the
## skills overlay. An empty overlay (no disease) clears it back to raw levels.
func _refresh_skill_maluses() -> void:
	var skills: PawnSkillsComponent = owner_pawn.get_skills_component()
	if skills == null:
		return
	var overlay: Dictionary[StringName, int] = {}
	for disease_id: StringName in _active:
		var disease: DiseaseData = DiseaseData.by_id(disease_id)
		if disease == null:
			continue
		var stage: DiseaseStage = disease.get_stage(int(_active[disease_id]["stage"]))
		if stage == null:
			continue
		for skill_id: StringName in stage.skill_maluses:
			overlay[skill_id] = maxi(overlay.get(skill_id, 0), int(stage.skill_maluses[skill_id]))
	skills.set_disease_malus(overlay)

## One INF happiness modifier per active disease, keyed by disease id. Every
## disease's key is cleared first so a cured/regressed disease's mood lift removes.
func _refresh_mood_modifiers() -> void:
	var needs: PawnNeedsComponent = _needs_component()
	if needs == null:
		return
	for disease: DiseaseData in DiseaseData.all():
		needs.remove_modifier(_mood_mod_id(disease.id))
	for disease_id: StringName in _active:
		var disease: DiseaseData = DiseaseData.by_id(disease_id)
		if disease == null:
			continue
		var stage: DiseaseStage = disease.get_stage(int(_active[disease_id]["stage"]))
		if stage != null and stage.mood_modifier != 0.0:
			needs.add_modifier(_mood_mod_id(disease_id), stage.mood_modifier)

## Product of every active disease's current-stage move multiplier (Fervent Fever
## speeds a pawn up). 1.0 with no disease - resets move_speed_scale cleanly.
func _refresh_move_speed() -> void:
	var mult: float = 1.0
	for disease_id: StringName in _active:
		var disease: DiseaseData = DiseaseData.by_id(disease_id)
		if disease == null:
			continue
		var stage: DiseaseStage = disease.get_stage(int(_active[disease_id]["stage"]))
		if stage != null:
			mult *= stage.move_speed_mult
	owner_pawn.move_speed_scale = mult

func _mood_mod_id(disease_id: StringName) -> StringName:
	return StringName("disease_" + String(disease_id))

# --- transmission -------------------------------------------------------------

func _on_hour_changed(_hour: int) -> void:
	if _active.is_empty():
		return
	_spread()

## For each contagious active disease, roll every co-located, uninfected organic
## pawn. The module's purified_air adjacency field divides the rate down.
func _spread() -> void:
	var module: ModuleBase = owner_pawn.current_module
	if module == null:
		return
	var purified: float = 0.0
	if Global.adjacency_manager != null:
		purified = Global.adjacency_manager.get_field(module, &"purified_air")
	var air_scale: float = 1.0 / (1.0 + purified * purified_air_scaling_k)
	for disease_id: StringName in _active:
		var disease: DiseaseData = DiseaseData.by_id(disease_id)
		if disease == null or not disease.is_contagious():
			continue
		var chance: float = disease.contagious_rate * air_scale
		if chance <= 0.0:
			continue
		for node: Node in owner_pawn.get_tree().get_nodes_in_group(Groups.PAWN):
			var other: PawnBase = node as PawnBase
			if other == null or other == owner_pawn or other.current_module != module:
				continue
			# Robots/drones lack the component - that's what excludes them.
			var other_disease: PawnDiseaseComponent = other.get_component_by_type(PawnDiseaseComponent) as PawnDiseaseComponent
			if other_disease == null or other_disease.has_disease(disease_id):
				continue
			if randf() < chance:
				other_disease.infect(disease_id)

# --- treatment seeking (mirrors RobotIntegrityComponent) ----------------------

## The worst-off active disease to treat next: latest stage first, then heaviest
## drain. &"" when there's nothing to treat.
func worst_active_disease() -> StringName:
	var worst: StringName = &""
	var worst_stage: int = -1
	var worst_drain: float = -1.0
	for disease_id: StringName in _active:
		var disease: DiseaseData = DiseaseData.by_id(disease_id)
		if disease == null:
			continue
		var stage_idx: int = int(_active[disease_id]["stage"])
		var stage: DiseaseStage = disease.get_stage(stage_idx)
		var drain: float = stage.health_drain_per_hour if stage != null else 0.0
		if stage_idx > worst_stage or (stage_idx == worst_stage and drain > worst_drain):
			worst = disease_id
			worst_stage = stage_idx
			worst_drain = drain
	return worst

## Add `progress_hours` of treatment to the worst active disease. Crossing its
## treat_hours_base cures it (or regresses one stage when cure_at_stage_reset).
## Called by Action_Treat each tick while the pawn lies in a Medical Bay bunk.
func apply_treatment(progress_hours: float) -> void:
	if progress_hours <= 0.0:
		return
	var disease_id: StringName = worst_active_disease()
	if disease_id == &"":
		return
	var disease: DiseaseData = DiseaseData.by_id(disease_id)
	var state: Dictionary = _active[disease_id]
	var progress: float = float(state["treat_progress"]) + progress_hours
	if progress < disease.treat_hours_base:
		state["treat_progress"] = progress
		_active[disease_id] = state
		return
	if disease.cure_at_stage_reset and int(state["stage"]) > 0:
		state["stage"] = int(state["stage"]) - 1
		state["stage_hours"] = 0.0
		state["treat_progress"] = 0.0
		_active[disease_id] = state
		_refresh_effects()
		diseases_changed.emit()
	else:
		cure(disease_id)
		SignalBus.station_alert.emit("%s has recovered from %s" % [_pawn_label(), disease.display_name])

## True while an injured or diseased pawn should be at a Medical Bay.
func wants_treatment() -> bool:
	return has_active_disease() or _health_percent() < treat_seek_health_percent

## Whether the pawn should jump the personal queue: critically injured, or any
## disease has run to its terminal stage.
func _is_critical() -> bool:
	if _health_percent() < critical_health_percent:
		return true
	for disease_id: StringName in _active:
		var disease: DiseaseData = DiseaseData.by_id(disease_id)
		if disease != null and disease.is_final_stage(int(_active[disease_id]["stage"])):
			return true
	return false

func _maybe_seek_treatment() -> void:
	if not wants_treatment():
		_stranded_alerted = false
		return
	if _treatment_job != null and not _treatment_job.is_ended():
		# Already queued/running; promote it to the front if we've turned critical.
		if _is_critical():
			owner_pawn.promote_queued_job(_treatment_job)
		return
	if _retry_cooldown > 0.0:
		return
	_treatment_job = Job.of(&"get_treatment")
	_treatment_job.job_end.connect(_on_treatment_end.bind(_treatment_job), CONNECT_ONE_SHOT)
	# Non-disruptive: treatment runs after the current job finishes (the WI-05
	# needs pattern), unless critical, in which case it jumps the queue front.
	owner_pawn.queue_job(_treatment_job)
	if _is_critical():
		owner_pawn.promote_queued_job(_treatment_job)

func _on_treatment_end(job: Job) -> void:
	if job == _treatment_job:
		_treatment_job = null
	# Still wanting treatment after the attempt (no reachable bay / all bunks full):
	# throttle the next try and alert once so the player knows capacity is short.
	if wants_treatment():
		_retry_cooldown = retry_cooldown_seconds
		if not _stranded_alerted:
			SignalBus.station_alert.emit("%s needs treatment but no Medical Bay is available" % _pawn_label())
			_stranded_alerted = true
	else:
		_stranded_alerted = false

## Re-link a treatment job restored from a save so the seek loop treats it as the
## already-pending job (mirrors adopt_restored_repair_job).
func adopt_restored_treatment_job(job: Job) -> void:
	if _treatment_job == null:
		_treatment_job = job
		job.job_end.connect(_on_treatment_end.bind(job), CONNECT_ONE_SHOT)

# --- helpers ------------------------------------------------------------------

func _needs_component() -> PawnNeedsComponent:
	if _needs == null:
		_needs = owner_pawn.get_component_by_type(PawnNeedsComponent) as PawnNeedsComponent
	return _needs

func _health_component() -> PawnHealthComponent:
	if _health == null:
		_health = owner_pawn.get_component_by_type(PawnHealthComponent) as PawnHealthComponent
	return _health

func _health_percent() -> float:
	var health: PawnHealthComponent = _health_component()
	return health.health_value / health.health_max * 100.0 if health != null and health.health_max > 0.0 else 100.0

func _pawn_label() -> String:
	if owner_pawn != null and not owner_pawn.pawn_name.is_empty():
		return owner_pawn.pawn_name
	return "A crew member"

# --- persistence --------------------------------------------------------------

func get_save_data() -> Dictionary:
	if _active.is_empty():
		return {}
	var out: Dictionary = {}
	for disease_id: StringName in _active:
		var state: Dictionary = _active[disease_id]
		out[String(disease_id)] = {
			"stage": int(state["stage"]),
			"stage_hours": float(state["stage_hours"]),
			"treat_progress": float(state["treat_progress"]),
		}
	return out

func load_save_data(data: Dictionary) -> void:
	_active.clear()
	for id_str: String in data:
		var disease_id := StringName(id_str)
		# A disease removed from data since the save just drops out.
		if DiseaseData.by_id(disease_id) == null:
			continue
		var entry: Dictionary = data[id_str]
		_active[disease_id] = {
			"stage": int(entry.get("stage", 0)),
			"stage_hours": float(entry.get("stage_hours", 0.0)),
			"treat_progress": float(entry.get("treat_progress", 0.0)),
		}
	# Re-derive maluses/mood/move-speed from restored state, never from saved
	# modifiers (the WI-22 trait rule - no doubled modifiers on load).
	_refresh_effects()
	diseases_changed.emit()
