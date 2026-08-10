class_name MoodCatalog
extends RefCounted

## Display metadata for every happiness modifier a pawn can carry (WI-51).
##
## [PawnNeedsComponent] keys its modifiers by bare [StringName] - `good_meal`,
## `trait_exterior`, `disease_void_sickness`, whatever id an event's effect
## happened to be authored with. Those ids are the *mechanism*; none of them is
## a thing to show a player. This maps each one to a label, a blurb and, for the
## permanent ones, the **cause** that keeps it alive.
##
## The cause matters more than it looks. The Needs tab has a column for "how much
## longer", and for a finite modifier that is a duration. For an INF one, "forever"
## is a lie and "∞" answers the wrong question - what the player needs to know is
## *what to change*: "while sick", "while outside", "trait", "difficulty". So the
## column reads a duration or a cause, and which one is a property of the id.
##
## Three id families cannot be enumerated, because their ids come from data:
## diseases, traits and events. Each resolves through its own registry, and an id
## that resolves through none of them falls back to a capitalised form of itself
## rather than being dropped. **Unknown must never mean hidden** - a modded event
## that moves crew mood has to appear in the breakdown even if this file has
## never heard of it, or the number at the top stops adding up and the player has
## no way to find out why.
##
## Pure: static, no nodes, no [Global], no [SignalBus]. It reads the same shared
## data registries the gameplay code does.

# --- id families ---------------------------------------------------------------

## Prefix [PawnDiseaseComponent] puts on its per-disease mood modifier, so the
## disease id can be recovered from the modifier id. Must match
## `PawnDiseaseComponent._mood_mod_id`.
const DISEASE_PREFIX: String = "disease_"

## Prefix [EventEffectHappinessModifier] falls back to when an effect declares no
## id of its own. An effect that *does* declare one is found by scan instead -
## see [method _event_for].
const EVENT_PREFIX: String = "event_"

# --- cause words ---------------------------------------------------------------
#
# What keeps a permanent modifier alive, in the words the tab prints. Kept as
# constants rather than inline strings so the same cause reads identically
# wherever it appears.

const CAUSE_TRAIT: String = "trait"
const CAUSE_DIFFICULTY: String = "difficulty"
const CAUSE_SICK: String = "while sick"
const CAUSE_OUTSIDE: String = "while outside"
const CAUSE_EXHAUSTED: String = "while exhausted"
const CAUSE_COMPANY: String = "who's nearby"
const CAUSE_EVENT: String = "event"

## Every id that is fixed in code, with its label, its one-line explanation, and
## the cause that holds it (empty for a finite modifier, which prints a duration
## instead).
##
## The `cause` on a finite modifier is deliberately empty rather than absent, so
## [method cause_of] never has to distinguish "no cause recorded" from "ticks
## down on its own".
const STATIC_ENTRIES: Dictionary[StringName, Dictionary] = {
	&"good_shopping": {
		"label": "Retail therapy",
		"blurb": "A satisfying visit to one of the station's shops.",
		"cause": "",
	},
	&"good_lodging": {
		"label": "Comfortable lodging",
		"blurb": "Slept somewhere better than a standard bunk.",
		"cause": "",
	},
	&"difficulty": {
		"label": "Station conditions",
		"blurb": "The standing mood offset the chosen difficulty carries.",
		"cause": CAUSE_DIFFICULTY,
	},
	&"exhausted": {
		"label": "Exhausted",
		"blurb": "Ran the sleep need to zero and is still awake.",
		"cause": CAUSE_EXHAUSTED,
	},
	&"trait_exterior": {
		"label": "Out in the void",
		"blurb": "Working outside the hull, which some crew love and some hate.",
		"cause": CAUSE_OUTSIDE,
	},
	&"bad_chat": {
		"label": "Argument",
		"blurb": "A conversation with a crewmate that went badly.",
		"cause": "",
	},
	&"company": {
		"label": "Company",
		"blurb": "How this pawn feels about the crew currently around them.",
		"cause": CAUSE_COMPANY,
	},
	&"interrupted_meal": {
		"label": "Interrupted meal",
		"blurb": "Was pulled away from a meal before finishing it.",
		"cause": "",
	},
	&"good_meal": {
		"label": "Good meal",
		"blurb": "Ate something well above the station's usual standard.",
		"cause": "",
	},
	&"bad_meal": {
		"label": "Poor meal",
		"blurb": "Ate something well below the station's usual standard.",
		"cause": "",
	},
}

## What an id resolves to when nothing else claims it. Not a hidden row and not
## an error: an unrecognised modifier is still moving the number the player is
## looking at.
static func fallback_label(id: StringName) -> String:
	return String(id).capitalize()

# --- lookup --------------------------------------------------------------------

## `{label: String, blurb: String, cause: String}` for `id`. Never null and never
## empty-labelled.
static func describe(id: StringName) -> Dictionary:
	if STATIC_ENTRIES.has(id):
		return STATIC_ENTRIES[id]
	var disease: DiseaseData = _disease_for(id)
	if disease != null:
		return {
			"label": disease.display_name if not disease.display_name.is_empty()
				else fallback_label(disease.id),
			"blurb": disease.description,
			"cause": CAUSE_SICK,
		}
	var trait_data: TraitData = TraitData.by_id(id)
	if trait_data != null:
		return {
			"label": trait_data.display_name if not trait_data.display_name.is_empty()
				else fallback_label(trait_data.id),
			"blurb": trait_data.description,
			"cause": CAUSE_TRAIT,
		}
	var event: EventData = _event_for(id)
	if event != null:
		return {
			"label": event.title if not event.title.is_empty() else fallback_label(event.id),
			"blurb": event.body,
			"cause": CAUSE_EVENT,
		}
	return {"label": fallback_label(id), "blurb": "", "cause": ""}

