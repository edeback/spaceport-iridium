class_name JobData
extends Resource

## The definition of a job *type* (WI-44) - RimWorld's JobDef. One `.tres` per
## type under `data/jobs/`, discovered by ResourceScanner the same way
## ModuleData and UnlockData are, which is what lets JobSerializer's
## hand-maintained type-id -> factory table go away: a new job type becomes
## known to the save system by existing in the directory.
##
## Everything here is static configuration shared by every instance of the type.
## Per-instance state (targets, count, progress) lives on Job.

## Which board queue jobs of this type live in.
enum Category { HAUL, BUILD, WORK, NEEDS, MOVE, MISC }

@export var id: StringName = &""
@export var display_name: String = ""

## Report text shown in the pawn's job tab and the board inspector. The
## placeholders {a} {b} {c} {resource} {count} are substituted from the Job's
## own targets by Job.report(), so a new job type gets usable text without
## writing any. Leave empty to fall back to display_name.
@export_multiline var report_template: String = ""

@export var category: Category = Category.MISC

## The skill (WI-22) whose multiplier gates this job's work rate and that gains
## xp on completion. &"" = unskilled: no multiplier, no xp.
@export var skill: StringName = &""

## XP granted to `skill` on SUCCESSFUL completion. Long jobs that trickle xp as
## they work (mining) leave this at 0 and grant from their action instead.
@export var xp_reward: float = 0.0

@export var player_cancelable: bool = true

## false = a system re-derives this job on load, so the pawn's copy is dropped
## rather than saved. This is the data-driven replacement for the "deliberately
## NOT registered" list that used to live as a comment in job_serializer.gd:
## idle, idle-wander, store-inventory, leave-station.
@export var saveable: bool = true

## Script whose class extends JobDriver - the per-type behaviour. Held as a
## Script reference rather than a class_name string so that renaming the driver
## is caught when the resource is loaded, not when a pawn first tries the job.
@export var driver: Script = null

## Deliberately NOT here: priority. Storage priority is the routing language
## (construction imports at +99, deconstruction exports at -99) and is computed
## per-post by the component that posts the job, so a per-type default would
## only ever serve the handful of types that post at a fixed number. Priority
## lives on Job, set by the poster.

func category_name() -> String:
	return String(Category.keys()[category]).capitalize()
