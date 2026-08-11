class_name AlertRules
extends RefCounted

## The rules behind the alert feed (WI-53), extracted so they can be tested
## without a HUD - the same split [LedgerModel] and [InspectorTabPlan] use.
##
## Five rules live here, and each is one the feed would otherwise re-derive:
## what a priority *means* (sticky? pauses? logged? ages out?), what an alert id
## is made of, what order rows go in, what `CLEAR ALL` is allowed to take away,
## and when a burst of related alerts collapses into one row.
##
## The tier table is the load-bearing part. **CRITICAL is deliberately tiny** -
## a tier that pauses the game is only useful if it almost never fires, and the
## test for membership is "the player will lose something irreversible if they
## are looking away". Difficulty (WI-37) does not gate any of it: an alert tier
## is a UI contract, and a Peaceful game having fewer breaches is the difficulty
## lever, not a quieter UI when one happens.
##
## Pure: static, no nodes, no [Global], no [SignalBus]. Wall-clock "now" is a
## parameter rather than a [Time] read, so ageing is testable without waiting.

# --- ids ----------------------------------------------------------------------

## Separates the family from the subject in an alert id. Kept from the strip this
## replaces, whose dedupe key was already `"%s|%s" % [pawn, need]`.
const ID_SEPARATOR: String = "|"

## Cheat alerts stay LOW and are never logged (standing rule: a save that used
## cheats is self-documenting via this prefix). Mirrors [method Cheats._report].
const CHEAT_PREFIX: String = "CHEAT: "

# --- tuning -------------------------------------------------------------------

## How long a LOW alert survives, in **wall-clock** seconds. Unchanged from the
## strip this replaces. Wall-clock because a transient alert is a UI affordance,
## not a sim event - it must not stretch to four minutes because the player
## paused, and must not vanish four times faster at 4x.
const LOW_TTL_SECONDS: float = 15.0

## Rows the feed shows before it summarises the rest as `+ n more`. A backed-up
## feed of forty rows is the failure mode the history/clear pairing exists to
## prevent, and a cap is what makes the pairing necessary rather than optional.
##
## Four, not the eight the design sketched, and the reason is the right column:
## the feed shares it with the station map above and the inspector below, and a
## feed tall enough for eight rows squeezes the selection surface to nothing
## exactly when a bad cycle makes the player most want to click something.
## [constant UIMetrics.ALERT_FEED_MAX_HEIGHT] is the same limit expressed in
## pixels and the two have to agree - a cap the panel is too short to render is
## a scrollbar plus a "+ n more" line that disagree about how many rows are
## hidden.
const FEED_CAP: int = 4

## Entries the history log retains. Bounded because it is saved, and a log that
## grows without limit turns into a save-size problem on a long run.
const HISTORY_CAP: int = 300

## Alerts in one id family before they collapse into a single row. Three, not
## two: a pair of hungry crew is two facts the player can act on individually,
## and six is a situation. Below the threshold nothing is grouped.
const COALESCE_THRESHOLD: int = 3

# --- tiers --------------------------------------------------------------------

## Whether an alert of this priority stays until the player clicks it. HIGH is
## the tier that earns most of the item's value and carries none of its risk.
static func is_sticky(priority: AlertData.Priority) -> bool:
	return priority != AlertData.Priority.LOW

## Whether an alert of this priority holds the sim paused while it is
## outstanding. Only CRITICAL, and see the class docs for how small that set is.
static func pauses(priority: AlertData.Priority) -> bool:
	return priority == AlertData.Priority.CRITICAL

## Whether an alert of this priority is written to the history log.
##
## LOW alerts are **not** logged: they are the ones that were designed to be
## missable, and logging them would bury the ones that were not.
static func is_logged(priority: AlertData.Priority) -> bool:
	return priority != AlertData.Priority.LOW

## Whether an alert of this priority expires on its own.
static func ages_out(priority: AlertData.Priority) -> bool:
	return priority == AlertData.Priority.LOW

## A debug/cheat message, which stays LOW and out of the history log however it
## was raised. Matched on the message rather than on a flag so it also catches a
## mod or a future system that adopts the same prefix.
static func is_cheat(text: String) -> bool:
	return text.begins_with(CHEAT_PREFIX)

static func priority_label(priority: AlertData.Priority) -> String:
	match priority:
		AlertData.Priority.CRITICAL:
			return "Critical"
		AlertData.Priority.HIGH:
			return "High"
		_:
			return "Low"

# --- identity -----------------------------------------------------------------

