class_name EventSchedule
extends RefCounted

## Events a conversation has promised will happen later (WI-62 §5).
##
## `story.queue_event("kestrel_pursuit", 4)` puts an event id on this queue with a
## due time four game-hours out. [EventManager] drains what is due on
## `hour_changed`, **bypassing the weighted roll, the cooldown and `min_cycle`** -
## a scheduled event was already decided by a choice the player made, and
## re-litigating its eligibility would drop chapter two on the floor. Its
## `conditions` are still checked, because those describe a world the event needs
## to make sense in.
##
## Due times are stored as cycle + hour rather than as an absolute hour count, so
## a save file reads the way the clock does. Every rule here is a static function
## taking `hours_per_cycle` as a parameter: this class must not reach for
## [TimeManager], because then it could not be tested without one.
##
## Pure: no [Global], no [SignalBus], no nodes.

## One promised event.
class Entry extends RefCounted:
	var event_id: StringName = &""
	var due_cycle: int = 0
	var due_hour: int = 0

	func _init(id: StringName = &"", cycle: int = 0, hour: int = 0) -> void:
		event_id = id
		due_cycle = cycle
		due_hour = hour

	func _to_string() -> String:
		return "%s @ cycle %d hour %d" % [event_id, due_cycle, due_hour]

var _entries: Array[Entry] = []

# --- calendar arithmetic --------------------------------------------------------

## `(cycle, hour)` advanced by `delay_hours`, as a [Vector2i] of `(cycle, hour)`.
## A delay of zero means "the next drain", not "never".
static func advance(cycle: int, hour: int, delay_hours: int, hours_per_cycle: int) -> Vector2i:
	if hours_per_cycle <= 0:
		return Vector2i(cycle, hour)
	var total: int = hour + maxi(0, delay_hours)
	return Vector2i(cycle + total / hours_per_cycle, total % hours_per_cycle)

## Whether something due at `(due_cycle, due_hour)` has come round by
## `(now_cycle, now_hour)`. Inclusive of the exact hour, so a four-hour delay
## fires on the fourth hour rather than the fifth.
static func is_due(due_cycle: int, due_hour: int, now_cycle: int, now_hour: int) -> bool:
	if now_cycle != due_cycle:
		return now_cycle > due_cycle
	return now_hour >= due_hour

# --- the queue ------------------------------------------------------------------

## Promises `event_id`. Re-queuing an id that is already promised **replaces** its
## due time rather than stacking a second copy: two conversations that both ask
## for the same follow-up want one follow-up, and the later ask is the one that
## knows the most.
func queue(event_id: StringName, due_cycle: int, due_hour: int) -> bool:
	if event_id == &"":
		push_error("EventSchedule: refusing to queue an event with no id")
		return false
	for entry: Entry in _entries:
		if entry.event_id == event_id:
			entry.due_cycle = due_cycle
			entry.due_hour = due_hour
			return true
	_entries.append(Entry.new(event_id, due_cycle, due_hour))
	return true

func has(event_id: StringName) -> bool:
	for entry: Entry in _entries:
		if entry.event_id == event_id:
			return true
	return false

func cancel(event_id: StringName) -> bool:
	for index: int in _entries.size():
		if _entries[index].event_id == event_id:
			_entries.remove_at(index)
			return true
	return false

## Every id that has come round, **removed from the queue**, oldest due first.
##
## Draining and removing in one call rather than a peek plus an erase is
## deliberate: a caller that fires an event and then forgets to remove it fires it
## every hour forever, and that failure is invisible until a player reports a
## conversation they cannot get rid of.
func drain_due(now_cycle: int, now_hour: int) -> Array[StringName]:
	var due: Array[Entry] = []
	var kept: Array[Entry] = []
	for entry: Entry in _entries:
		if is_due(entry.due_cycle, entry.due_hour, now_cycle, now_hour):
			due.append(entry)
		else:
			kept.append(entry)
	_entries = kept
	due.sort_custom(func(a: Entry, b: Entry) -> bool:
		if a.due_cycle != b.due_cycle:
			return a.due_cycle < b.due_cycle
		return a.due_hour < b.due_hour)
	var out: Array[StringName] = []
	for entry: Entry in due:
		out.append(entry.event_id)
	return out

func size() -> int:
	return _entries.size()

## Read-only view, for the cheat dump and for tests.
func entries() -> Array[Entry]:
	return _entries.duplicate()

func clear() -> void:
	_entries.clear()

func to_save() -> Array:
	var out: Array = []
	for entry: Entry in _entries:
		out.append({
			"id": String(entry.event_id),
			"cycle": entry.due_cycle,
			"hour": entry.due_hour,
		})
	return out

func from_save(data: Array) -> void:
	_entries.clear()
	for raw: Variant in data:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = raw
		var id := StringName(String(entry.get("id", "")))
		if id == &"":
			continue
		queue(id, int(entry.get("cycle", 0)), int(entry.get("hour", 0)))
