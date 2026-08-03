class_name RecipeData
extends Resource

@export var name: String = ""
@export var inputs: Dictionary[ResourceData, int] = {}
@export var outputs: Dictionary[ResourceData, int] = {}

## Which processors may run this recipe, by MODULE TAG (WI-47 M8).
##
## Eligibility is declared here rather than on the processor because the array it
## used to live in - ProcessorComponent.available_recipes - is authored inside the
## module's *scene*. A mod could add an ore and a refining recipe for it and have
## no way to make the existing refinery accept it short of shipping a replacement
## refinery scene, which then conflicts with every other mod that did the same.
## That single fact was the difference between "mods can add ores" and "mods can
## add ore chains".
##
## Tags, not module ids: one declaration reaches the vanilla refinery and any
## modded refinery that claims the same tag, which is the whole point of the tag
## vocabulary upgrades and adjacency already share.
@export var processor_tags: Array[String] = []

## Position in a multi-recipe processor's selector, ascending. Vanilla leaves gaps
## of 10 so a mod can slot a recipe between two existing ones rather than only at
## the end. Ties break on name.
@export var sort_order: int = 0

# --- reverse index --------------------------------------------------------------
# Scanned once and cached on the data class, the way SkillData and
# BuildCategoryData are. A processor asks "which recipes claim any of my module's
# tags", instead of a scene array answering "which recipes do I offer".

static var _by_tag: Dictionary[String, Array] = {}
static var _scanned: bool = false

static func _ensure_scanned() -> void:
	if _scanned:
		return
	_scanned = true
	for path: String in ContentPaths.scan(ContentPaths.RECIPES):
		var res: Resource = ResourceLoader.load(path)
		if res is not RecipeData:
			continue
		var recipe := res as RecipeData
		for tag: String in recipe.processor_tags:
			var bucket: Array = _by_tag.get_or_add(tag, [])
			if not bucket.has(recipe):
				bucket.append(recipe)

## Every recipe claiming any of `tags`, in selector order. Deterministic: a
## processor's recipe list must not reshuffle between runs.
static func for_tags(tags: Array[String]) -> Array[RecipeData]:
	_ensure_scanned()
	var out: Array[RecipeData] = []
	for tag: String in tags:
		for recipe: RecipeData in _by_tag.get(tag, []):
			if not out.has(recipe):
				out.append(recipe)
	out.sort_custom(func(a: RecipeData, b: RecipeData) -> bool:
		if a.sort_order != b.sort_order:
			return a.sort_order < b.sort_order
		return a.name.naturalnocasecmp_to(b.name) < 0)
	return out

## Test seam - the index is static and shared by every suite in a run.
static func register_for_test(recipe: RecipeData) -> void:
	_scanned = true
	for tag: String in recipe.processor_tags:
		var bucket: Array = _by_tag.get_or_add(tag, [])
		if not bucket.has(recipe):
			bucket.append(recipe)

static func clear_for_test() -> void:
	_by_tag.clear()
	_scanned = false

## Output scaling across input richness: a batch of richness 0.0 yields
## outputs × min_yield_mult, richness 1.0 yields × max_yield_mult (lerped
## between). Both 1.0 (the default) = outputs are always exactly recipe-sized,
## which is correct for recipes whose inputs carry no variance.
@export var min_yield_mult: float = 1.0
@export var max_yield_mult: float = 1.0

## Base quality (0..1) stamped onto this recipe's outputs as FoodInstanceData
## (WI-29). -1.0 (the default) = this isn't a food recipe: outputs stay plain,
## exactly as before. Food recipes set a positive base expressing the module
## ladder (algae tank/vats < hydroponics < greenhouse); a manned producer's
## worker shifts it further via ProcessorComponent.worker_quality_shift_at_max.
@export_range(-1.0, 1.0, 0.01) var output_quality_base: float = -1.0
