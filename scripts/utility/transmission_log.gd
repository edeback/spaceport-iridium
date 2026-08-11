class_name TransmissionLog
extends RefCounted

## The station's incoming-transmission log (WI-57): a bounded, saved, newest-first
## list that existing systems post to.
##
## There is no message *system* in this game and this deliberately does not invent
## one. It is the same shape as [AlertManager]'s history log - a ring buffer with
## a save block - because the two lists sit side by side in the HUD and one
## pattern is easier to reason about than two. What it adds over that log is
## exactly one field of state, [member TransmissionData.unread], which is what the
## console's COMMS badge counts.
##
## **Repeats never collapse.** [method post] appends unconditionally and stamps a
## unique id; a trader arriving five times is five rows with five timestamps. That
## is the one rule that differs from the alert queue, where a repeat of an id
## refreshes the row in place - and the difference is not an oversight, it is the
## difference between a feed of live conditions and a record of things that
## happened.
##
## Pure: a [RefCounted] with no nodes, no [Global] and no [SignalBus], so the
## whole thing is constructible in a GUT suite. [AlertManager] owns one instance,
## registers its save section and emits the change signal - the wiring lives
## there, the rules live here.

## How many entries the log keeps. Oldest are dropped first once it is full.
##
## Sized like the alert history rather than tuned: a transmission is a few lines
## of text, sixty of them is a couple of hours of play, and a log that keeps
## everything would grow a save file without bound for information nobody reads
## twice.
const CAP: int = 60

## Newest first, so index 0 is the most recent thing that arrived and the panel
## renders in array order.
var _entries: Array[TransmissionData] = []

## Monotonic post counter. Also the second half of every id, which is what makes
## two arrivals from one sender two distinct rows - see [TransmissionData].
var _sequence: int = 0

# --- posting ------------------------------------------------------------------

## Appends a transmission and returns it.
##
## Always appends. There is no "refresh the existing row" path and there must not
## be one; see the class docs.
func post(family: StringName, sender: String, subject: String, body: String = "",
		cycle: int = 0, hour: int = 0, route: StringName = &"",
		subject_ref: Variant = null) -> TransmissionData:
	var entry: TransmissionData = TransmissionData.create(family, sender, subject, body, route)
	_sequence += 1
	entry.sequence = _sequence
	entry.id = StringName("%s#%d" % [String(family), _sequence])
	entry.cycle = cycle
	entry.hour = hour
	entry.subject_ref = subject_ref
	_entries.push_front(entry)
	_trim()
	return entry

## Drops the overflow off the back - the oldest entries, because the list is
## newest-first.
func _trim() -> void:
	while _entries.size() > CAP:
		_entries.pop_back()

# --- reads --------------------------------------------------------------------

## Every entry, newest first. A copy, so a caller iterating it cannot be tripped
## by a post landing mid-render.
func entries() -> Array[TransmissionData]:
	return _entries.duplicate()

func size() -> int:
	return _entries.size()

func is_empty() -> bool:
	return _entries.is_empty()

## The console's COMMS badge, and the panel's `n UNREAD` subtitle.
func unread_count() -> int:
	var count: int = 0
	for entry: TransmissionData in _entries:
		if entry.unread:
			count += 1
	return count

func has_unread() -> bool:
	return unread_count() > 0

## The unread entries, newest first - for a caller that wants to render them
## first rather than count them.
func unread() -> Array[TransmissionData]:
	var out: Array[TransmissionData] = []
	for entry: TransmissionData in _entries:
		if entry.unread:
			out.append(entry)
	return out

func find(id: StringName) -> TransmissionData:
	for entry: TransmissionData in _entries:
		if entry.id == id:
			return entry
	return null

## Entries of one family, newest first. Nothing in the panel groups on this yet;
## it exists because "what has ARC said to me" is the obvious next question and
## the alternative is every caller re-writing the filter.
func of_family(family: StringName) -> Array[TransmissionData]:
	var out: Array[TransmissionData] = []
	for entry: TransmissionData in _entries:
		if entry.family == family:
			out.append(entry)
	return out

# --- read state ---------------------------------------------------------------

## Marks one entry read. Returns true if that actually changed something, so a
## caller can skip emitting a change signal for a no-op.
func mark_read(entry: TransmissionData) -> bool:
	if entry == null or not entry.unread:
		return false
	entry.unread = false
	return true

## `MARK ALL READ`. **Non-destructive** - it zeroes the badge without deleting
## anything, matching `CLEAR ALL`'s non-destructiveness in the alert feed, which
## is what makes players willing to press it instead of letting the badge sit at
## forty forever.
func mark_all_read() -> bool:
	var changed: bool = false
	for entry: TransmissionData in _entries:
		if entry.unread:
			entry.unread = false
			changed = true
	return changed

## Empties the log outright. Not wired to any control - the panel has no `CLEAR`,
## deliberately, because a log with a cap does not need one - but a new game and
## a load both need to start from a known-empty list.
func clear() -> void:
	_entries.clear()
	_sequence = 0

# --- persistence --------------------------------------------------------------

## The saved form: the entries in order, plus the sequence counter so ids stay
## unique across a save (without it, a reloaded game would start numbering at 1
## again and could mint an id the log already holds).
func to_save() -> Dictionary:
	var out: Array[Dictionary] = []
	for entry: TransmissionData in _entries:
		out.append(entry.to_dict())
	return {"sequence": _sequence, "entries": out}

## Restores from [method to_save]. An absent `entries` key yields an empty log,
## which is what makes a pre-WI-57 save load without moving `SAVE_VERSION`.
##
## The sequence is restored to at least the highest id it sees rather than trusted
## outright, so a hand-edited or truncated save cannot produce a duplicate id.
func load_save(data: Dictionary) -> void:
	clear()
	for value: Variant in data.get("entries", []):
		var record: Dictionary = value as Dictionary
		if record == null:
			continue
		var entry: TransmissionData = TransmissionData.from_dict(record)
		_entries.append(entry)
		_sequence = maxi(_sequence, entry.sequence)
	_sequence = maxi(_sequence, int(data.get("sequence", 0)))
	_trim()