## The dedupe key for `family` about `subject`.
##
## Object subjects key on their instance id, not their name: two Corridors called
## "Corridor" breaching are two alerts, and a name-keyed id would silently merge
## them into one. Anything else (a [StringName] need, a cell, an int) is
## stringified, and a null subject makes the family its own id - which is what a
## station-wide alert ("no docking bay") wants.
##
## The object test is `typeof`, for the reason [method AlertData.subject_node]
## documents: `subject as Object` is a hard error for both a non-object Variant
## and a freed one, which are two of the three cases this has to handle.
static func make_id(family: StringName, subject: Variant = null) -> StringName:
	if subject == null:
		return family
	if typeof(subject) == TYPE_OBJECT:
		if not is_instance_valid(subject):
			return family
		return StringName("%s%s%d" % [family, ID_SEPARATOR, (subject as Object).get_instance_id()])
	return StringName("%s%s%s" % [family, ID_SEPARATOR, str(subject)])

## The family half of an id - everything before the first separator. Two alerts
## share a family when they are the same *kind* of event about different
## subjects, which is exactly the set the coalescer groups.
static func family_of(id: StringName) -> StringName:
	var text: String = String(id)
	var cut: int = text.find(ID_SEPARATOR)
	if cut < 0:
		return id
	return StringName(text.substr(0, cut))

# --- state --------------------------------------------------------------------

## A CRITICAL that has not been acknowledged - the set that holds the pause and
## that `CLEAR ALL` may not touch.
static func is_outstanding(alert: AlertData) -> bool:
	return (alert != null and alert.priority == AlertData.Priority.CRITICAL
		and not alert.acknowledged)

## Whether `CLEAR ALL` may take this row away.
##
## `CLEAR ALL` is non-destructive precisely because history exists, which is what
## makes players willing to use it instead of letting forty rows pile up. But a
## "clear" that can dismiss a game-pausing alert defeats the tier, so an
## outstanding critical survives it.
static func is_clearable(alert: AlertData) -> bool:
	return alert != null and not is_outstanding(alert)

## Whether clicking the row does something beyond dismissing it - it has a live
## subject to jump to, or a mode to open. Drives the row's action verb and the
## "actionable but not alarming" cyan treatment.
static func is_actionable(alert: AlertData) -> bool:
	if alert == null:
		return false
	return alert.has_live_subject() or alert.route != &""

## Whether the alert should hold the sim paused right now.
static func holds_pause(alert: AlertData) -> bool:
	return is_outstanding(alert) and not alert.suppress_pause

## Whether any alert in `alerts` is holding the pause. One pause, not one per
## alert: three simultaneous criticals pause once and release when the last is
## acknowledged.
static func any_holds_pause(alerts: Array[AlertData]) -> bool:
	for alert: AlertData in alerts:
		if holds_pause(alert):
			return true
	return false

static func outstanding_count(alerts: Array[AlertData]) -> int:
	var total: int = 0
	for alert: AlertData in alerts:
		if is_outstanding(alert):
			total += 1
	return total

# --- ordering -----------------------------------------------------------------

## Sort band: outstanding criticals above everything regardless of recency, then
## sticky alerts, then the transient ones.
static func rank(alert: AlertData) -> int:
	if is_outstanding(alert):
		return 0
	if is_sticky(alert.priority):
		return 1
	return 2

## `alerts` in feed order: band first, then newest first within a band.
##
## Recency is [member AlertData.sequence] rather than the wall-clock stamp -
## `sort_custom` is not stable, and two alerts raised in the same millisecond
## must not swap places between frames. Returns a new array; the caller's is
## untouched.
static func order(alerts: Array[AlertData]) -> Array[AlertData]:
	var sorted: Array[AlertData] = alerts.duplicate()
	sorted.sort_custom(func(a: AlertData, b: AlertData) -> bool:
		var rank_a: int = rank(a)
		var rank_b: int = rank(b)
		if rank_a != rank_b:
			return rank_a < rank_b
		return a.sequence > b.sequence)
	return sorted

# --- ageing & clearing --------------------------------------------------------

## The members of `alerts` that have outlived their wall-clock TTL. Only LOW
## alerts age; high and critical never do, which is the whole distinction between
## the tiers.
static func expired(alerts: Array[AlertData], now_seconds: float,
		ttl: float = LOW_TTL_SECONDS) -> Array[AlertData]:
	var out: Array[AlertData] = []
	for alert: AlertData in alerts:
		if ages_out(alert.priority) and now_seconds - alert.raised_at >= ttl:
			out.append(alert)
	return out

