class_name CandidateRoller
extends RefCounted

## Rolls a [HireCandidate] (WI-59). Extracted out of CrewManager because the New
## Game setup screen has to show a pool of candidates BEFORE main.tscn exists -
## there is no CrewManager node in the menu scene, and `Global.crew_manager` is
## null there - so the roll cannot live on a manager any more.
##
## Pure and constructible without Global: the knobs are plain fields, and the
## content it draws from (PawnData kinds, TraitData, SkillData, NameGenerator)
## is reached through statics over scanned data. ModManager is an autoload and
## mounts before the main menu precisely so those scans see modded content, so a
## modded pawn kind or trait can turn up in the starting pool with no wiring.
##
## **The DEFAULT_* consts here are the balance source of truth.** CrewManager
## keeps @export knobs so main.tscn can still tune the in-game pool, but they
## initialise from these consts rather than restating them, so the menu's roller
## and the manager's roller cannot drift apart. `test_candidate_roller.gd` holds
## the two sides against each other anyway, to catch a re-typed literal.

const DEFAULT_HIRE_COST: int = 400
const DEFAULT_SKILL_PREMIUM_PER_LEVEL: float = 0.08
const DEFAULT_MAX_TRAITS: int = 2
const DEFAULT_BASE_SKILL_MAX: int = 2
const DEFAULT_STANDOUT_MIN: int = 1
const DEFAULT_STANDOUT_MAX: int = 2
const DEFAULT_STANDOUT_MIN_LEVEL: int = 4
const DEFAULT_STANDOUT_MAX_LEVEL: int = 9

## Curated identity tints rolled per candidate (WI-22). Deliberately light and
## low-saturation: modulate multiplies the sprite art, so full-random colours
## muddy it - these keep the pawn readable against module interiors.
##
## Typed `Array[Color]` rather than the `PackedColorArray` this used to be:
## GDScript cannot resolve a `PackedColorArray(...)` const from another script
## ("Could not resolve external class member"), and CrewManager's export has to
## read this one to avoid restating the palette.
const DEFAULT_TINTS: Array[Color] = [
	Color(1.0, 0.76, 0.72),   # salmon
	Color(0.98, 0.85, 0.68),  # tan
	Color(0.98, 0.92, 0.70),  # gold
	Color(0.86, 0.94, 0.70),  # chartreuse
	Color(0.78, 0.94, 0.76),  # sage
	Color(0.72, 0.92, 0.86),  # aqua
	Color(0.74, 0.90, 0.98),  # sky
	Color(0.78, 0.82, 0.98),  # periwinkle
	Color(0.87, 0.79, 0.97),  # lavender
	Color(0.98, 0.80, 0.92),  # rose
	Color(0.88, 0.85, 0.80),  # warm grey
	Color(0.74, 0.83, 0.88),  # slate
]

## Base price before the skill premium and the trait/kind multipliers.
var hire_cost: int = DEFAULT_HIRE_COST
## Price = hire_cost x (1 + total_skill_levels * this) x trait price modifiers.
var skill_premium_per_level: float = DEFAULT_SKILL_PREMIUM_PER_LEVEL
## Upper bound on traits rolled per candidate; the actual count is a uniform
## 0..this. TraitData.roll_set never picks two conflicting traits.
var max_traits_per_crew: int = DEFAULT_MAX_TRAITS
## Skill roll: every skill starts a low 0..base_skill_max, then a few standouts
## are bumped into the standout band.
var base_skill_max: int = DEFAULT_BASE_SKILL_MAX
var standout_min: int = DEFAULT_STANDOUT_MIN
var standout_max: int = DEFAULT_STANDOUT_MAX
var standout_min_level: int = DEFAULT_STANDOUT_MIN_LEVEL
var standout_max_level: int = DEFAULT_STANDOUT_MAX_LEVEL
var tint_palette: Array[Color] = DEFAULT_TINTS

## One fully rolled candidate: kind, name, tint, skills, traits, price.
func roll() -> HireCandidate:
	var candidate := HireCandidate.new()
	# Rolled up front so the price below can account for the kind's band, and so
	# the offer the player sees is the one that actually turns up (WI-47 M10).
	var kind: PawnData = PawnData.roll_for_role(PawnData.Role.CREW)
	if kind != null:
		candidate.pawn_id = kind.id
	candidate.pawn_name = NameGenerator.random_name()
	candidate.tint = roll_tint()
	candidate.skills = roll_skills()
	for trait_data: TraitData in TraitData.roll_set(randi_range(0, max_traits_per_crew)):
		candidate.trait_ids.append(trait_data.id)
	candidate.price = price_for(candidate)
	return candidate

## Every skill low (0..base_skill_max), then 1-2 standouts bumped high - "mostly
## low with a couple of strengths".
func roll_skills() -> Dictionary[StringName, int]:
	var out: Dictionary[StringName, int] = {}
	var all_skills: Array[SkillData] = SkillData.all()
	for skill: SkillData in all_skills:
		out[skill.id] = randi_range(0, base_skill_max)
	var pool: Array[SkillData] = all_skills.duplicate()
	pool.shuffle()
	var standouts: int = randi_range(standout_min, standout_max)
	for i: int in mini(standouts, pool.size()):
		out[pool[i].id] = randi_range(standout_min_level, standout_max_level)
	return out

## Random tint from the curated palette. White when the palette is empty, which
## is "nobody configured one" rather than an error.
func roll_tint() -> Color:
	if tint_palette.is_empty():
		return Color.WHITE
	return tint_palette[randi() % tint_palette.size()]

## Base cost scaled by a skill premium (monotonic in total levels) and the
## product of the candidate's trait price modifiers (good up, bad down).
func price_for(candidate: HireCandidate) -> int:
	var trait_mod: float = 1.0
	for tid: StringName in candidate.trait_ids:
		var trait_data: TraitData = TraitData.by_id(tid)
		if trait_data != null:
			trait_mod *= trait_data.price_modifier
	# The pawn kind's band folds into the same multiplier chain as traits (WI-47
	# M10), so a cheap contractor or a pricey specialist needs no separate rule.
	var kind: PawnData = PawnData.by_id(candidate.pawn_id) if candidate.pawn_id != &"" else null
	if kind != null:
		trait_mod *= kind.hire_price_mult
	return compute_price(hire_cost, candidate.total_skill_levels(), trait_mod, skill_premium_per_level)

## Pure pricing arithmetic (WI-22), static so it can be unit-tested without even
## a roller. Strictly increasing in total_skill_levels for a fixed trait
## modifier, which guarantees a higher-skilled roll is never cheaper (the "no
## elite for free" edge case).
static func compute_price(base_cost: int, total_skill_levels: int, trait_price_mod: float, premium_per_level: float) -> int:
	var skill_premium: float = 1.0 + float(total_skill_levels) * premium_per_level
	return int(round(float(base_cost) * skill_premium * trait_price_mod))
