class_name Job_WorkProcessor
extends JobBase

## Operating a manned processor (WI-23). Posted by a ProcessorComponent whose
## requires_worker is set once a batch is readied and no worker is engaged. The
## pawn walks to the module's WORKSTATION anchor (playing its authored
## animation), then drives the batch's progress forward each tick at its
## happiness x crafting-skill rate. On batch completion it chains a followup
## (staying at the machine) when there's more work and it's still on shift,
## otherwise it ends and the pawn moves on.

var pawn: PawnBase
var processor: ProcessorComponent
## The module's PathComponent and the WORKSTATION anchor claimed on it. anchor
## may be null (module authored none) - the pawn then works at the module center.
var _path_component: PathComponent = null
var anchor: AnchorDef = null

## XP granted to the worker skill per completed batch (WI-22 completion-style).
var batch_xp_reward: float = 12.0

var state: WorkState = WorkState.Starting:
	set(new_state):
		if new_state != state:
			state = new_state
			subtask_changed.emit()

enum WorkState { Starting, MovingToStation, Working, Finished, Failed }

func get_category() -> Category:
	return Category.WORK

func get_skill() -> StringName:
	if processor != null:
		return processor.worker_skill
	return &"crafting"

## Completion xp: paid once per finished batch (see PawnBase._end_current_job).
func xp_reward() -> float:
	return batch_xp_reward

func get_job_description() -> String:
	if processor != null and is_instance_valid(processor.owner_module) and processor.owner_module.module_data != null:
		return "Operate " + processor.owner_module.module_data.name
	return "Operate processor"

func get_subtask_description() -> String:
	match state:
		WorkState.MovingToStation:
			return "Walking to workstation"
		WorkState.Working:
			return "Working"
	return ""

## Wires the job to its processor and adopts the module's workspace gate (WI-23),
## so only assignees can claim it and assignees get the affinity bump.
func setup(component: ProcessorComponent) -> void:
	assert(component != null and component.owner_module != null)
	processor = component
	workspace = component.owner_module.get_component_by_type(WorkspaceComponent) as WorkspaceComponent
	SignalBus.module_removed.connect(_module_removed)

## Alive while there's work to do: the processor exists and either has a batch in
## progress or could ready one. Not tied to `processing` alone, so the job
## survives the brief between-batch moment when a chained followup takes over.
## Also invalid if the processor is turned off (intentionally or brownout)
func is_valid() -> bool:
	return is_instance_valid(processor) and is_instance_valid(processor.owner_module) \
		and (processor.has_active_batch() or processor.can_ready_batch()) \
		and (processor.power_consumer == null or processor.power_consumer.powered)

func can_do_job(_pawn: PawnBase) -> bool:
	if not is_valid():
		return false
	# Workspace gate (WI-23): assignees only when the module has an assignment.
	if workspace != null and not workspace.allows(_pawn):
		return false
	return Global.path_manager.is_reachable(_pawn, processor.owner_module)

func start_job(_pawn: PawnBase) -> void:
	pawn = _pawn
	_path_component = processor.owner_module.get_path_component()
	if _path_component != null:
		# WORKSTATION anchors aren't generated; null just means "work at center".
		anchor = _path_component.claim_anchor(AnchorDef.AnchorType.WORKSTATION, self)
	_move_to_station()

func _move_to_station() -> void:
	state = WorkState.MovingToStation
	pawn.movement_component.movement_ended.connect(_arrived, CONNECT_ONE_SHOT)
	pawn.movement_component.move_to(processor.owner_module, 1.0, false, anchor)

func _arrived(success: bool) -> void:
	# _ended: a stale movement one-shot after an external cancel must not revive
	# the job (Failed -> Working would strand the pawn on a dead job).
	if _ended:
		return
	if not success or not is_valid():
		cancel(true)
		return
	state = WorkState.Working
	# Play the anchor's authored animation (interact, ...) at the workstation.
	pawn.begin_anchor_animation(anchor)

func process_job(_delta: float) -> void:
	if state != WorkState.Working:
		return
	if not is_valid():
		cancel(true)
		return
	# Rate folds worker happiness x crafting skill, floored (WI-22). advance_work
	# returns true only on the tick the batch completes.
	if processor.advance_work(_delta * pawn.work_rate(get_skill())):
		_complete_batch()

func _complete_batch() -> void:
	# Resolve the followup synchronously (like Job_GetResource): the processor's
	# own _process could run before or after the pawn's, so hand the next batch
	# over now rather than waiting to be asked. adopt keeps the processor from
	# posting a duplicate board job during the handoff.
	var followup: Job_WorkProcessor = _build_followup()
	if followup != null:
		processor.adopt_followup_work_job(followup)
		pawn.queue_job(followup, true)
	state = WorkState.Finished

## A fresh job for the same processor when it makes sense to keep working: still
## on shift, no queued needs waiting, more work available, still allowed and
## reachable. Null ends the shift at this machine.
func _build_followup() -> Job_WorkProcessor:
	if pawn == null or not is_instance_valid(processor) or not is_instance_valid(processor.owner_module):
		return null
	if not pawn.is_on_shift():
		return null
	# Queued needs (eat/sleep) outrank chaining another batch - let them run.
	if not pawn.job_queue.is_empty():
		return null
	if not (processor.has_active_batch() or processor.can_ready_batch()):
		return null
	if workspace != null and not workspace.allows(pawn):
		return null
	if not Global.path_manager.is_reachable(pawn, processor.owner_module):
		return null
	var followup := Job_WorkProcessor.new()
	followup.setup(processor)
	return followup

func _module_removed(module: ModuleBase) -> void:
	if is_instance_valid(processor) and module == processor.owner_module:
		state = WorkState.Failed

func _on_cancel(as_failed: bool) -> void:
	if as_failed:
		state = WorkState.Failed
	else:
		state = WorkState.Finished

func _on_end() -> void:
	if SignalBus.module_removed.is_connected(_module_removed):
		SignalBus.module_removed.disconnect(_module_removed)
	# Release the workstation claim on EVERY end path (reservation discipline).
	if _path_component != null and is_instance_valid(_path_component):
		_path_component.release_anchor(self)
	# Tell the processor we're gone so it re-posts if a batch still needs work -
	# unless we already handed off to a followup (then _work_job points elsewhere).
	if is_instance_valid(processor):
		processor.notify_work_job_ended(self)
	# Stop the workstation animation; a chained followup replays it on arrival.
	if pawn != null and is_instance_valid(pawn):
		pawn.end_anchor_animation()

func is_failed() -> bool:
	return state == WorkState.Failed

func is_finished() -> bool:
	return state == WorkState.Finished

# --- persistence (WI-21) ------------------------------------------------------

## Records the processor; the batch's own progress lives in the processor's save
## data. Restart is from Starting (re-walk to the station), resuming the batch
## the processor restored. Dropped if we can't identify the module (never
## happens for a live job, but keeps hand-edited saves safe).
func get_save_data() -> Dictionary:
	if processor == null or not is_instance_valid(processor):
		return {}
	return {
		"type": "work_processor",
		"processor": SaveManager.component_ref(processor),
	}

static func restore(data: Dictionary) -> JobBase:
	var component: ProcessorComponent = SaveManager.resolve_component_ref(data.get("processor", {})) as ProcessorComponent
	if component == null:
		return null
	var job := Job_WorkProcessor.new()
	job.setup(component)
	# Claim the processor's outstanding-job slot immediately so its _process
	# doesn't post a duplicate board job before this restored pawn runs it.
	component.adopt_followup_work_job(job)
	return job
