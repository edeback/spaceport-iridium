class_name DifficultyData
extends Resource

## One difficulty level (WI-37). Authored as a .tres under res://data/difficulty/,
## one per level, discovered via ResourceScanner. Definition only - the chosen
## level is runtime state on Global.difficulty, never written back onto this
## shared resource.
##
## Difficulty is deliberately a thin data layer over knobs earlier work items
## already installed: WI-25's recurring cost streams, WI-32's raids, and WI-05's
## happiness modifiers. Adding a dial means adding an export here plus one read at
## the consuming site - never a new subsystem. Every number is balance, so it
## lives in the .tres, not in code.

## The level a game runs at when nothing has been chosen: a fresh boot straight
## into main.tscn, and every pre-WI-37 save.
const DEFAULT_ID: StringName = &"normal"

## Stable identifier. Saved in the envelope meta and the difficulty section, so
## renaming one orphans existing saves back to DEFAULT_ID.
@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Lower sorts first on the New Game picker, so the cards read easiest-to-hardest
## rather than in filesystem order.
@export var sort_order: int = 0

## Scales the recurring ARC cost streams (WI-25): crew wages, module upkeep, and
## the flat levy fee. One knob in v1 - the three move together, which is the whole
## "cheaper/pricier station" lever. Never touches loan repayments, severance, or
## event/contract penalties: those are consequences of player choices, not a
## standing tax rate.
@export var upkeep_multiplier: float = 1.0

## False disables pirate raids entirely (WI-32): RaidManager.start_raid no-ops and
## the whole raid event family is ineligible, so Peaceful never even draws the
## card. Breakdowns and hull breaches are unaffected - Peaceful removes pirates,
## not maintenance.
@export var raids_enabled: bool = true

## Flat addition to every crew member's 0..1 happiness, applied as a permanent
## &"difficulty" modifier (WI-05 machinery). Kept small: it must never on its own
## carry a fresh station under PawnNeedsComponent.resignation_threshold.
@export var mood_offset: float = 0.0

## The one-line effect summary the New Game cards and the settings readout show.
## Derived rather than authored so a .tres tweak can't leave stale ad copy behind.
func effect_summary() -> String:
	var parts: Array[String] = []
	if not is_equal_approx(upkeep_multiplier, 1.0):
		parts.append("wages, upkeep & ARC fees %+d%%" % roundi((upkeep_multiplier - 1.0) * 100.0))
	if not raids_enabled:
		parts.append("no pirate raids")
	if not is_zero_approx(mood_offset):
		parts.append("crew morale %+d%%" % roundi(mood_offset * 100.0))
	if parts.is_empty():
		return "The standard experience - no adjustments."
	# Only the first character, never String.capitalize(): that title-cases the
	# whole line (mangling "ARC" to "Arc") and treats the minus in "-5%" as a word
	# separator, silently rendering a penalty as a bonus.
	var text: String = ", ".join(parts)
	return text.substr(0, 1).to_upper() + text.substr(1)

# --- shared registry ----------------------------------------------------------
# Difficulty definitions are a fixed global set, so scan once and cache
# id -> DifficultyData (the SkillData/TraitData/DiseaseData pattern). Kept on the
# data class rather than a manager because the menus need it before any manager
# node exists, and statics survive the scene swap into main.tscn.

static var _registry: Dictionary[StringName, DifficultyData] = {}
static var _ordered: Array[DifficultyData] = []
## The [member ContentPaths.generation] this cache last scanned at, -1 for never.
## A stale one rescans on the next read (WI-74 §2).
static var _scanned_generation: int = -1

static func _ensure_scanned() -> void:
	if _scanned_generation == ContentPaths.generation:
		return
	_scanned_generation = ContentPaths.generation
	_registry.clear()
	_ordered.clear()
	for path: String in ContentPaths.scan(ContentPaths.DIFFICULTY):
		var res: Resource = ResourceLoader.load(path)
		if res is DifficultyData:
			var difficulty := res as DifficultyData
			if not ContentPaths.accept_id(difficulty.id, path, "DifficultyData"):
				continue
			_registry[difficulty.id] = difficulty
			_ordered.append(difficulty)
	_ordered.sort_custom(func(a: DifficultyData, b: DifficultyData) -> bool: return a.sort_order < b.sort_order)

## Every difficulty, easiest first (sort_order).
static func all() -> Array[DifficultyData]:
	_ensure_scanned()
	return _ordered

## The definition for `difficulty_id`, or null if there's no such level.
static func by_id(difficulty_id: StringName) -> DifficultyData:
	_ensure_scanned()
	return _registry.get(difficulty_id, null)

## by_id with the Normal fallback every caller wants: an unknown/absent id (a
## pre-WI-37 save, a renamed .tres, a hand-edited file) resolves to Normal rather
## than leaving the game with no difficulty at all. Null only if data/difficulty/
## is missing entirely, which callers treat as "all multipliers neutral".
static func resolve(difficulty_id: StringName) -> DifficultyData:
	var found: DifficultyData = by_id(difficulty_id)
	if found != null:
		return found
	return by_id(DEFAULT_ID)
