class_name TutorialTriggers
extends RefCounted

## What SAI is allowed to react to (WI-63 §5).
##
## A trigger is a bare string on both sides of a contract - named in a
## [TutorialHintData] `.tres`, watched for in [TutorialManager] - and the typo is
## silent in the direction that matters: a hint naming `&"module_unpowerd"` simply
## never fires, forever, with nothing on screen to say so. So triggers are
## **declared**, exactly as [Groups] (WI-41), [UIType] (WI-49) and [StoryFlags]
## (WI-62) declare theirs.
##
## The declaration also records whether the trigger takes a **filter** - the one
## discriminator [member TutorialHintData.trigger_filter] carries. It is what lets
## the three critical-need hints share one watcher instead of being three copies
## of it, and what lets the comet hint pick its body kind out of a generic
## arrival. A filter present on a trigger that takes none is an authoring mistake
## the content sweep catches.
##
## Pure: no [Global], no [SignalBus], no nodes. [TutorialManager] owns the
## watchers; this class only knows which ones there are.

## A trigger id -> whether it takes a [member TutorialHintData.trigger_filter].
##
## Adding one here is half the job; the other half is a watcher in
## [TutorialManager], which is why `test_tutorial_triggers.gd` asserts the two
## tables agree.
const DECLARED: Dictionary[StringName, bool] = {
	## A built module the crew cannot walk to, for longer than the grace window.
	## No filter: a module is a module.
	&"module_unreachable": false,
	## A power consumer that has been dark for longer than the grace window, and
	## is not dark because the player switched it off.
	&"module_unpowered": false,
	## A trader has docked. No filter - the hint is about trading, not about who.
	&"trader_arrived": false,
	## A mineable body has entered the envelope. **Filtered by the profile id**
	## (`comet`), so a mod's own body kind can carry its own hint with no core
	## edit and the asteroid belt does not trip the comet's advice.
	&"space_body_arrived": true,
	## A crew member has given notice and is inside their grace window.
	&"crew_resigning": false,
	## A pawn need has crossed into its critical band. **Filtered by the need
	## name** (`hunger`, `sleep`, `recreation`) - one watcher, three hints.
	&"need_critical": true,
}

## Triggers declared at runtime by a mod. Kept separate from [constant DECLARED]
## so the base game's table stays a readable const and a mod cannot quietly
## redefine a vanilla trigger's arity.
var _extra: Dictionary[StringName, bool] = {}

func is_declared(id: StringName) -> bool:
	return DECLARED.has(id) or _extra.has(id)

## Declares a trigger a mod owns and watches itself. Re-declaring an existing id
## is refused rather than overwritten - two mods claiming one trigger would
## otherwise depend on load order.
func declare(id: StringName, takes_filter: bool) -> bool:
	if id == &"":
		push_error("TutorialTriggers: refusing to declare a trigger with no id")
		return false
	if is_declared(id):
		push_error("TutorialTriggers: '%s' is already declared" % id)
		return false
	_extra[id] = takes_filter
	return true

## Whether `id` carries a [member TutorialHintData.trigger_filter]. An undeclared
## id answers false **and** errors: returning a plausible answer silently is how a
## typo survives to ship.
func takes_filter(id: StringName) -> bool:
	if DECLARED.has(id):
		return DECLARED[id]
	if _extra.has(id):
		return _extra[id]
	push_error("TutorialTriggers: no such trigger '%s' - declare it in DECLARED" % id)
	return false

## Every trigger there is, vanilla first then mods', each set sorted so a sweep
## reports in a stable order.
func all() -> Array[StringName]:
	var out: Array[StringName] = DECLARED.keys()
	out.sort()
	var extra: Array[StringName] = _extra.keys()
	extra.sort()
	out.append_array(extra)
	return out
