extends GutTest

## WI-74 §2: the thirteen static content caches, and [member ContentPaths.generation].
##
## Each cache scans [ContentPaths] once and keeps the answer in a static, which
## survives a scene swap - the point of it - and also survived a mod root being
## registered, which was the problem: WI-47's deferred patch ops and any runtime mod
## toggle both need the caches to forget. Now each remembers the generation it
## scanned at, and [method ContentPaths.invalidate] moves the generation on.
##
## Two halves. Every cache listed in [method _caches] is driven through the same
## five steps: read it, plant a fake in its live registry, see the fake, invalidate,
## and see the fake gone with the real content back. And a **source sweep** fails on
## a fourteenth cache written the old way - a static function that scans content
## with no generation to compare against - and on a cache the list below does not
## drive, so a new one cannot land untested.

## Where the game's scripts live - the same roots every other source sweep reads.
const ROOTS: PackedStringArray = ["res://scripts", "res://modules", "res://pawns",
	"res://data", "res://ui", "res://objects"]

## The id every plant uses. Namespaced, so no shipped definition can collide.
const PLANTED: StringName = &"wi74.planted"

func after_each() -> void:
	# Whatever a test planted is gone for every later suite.
	ContentPaths.invalidate()

# --- the caches -----------------------------------------------------------------

## One row per cache: the script it lives in, how to plant a fake in its live
## registry, whether the fake is visible, and whether real content is.
func _caches() -> Array[Dictionary]:
	return [
		_row("res://data/build_categories/build_category_data.gd",
			func() -> void: BuildCategoryData._registry[PLANTED] = BuildCategoryData.new(),
			func() -> bool: return BuildCategoryData.by_id(PLANTED) != null,
			func() -> bool: return not BuildCategoryData.all().is_empty()),
		_row("res://data/difficulty/difficulty_data.gd",
			func() -> void: DifficultyData._registry[PLANTED] = DifficultyData.new(),
			func() -> bool: return DifficultyData.by_id(PLANTED) != null,
			func() -> bool: return not DifficultyData.all().is_empty()),
		_row("res://data/diseases/disease_data.gd",
			func() -> void: DiseaseData._registry[PLANTED] = DiseaseData.new(),
			func() -> bool: return DiseaseData.by_id(PLANTED) != null,
			func() -> bool: return not DiseaseData.all().is_empty()),
		_row("res://data/pawns/pawn_data.gd",
			func() -> void: PawnData._registry[PLANTED] = PawnData.new(),
			func() -> bool: return PawnData.by_id(PLANTED) != null,
			func() -> bool: return not PawnData.all().is_empty()),
		_row("res://data/planet_variants/planet_variant.gd",
			func() -> void: PlanetVariant._registry[PLANTED] = PlanetVariant.new(),
			func() -> bool: return PlanetVariant.by_id(PLANTED) != null,
			func() -> bool: return not PlanetVariant.all().is_empty()),
		_row("res://data/recipes/recipe_data.gd",
			func() -> void: RecipeData._by_tag[String(PLANTED)] = [RecipeData.new()],
			func() -> bool: return not RecipeData.for_tags([String(PLANTED)] as Array[String]).is_empty(),
			func() -> bool: return not RecipeData.for_tags(["Industrial", "Refinery"] as Array[String]).is_empty()),
		_row("res://data/ships/ship_data.gd",
			func() -> void: ShipData._registry[PLANTED] = ShipData.new(),
			func() -> bool: return ShipData.by_id(PLANTED) != null,
			func() -> bool: return not ShipData.all().is_empty()),
		_row("res://data/shops/shop_type_data.gd",
			func() -> void: ShopTypeData._registry[PLANTED] = ShopTypeData.new(),
			func() -> bool: return ShopTypeData.by_id(PLANTED) != null,
			func() -> bool: return not ShopTypeData.all().is_empty()),
		_row("res://data/skills/skill_data.gd",
			func() -> void: SkillData._registry[PLANTED] = SkillData.new(),
			func() -> bool: return SkillData.by_id(PLANTED) != null,
			func() -> bool: return not SkillData.all().is_empty()),
		_row("res://data/star_classes/star_class.gd",
			func() -> void: StarClass._registry[PLANTED] = StarClass.new(),
			func() -> bool: return StarClass.by_id(PLANTED) != null,
			func() -> bool: return not StarClass.all().is_empty()),
		_row("res://data/traits/trait_data.gd",
			func() -> void: TraitData._registry[PLANTED] = TraitData.new(),
			func() -> bool: return TraitData.by_id(PLANTED) != null,
			func() -> bool: return not TraitData.all().is_empty()),
		_row("res://scripts/jobs/job_data_registry.gd",
			func() -> void: JobDataRegistry._by_id[PLANTED] = JobData.new(),
			func() -> bool: return JobDataRegistry.has(PLANTED),
			func() -> bool: return JobDataRegistry.has(&"haul_resource")),
		_row("res://scripts/utility/mood_catalog.gd",
			func() -> void: MoodCatalog._event_by_modifier[PLANTED] = EventData.new(),
			func() -> bool: return MoodCatalog._event_for(PLANTED) != null,
			func() -> bool: return MoodCatalog._event_for(&"arc_levy") != null),
	]

func _row(path: String, plant: Callable, sees_plant: Callable, sees_content: Callable) -> Dictionary:
	return {"path": path, "plant": plant, "sees_plant": sees_plant, "sees_content": sees_content}

