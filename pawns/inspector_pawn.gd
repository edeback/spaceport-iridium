class_name InspectorPawn
extends PawnBase

## The ARC inspector (WI-26): a visitor pawn that tours the station for a tier
## promotion. Reuses the crew sprite + breathing + health, but has no needs,
## schedule, skills, or traits, and is excluded from the crew roster (is_visitor,
## set on the scene). An InspectionRunner drives it via interrupt_with_job; on its
## own it never pulls station work off the board and never wanders - it just holds
## position, so a gap between legs can't send it off to do chores.

## Distinct tint so the inspector reads as an outsider, not crew (WI-26). ARC
## steel-blue; applied on spawn like crew identity tints.
const ARC_TINT: Color = Color(0.62, 0.74, 0.95)

func _ready() -> void:
	super()
	tint = ARC_TINT

## Only ever run what the runner explicitly queued (a follow-up leg); otherwise
## hold position. Deliberately does NOT consult JobManager or wander, mirroring
## MiningDronePawn's narrowed start_job.
func start_job() -> void:
	while not job_queue.is_empty():
		var queued_job: JobBase = job_queue.pop_front()
		if queued_job.is_valid() and queued_job.can_do_job(self):
			_begin_job(queued_job)
			return
		queued_job.cancel(true)
	if animated_sprite != null:
		animated_sprite.play("idle")
