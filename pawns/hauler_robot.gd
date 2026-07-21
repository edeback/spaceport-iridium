class_name HaulerRobotPawn
extends PawnBase

## Robot hauler (WI-27). A pure HAUL-board consumer produced by a Logistics Bay:
## it claims only hauling jobs, never BUILD/WORK/NEEDS, has no schedule (always on
## duty) and no needs, and traverses the station interior (corridors/turbolifts)
## like crew - it never paths to space. Patterned on MiningDronePawn, but claims
## from the shared board instead of a parent component, so construction imports at
## +99 and every other band stay preserved (robots and crew serve one board).

## Owning Logistics Bay component. The bay is the robot's "home" for save/load and
## powers it down / tears it down. Modules load before pawns, so a loaded robot
## re-registers here via set_owner_component().
var parent_bay: LogisticsBayComponent = null

## Driven by the bay each tick: an unpowered bay freezes its robots in place
## (mirrors MiningComponent gating its drones).
@export var powered: bool = true:
	set(new_powered):
		if powered != new_powered:
			powered = new_powered

func _process(delta: float) -> void:
	# Frozen while the bay is unpowered - skip all sim work, including job ticks.
	if powered:
		super(delta)

## HAUL-only claim path (WI-27). Same ordering as PawnBase.start_job - sweep
## carried cargo, drain the personal queue, then the board - but the board claim
## is filtered to HAUL and there's no shift gate or idle-wander fallback (robots
## just hold an idle pose when the board is empty).
func start_job() -> void:
	# Return carried cargo first so a robot never sits on stock it could deposit.
	if inventory_component != null and not inventory_component.is_empty():
		var return_job: Job_StoreInventory = Job_StoreInventory.new()
		if return_job.can_do_job(self):
			_begin_job(return_job)
			return
		# Nowhere takes it right now - fall through and look for other work rather
		# than stalling the robot entirely (matches PawnBase's fall-through).
	# Personal queue next: chained followups / requeued work. Checked once here
	# rather than polled every frame by whatever queued them.
	while not job_queue.is_empty():
		var queued_job: JobBase = job_queue.pop_front()
		if queued_job.is_valid() and queued_job.can_do_job(self):
			_begin_job(queued_job)
			return
		queued_job.cancel(true) # cancel implies end_job (lifecycle contract)
	# Board, HAUL only. Never BUILD/WORK/NEEDS: crew keep those. Priority bands
	# are untouched because robots claim from the same board crew do.
	current_job = Global.job_manager.find_job(self, [JobBase.Category.HAUL])
	if current_job:
		current_job.start_job(self)
	elif animated_sprite != null:
		# No haul waiting - idle pose (no wandering; robots stay put).
		animated_sprite.play("idle")

## Tears the robot down when its bay is removed. Carried cargo is dumped as a
## pile by PawnBase's PREDELETE handler, satisfying the resource invariant.
func self_destruct() -> void:
	if current_job != null:
		current_job.cancel(true)
		current_job = null
	queue_free()

# --- persistence ------------------------------------------------------------

## Modules load before pawns, so a restored robot re-registers with its bay
## (mirrors MiningDronePawn.set_owner_component).
func set_owner_component(bay: LogisticsBayComponent) -> void:
	if bay:
		parent_bay = bay
		parent_bay.register_robot(self)