func test_every_cache_forgets_a_plant_when_content_paths_moves_on() -> void:
	for cache: Dictionary in _caches():
		var label: String = String(cache["path"]).get_file()
		var sees_plant: Callable = cache["sees_plant"] as Callable
		var sees_content: Callable = cache["sees_content"] as Callable
		# Read first, so the plant lands in a scanned registry rather than one the
		# first read would have built from scratch anyway.
		assert_true(sees_content.call(), "%s scans the shipped content" % label)
		(cache["plant"] as Callable).call()
		assert_true(sees_plant.call(), "%s: the plant is in the live registry" % label)
		ContentPaths.invalidate()
		assert_false(sees_plant.call(), "%s rescans after invalidate() and the plant is gone" % label)
		assert_true(sees_content.call(), "%s: and the shipped content is back" % label)

func test_a_cache_left_alone_does_not_rescan() -> void:
	# The other half of the contract: nothing moved, so the plant stays. Without
	# this, a cache that rescanned on every read would pass the test above.
	SkillData.all()
	SkillData._registry[PLANTED] = SkillData.new()
	assert_not_null(SkillData.by_id(PLANTED), "no invalidate, no rescan")

func test_registering_a_mod_root_invalidates() -> void:
	SkillData.all()
	SkillData._registry[PLANTED] = SkillData.new()
	ContentPaths.register_mod_root("res://mods/wi74_absent/data/", &"wi74")
	assert_null(SkillData.by_id(PLANTED), "a new root is new content, so every cache rescans")
	ContentPaths.clear_mod_roots()

# --- the sweep ------------------------------------------------------------------

## What is wrong with `source` as a content cache, or "" if nothing is: a static
## function that scans [ContentPaths] with no generation to compare against, or the
## old boolean latch that could never be reset from outside.
static func cache_problem(source: String) -> String:
	if _old_latch().search(source) != null:
		return "keeps a `static var ..._scanned: bool` latch, which invalidate() cannot reach"
	if _scans_statically(source) and not source.contains("ContentPaths.generation"):
		return "scans ContentPaths from a static function without comparing ContentPaths.generation"
	return ""

static func _old_latch() -> RegEx:
	return RegEx.create_from_string("static var \\w*scanned\\w*\\s*:\\s*bool")

## Whether any `ContentPaths.scan(` sits inside a `static func`. Line by line, since
## a function ends at the next line that starts at column 0 and is not a comment.
static func _scans_statically(source: String) -> bool:
	var in_static: bool = false
	for line: String in source.split("\n"):
		var trimmed: String = line.strip_edges()
		if line.begins_with("static func "):
			in_static = true
		elif not line.is_empty() and not line.begins_with("\t") and not line.begins_with(" ") \
				and not trimmed.begins_with("#") and not trimmed.is_empty():
			in_static = false
		if in_static and line.contains("ContentPaths.scan("):
			return true
	return false

func test_the_sweep_bites() -> void:
	var old_style: String = "static var _registry: Dictionary = {}\nstatic var _scanned: bool = false\n\nstatic func _ensure_scanned() -> void:\n\tif _scanned:\n\t\treturn\n\t_scanned = true\n\tfor path: String in ContentPaths.scan(ContentPaths.SKILLS):\n\t\tpass\n"
	assert_ne(cache_problem(old_style), "", "the pre-WI-74 shape is caught")
	var no_latch: String = "static var _registry: Dictionary = {}\n\nstatic func _ensure_scanned() -> void:\n\tif not _registry.is_empty():\n\t\treturn\n\tfor path: String in ContentPaths.scan(ContentPaths.SKILLS):\n\t\tpass\n"
	assert_ne(cache_problem(no_latch), "", "so is a cache that latches on something else")
	var manager: String = "var _cache: Array = []\n\nfunc _ready() -> void:\n\tfor path: String in ContentPaths.scan(ContentPaths.EVENTS):\n\t\tpass\n"
	assert_eq(cache_problem(manager), "", "an instance scan rescans with its scene, and is left alone")
	var good: String = "static var _scanned_generation: int = -1\n\nstatic func _ensure_scanned() -> void:\n\tif _scanned_generation == ContentPaths.generation:\n\t\treturn\n\tfor path: String in ContentPaths.scan(ContentPaths.SKILLS):\n\t\tpass\n"
	assert_eq(cache_problem(good), "", "the WI-74 shape passes")

func test_every_static_cache_compares_the_generation() -> void:
	var caches: PackedStringArray = PackedStringArray()
	for path: String in _script_paths():
		var source: String = FileAccess.get_file_as_string(path)
		var problem: String = cache_problem(source)
		if not problem.is_empty():
			fail_test("%s %s" % [path, problem])
		if _scans_statically(source):
			caches.append(path)
	assert_eq(caches.size(), 13, "the thirteen caches WI-74 §2 names: %s" % str(caches))

func test_the_list_above_drives_every_cache_the_sweep_finds() -> void:
	var driven: PackedStringArray = PackedStringArray()
	for cache: Dictionary in _caches():
		driven.append(String(cache["path"]))
	for path: String in _script_paths():
		if _scans_statically(FileAccess.get_file_as_string(path)):
			assert_true(driven.has(path), "%s is a static content cache that _caches() does not drive" % path)
	for path: String in driven:
		assert_true(FileAccess.file_exists(path), "%s is listed and no longer exists" % path)

func _script_paths() -> PackedStringArray:
	var out := PackedStringArray()
	for root: String in ROOTS:
		_collect(root, out)
	return out

func _collect(dir_path: String, out: PackedStringArray) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var full: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			_collect(full, out)
		elif entry.ends_with(".gd"):
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