static func label_of(id: StringName) -> String:
	return String(describe(id).get("label", ""))

static func blurb_of(id: StringName) -> String:
	return String(describe(id).get("blurb", ""))

## Why a permanent modifier is still there, or "" for one that ticks down.
static func cause_of(id: StringName) -> String:
	return String(describe(id).get("cause", ""))

## The right-hand column of a breakdown row: a duration for a finite modifier, a
## cause for a permanent one.
##
## An unknown permanent id has no cause to print, so it prints nothing rather
## than "∞" - the row still shows its label and its value, which is the part that
## has to add up.
static func duration_text(id: StringName, hours_remaining: float) -> String:
	if is_inf(hours_remaining):
		return cause_of(id)
	if hours_remaining >= 1.0:
		return "%dh" % int(round(hours_remaining))
	return "<1h"

# --- happiness arithmetic ------------------------------------------------------

## The one place the happiness formula lives: the mean of the needs, plus every
## modifier, clamped into 0..1.
##
## [PawnNeedsComponent] calls this rather than inlining it, so the breakdown the
## Needs tab renders is arithmetically the same operation the sim ran - including
## the clamp, which is why a pawn at 0.98 with a `+0.05` modifier reads 100% and
## not 103%.
static func combine(needs_average: float, modifier_sum: float) -> float:
	return clampf(needs_average + modifier_sum, 0.0, 1.0)

## Sum of the `value` field over breakdown rows, in the shape
## [method PawnNeedsComponent.get_modifier_breakdown] returns.
static func modifier_sum(rows: Array[Dictionary]) -> float:
	var total: float = 0.0
	for row: Dictionary in rows:
		total += float(row.get("value", 0.0))
	return total

## Breakdown rows, biggest effect first regardless of direction - the player
## wants "what is moving this the most", not "what is good and what is bad".
##
## Ties break on id so the list does not reshuffle between refreshes, which a
## sort over a dictionary's iteration order otherwise would.
static func sort_by_magnitude(rows: Array[Dictionary]) -> Array[Dictionary]:
	var sorted: Array[Dictionary] = rows.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var left: float = absf(float(a.get("value", 0.0)))
		var right: float = absf(float(b.get("value", 0.0)))
		if is_equal_approx(left, right):
			return String(a.get("id", "")) < String(b.get("id", ""))
		return left > right)
	return sorted

# --- dynamic families ----------------------------------------------------------

static func _disease_for(id: StringName) -> DiseaseData:
	var text: String = String(id)
	if not text.begins_with(DISEASE_PREFIX):
		return null
	return DiseaseData.by_id(StringName(text.substr(DISEASE_PREFIX.length())))

## Events are the awkward family: an [EventEffectHappinessModifier] carries its
## own `id`, which need not resemble the event's ("meteor_lightshow" on
## "morale_lightshow"), and only falls back to `event_<event id>` when left
## blank. So both routes are tried: strip the prefix and ask by id, then consult
## a scan of every authored effect id.
##
## The scan is cached like [DiseaseData]'s and [TraitData]'s registries, and for
## the same reason - statics survive a scene reload, so it costs one directory
## walk per process rather than one per selection.
static var _event_by_modifier: Dictionary[StringName, EventData] = {}
static var _events_scanned: bool = false

static func _event_for(id: StringName) -> EventData:
	_ensure_events_scanned()
	var direct: EventData = _event_by_modifier.get(id, null)
	if direct != null:
		return direct
	var text: String = String(id)
	if not text.begins_with(EVENT_PREFIX):
		return null
	return _event_by_modifier.get(StringName(text.substr(EVENT_PREFIX.length())), null)

static func _ensure_events_scanned() -> void:
	if _events_scanned:
		return
	_events_scanned = true
	for path: String in ContentPaths.scan(ContentPaths.EVENTS):
		var res: Resource = ResourceLoader.load(path)
		var event := res as EventData
		if event == null:
			continue
		# Indexed by the event's own id too, so the `event_<id>` fallback form
		# resolves without a second table.
		_event_by_modifier[event.id] = event
		for effect: EventEffect in _happiness_effects(event):
			var modifier := effect as EventEffectHappinessModifier
			if modifier != null and modifier.id != &"":
				_event_by_modifier[modifier.id] = event

## Every happiness effect an event can apply, from both the auto-effect list and
## each choice - a choice-driven modifier is just as visible to the player.
static func _happiness_effects(event: EventData) -> Array[EventEffect]:
	var out: Array[EventEffect] = []
	for effect: EventEffect in event.auto_effects:
		if effect is EventEffectHappinessModifier:
			out.append(effect)
	for choice: EventChoice in event.choices:
		if choice == null:
			continue
		for effect: EventEffect in choice.effects:
			if effect is EventEffectHappinessModifier:
				out.append(effect)
	return out

## Drops the event scan, so a test (or a mod mount) can force it to run again.
static func reset_event_cache() -> void:
	_event_by_modifier.clear()
	_events_scanned = false
