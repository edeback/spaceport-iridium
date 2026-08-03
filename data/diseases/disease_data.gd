class_name DiseaseData
extends Resource

## Definition of one disease (WI-31). Authored as a .tres under res://data/diseases/.
## Per-pawn active state (which stage, elapsed hours, treatment progress) lives on
## PawnDiseaseComponent; this holds only the shared, tunable definition - staged
## effects, contagiousness, acquisition tags, treatment cost, and the station tier
## it unlocks at (balance-in-data invariant).


## Stable identifier used as the disease key everywhere (the active-state dict,
## the infect cheat, save/load, outbreak selection).
@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Ordered progression. A newly-caught disease starts at stage 0 and advances
## through the array as each stage's duration elapses (see PawnDiseaseComponent).
@export var stages: Array[DiseaseStage] = []
## Per-game-hour chance one co-located, uninfected organic pawn catches this from
## a carrier (scaled down by the module's purified_air adjacency field). 0 =
## non-infectious (Void Sickness).
@export var contagious_rate: float = 0.0
## How this disease can be seeded: &"outbreak" (event), &"space" (EVA accrual),
## &"visitor" (WI-33). Pawn-to-pawn spread uses contagious_rate regardless; these
## tag which *sources* may introduce it.
@export var acquisition: Array[StringName] = []
## Treatment progress-hours needed (against the baseline auto-med rate of 1.0/hr)
## to clear the disease, or to regress one stage when cure_at_stage_reset is set.
@export var treat_hours_base: float = 12.0
## When true, reaching treat_hours_base regresses one stage (worst-first) instead
## of curing outright; the disease clears only when treated below stage 0. When
## false, a single completed treatment cures it whatever stage it's at.
@export var cure_at_stage_reset: bool = false
## Station tier at which this disease becomes possible (WI-26 tiers). >= 2 for all
## v1 content, so a Tier-1 station has no disease - and no outbreak event - at all.
@export var min_station_tier: int = 2

func is_contagious() -> bool:
	return contagious_rate > 0.0

func stage_count() -> int:
	return stages.size()

## The stage at `index`, clamped into range. Null only when the disease has no
## stages authored (a data error).
func get_stage(index: int) -> DiseaseStage:
	if stages.is_empty():
		return null
	return stages[clampi(index, 0, stages.size() - 1)]

func is_final_stage(index: int) -> bool:
	return index >= stages.size() - 1

func has_acquisition(tag: StringName) -> bool:
	return acquisition.has(tag)

# --- shared registry ----------------------------------------------------------
# Disease definitions are global and fixed, so scan res://data/diseases/ once and
# cache id -> DiseaseData (mirrors SkillData/TraitData). Statics survive scene
# reload, so the cache persists across save/load.

static var _registry: Dictionary[StringName, DiseaseData] = {}
static var _ordered: Array[DiseaseData] = []
static var _scanned: bool = false

static func _ensure_scanned() -> void:
	if _scanned:
		return
	_scanned = true
	for path: String in ContentPaths.scan(ContentPaths.DISEASES):
		var res: Resource = ResourceLoader.load(path)
		if res is DiseaseData:
			var disease := res as DiseaseData
			if not ContentPaths.accept_id(disease.id, path, "DiseaseData"):
				continue
			_registry[disease.id] = disease
			_ordered.append(disease)

## Every disease definition.
static func all() -> Array[DiseaseData]:
	_ensure_scanned()
	return _ordered

## The definition for `disease_id`, or null if there's no such disease.
static func by_id(disease_id: StringName) -> DiseaseData:
	_ensure_scanned()
	return _registry.get(disease_id, null)

## Diseases unlocked at `tier` (min_station_tier <= tier). Empty at tier 1.
static func unlocked_at_tier(tier: int) -> Array[DiseaseData]:
	var out: Array[DiseaseData] = []
	for disease: DiseaseData in all():
		if tier >= disease.min_station_tier:
			out.append(disease)
	return out

## Unlocked, infectious diseases an outbreak event may seed (acquisition includes
## &"outbreak"). Excludes non-contagious diseases like Void Sickness.
static func outbreak_pool(tier: int) -> Array[DiseaseData]:
	var out: Array[DiseaseData] = []
	for disease: DiseaseData in unlocked_at_tier(tier):
		if disease.is_contagious() and disease.has_acquisition(&"outbreak"):
			out.append(disease)
	return out
