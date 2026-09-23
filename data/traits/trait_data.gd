class_name TraitData
extends Resource

## Definition of one pawn trait (WI-22). Authored as a .tres under
## res://data/traits/. A trait is pure data: it never runs its own process
## loop - the host systems (needs, health, socialize) query the trait's hook
## fields below and apply them. Which traits a pawn has lives on
## PawnTraitsComponent; this is the shared, tunable definition.


## Stable identifier - also the key used for this trait's permanent happiness
## modifier on PawnNeedsComponent, so applying/removing it is idempotent.
@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Traits sharing a non-empty group are mutually exclusive at roll time, so a
## pawn never gets both Optimist and Pessimist. Empty = never conflicts.
@export var exclusive_group: StringName = &""

# --- hook fields (all default to no-op) --------------------------------------
## Permanent flat happiness offset (Optimist +, Pessimist −), applied as an
## INF-duration PawnNeedsComponent modifier keyed by this trait's id.
@export var happiness_offset: float = 0.0
## Happiness offset active only while the pawn is outside (current_module ==
## null). Spacer is +; toggled on interior/exterior transitions.
@export var exterior_happiness_offset: float = 0.0
## Multiplies incoming health decay (starvation/suffocation). Hardy < 1 (tough),
## Weak > 1 (frail). 1.0 = unaffected.
@export var damage_multiplier: float = 1.0
## Scales how long this pawn waits between wanting to chat (WI-48). Extrovert
## 0.5 (twice as often), Introvert 2.0 (half as often). 1.0 = normal.
##
## Replaced passive_social_multiplier when chats replaced the passive company
## drip: the trait now changes how OFTEN company pays off, not how fast it
## trickles.
@export var chat_interval_multiplier: float = 1.0
## Scales the recreation one good chat pays this pawn (WI-48). 1.0 = normal.
@export var chat_recreation_multiplier: float = 1.0
## Introvert: gains passive recreation while ALONE in a module. Untouched by
## WI-48 - solitude doesn't involve another pawn, so chats don't replace it.
@export var solitude_recreation: bool = false

# --- social axes (WI-48) -------------------------------------------------------
# Two pawns whose traits sit on the same axis get along better when their
# polarities match and worse when they oppose. A trait opts in by carrying a
# nonzero polarity; everything else is socially invisible.

## Where this trait sits on its axis: +1 and -1 are the two poles, 0.0 (the
## default) means the trait has no bearing on how people get on.
@export_range(-1.0, 1.0) var social_polarity: float = 0.0
## The axis social_polarity is measured on. Empty falls back to exclusive_group,
## which already pairs Optimist/Pessimist and Introvert/Extrovert - so the
## vanilla traits need one line each, not a second taxonomy. Set this explicitly
## only for an axis whose traits are NOT mutually exclusive at roll time.
@export var social_axis: StringName = &""

## Multiplies a hire candidate's price (WI-22): desirable traits > 1 (costlier),
## drawbacks < 1 (cheaper). 1.0 = price-neutral.
@export var price_modifier: float = 1.0

## The axis this trait actually contributes to; see social_axis.
func effective_social_axis() -> StringName:
	return social_axis if social_axis != &"" else exclusive_group

# --- shared registry ----------------------------------------------------------
# Same pattern as SkillData: scan res://data/traits/ once, cache id -> TraitData.
# Statics survive scene reload, so the cache persists across save/load.

static var _registry: Dictionary[StringName, TraitData] = {}
static var _ordered: Array[TraitData] = []
## The [member ContentPaths.generation] this cache last scanned at, -1 for never.
## A stale one rescans on the next read (WI-74 §2).
static var _scanned_generation: int = -1

static func _ensure_scanned() -> void:
	if _scanned_generation == ContentPaths.generation:
		return
	_scanned_generation = ContentPaths.generation
	_registry.clear()
	_ordered.clear()
	for path: String in ContentPaths.scan(ContentPaths.TRAITS):
		var res: Resource = ResourceLoader.load(path)
		if res is TraitData:
			var trait_data := res as TraitData
			if not ContentPaths.accept_id(trait_data.id, path, "TraitData"):
				continue
			_registry[trait_data.id] = trait_data
			_ordered.append(trait_data)

## Every trait definition.
static func all() -> Array[TraitData]:
	_ensure_scanned()
	return _ordered

## The definition for `trait_id`, or null if there's no such trait.
static func by_id(trait_id: StringName) -> TraitData:
	_ensure_scanned()
	return _registry.get(trait_id, null)

## Rolls up to `count` distinct traits with no two sharing an exclusive_group
## (so a pawn never gets Optimist+Pessimist). Reused by hire-candidate
## generation (WI-22 step 4).
static func roll_set(count: int) -> Array[TraitData]:
	var pool: Array[TraitData] = all().duplicate()
	pool.shuffle()
	var chosen: Array[TraitData] = []
	var used_groups: Array[StringName] = []
	for trait_data: TraitData in pool:
		if chosen.size() >= count:
			break
		if trait_data.exclusive_group != &"" and used_groups.has(trait_data.exclusive_group):
			continue
		chosen.append(trait_data)
		if trait_data.exclusive_group != &"":
			used_groups.append(trait_data.exclusive_group)
	return chosen
