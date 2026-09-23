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

## Never saved (WI-26). The inspector is driven by a runtime-only InspectionRunner
## that a load doesn't restore, so a saved inspector would dangle; instead the
## in-progress inspection cancels cleanly on load and the offer re-rolls. Guest
## visitors, whose behaviour is their own needs, ARE saved.
func is_saved() -> bool:
	return false

## Only ever run what the runner explicitly queued (a follow-up leg); otherwise
## hold position. Three hooks on the one PawnBase.start_job (WI-74 §1): no cargo
## sweep, no work, and an idle pose rather than a wander - so a gap between legs
## can never send it off to do chores. It has no restored job to resume, since it
## is never saved.
func _sweeps_cargo() -> bool:
	return false

func _claim_work_job() -> bool:
	return false

func _fallback_job() -> void:
	_idle_pose()
