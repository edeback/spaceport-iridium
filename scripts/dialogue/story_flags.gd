class_name StoryFlags
extends RefCounted

## What a conversation is allowed to remember (WI-62).
##
## A flag is a bare string on both sides of a contract - written in a `.dialogue`
## file, read back in another one - and the typo is silent in the direction that
## matters: `flag("kestrel_dockd")` reads false forever and the chain simply never
## continues. So flags are **declared**, exactly as [Groups] (WI-41) and [UIType]
## (WI-49) declare theirs, and an undeclared id is an error rather than a new
## entry.
##
## The declaration also carries the default, which is what makes a *new* flag
## backward-compatible with an old save: absent means default, and no migration is
## needed to add one.
##
## Pure: no [Global], no [SignalBus], no nodes. [StoryState] owns an instance and
## registers it with the dialogue runtime; this class only knows the rules.

## Every flag the base game declares, and the value it reads as before anything
## sets it. The type of the default is the type of the flag.
const DECLARED: Dictionary[StringName, Variant] = {
	# --- Damaged Ship Needs Help (WI-62 §7) ---
	## The Kestrel was let in. Read by its own follow-up and by anything later
	## that wants to know whether the station takes strays.
	&"kestrel_docked": false,
	## The player took the captain's hush money instead of the patrol's bounty.
	## This is the flag the whole chain exists to demonstrate: it changes what
	## `kestrel_pursuit` opens with, hours later, in a different conversation.
	&"kestrel_captain_hidden": false,
	## The pursuit follow-up has played. Guards the chain against a second run.
	&"kestrel_pursuit_seen": false,

	# --- station AI (WI-62 §9) ---
	## SAI has introduced itself. The tutorial item will read this; nothing in
	## this item sets it, and that is deliberate.
	&"sai_introduced": false,

	# --- counters ---
	## How many distress hails the station has answered, either way. A counter
	## rather than a bool because a later event wants "you have a reputation for
	## this" rather than "you did it once".
	&"distress_hails_answered": 0,
}

## Set values only. A flag sitting at its declared default is not stored, so a
## save file carries the story's *deltas* rather than a copy of the table.
var _values: Dictionary[StringName, Variant] = {}

## Whether `id` is a flag at all. Mods add flags by [method declare]; this is the
## question every write asks first.
func is_declared(id: StringName) -> bool:
	return DECLARED.has(id) or _extra.has(id)

## Flags declared at runtime by a mod. Kept separate from [constant DECLARED] so
## the base game's table stays a readable const and a mod cannot quietly redefine
## a vanilla flag's default.
var _extra: Dictionary[StringName, Variant] = {}

## Declares a flag a mod owns. Re-declaring an existing id is refused rather than
## overwritten - two mods claiming one flag would otherwise depend on load order.
func declare(id: StringName, default_value: Variant) -> bool:
	if id == &"":
		push_error("StoryFlags: refusing to declare a flag with no id")
		return false
	if is_declared(id):
		push_error("StoryFlags: '%s' is already declared" % id)
		return false
	_extra[id] = default_value
	return true

func default_for(id: StringName) -> Variant:
	if DECLARED.has(id):
		return DECLARED[id]
	return _extra.get(id, false)

## The flag's current value, or its declared default. An undeclared id reads
## false **and** errors: returning a plausible value silently is how a typo
## survives to ship.
func flag(id: StringName) -> Variant:
	if not is_declared(id):
		push_error("StoryFlags: no such flag '%s' - declare it in StoryFlags.DECLARED" % id)
		return false
	if _values.has(id):
		return _values[id]
	return default_for(id)

## Writes `value`. Returns false (and errors) for an undeclared id, so a caller
## that cares can tell the difference between "set" and "typo".
func set_flag(id: StringName, value: Variant) -> bool:
	if not is_declared(id):
		push_error("StoryFlags: no such flag '%s' - declare it in StoryFlags.DECLARED" % id)
		return false
	# Storing only the deltas keeps the save honest about what the run actually
	# did, and means a newly declared flag needs no migration.
	if _matches_default(id, value):
		_values.erase(id)
	else:
		_values[id] = value
	return true

## Adds to a numeric flag and returns the new value. A non-numeric flag is a
## programming error in the dialogue, not a silent coercion.
func bump(id: StringName, amount: int = 1) -> int:
	if not is_declared(id):
		push_error("StoryFlags: no such flag '%s' - declare it in StoryFlags.DECLARED" % id)
		return 0
	var current: Variant = flag(id)
	if typeof(current) != TYPE_INT and typeof(current) != TYPE_FLOAT:
		push_error("StoryFlags: '%s' is not a number, bump() cannot add to it" % id)
		return 0
	var next: int = int(current) + amount
	set_flag(id, next)
	return next

## True when the flag is a bool that is set, or a number above zero. The one
## coercion, and it exists because `[if story.flag("x") /]` is what a dialogue
## author writes and they should not have to know the storage type.
func is_set(id: StringName) -> bool:
	var value: Variant = flag(id)
	match typeof(value):
		TYPE_BOOL:
			return bool(value)
		TYPE_INT, TYPE_FLOAT:
			return float(value) > 0.0
		TYPE_STRING, TYPE_STRING_NAME:
			return not String(value).is_empty()
	return value != null

func clear() -> void:
	_values.clear()

## Set flags only, as `String` keys - JSON has no StringName.
func to_save() -> Dictionary:
	var out: Dictionary = {}
	for id: StringName in _values:
		out[String(id)] = _values[id]
	return out

## Restores set flags. An id that is no longer declared (a mod was removed) is
## dropped with a warning rather than resurrected: keeping it would let it come
## back if the mod ever returned, carrying a value from a run that no longer
## makes sense.
func from_save(data: Dictionary) -> void:
	_values.clear()
	for key: String in data:
		var id := StringName(key)
		if not is_declared(id):
			push_warning("StoryFlags: dropping unknown saved flag '%s'" % key)
			continue
		set_flag(id, _coerce(id, data[key]))

## JSON turns every number into a float. A flag declared as an int has to come
## back as one, or `bump()` starts producing 3.0 where the author wrote 3.
func _coerce(id: StringName, value: Variant) -> Variant:
	var default_value: Variant = default_for(id)
	if typeof(default_value) == TYPE_INT and typeof(value) == TYPE_FLOAT:
		return int(value)
	if typeof(default_value) == TYPE_BOOL and typeof(value) != TYPE_BOOL:
		return bool(value)
	return value

func _matches_default(id: StringName, value: Variant) -> bool:
	var default_value: Variant = default_for(id)
	if typeof(default_value) != typeof(value):
		return false
	return default_value == value
