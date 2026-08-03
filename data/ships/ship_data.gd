class_name ShipData
extends Resource

## One kind of raider (WI-47 M7). `RaidManager` used to hold a single
## `pirate_ship_scene` export and instantiate it N times, so "pirates" was one
## ship with one stat line and a mod could not add a second kind at all.
##
## A variant is a scene plus the selection and salvage rules around it. The
## PER-SHIP numbers - hull, speed, laser damage, fire interval and range, tint -
## deliberately stay exported on the scene rather than being mirrored here: that
## is where they already live, it is how ModuleData relates to its module scene,
## and duplicating them would only create two places to disagree. A modder making
## a heavier raider inherits the pirate ship scene, retunes its exports, and points
## a ShipData at it.
##
## Not a threat *type*: this covers "mods can add pirate ships and wave
## compositions", which is the common ask. A genuinely different danger - a
## derelict, a blockade, a solar flare - is the deferred ThreatData/ThreatDriver
## half of M7, and M3's save-participant registry is what lets a mod build one
## without this.

## Stable id. Saved per-ship so a mid-raid save restores the right variant;
## namespace mod ships `modid.thing` like any other content id.
@export var id: StringName = &""
@export var display_name: String = ""
## The PirateShip scene this variant flies.
@export var scene: PackedScene

## --- selection --------------------------------------------------------------
## Station value (RaidManager's computed strength) below which this variant never
## appears, so heavier raiders show up as the station grows rather than ambushing
## a starting base.
@export var min_strength: float = 0.0
## Relative likelihood among the eligible variants. 0 = never picked.
@export var weight: float = 1.0

## --- salvage ----------------------------------------------------------------
## What this variant drops when destroyed. Null falls back to RaidManager's
## salvage_resource, so a variant only declares salvage if it differs.
@export var salvage_resource: ResourceData
## Min/max units dropped. x < 0 falls back to RaidManager's salvage_amount.
@export var salvage_amount: Vector2i = Vector2i(-1, -1)

# --- registry -------------------------------------------------------------------
# Scanned once and cached, the way SkillData / BuildCategoryData / RecipeData are.

static var _registry: Dictionary[StringName, ShipData] = {}
static var _ordered: Array[ShipData] = []
static var _scanned: bool = false

static func _ensure_scanned() -> void:
	if _scanned:
		return
	_scanned = true
	for path: String in ContentPaths.scan(ContentPaths.SHIPS):
		var res: Resource = ResourceLoader.load(path)
		if res is not ShipData:
			continue
		var ship := res as ShipData
		if not ContentPaths.accept_id(ship.id, path, "ShipData"):
			continue
		_registry[ship.id] = ship
		_ordered.append(ship)

static func all() -> Array[ShipData]:
	_ensure_scanned()
	return _ordered

static func by_id(ship_id: StringName) -> ShipData:
	_ensure_scanned()
	return _registry.get(ship_id, null)

## Variants a station worth `strength` can draw, weight > 0 and unlocked by value.
##
## Sorted by id HERE rather than at scan time: this is the list that feeds the
## weighted roll, so it is the one place the order has to be reproducible, and
## sorting here holds however entries reached the registry (scan or test seam).
static func eligible(strength: float) -> Array[ShipData]:
	var out: Array[ShipData] = []
	for ship: ShipData in all():
		if ship.weight > 0.0 and ship.scene != null and strength >= ship.min_strength:
			out.append(ship)
	out.sort_custom(func(a: ShipData, b: ShipData) -> bool: return String(a.id) < String(b.id))
	return out

## Weighted pick from `pool` for `roll` in [0, 1). Null for an empty pool or
## all-zero weights; a roll at either end still lands on a real entry, so the
## caller never has to special-case the boundaries (see WeightedPick).
static func pick(pool: Array[ShipData], roll: float) -> ShipData:
	var weights: PackedFloat32Array = PackedFloat32Array()
	for ship: ShipData in pool:
		weights.append(ship.weight)
	var index: int = WeightedPick.index_for(weights, roll)
	return pool[index] if index >= 0 else null

static func register_for_test(ship: ShipData) -> void:
	_scanned = true
	if ship != null and ship.id != &"":
		_registry[ship.id] = ship
		_ordered.append(ship)

static func clear_for_test() -> void:
	_registry.clear()
	_ordered.clear()
	_scanned = false
