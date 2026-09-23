class_name MiningDronePawn
extends RobotPawnBase

@export var drone_efficiency: float = 0.2

var parent_mining_component: MiningComponent = null

## Numbered station-wide, not per bay: two Mining Bays produce Mining Droid 1-6,
## not two sets of 1-3 (see RobotDesignation).
func default_designation() -> String:
	return "Mining Droid"

## Drones only mine, and only for their own bay - never the shared board. The
## shared RobotPawnBase.start_job handles the cargo sweep, personal queue, and the
## WI-28 energy gates; these two hooks supply the drone-specific bits.
func _claim_work_job() -> void:
	if parent_mining_component != null:
		current_job = parent_mining_component.get_next_job(self)
	if current_job != null:
		current_job.start_job(self)
	elif animated_sprite != null:
		# No job, idle pose
		animated_sprite.play("idle")

## Drones head for their own bay's output storage first. Pre-setting the target
## is enough: the sweep's finder skips a slot that is already resolved. If the bay
## will not take everything, the sweep's loop then finds somewhere that will,
## rather than the drone stalling with cargo it cannot put down - a small
## relaxation of the old "own bay only" rule, in the direction of not deadlocking.
func _make_store_inventory_job() -> Job:
	var return_job: Job = Job.of(&"store_inventory")
	if parent_mining_component != null and parent_mining_component.output_storage != null:
		return_job.target_a = JobTarget.of_component(parent_mining_component.output_storage)
	return return_job

## Destroyed (WI-28): drop off the bay's roster so its respawn timer builds a
## replacement (a bay always keeps up to max_drones running).
func _notify_owner_removed() -> void:
	if parent_mining_component != null:
		parent_mining_component.notify_drone_destroyed(self)

# --- persistence ------------------------------------------------------------

## The bay's MiningComponent, as a component ref. A drone with no bay writes no
## key, which reads back as no bay.
func save_kind_data(entry: Dictionary) -> void:
	super(entry)
	if parent_mining_component != null:
		entry["mining_comp"] = SaveRefs.component_ref(parent_mining_component)

## Modules load before pawns, so the bay is already placed and the drone can
## re-register with it. A ref that no longer resolves hands set_owner_component a
## null, which leaves the drone ownerless rather than erroring.
func load_kind_data(entry: Dictionary) -> void:
	super(entry)
	set_owner_component(SaveRefs.resolve_component_ref(entry.get("mining_comp", {})) as MiningComponent)

## Modules load before pawns, so register this drone with its MiningComponent
func set_owner_component(mining_component: MiningComponent) -> void:
	if mining_component:
		parent_mining_component = mining_component
		parent_mining_component.register_drone(self)
