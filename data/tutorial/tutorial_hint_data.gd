class_name TutorialHintData
extends Resource

## One thing SAI knows how to warn you about (WI-63 §1). Authored as a `.tres`
## under `res://data/tutorial/`.
##
## **A hint is two files**, the same shape [EventData] took in WI-62: this
## resource decides *when* it happens, and the `.dialogue` file it points at
## decides what is said and what is highlighted. Nothing here describes a
## consequence, because a hint has none - it is advice.
##
## ## Why this is not an [EventData]
##
## They are close, and there is precedent for a non-random event: `insolvency_
## warning` is a `weight = 0` event fired from code by [EconomyManager]. But four
## of [EventData]'s fields - `weight`, `min_cycle`, `cooldown_cycles`,
## `conditions` - are meaningless here, and a resource where half the fields must
## be left at zero is one that will eventually be filled in wrong. A hint under
## `ContentPaths.EVENTS` would also join the weighted roll's candidate list and
## the event reachability sweep, both of which would then need a special case.
##
## ## Firing
##
## A hint fires **at most once per run** and is then spent forever - see
## [TutorialLedger]. Its watcher is disconnected rather than merely skipped, so a
## spent hint costs nothing for the rest of the save.

## Stable identifier. Also the ledger key, so renaming one in a shipped build
## makes every save think it has not been given yet.
@export var id: StringName = &""

## Which [TutorialTriggers] entry arms this hint. An undeclared trigger is
## refused at load: a hint watching for something nothing ever emits is invisible
## rather than broken, which is the worst way for it to fail.
@export var trigger: StringName = &""

## The one discriminator its trigger takes, or empty for a trigger that takes
## none. The body profile id for `space_body_arrived`, the need name for
## `need_critical`. Meaning is the trigger's to define; the content sweep only
## checks that a filter is present exactly where one is expected.
@export var trigger_filter: StringName = &""

## The script. A hint with no dialogue would spend itself and say nothing.
@export var dialogue: DialogueResource

## Which cue in [member dialogue] to start from. Validated at load against
## `get_cues()`, for the same reason [member EventData.cue] is: a typo'd cue is a
## hint that fires, spends itself, and shows nothing, once, unrepeatably.
@export var cue: String = ""

## The transmission subject.
@export var title: String = ""

## The transmission body - the durable copy of the advice.
##
## **A hint always transmits, and that is not a flag.** It fires once and never
## again; a player who was mid-placement when it appeared and clicked through it
## has permanently lost it otherwise. WI-57's line between the two lists is that
## an alert is "look at this now" and a transmission is "this arrived, read it
## later" - a hint is both, and there is no hint for which the answer is no.
@export_multiline var body: String = ""

## Whether this hint's trigger supplies a subject (a pawn or a module) for
## `guide.point_at_subject()` and `guide.subject_name()` to reach. Presentation
## only: the watcher decides what it hands over, this records what the author may
## rely on, and the content sweep checks the dialogue does not ask for a subject
## the trigger never provides.
@export var has_subject: bool = false

## Why this hint could never say anything, or "" when it is sound. Same shape and
## same reason as [method EventData.script_problem]: the manager checks it at load
## and the content sweep checks it in CI, and both have to be asking the one
## question rather than two that can drift apart.
func script_problem() -> String:
	if dialogue == null:
		return "names no dialogue resource"
	if cue.is_empty():
		return "names no cue"
	if not dialogue.get_cues().has(cue):
		return "names cue '%s', which is not in %s" % [cue, dialogue.resource_path]
	return ""
