class_name MiningDronePawn
extends RobotPawnBase

@export var drone_efficiency: float = 0.2

var parent_mining_component: MiningComponent = null

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

## Modules load before pawns, so register this drone with its MiningComponent
func set_owner_component(mining_component: MiningComponent) -> void:
	if mining_component:
		parent_mining_component = mining_component
		parent_mining_component.register_drone(self)
