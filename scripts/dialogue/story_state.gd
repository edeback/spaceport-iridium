class_name StoryState
extends Node

## Everything a conversation may **remember** (WI-62 §5), exposed to dialogue
## under the alias `story`.
##
## Three mechanisms, one save section:
##
## - **Flags** ([StoryFlags]) - declared ids a choice can set and a later
##   conversation can read. This is what makes chaining possible at all.
## - **Standing** ([FactionStanding]) - how the station stands with the powers
##   around it.
## - **Scheduled events** ([EventSchedule]) - "and then, four hours later…".
##
## All three rule-sets are pure classes with their own GUT suites; this node is
## the thin part that owns instances of them, converts game time, and persists.
##
## The counterpart is [DialogueBridge] (alias `station`), which is what a
## conversation may *do*. Two aliases because they are two jobs: one changes the
## world, one remembers it.

const SAVE_SECTION: StringName = &"story"
## After events (130), so a scheduled event restored here lands on a manager whose
## own cooldown table is already back.
const SAVE_ORDER: int = 135

var flags: StoryFlags = StoryFlags.new()
var standing: FactionStanding = FactionStanding.new()
var schedule: EventSchedule = EventSchedule.new()

## id -> definition, discovered from every content root.
var _factions: Dictionary[StringName, FactionData] = {}

func _ready() -> void:
	Global.story_state = self
	_load_factions()
	SaveManager.register_section(SAVE_SECTION, SAVE_ORDER, get_save_data, load_save_data)

func _exit_tree() -> void:
	if Global.story_state == self:
		Global.story_state = null

func _load_factions() -> void:
	for path: String in ContentPaths.scan(ContentPaths.FACTIONS):
		var faction: FactionData = ResourceLoader.load(path) as FactionData
		if faction == null:
			continue
		if not ContentPaths.accept_id(faction.id, path, "FactionData"):
			continue
		_factions[faction.id] = faction

# --- the `story` vocabulary -----------------------------------------------------
#
# Every method below is callable from a `.dialogue` file. Ids arrive as plain
# `String` and are coerced on the way in: Godot's `Expression` - which is what
# runs a dialogue mutation - rejects a `&"…"` literal outright, so an author
# cannot write one even if they wanted to. Same rule the Panku cheats follow.

## `if story.flag("kestrel_docked")`. Truthy for a set bool, a positive number or
## a non-empty string, so an author never has to know the storage type.
func flag(id: String) -> bool:
	return flags.is_set(StringName(id))

## The raw value, for a counter an author wants to compare against a number.
func value(id: String) -> Variant:
	return flags.flag(StringName(id))

## `$> story.set_flag("kestrel_docked", true)`.
func set_flag(id: String, flag_value: Variant) -> void:
	flags.set_flag(StringName(id), flag_value)

## `$> story.bump("distress_hails_answered")`.
func bump(id: String, amount: int = 1) -> int:
	return flags.bump(StringName(id), amount)

## `if story.standing("authority") > 0.5`.
func standing_of(id: String) -> float:
	return standing.standing(StringName(id))

## `$> story.shift_standing("authority", -0.2)`. Clamped by [FactionStanding], so
## a `.dialogue` file never has to know where the floor is.
func shift_standing(id: String, delta: float) -> float:
	var faction_id := StringName(id)
	if not _factions.has(faction_id):
		push_error("StoryState: no such faction '%s'" % id)
		return FactionStanding.NEUTRAL
	if not _factions[faction_id].scored:
		# ARC. Silently moving a number nothing reads would look like it worked.
		push_error("StoryState: faction '%s' is not scored - see FactionData.scored" % id)
		return FactionStanding.NEUTRAL
	return standing.shift(faction_id, delta)

## The band as a word, for a line that wants to say it out loud.
func standing_band(id: String) -> String:
	return FactionStanding.band_name(standing.band_of(StringName(id)))

## `$> story.queue_event("kestrel_pursuit", 4)`. The follow-up fires whether or
## not the weighted roll would ever have picked it - it was already decided.
func queue_event(event_id: String, delay_hours: int) -> void:
	var time: TimeManager = Global.time_manager
	if time == null:
		push_error("StoryState: no time manager, cannot queue '%s'" % event_id)
		return
	var due: Vector2i = EventSchedule.advance(
		time.cycle, time.hour, delay_hours, TimeManager.HOURS_PER_CYCLE)
	schedule.queue(StringName(event_id), due.x, due.y)

func cancel_event(event_id: String) -> void:
	schedule.cancel(StringName(event_id))

# --- factions -------------------------------------------------------------------

func faction(id: StringName) -> FactionData:
	return _factions.get(id)

## Every faction, scored ones and ARC alike, in authored display order. What the
## Comms standing block renders.
func factions() -> Array[FactionData]:
	var out: Array[FactionData] = _factions.values()
	out.sort_custom(func(a: FactionData, b: FactionData) -> bool:
		if a.sort_order != b.sort_order:
			return a.sort_order < b.sort_order
		return a.display_name < b.display_name)
	return out

# --- persistence ----------------------------------------------------------------

func get_save_data() -> Dictionary:
	return {
		"flags": flags.to_save(),
		"standing": standing.to_save(),
		"schedule": schedule.to_save(),
	}

func load_save_data(data: Dictionary) -> void:
	flags.from_save(data.get("flags", {}))
	standing.from_save(data.get("standing", {}))
	schedule.from_save(data.get("schedule", []))
