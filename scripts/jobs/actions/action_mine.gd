class_name Action_Mine
extends ActionBase

## Chip ore off the asteroid in a slot until the hold is full (WI-44).
##
## The per-unit timing is unchanged from the mining job: drone efficiency x the
## bay's mining_rate stat (so a damaged bay measurably slows) x the miner's
## work_rate for the mining skill. Drones have neither happiness nor skills, so
## that last term resolves to 1.0 for them and their timing is exactly as before.
##
## The remaining quota lives in job.count rather than in this action, and is
## decremented as ore comes in. That is what lets a trip survive its asteroid
## running dry: the driver sends the pawn back to pick a new rock and re-enters
## this action, which must NOT restart the quota. It also means the quota
## persists across a save for free, since job.count is already saved.

## Sim-seconds per unit at rate 1.0.
@export var seconds_per_unit: float = 1.0
## Mining xp per unit, trickled rather than paid on completion because a mining
## trip is long. No-op for drones (no skills component).
@export var xp_per_unit: float = 6.0
@export var slot: JobTarget.Slot = JobTarget.Slot.A
## Slot holding the MiningComponent, for its mining_rate stat.
@export var bay_slot: JobTarget.Slot = JobTarget.Slot.B

## Progress toward the next unit. Saved, so a reload does not silently discard
## most of a unit's work.
var _progress: float = 0.0

func _init(asteroid_slot: JobTarget.Slot = JobTarget.Slot.A,
		mining_bay_slot: JobTarget.Slot = JobTarget.Slot.B) -> void:
	slot = asteroid_slot
	bay_slot = mining_bay_slot
	complete_mode = CompleteMode.CONDITION

func on_start(job: Job) -> Status:
	_progress = 0.0
	return _entry_status(job)

## load_state() has already restored the part-mined unit; keep it.
func on_resume(job: Job) -> Status:
	return _entry_status(job)

func _entry_status(job: Job) -> Status:
	if job.pawn == null or job.pawn.inventory_component == null:
		return Status.FAILED
	# The rock broke up before we got a swing in - another drone took the last
	# unit while we were still flying out. DONE rather than FAILED for the same
	# reason tick() uses DONE: the driver decides whether there is room left in
	# the hold to go find another one.
	if _asteroid(job) == null:
		return Status.DONE
	return Status.ONGOING

func tick(job: Job, delta: float) -> Status:
	var asteroid: AsteroidBase = _asteroid(job)
	if asteroid == null:
		# Emptied out from under us. DONE rather than FAILED: the driver decides
		# whether there is room left in the hold for another rock.
		return Status.DONE
	# Stay glued to the rock while working it, exactly as the pre-WI-44 job did -
	# the drone has no separate mining animation, the position IS the tell.
	job.pawn.position = asteroid.position
	if _is_full(job):
		return Status.DONE
	_progress += delta * _rate(job)
	if _progress < seconds_per_unit:
		return Status.ONGOING
	_progress = 0.0
	# Null when another drone took the last unit this same frame; the is_empty()
	# check on the next tick sends us hunting for a new rock.
	var mined: ResourceData = asteroid.mine_resource()
	if mined == null:
		return Status.ONGOING
	var stack := ResourceStack.new()
	stack.resource_data = mined
	stack.amount = 1
	if mined.has_variance:
		var instance := OreInstanceData.new()
		instance.richness = asteroid.sample_richness()
		stack.instance_data = instance
	job.pawn.inventory_component.add_stacks(mined, [stack])
	job.count = maxi(job.count - 1, 0)
	job.pawn.grant_skill_xp(job.get_skill(), xp_per_unit)
	return Status.ONGOING

func check(job: Job) -> Status:
	if _is_full(job):
		return Status.DONE
	var asteroid: AsteroidBase = _asteroid(job)
	return Status.DONE if asteroid == null or asteroid.is_empty() else Status.ONGOING

func report(_job: Job) -> String:
	return "Mining"

func save_state() -> Dictionary:
	return {} if _progress <= 0.0 else {"progress": _progress}

func load_state(data: Dictionary) -> void:
	_progress = float(data.get("progress", 0.0))

## Quota met, or physically out of room.
func _is_full(job: Job) -> bool:
	if job.count <= 0:
		return true
	return job.pawn.inventory_component != null and job.pawn.inventory_component.space_available() <= 0

func _rate(job: Job) -> float:
	var rate: float = 1.0
	var drone: MiningDronePawn = job.pawn as MiningDronePawn
	if drone != null:
		rate *= drone.drone_efficiency
	var bay: JobTarget = job.target(bay_slot)
	if bay != null and bay.is_alive():
		var mining: MiningComponent = bay.component() as MiningComponent
		if mining != null:
			rate *= mining.get_mining_rate()
	return rate * job.pawn.work_rate(job.get_skill())

func _asteroid(job: Job) -> AsteroidBase:
	var slot_target: JobTarget = job.target(slot)
	return slot_target.asteroid() if slot_target != null else null
