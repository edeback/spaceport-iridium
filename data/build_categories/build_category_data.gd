class_name BuildCategoryData
extends Resource

## One rail bucket in the build menu (WI-47 M5). Replaces ModuleData's fixed
## UICategory enum: an enum cannot be extended from data, so a mod's modules all
## landed in OTHER no matter what they were.
##
## Purely a UI concept, exactly as the enum was. `ModuleData.tags` remains the
## gameplay vocabulary (upgrade eligibility, stat targeting, inspection
## checklists, event conditions, minimap colour); a category only decides which
## rail button a module appears under. Never gate gameplay on one.

## What a module gets when it declares no category, and the bucket that has
## always sorted last.
const DEFAULT_ID: StringName = &"other"

## Sort order used for a category id that no .tres declares - a module pointing at
## a category from a mod that isn't installed. It lands after every real category
## rather than silently first, and the rail still renders (the id is its own label).
const UNKNOWN_SORT_ORDER: int = 9999

## Stable id, matching the .tres file stem. Modules reference this; mod categories
## must be namespaced `modid.thing` like every other content id.
@export var id: StringName = &""
@export var display_name: String = ""
## Rail position, ascending. Vanilla leaves gaps of 10 so a mod can slot between.
@export var sort_order: int = 0
## Rail icon. Optional - the menu falls back to a representative module's icon.
@export var cat_icon: Texture2D

# --- shared registry ------------------------------------------------------------
# Same shape as SkillData/TraitData: scanned once per ContentPaths.generation, cached on the data class, and
# surviving the scene swap because statics do.

static var _registry: Dictionary[StringName, BuildCategoryData] = {}
static var _ordered: Array[BuildCategoryData] = []
## The [member ContentPaths.generation] this cache last scanned at, -1 for never.
## A stale one rescans on the next read (WI-74 §2).
static var _scanned_generation: int = -1

static func _ensure_scanned() -> void:
	if _scanned_generation == ContentPaths.generation:
		return
	_scanned_generation = ContentPaths.generation
	_registry.clear()
	_ordered.clear()
	for path: String in ContentPaths.scan(ContentPaths.BUILD_CATEGORIES):
		var res: Resource = ResourceLoader.load(path)
		if res is BuildCategoryData:
			var category := res as BuildCategoryData
			if not ContentPaths.accept_id(category.id, path, "BuildCategoryData"):
				continue
			_registry[category.id] = category
			_ordered.append(category)
	_ordered.sort_custom(func(a: BuildCategoryData, b: BuildCategoryData) -> bool:
		if a.sort_order != b.sort_order:
			return a.sort_order < b.sort_order
		return String(a.id) < String(b.id))

## Every declared category, in rail order.
static func all() -> Array[BuildCategoryData]:
	_ensure_scanned()
	return _ordered

static func by_id(category_id: StringName) -> BuildCategoryData:
	_ensure_scanned()
	return _registry.get(category_id, null)

## Rail position for an id, or UNKNOWN_SORT_ORDER when nothing declares it.
static func sort_order_of(category_id: StringName) -> int:
	var category: BuildCategoryData = by_id(category_id)
	return category.sort_order if category != null else UNKNOWN_SORT_ORDER

## Rail label, falling back to the id itself so a module whose category came from
## an uninstalled mod still renders under something readable.
static func display_name_of(category_id: StringName) -> String:
	var category: BuildCategoryData = by_id(category_id)
	if category != null and category.display_name != "":
		return category.display_name
	return String(category_id).capitalize()

static func icon_of(category_id: StringName) -> Texture2D:
	var category: BuildCategoryData = by_id(category_id)
	return category.cat_icon if category != null else null

## Test seam, mirroring JobDataRegistry's: the registry is static and shared by
## every suite in a run.
static func register_for_test(category: BuildCategoryData) -> void:
	_scanned_generation = ContentPaths.generation
	if category != null and category.id != &"":
		_registry[category.id] = category
		_ordered.append(category)

static func clear_for_test() -> void:
	_registry.clear()
	_ordered.clear()
	_scanned_generation = -1
