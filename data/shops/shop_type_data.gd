class_name ShopTypeData
extends Resource

## One shop flavor (WI-33). Authored as a .tres under res://data/shops/, scanned
## once into a shared registry (mirrors SkillData/DiseaseData). A ShopComponent is
## customized by the type the player picks at placement / in the panel, the same
## way a ProcessorComponent is customized by its selected recipe - so one shop
## scene + one component covers every storefront.
##
## Definition only: the current selection is runtime state on ShopComponent, never
## written back onto this shared resource. Balance (price band, payout) lives here
## per the balance-in-data invariant.


## Stable identifier (matches the .tres stem); saved as the ShopComponent's
## selected type. Never rename once players have saves referencing it.
@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var flavor: String = ""

## Credits charged per visit, rolled uniformly in [price_min, price_max] when a
## customer commits. The whole charge is booked as station income (levy applies).
@export var price_min: int = 20
@export var price_max: int = 40

## Recreation points restored per game-hour while a customer is inside - a shop is
## a recreation provider (RecreationProviderComponent), so this is its raw rate.
@export var recreation_per_hour: float = 40.0

## Mood lift a visitor takes away from a satisfying visit (WI-33), a timed
## happiness modifier. Nudges reputation up through happier departures. 0 = none.
@export var visit_mood_bonus: float = 0.05
@export var visit_mood_duration_hours: float = 6.0

## Sprite tint applied to the storefront so the picked type reads at a glance
## (the shop scene reuses one generic sprite). White = untinted.
@export var modulate: Color = Color.WHITE

# --- shared registry ----------------------------------------------------------
# Shop definitions are global and fixed, so scan res://data/shops/ once and cache
# id -> ShopTypeData. Statics survive scene reload, so the cache persists across
# save/load.

static var _registry: Dictionary[StringName, ShopTypeData] = {}
static var _ordered: Array[ShopTypeData] = []
static var _scanned: bool = false

static func _ensure_scanned() -> void:
	if _scanned:
		return
	_scanned = true
	for path: String in ContentPaths.scan(ContentPaths.SHOPS):
		var res: Resource = ResourceLoader.load(path)
		if res is ShopTypeData:
			var shop := res as ShopTypeData
			if not ContentPaths.accept_id(shop.id, path, "ShopTypeData"):
				continue
			_registry[shop.id] = shop
			_ordered.append(shop)

## Every shop-type definition, in scan order (the build/panel selector order).
static func all() -> Array[ShopTypeData]:
	_ensure_scanned()
	return _ordered

## The definition for `type_id`, or null if there's no such type.
static func by_id(type_id: StringName) -> ShopTypeData:
	_ensure_scanned()
	return _registry.get(type_id, null)

## Pure price roll (WI-33), extracted so it's unit-testable without Global. Clamps
## a malformed band (min > max) rather than erroring, and never returns below 0.
static func roll_price(min_price: int, max_price: int) -> int:
	var lo: int = maxi(min_price, 0)
	var hi: int = maxi(max_price, lo)
	return randi_range(lo, hi)

## This type's rolled visit price.
func visit_price() -> int:
	return roll_price(price_min, price_max)

## The cheapest this type can ever charge - the affordability gate a customer
## checks before committing (so a visit can't fail on price after paying to walk).
func min_visit_price() -> int:
	return maxi(price_min, 0)
