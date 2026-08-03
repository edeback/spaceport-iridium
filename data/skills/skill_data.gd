class_name SkillData
extends Resource

## Definition of one pawn skill (WI-22). Authored as a .tres under
## res://data/skills/. Per-pawn level/xp state lives on PawnSkillsComponent;
## this holds only the shared, tunable curve constants (balance-in-data
## invariant) and display metadata.

const MAX_LEVEL: int = 10

## Stable identifier used as the skill key everywhere (jobs' get_skill(),
## the per-pawn state dict, the set_skill cheat).
@export var id: StringName = &""
@export var display_name: String = ""
@export var icon: Texture2D
## Lower sorts first in the skills tab, so the fixed set reads in intended
## groups (combat, work, social) rather than filesystem order.
@export var sort_order: int = 0
## Work-rate multiplier at level 0 and at MAX_LEVEL, linearly interpolated
## between. Level 0 is deliberately a malus (unskilled), MAX a solid bonus.
@export var min_multiplier: float = 0.6
@export var max_multiplier: float = 1.5
## XP to advance FROM level 0 to 1; each further level costs xp_growth^level
## more, so later levels take progressively longer.
@export var base_xp_to_level: float = 100.0
@export var xp_growth: float = 1.4

## Work-rate multiplier for a level, clamped to the 0..MAX_LEVEL band.
func multiplier_for_level(level: int) -> float:
	var t: float = clampf(float(level) / float(MAX_LEVEL), 0.0, 1.0)
	return lerpf(min_multiplier, max_multiplier, t)

## XP needed to go from `level` to level+1. INF at/above the cap, so xp can
## keep accumulating on a maxed skill but can never advance past MAX_LEVEL.
func xp_to_next(level: int) -> float:
	if level >= MAX_LEVEL:
		return INF
	return base_xp_to_level * pow(xp_growth, float(maxi(level, 0)))

# --- shared registry ----------------------------------------------------------
# Skill definitions are global and fixed, so scan res://data/skills/ once and
# cache id -> SkillData (mirrors how the managers load their .tres via
# ResourceScanner). Kept on the data class itself so a ten-item static set
# doesn't need a whole manager. Statics survive scene reload, so the cache
# persists across save/load.

static var _registry: Dictionary[StringName, SkillData] = {}
static var _ordered: Array[SkillData] = []
static var _scanned: bool = false

static func _ensure_scanned() -> void:
	if _scanned:
		return
	_scanned = true
	for path: String in ContentPaths.scan(ContentPaths.SKILLS):
		var res: Resource = ResourceLoader.load(path)
		if res is SkillData:
			var skill := res as SkillData
			if not ContentPaths.accept_id(skill.id, path, "SkillData"):
				continue
			_registry[skill.id] = skill
			_ordered.append(skill)
	_ordered.sort_custom(func(a: SkillData, b: SkillData) -> bool: return a.sort_order < b.sort_order)

## Every skill definition, in display (sort_order) order.
static func all() -> Array[SkillData]:
	_ensure_scanned()
	return _ordered

## The definition for `skill_id`, or null if there's no such skill.
static func by_id(skill_id: StringName) -> SkillData:
	_ensure_scanned()
	return _registry.get(skill_id, null)
