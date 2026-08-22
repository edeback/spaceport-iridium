class_name EventData
extends Resource

## One random event definition (WI-13, rewritten in WI-62). Authored as a `.tres`
## under `res://data/events/`. Definition only - cooldowns, the pending queue and
## timed-effect state are runtime state held by [EventManager], never written back
## onto this shared resource.
##
## ## What an event is after WI-62
##
## **This resource keeps eligibility and pacing. A `.dialogue` file owns the
## script and the consequences.** The old `choices` / `auto_effects` fields and
## the [EventChoice] and `EventEffect` classes behind them are gone; what an event
## *does* is written as mutations in its dialogue, through the `station` and
## `story` vocabularies ([DialogueBridge], [StoryState]).
##
## [EventCondition] stayed, and the asymmetry is deliberate. A condition answers
## *"may this event fire at all"*, and [method EventManager.try_fire_random_event]
## needs that answer for every candidate **before** any conversation exists, in
## order to weight the roll. Expressing it as an `if` inside the dialogue would
## mean opening a conversation to discover it should not have happened - burning
## the roll and showing nothing. An effect had no such caller.
##
## ## Notification events
##
## An event whose cue contains no dialogue lines - only mutations and a jump to
## END - runs headlessly: the balloon never shows a line, never takes the pause
## hold, and frees itself. That is the whole mechanism, and it is why there is no
## `is_silent` flag here and no branch in [EventManager]. Whether an event
## interrupts the player is a property of what its author wrote.

## Stable identifier, used for save/load (cooldowns, pending queue) and by
## `story.queue_event`. Must be unique and non-empty.
@export var id: StringName = &""

## The alert headline and the transmission subject.
@export var title: String = ""

## **The Comms row, not card text.** Nothing renders this as prose to answer any
## more - the conversation says what is happening. This is the durable record a
## player who was mid-placement can go back and read.
@export_multiline var body: String = ""

## The script. An event with no dialogue resource never fires: it would log a
## transmission and then do nothing, forever, silently.
@export var dialogue: DialogueResource

## Which cue in [member dialogue] to start from. Validated at load against
## `get_cues()` - a typo'd cue is the worst failure this design can produce, so it
## is the one thing checked eagerly.
@export var cue: String = ""

## Relative chance among eligible events when a natural roll fires.
@export var weight: float = 1.0
## Earliest cycle this event may occur naturally.
@export var min_cycle: int = 1
## Cycles after firing before this event is eligible again.
@export var cooldown_cycles: int = 4
## All must hold for the event to be eligible.
@export var conditions: Array[EventCondition] = []

## The station-wide mood modifier ids this event's dialogue can apply, if any.
##
## Declared here rather than discovered, because after WI-62 there is nothing left
## to discover them from: [MoodCatalog] used to scan the authored
## `EventEffectHappinessModifier` resources to learn that the modifier
## "meteor_lightshow" belongs to the event "morale_lightshow", and those resources
## are gone. Without the mapping the Needs tab prints a modifier the player cannot
## account for, which is the exact defect WI-51 added the breakdown to fix.
##
## A modifier id that is simply `event_<this event's id>` needs no entry -
## [MoodCatalog] recovers that shape by stripping the prefix.
@export var mood_ids: PackedStringArray = []

func is_eligible(current_cycle: int) -> bool:
	if current_cycle < min_cycle:
		return false
	return conditions_met()

## The condition half on its own. A **scheduled** event (`story.queue_event`)
## skips the roll, the cooldown and `min_cycle` - it was already decided by a
## choice the player made - but still has to make sense in the world it lands in.
func conditions_met() -> bool:
	for condition: EventCondition in conditions:
		if condition != null and not condition.is_met():
			return false
	return true

## Whether this event can actually be run. Checked once at load, so a broken
## definition is a warning on startup rather than a dead event nobody notices.
## Returns an empty string when it is fine, or the reason it is not.
func script_problem() -> String:
	if dialogue == null:
		return "names no dialogue resource"
	if cue.is_empty():
		return "names no cue"
	if not dialogue.get_cues().has(cue):
		return "names cue '%s', which is not in %s" % [cue, dialogue.resource_path]
	return ""
