class_name PawnData
extends Resource

## One kind of pawn a manager can spawn (WI-47 M10). `CrewManager` held a single
## `crew_pawn_scene` and `VisitorManager` a single `visitor_pawn_scene`, so
## "crew" and "visitor" were each exactly one scene and a mod could not add an
## alternate kind - a synthetic worker, a VIP guest, a contractor.
##
## RESTORE was already fine: the save stores each pawn's `scene_file_path` and
## rebuilds from it, so a modded pawn round-trips today. Only SPAWNING was
## hardcoded, which is all this changes.
##
## As with ShipData, the per-pawn behaviour stays on the scene (its components and
## their exports); this resource is identity plus the rules for picking it.
##
## Deliberately NOT carried, contrary to the finding's list: a name-generator
## style. `NameGenerator` has no notion of styles today, and adding an export
## nothing reads is worse than leaving it out - it belongs with the name-word-list
## audit the WI already defers.

## Which manager sources this kind.
enum Role {
	CREW,     ## CrewManager: starting crew and hires.
	VISITOR,  ## VisitorManager: paying guests.
}

## Stable id, saved on a hire candidate so a queued arrival remembers its kind.
## Namespace mod pawns `modid.thing` like any other content id.
@export var id: StringName = &""
@export var display_name: String = ""
@export var scene: PackedScene
@export var role: Role = Role.CREW

## Relative likelihood among the eligible kinds for a role. 0 = never spawned,
## which is how a kind can exist purely to be summoned by a mod's own code.
@export var weight: float = 1.0

## Scales the rolled hire price for this kind (CREW only). 1.0 = standard;
## a cheap contractor or an expensive specialist moves it.
@export var hire_price_mult: float = 1.0

# --- registry -------------------------------------------------------------------

static var _registry: Dictionary[StringName, PawnData] = {}
static var _ordered: Array[PawnData] = []
## The [member ContentPaths.generation] this cache last scanned at, -1 for never.
## A stale one rescans on the next read (WI-74 §2).
static var _scanned_generation: int = -1

static func _ensure_scanned() -> void:
	if _scanned_generation == ContentPaths.generation:
		return
	_scanned_generation = ContentPaths.generation
	_registry.clear()
	_ordered.clear()
	for path: String in ContentPaths.scan(ContentPaths.PAWNS):
		var res: Resource = ResourceLoader.load(path)
		if res is not PawnData:
			continue
		var pawn_data := res as PawnData
		if not ContentPaths.accept_id(pawn_data.id, path, "PawnData"):
			continue
		_registry[pawn_data.id] = pawn_data
		_ordered.append(pawn_data)

static func all() -> Array[PawnData]:
	_ensure_scanned()
	return _ordered

static func by_id(pawn_id: StringName) -> PawnData:
	_ensure_scanned()
	return _registry.get(pawn_id, null)

## Spawnable kinds for `role`, sorted by id. Sorted here rather than at scan time
## for the same reason ShipData does it: this is the list that feeds the roll, so
## it is where reproducibility has to hold.
static func for_role(role: Role) -> Array[PawnData]:
	var out: Array[PawnData] = []
	for pawn_data: PawnData in all():
		if pawn_data.role == role and pawn_data.weight > 0.0 and pawn_data.scene != null:
			out.append(pawn_data)
	out.sort_custom(func(a: PawnData, b: PawnData) -> bool: return String(a.id) < String(b.id))
	return out

static func pick(pool: Array[PawnData], roll: float) -> PawnData:
	var weights: PackedFloat32Array = PackedFloat32Array()
	for pawn_data: PawnData in pool:
		weights.append(pawn_data.weight)
	var index: int = WeightedPick.index_for(weights, roll)
	return pool[index] if index >= 0 else null

## Convenience for the spawn sites: roll a kind for `role`, or null when nothing
## is declared (the caller then uses its own fallback scene).
static func roll_for_role(role: Role) -> PawnData:
	return pick(for_role(role), randf())

static func register_for_test(pawn_data: PawnData) -> void:
	_scanned_generation = ContentPaths.generation
	if pawn_data != null and pawn_data.id != &"":
		_registry[pawn_data.id] = pawn_data
		_ordered.append(pawn_data)

static func clear_for_test() -> void:
	_registry.clear()
	_ordered.clear()
	_scanned_generation = -1
