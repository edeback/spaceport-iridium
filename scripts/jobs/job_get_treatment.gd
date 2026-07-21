class_name Job_GetTreatment
extends JobBase

## Personal-queue need job (never on the shared board): a sick or injured crew
## member walks to the nearest reachable powered Medical Bay with a free bunk, lies
## down, and heals - treatment progress accrues on their worst disease and HP
## regenerates - until cured and back to full health. Posted by
## PawnDiseaseComponent. Slot + bunk-anchor claim/release discipline mirrors
## Job_Sleep; treatment progress persists on the disease state, so an interrupted
## session resumes exactly where it left off (progress is never lost on cancel).

var pawn: PawnBase
var medical: MedicalComponent
var _disease: PawnDiseaseComponent = null
## Authored BUNK anchor (WI-16): the patient lies on the bunk, not module centre.
var bunk_anchor: AnchorDef = null
var _bunk_path: PathComponent = null

enum TreatState { Starting, MovingToBay, Treating, Finished, Failed }
var state: TreatState = TreatState.Starting:
	set(new_state):
		if new_state != state:
			state = new_state
			subtask_changed.emit()

func get_category() -> Category:
	return Category.NEEDS

func get_job_description() -> String:
	return "Getting treatment"

func get_subtask_description() -> String:
	match state:
		TreatState.MovingToBay:
			return "Heading to a Medical Bay"
		TreatState.Treating:
			return "Under treatment"
	return ""

func can_do_job(_pawn: PawnBase) -> bool:
	return _find_bay(_pawn) != null

func start_job(_pawn: PawnBase) -> void:
	pawn = _pawn
	_disease = pawn.get_component_by_type(PawnDiseaseComponent) as PawnDiseaseComponent
	medical = _find_bay(pawn)
	if medical == null or not medical.claim_slot(self):
		cancel(true)
		return
	SignalBus.module_removed.connect(_module_removed)
	_bunk_path = medical.owner_module.get_path_component()
	if _bunk_path != null:
		bunk_anchor = _bunk_path.claim_anchor(AnchorDef.AnchorType.BUNK, self)
	state = TreatState.MovingToBay
	pawn.movement_component.movement_ended.connect(_arrived, CONNECT_ONE_SHOT)
	pawn.movement_component.move_to(medical.owner_module, 1.0, false, bunk_anchor)

func _arrived(prev_success: bool) -> void:
	# _ended: a stale movement one-shot after an external cancel must not overwrite
	# the terminal state (WI-04 lifecycle rule).
	if not prev_success or _ended:
		cancel(true)
		return
	if not is_instance_valid(medical) or not medical.powered():
		cancel(true)
		return
	state = TreatState.Treating
	if pawn.animated_sprite != null:
		pawn.animated_sprite.play("lay_down")

func process_job(delta: float) -> void:
	if state != TreatState.Treating:
		return
	if not is_instance_valid(medical):
		cancel(true)
		return
	# delta arrives sim-scaled from PawnBase._process.
	var sim_hours: float = delta / TimeManager.SECONDS_PER_HOUR
	var health: PawnHealthComponent = pawn.get_component_by_type(PawnHealthComponent) as PawnHealthComponent
	# HP regen applied directly, so it works even while a disease suppresses the
	# health component's passive regen (the WI-31 medical-bay override).
	if health != null:
		health.health_value += medical.heal_rate_per_hour() * sim_hours
	# Treatment progress on the worst active disease (worst-first, one at a time).
	if _disease != null and _disease.has_active_disease():
		_disease.apply_treatment(medical.treatment_per_hour() * sim_hours)
	# Done when nothing's left to treat and HP is topped up.
	var healed: bool = health == null or health.health_value >= health.health_max
	if (_disease == null or not _disease.has_active_disease()) and healed:
		state = TreatState.Finished

func _module_removed(module: ModuleBase) -> void:
	# Bay deconstructed mid-treatment: cancel gracefully; the disease component's
	# retry throttle finds another bay next attempt.
	if medical != null and module == medical.owner_module:
		cancel(true)

func _on_cancel(as_failed: bool) -> void:
	if as_failed:
		state = TreatState.Failed
	else:
		state = TreatState.Finished

func _on_end() -> void:
	if SignalBus.module_removed.is_connected(_module_removed):
		SignalBus.module_removed.disconnect(_module_removed)
	# Slot + anchor released on EVERY termination path.
	if is_instance_valid(medical):
		medical.release_slot(self)
	if _bunk_path != null and is_instance_valid(_bunk_path):
		_bunk_path.release_anchor(self)
	# Stand back up however the job ended - lay_down isn't a self-replacing state.
	if pawn != null and is_instance_valid(pawn) and pawn.animated_sprite != null \
			and pawn.animated_sprite.animation == &"lay_down":
		pawn.animated_sprite.play("idle")

func is_failed() -> bool:
	return state == TreatState.Failed

func is_finished() -> bool:
	return state == TreatState.Finished

# --- persistence (WI-21/WI-31) ------------------------------------------------

## No target ref: start_job() re-finds the nearest bay and re-claims a slot on
## load. SaveManager re-links it via PawnDiseaseComponent.adopt_restored_treatment_job
## so the seek loop doesn't queue a duplicate.
func get_save_data() -> Dictionary:
	return {"type": "get_treatment"}

static func restore(_data: Dictionary) -> JobBase:
	return Job_GetTreatment.new()

## Nearest reachable, powered Medical Bay with a free bunk. Pure query - safe from
## can_do_job.
func _find_bay(_pawn: PawnBase) -> MedicalComponent:
	var best: MedicalComponent = null
	var best_dist: int = 0
	var pawn_cell: Vector2i = Global.world_to_cell(_pawn.global_position)
	for node: Node in _pawn.get_tree().get_nodes_in_group("medical_bay"):
		var candidate: MedicalComponent = node as MedicalComponent
		if candidate == null or not candidate.is_available():
			continue
		if not Global.path_manager.is_reachable(_pawn, candidate.owner_module):
			continue
		var dist: int = candidate.owner_module.module_cell.distance_squared_to(pawn_cell)
		if best == null or dist < best_dist:
			best = candidate
			best_dist = dist
	return best
