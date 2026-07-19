class_name TraitData
extends Resource

## Definition of one pawn trait (WI-22). Authored as a .tres under
## res://data/traits/. A trait is pure data: it never runs its own process
## loop - the host systems (needs, health, socialize) query the trait's hook
## fields below and apply them. Which traits a pawn has lives on
## PawnTraitsComponent; this is the shared, tunable definition.

const TRAITS_PATH: String = "res://data/traits/"

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
## Scales passive social recreation gain from company. Introvert 0 (crowds do
## nothing), Extrovert 2 (thrives). 1.0 = normal.
@export var passive_social_multiplier: float = 1.0
## Percentage points added to the passive-social recreation cap (Extrovert).
@export var passive_social_cap_bonus: float = 0.0
## Introvert: gains passive recreation while ALONE in a module instead of from
## company.
@export var solitude_recreation: bool = false
## Multiplies a hire candidate's price (WI-22): desirable traits > 1 (costlier),
## drawbacks < 1 (cheaper). 1.0 = price-neutral.
@export var price_modifier: float = 1.0

# --- shared registry ----------------------------------------------------------
# Same pattern as SkillData: scan res://data/traits/ once, cache id -> TraitData.
# Statics survive scene reload, so the cache persists across save/load.

static var _registry: Dictionary[StringName, TraitData] = {}
static var _ordered: Array[TraitData] = []
static var _scanned: bool = false

static func _ensure_scanned() -> void:
	if _scanned:
		return
	_scanned = true
	for path: String in ResourceScanner.scan_paths(TRAITS_PATH):
		var res: Resource = ResourceLoader.load(path)
		if res is TraitData:
			var trait_data := res as TraitData
			if trait_data.id == &"":
				push_warning("TraitData with empty id, skipping: " + path)
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
