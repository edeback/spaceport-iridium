class_name HaulerRobotPawn
extends RobotPawnBase

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

## HAUL-only board claim (WI-27). The shared RobotPawnBase.start_job handles the
## cargo sweep, personal queue, and the WI-28 energy gates; this hook supplies the
## board claim, filtered to HAUL - never BUILD/WORK/NEEDS, which crew keep. Priority
## bands are untouched because robots claim from the same board crew do. No shift
## gate or idle-wander fallback (robots just hold an idle pose when the board is empty).
func _claim_work_job() -> void:
	current_job = Global.job_manager.find_job(self, [JobBase.Category.HAUL])
	if current_job != null:
		current_job.start_job(self)
	elif animated_sprite != null:
		# No haul waiting - idle pose (no wandering; robots stay put).
		animated_sprite.play("idle")

## Destroyed (WI-28): drop off the bay's roster so it frees a slot under the cap
## and the player can buy a replacement.
func _notify_owner_removed() -> void:
	if parent_bay != null:
		parent_bay.notify_robot_destroyed(self)

# --- persistence ------------------------------------------------------------

## Modules load before pawns, so a restored robot re-registers with its bay
## (mirrors MiningDronePawn.set_owner_component).
func set_owner_component(bay: LogisticsBayComponent) -> void:
	if bay:
		parent_bay = bay
		parent_bay.register_robot(self)
