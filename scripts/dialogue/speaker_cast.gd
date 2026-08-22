class_name SpeakerCast
extends RefCounted

## Who is in *this* conversation, and what they look like (WI-62 §4).
##
## The brief: *"an image can be required but random - if so, the image should be
## stable over several lines of conversation."* The rule that satisfies it is one
## sentence: **a speaker is resolved once per conversation, not once per line.**
## A cast is built when a conversation opens and thrown away when it closes; the
## first time an id is seen it gets a name and a face, and every line after that
## gets the same one.
##
## What this replaces is a real defect, not a gap: the balloon's placeholder ran
## `randi_range(12, 49)` inside `apply_dialogue_line()`, so the pirate's face
## changed every time he opened his mouth.
##
## Two faces from one pool never collide inside a conversation - a two-hander
## where both parties look identical reads as a bug even though each roll was
## fair on its own.
##
## Pure: no [Global], no [SignalBus], no nodes. The catalogue and the name roller
## are injected, which is also what makes the whole thing testable without the
## plaintext name trees.

## One resolved speaker. Held for the life of the conversation.
class Member extends RefCounted:
	var id: StringName = &""
	var display_name: String = ""
	var portrait_path: String = ""
	var faction: StringName = &""
	## False for a character string that is not a declared [SpeakerData] - the
	## narration case. The balloon prints the string and shows no portrait.
	var known: bool = false

	var _portrait: Texture2D = null
	var _loaded: bool = false

	## Loaded on demand and cached, so building a cast costs no texture loads and
	## a re-render costs none either.
	func portrait() -> Texture2D:
		if _loaded:
			return _portrait
		_loaded = true
		if not portrait_path.is_empty():
			_portrait = ResourceLoader.load(portrait_path) as Texture2D
		return _portrait

	func _to_string() -> String:
		return "%s (%s)" % [display_name, id]

## id -> definition. Shared with the runner; never mutated here.
var _catalog: Dictionary[StringName, SpeakerData] = {}
## id -> resolved member, for this conversation only.
var _members: Dictionary[StringName, Member] = {}
## pool id -> the indices already handed out, so two speakers drawn from one pool
## get different faces.
var _taken: Dictionary[StringName, PackedInt32Array] = {}

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Injected so a nameless speaker can be given a name without this class knowing
## what a [NameGenerator] is - and so a test can hand it a counter.
var _name_roller: Callable

func _init(catalog: Dictionary[StringName, SpeakerData], name_roller: Callable,
		seed_value: int = 0) -> void:
	_catalog = catalog
	_name_roller = name_roller
	if seed_value != 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()

## The member for `character`, resolving it on first sight. Never null.
func resolve(character: String) -> Member:
	var id := StringName(character)
	if _members.has(id):
		return _members[id]
	var member := Member.new()
	member.id = id
	var definition: SpeakerData = _catalog.get(id)
	if definition == null:
		# Not a declared speaker: print what the author wrote, show no face. This
		# is the narration path and it must not warn - `Station sensors flag a
		# debris cluster.` is a legitimate line with no speaker at all.
		member.display_name = character
		member.known = false
		_members[id] = member
		return member
	member.known = true
	member.faction = definition.faction
	member.display_name = definition.name_for(_roll_name())
	member.portrait_path = _roll_portrait(definition)
	_members[id] = member
	return member

## Whether `character` has already been seen in this conversation. The stability
## property, asked directly.
func has_resolved(character: String) -> bool:
	return _members.has(StringName(character))

func size() -> int:
	return _members.size()

func _roll_name() -> String:
	if not _name_roller.is_valid():
		return ""
	var rolled: Variant = _name_roller.call()
	return String(rolled) if rolled != null else ""

## Picks a face, avoiding one already handed out from the same pool.
##
## The scan is bounded by the pool size and then gives up: a pool with fewer faces
## than the conversation has speakers is a content problem, and repeating a face
## is a better answer than looping.
func _roll_portrait(definition: SpeakerData) -> String:
	if definition.portrait != null:
		return definition.portrait.resource_path
	var pool: PortraitPool = definition.portrait_pool
	if pool == null or pool.is_empty():
		return ""
	var count: int = pool.size()
	var taken: PackedInt32Array = _taken.get(pool.id, PackedInt32Array())
	var index: int = _rng.randi_range(0, count - 1)
	for _attempt: int in count:
		if not taken.has(index):
			break
		index = posmod(index + 1, count)
	taken.append(index)
	_taken[pool.id] = taken
	return pool.path_at(index)
