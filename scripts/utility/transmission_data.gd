class_name TransmissionData
extends RefCounted

## One incoming transmission (WI-57): something that arrived and can be read
## later.
##
## Deliberately the sibling of [AlertData] rather than a second flavour of it,
## because the two answer different questions and the difference is the whole
## reason both exist:
##
## | | Alert | Transmission |
## | --- | --- | --- |
## | Means | "look at this now" | "this arrived, read it when you like" |
## | Lifetime | transient or acknowledgeable | durable, kept until the log rolls |
## | A repeat | refreshes the existing row | is a **second row** with its own stamp |
## | A hull breach | yes | never |
## | A contract offer | yes | yes |
##
## That third line is the one that bites. A trader arriving five times is five
## transmissions with five timestamps, not one refreshed row - so this record has
## no dedupe key at all. [member family] says what *kind* of thing arrived (for
## grouping and for a future faction portrait); [member id] is unique per entry
## and is built from the family plus the log's own sequence, so the id shape makes
## "these do not collapse" obvious at a glance.
##
## Not a [Resource]: transmissions are created a few dozen per session, live in an
## array, and have no `.tres` on disk. The bounded-log *rules* are
## [TransmissionLog], which is pure and tested; this is only the record.

## What kind of thing arrived - `&"contract"`, `&"trader"`, `&"arc"`,
## `&"finance"`, `&"event"`. Grouping and (later) the faction portrait key. Never
## a dedupe key.
var family: StringName = &""

## Unique per entry, `"family#sequence"`. Assigned by [TransmissionLog]; see the
## class docs for why it is unique rather than a dedupe key.
var id: StringName = &""

## Who it is from, as the row's name column - "ARC Central", "Meridian Combine".
## A proper noun, so it is **not** upper-cased by the row.
var sender: String = ""

## The one-line subject, rendered as the row's caps meta line.
var subject: String = ""

## The body, revealed when the row is expanded in place. 620px with a 34px avatar
## slot fits a sender and a subject; the body needs the row to open, which is why
## reading one is never a sub-window (WI-57 edge case).
var body: String = ""

## Sim-time stamp. Same split [AlertData] uses: game facts are stamped in cycles
## and hours.
var cycle: int = 0
var hour: int = 0

## Unread until the player expands the row or presses `MARK ALL READ`. Drives the
## row's cyan treatment and the console's COMMS badge, and it **is saved** - a
## message the player has not read yet is a fact about the run, not a UI mood.
var unread: bool = true

## A mode this transmission opens, mapped by the panel exactly as
## [member AlertData.route] is. A [StringName] rather than a `ModeManager.Mode` so
## this record stays free of any dependency on `ui/`. Empty means "no action".
var route: StringName = &""

## The [Node2D] this is about, or null - a live object reference, never saved.
##
## A transmission routinely outlives its subject (the module was destroyed, the
## contract expired), and losing it costs the row its jump affordance and nothing
## else: **the row keeps its text and loses its action**, exactly like an alert
## whose subject died.
var subject_ref: Variant = null

## Monotonic post counter, assigned by [TransmissionLog]. Ordering tiebreak, and
## the second half of [member id].
var sequence: int = 0

static func create(entry_family: StringName, entry_sender: String, entry_subject: String,
		entry_body: String = "", entry_route: StringName = &"") -> TransmissionData:
	var entry := TransmissionData.new()
	entry.family = entry_family
	entry.sender = entry_sender
	entry.subject = entry_subject
	entry.body = entry_body
	entry.route = entry_route
	return entry

# --- subject ------------------------------------------------------------------

## The subject as a positioned node, or null - which covers "never had one", "it
## was something unpositioned", and "it has since been freed" in one answer.
##
## The type test is `typeof`, not a cast, for the reason
## [method AlertData.subject_node] documents: casting a Variant holding a
## non-object (or a freed one) is a hard engine error, and both are exactly the
## cases this method exists to answer.
func subject_node() -> Node2D:
	if typeof(subject_ref) != TYPE_OBJECT or not is_instance_valid(subject_ref):
		return null
	return subject_ref as Node2D

## Whether the row still has somewhere to go: a live subject, or a route.
func has_action() -> bool:
	return subject_node() != null or route != &""

# --- display ------------------------------------------------------------------

## "CYCLE 3 · 14:00" - the row's timestamp column, replaced by a `NEW` badge
## while the entry is unread.
func stamp() -> String:
	return "Cycle %d · %02d:00" % [cycle, hour]

# --- persistence --------------------------------------------------------------

## The saved form. [member subject_ref] is deliberately absent for the same
## reason an alert's is: an object reference cannot be serialised, and the jump
## affordance is a live-session nicety rather than a game fact.
func to_dict() -> Dictionary:
	return {
		"family": String(family),
		"id": String(id),
		"sender": sender,
		"subject": subject,
		"body": body,
		"cycle": cycle,
		"hour": hour,
		"unread": unread,
		"route": String(route),
		"sequence": sequence,
	}

## Rebuilds an entry. Every number is coerced, because JSON has one number type
## and an int comes back a float (the standing rule every `load_save_data` in the
## project follows).
static func from_dict(data: Dictionary) -> TransmissionData:
	var entry := TransmissionData.new()
	entry.family = StringName(str(data.get("family", "")))
	entry.id = StringName(str(data.get("id", "")))
	entry.sender = str(data.get("sender", ""))
	entry.subject = str(data.get("subject", ""))
	entry.body = str(data.get("body", ""))
	entry.cycle = int(data.get("cycle", 0))
	entry.hour = int(data.get("hour", 0))
	entry.unread = bool(data.get("unread", false))
	entry.route = StringName(str(data.get("route", "")))
	entry.sequence = int(data.get("sequence", 0))
	return entry