## What survives `CLEAR ALL` - the outstanding criticals, and nothing else.
static func survives_clear(alerts: Array[AlertData]) -> Array[AlertData]:
	var out: Array[AlertData] = []
	for alert: AlertData in alerts:
		if not is_clearable(alert):
			out.append(alert)
	return out

## Drops the oldest entries so the log fits `cap`. Newest-first input, so the
## trim comes off the tail.
static func trim_history(history: Array[AlertData], cap: int = HISTORY_CAP) -> Array[AlertData]:
	if cap <= 0:
		return [] as Array[AlertData]
	if history.size() <= cap:
		return history.duplicate()
	return history.slice(0, cap)

## The members of `alerts` at exactly `priority`, order preserved - the history
## flyout's filter.
static func filter_priority(alerts: Array[AlertData],
		priority: AlertData.Priority) -> Array[AlertData]:
	var out: Array[AlertData] = []
	for alert: AlertData in alerts:
		if alert.priority == priority:
			out.append(alert)
	return out

# --- coalescing ---------------------------------------------------------------

## One feed row: either a single alert, or a whole id family collapsed into one.
##
## A raid damaging eight modules at once, or an outbreak infecting six pawns,
## would otherwise fill the feed and let the cap swallow the row that mattered.
## Grouping happens at **render** time rather than at raise time, so the members
## stay individually acknowledgeable and the history log keeps them apart.
class Group extends RefCounted:
	var family: StringName = &""
	var members: Array[AlertData] = []

	func _init(group_family: StringName, group_members: Array[AlertData]) -> void:
		family = group_family
		members = group_members

	## The highest-ranked, newest member - the alert whose priority, subject and
	## route the row takes when the group is a single alert.
	func lead() -> AlertData:
		return members[0] if not members.is_empty() else null

	func size() -> int:
		return members.size()

	func is_collapsed() -> bool:
		return members.size() > 1

	## The row's title: the lead's own when this is one alert, the family's
	## plural template when it is many.
	func title() -> String:
		var head: AlertData = lead()
		if head == null:
			return ""
		if not is_collapsed():
			return head.title
		if head.group_title != "":
			return head.group_title % members.size()
		return AlertRules.default_group_title(head.title, members.size())

	## True when every member can be dismissed - a group row is all-or-nothing,
	## so a family containing an outstanding critical is not clearable as a unit.
	func is_clearable() -> bool:
		for alert: AlertData in members:
			if not AlertRules.is_clearable(alert):
				return false
		return true

## What a collapsed row says when the emit site did not supply a plural. Kept
## deliberately plain: an invented plural ("6 crews") reads worse than a count.
static func default_group_title(lead_title: String, count: int) -> String:
	return "%s ×%d" % [lead_title, count]

## `alerts` as feed rows, ordering first and then collapsing any family at or
## above `threshold` into one [Group].
##
## A collapsed group takes the position of its highest-ranked member, so a family
## containing an outstanding critical still sorts to the top.
static func group(alerts: Array[AlertData],
		threshold: int = COALESCE_THRESHOLD) -> Array[Group]:
	var ordered: Array[AlertData] = order(alerts)
	var counts: Dictionary[StringName, int] = {}
	for alert: AlertData in ordered:
		var family: StringName = family_of(alert.id)
		counts[family] = int(counts.get(family, 0)) + 1
	var rows: Array[Group] = []
	var claimed: Dictionary[StringName, int] = {}
	for alert: AlertData in ordered:
		var family: StringName = family_of(alert.id)
		if threshold <= 1 or int(counts[family]) < threshold:
			rows.append(Group.new(family, [alert] as Array[AlertData]))
			continue
		if claimed.has(family):
			continue
		claimed[family] = 1
		var members: Array[AlertData] = []
		for candidate: AlertData in ordered:
			if family_of(candidate.id) == family:
				members.append(candidate)
		rows.append(Group.new(family, members))
	return rows

# --- the cap ------------------------------------------------------------------

## The rows the feed actually renders.
static func visible(rows: Array[Group], cap: int = FEED_CAP) -> Array[Group]:
	if cap <= 0 or rows.size() <= cap:
		return rows.duplicate()
	return rows.slice(0, cap)

## How many alerts the `+ n more` line stands for - counted in alerts rather than
## rows, because "3 more" meaning "three hidden groups of six" would be a lie.
static func overflow(rows: Array[Group], cap: int = FEED_CAP) -> int:
	if cap <= 0 or rows.size() <= cap:
		return 0
	var hidden: int = 0
	for index: int in range(cap, rows.size()):
		hidden += rows[index].size()
	return hidden
