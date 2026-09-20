class_name AlertData
extends RefCounted

## One alert (WI-53).
##
## The reason this exists at all: `SignalBus.station_alert(message: String)` has
## fifty-odd emit sites and a `String` carries no severity, no subject and no
## identity - which is why the strip it fed could not do better than "red text
## for fifteen seconds, then gone forever". Everything this work item adds
## (priority tiers, jump-to, dedupe, a history log) is a field on this record.
##
## The [member title] / [member detail] split is the design's alert row: a name
## over a meta line. `"Hull breach in Reactor Hall! Emergency bulkheads will seal
## in 1.5 hours."` becomes `Hull breach` / `REACTOR HALL · SEALS IN 1.5H`, which
## reads in a glance instead of a sentence.
##
## Not a [Resource]: alerts are created dozens per session, live in an array, and
## have no `.tres` on disk. The classification *rules* are [AlertRules], which is
## static and testable; this is only the record they operate on.

## The three tiers, and the whole point of the item - importance is enforced
## rather than merely styled.
enum Priority {
	## Transient. Someone is hungry; it fades after [constant AlertRules.LOW_TTL_SECONDS].
	LOW,
	## Sticky: it stays in the feed until the player clicks it.
	HIGH,
	## Sticky *and* holds the sim paused until acknowledged. Deliberately tiny -
	## a tier that pauses the game is only useful if it almost never fires.
	CRITICAL,
}

## Dedupe key. Repeats of the same id refresh the existing alert rather than
## stacking a second row, so a module breaching twice is one alert and two
## modules breaching are two ([method AlertRules.make_id] builds the shape).
var id: StringName = &""

var priority: Priority = Priority.LOW

## What happened. Short, sentence case, no trailing punctuation - it is a row
## title, not a sentence.
var title: String = ""

## Who or where, plus the specifics. Rendered in caps by the row, so write it in
## normal case with `·` separators.
var detail: String = ""

## The [PawnBase] / [ModuleBase] / [Node2D] this alert is about, or null.
##
## A **live object reference**, not an id, and therefore `is_instance_valid`
## checked at click time and at render time: a history row routinely outlives its
## subject.
##
## A *live* row does not (WI-71 F27). An alert is never dropped because its
## condition might still be true and unread - but a subject that has been freed
## has no condition left to be true, and its JUMP goes nowhere, so
## [method AlertManager.sweep] drops those and [method AlertManager.resolve_for_subject]
## does it immediately on the removals and departures that can be seen coming.
## The history log keeps the record, exactly as it does for a resolved alert.
var subject: Variant = null

## A mode the row opens instead of jumping, for an alert about something with no
## position (a contract offer opens Trade). A [StringName] rather than a
## `ModeManager.Mode` so this record stays free of any dependency on `ui/`; the
## feed maps it. Empty means "no route".
var route: StringName = &""

## Sim-time stamp. Game facts are stamped in cycles and hours; the LOW age-out is
## wall-clock ([member raised_at]). Both are correct and they are not unified.
var cycle: int = 0
var hour: int = 0

## Wall-clock seconds (`Time.get_ticks_msec() / 1000.0`) when the alert was
## raised or last refreshed. Feeds the LOW age-out, which is a UI affordance and
## must not stretch because the player paused.
var raised_at: float = 0.0

## Monotonic raise counter, assigned by [AlertManager]. The recency tiebreak
## sorts on this rather than on [member raised_at]: `Array.sort_custom` is not
## stable and two alerts raised in the same millisecond must not swap between
## frames.
var sequence: int = 0

## How many times this id has been raised. Repeats refresh rather than stack, so
## the count is the only trace a repeat leaves.
var count: int = 1

## Set when the player clicks the row. For a CRITICAL this is what releases the
## pause hold; the alert leaves the live feed either way.
var acknowledged: bool = false

## Raised while a save was being applied, or before the world came online. Such
## an alert is recorded and shown but is **never allowed to pause** - a save must
## not open on a modal, and a restored breach is re-announced by
## [AtmosphereComponent] on its next tick anyway.
var suppress_pause: bool = false

## Template for the coalesced row, with one `%d` for the member count -
## `"%d crew have fallen ill"`. Set by the emit site, because only the emit site
## knows the plural. Empty falls back to [method AlertRules.default_group_title].
var group_title: String = ""

static func create(alert_id: StringName, alert_priority: Priority, alert_title: String,
		alert_detail: String = "", alert_subject: Variant = null,
		alert_route: StringName = &"") -> AlertData:
	var alert := AlertData.new()
	alert.id = alert_id
	alert.priority = alert_priority
	alert.title = alert_title
	alert.detail = alert_detail
	alert.subject = alert_subject
	alert.route = alert_route
	return alert

# --- subject ------------------------------------------------------------------

## The subject as a positioned node, or null - which covers "never had one", "it
## was something unpositioned", and "it has since been freed" in one answer, so
## callers never have to write the validity check themselves.
##
## The type test is `typeof`, not `subject as Object`: casting a Variant that
## holds a non-object is a hard engine error, and casting one that holds a
## *freed* object is another - so neither of the two cases this method exists to
## answer may go through a cast.
func subject_node() -> Node2D:
	if typeof(subject) != TYPE_OBJECT or not is_instance_valid(subject):
		return null
	return subject as Node2D

func has_live_subject() -> bool:
	return subject_node() != null

# --- display ------------------------------------------------------------------

## "CYCLE 3 · 14:00" - the history log's timestamp column.
func stamp() -> String:
	return "Cycle %d · %02d:00" % [cycle, hour]

# --- persistence --------------------------------------------------------------

## The history log's saved form. [member subject] is deliberately absent: an
## object reference cannot be serialised, and a history row's jump affordance is
## a live-session nicety rather than a game fact.
func to_dict() -> Dictionary:
	return {
		"id": String(id),
		"priority": int(priority),
		"title": title,
		"detail": detail,
		"cycle": cycle,
		"hour": hour,
		"count": count,
	}

## Rebuilds a history entry. Every field is coerced, because JSON has one number
## type and an int comes back a float (the standing rule every `load_save_data`
## in the project follows).
static func from_dict(data: Dictionary) -> AlertData:
	var alert := AlertData.new()
	alert.id = StringName(str(data.get("id", "")))
	alert.priority = _priority_from(int(data.get("priority", Priority.LOW)))
	alert.title = str(data.get("title", ""))
	alert.detail = str(data.get("detail", ""))
	alert.cycle = int(data.get("cycle", 0))
	alert.hour = int(data.get("hour", 0))
	alert.count = maxi(1, int(data.get("count", 1)))
	# A restored alert is history, never live: it has already happened, it has no
	# subject to jump to, and it must not be able to pause a game the player has
	# not seen yet.
	alert.acknowledged = true
	alert.suppress_pause = true
	return alert

## An out-of-range priority resolves to HIGH rather than being dropped. Only HIGH
## and CRITICAL are ever logged, so an unrecognised value came from a build that
## knew a tier this one does not - and the safe reading of "important enough to
## log" is the lower of the two, not silence.
static func _priority_from(value: int) -> Priority:
	if value == Priority.CRITICAL:
		return Priority.CRITICAL
	if value == Priority.LOW:
		return Priority.LOW
	return Priority.HIGH
