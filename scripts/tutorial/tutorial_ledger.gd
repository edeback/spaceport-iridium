class_name TutorialLedger
extends RefCounted

## What the tutorial remembers (WI-63 §6): whether the introduction ran, whether
## the player opted out, and which advisories SAI has already given.
##
## Pure: no [Global], no [SignalBus], no nodes. [TutorialManager] owns an instance
## and does the arming and disarming; this class only knows the rules.
##
## ## The one rule that is easy to get wrong
##
## **A hint fires once per run and is then spent forever.** "Spent" is not a
## filter applied at fire time - [TutorialManager] *disconnects* the watcher, so a
## spent hint costs nothing for the rest of the save. This class is what tells it
## when to do that, which is why [method spend] reports whether the spend was new:
## a second call must not look like a first.
##
## ## The migration decision
##
## A save written before this feature existed has no `tutorial` section at all.
## [method mark_legacy] is what such a save restores as, and it marks **everything
## complete** rather than everything fresh. The alternative would have a
## two-hundred-module veteran station stop dead to explain what a corridor is. A
## save that predates the tutorial belongs to somebody who already knows.

## Whether the onboarding conversation has run to its end (or been abandoned,
## which counts - see [method skip]).
var onboarding_done: bool = false

## Whether the player opted out, at New Game or from the coach mark's skip
## control. Distinct from [member onboarding_done] because AIDE says different
## things about the two, and because a skipped run has every hint spent while a
## completed one does not.
var skipped: bool = false

## Hint ids in the order they fired, oldest first. An array rather than a set
## because the AIDE archive renders newest-first and a set has no order to
## reverse. Membership tests go through [method is_spent], which is O(n) over a
## list that never exceeds the hint count.
var _spent: Array[StringName] = []

# --- hints ----------------------------------------------------------------------

func is_spent(id: StringName) -> bool:
	return _spent.has(id)

## Records that `id` has been given. Returns **true only the first time**, which
## is the signal [TutorialManager] disconnects the watcher on. A repeat is not an
## error - two triggers can race in one tick - it is simply not news.
func spend(id: StringName) -> bool:
	if id == &"":
		push_error("TutorialLedger: refusing to spend a hint with no id")
		return false
	if _spent.has(id):
		return false
	_spent.append(id)
	return true

## Everything SAI has said this run, oldest first. The AIDE archive reverses it.
func spent_hints() -> Array[StringName]:
	return _spent.duplicate()

func spent_count() -> int:
	return _spent.size()

# --- whole-tutorial state -------------------------------------------------------

## The onboarding reached its end normally.
func complete_onboarding() -> void:
	onboarding_done = true

## The player opted out, from either door. **Every hint is spent too**, and that
## is the whole content of the decision: a player who skipped the tutorial has
## said they know how to play, and a game that keeps interrupting them anyway did
## not listen. AIDE is where they go if they change their mind.
##
## `every_hint` is the full id list, since the ledger does not scan content.
func skip(every_hint: Array[StringName]) -> void:
	onboarding_done = true
	skipped = true
	for id: StringName in every_hint:
		if not _spent.has(id):
			_spent.append(id)

## What a save with no `tutorial` section restores as. Same shape as [method skip]
## but records itself as *not* skipped: the player never opted out, the feature
## simply did not exist when they started. AIDE reads the difference.
func mark_legacy(every_hint: Array[StringName]) -> void:
	onboarding_done = true
	for id: StringName in every_hint:
		if not _spent.has(id):
			_spent.append(id)

## Nothing has happened yet. The cheat surface's `reset_tutorial()`, and what a
## fresh run starts as.
func clear() -> void:
	onboarding_done = false
	skipped = false
	_spent.clear()

# --- persistence ----------------------------------------------------------------

## Always writes `onboarding_done`, so a saved section is never an empty
## dictionary and can therefore never be mistaken for the missing-section case.
func to_save() -> Dictionary:
	var ids := PackedStringArray()
	for id: StringName in _spent:
		ids.append(String(id))
	return {
		"onboarding_done": onboarding_done,
		"skipped": skipped,
		"spent": ids,
	}

## Restores. `known` is every hint id that currently exists; a saved id that is no
## longer one of them (a mod was removed) is dropped with a warning rather than
## kept, exactly as [method StoryFlags.from_save] drops an unknown flag - keeping
## it would let it come back if the mod ever returned, carrying a decision from a
## run that no longer makes sense.
func from_save(data: Dictionary, known: Array[StringName]) -> void:
	clear()
	onboarding_done = bool(data.get("onboarding_done", false))
	skipped = bool(data.get("skipped", false))
	for raw: Variant in data.get("spent", []):
		var id := StringName(str(raw))
		if not known.has(id):
			push_warning("TutorialLedger: dropping unknown saved hint '%s'" % id)
			continue
		if not _spent.has(id):
			_spent.append(id)
