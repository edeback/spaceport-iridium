extends GutTest

## ContentPaths (WI-47 M1): the roots registry the 13 scan sites walk.
##
## Its state is static and therefore process-global, so every test resets the mod
## roots first - a leaked root would otherwise make a later suite scan a
## directory that isn't there.

const MOD_ROOT: String = "res://mods/testmod/data/"
const OTHER_ROOT: String = "res://mods/other/data/"

func before_each() -> void:
	ContentPaths.clear_mod_roots()

func after_each() -> void:
	ContentPaths.clear_mod_roots()

# --- roots ----------------------------------------------------------------------

func test_base_root_is_always_present() -> void:
	assert_eq(ContentPaths.roots(), [ContentPaths.BASE_ROOT] as Array[String])

func test_registered_mod_root_comes_after_the_base_game() -> void:
	ContentPaths.register_mod_root(MOD_ROOT, &"testmod")
	assert_eq(ContentPaths.roots(), [ContentPaths.BASE_ROOT, MOD_ROOT] as Array[String],
			"vanilla is mod zero and must stay first")

func test_registering_the_same_root_twice_does_not_duplicate_it() -> void:
	ContentPaths.register_mod_root(MOD_ROOT, &"testmod")
	ContentPaths.register_mod_root(MOD_ROOT, &"testmod")
	assert_eq(ContentPaths.roots().size(), 2)

# --- generation (WI-74 §2) ------------------------------------------------------

func test_a_new_root_moves_the_generation_on() -> void:
	var before: int = ContentPaths.generation
	ContentPaths.register_mod_root(MOD_ROOT, &"testmod")
	assert_gt(ContentPaths.generation, before, "new content is possible, so every cache must rescan")

func test_re_registering_a_root_leaves_the_generation_alone() -> void:
	ContentPaths.register_mod_root(MOD_ROOT, &"testmod")
	var before: int = ContentPaths.generation
	ContentPaths.register_mod_root(MOD_ROOT, &"testmod")
	assert_eq(ContentPaths.generation, before, "nothing changed, so nothing need rescan")

func test_dropping_the_mod_roots_moves_the_generation_on() -> void:
	ContentPaths.register_mod_root(MOD_ROOT, &"testmod")
	var before: int = ContentPaths.generation
	ContentPaths.clear_mod_roots()
	assert_gt(ContentPaths.generation, before, "the mod's content is gone from every cache")

func test_invalidate_moves_the_generation_on() -> void:
	var before: int = ContentPaths.generation
	ContentPaths.invalidate()
	assert_eq(ContentPaths.generation, before + 1)

func test_a_root_is_normalised_to_a_trailing_slash() -> void:
	ContentPaths.register_mod_root("res://mods/testmod/data", &"testmod")
	assert_eq(ContentPaths.roots()[1], MOD_ROOT)

func test_roots_for_appends_the_kind_directory_to_every_root() -> void:
	ContentPaths.register_mod_root(MOD_ROOT, &"testmod")
	assert_eq(ContentPaths.roots_for(ContentPaths.JOBS),
			["res://data/jobs/", "res://mods/testmod/data/jobs/"] as Array[String])

func test_an_unknown_kind_yields_no_roots_and_is_loud_about_it() -> void:
	# A typo'd kind would otherwise surface as "this mod added no content",
	# which is invisible.
	assert_eq(ContentPaths.roots_for(&"not_a_kind"), [] as Array[String])
	assert_push_error("unknown content kind", "so a typo can't hide as empty content")

func test_every_declared_kind_resolves() -> void:
	for kind: StringName in ContentPaths.KINDS:
		assert_eq(ContentPaths.roots_for(kind).size(), 1, "kind %s" % kind)

# --- scanning -------------------------------------------------------------------

func test_scan_finds_the_base_game_content_for_a_kind() -> void:
	var found: Array[String] = ContentPaths.scan(ContentPaths.JOBS)
	assert_gt(found.size(), 0, "the base game ships job definitions")
	for path: String in found:
		assert_true(path.begins_with("res://data/jobs/"), path)
		assert_eq(path.get_extension(), "tres", path)

func test_scan_ignores_a_root_that_does_not_exist() -> void:
	var before: int = ContentPaths.scan(ContentPaths.JOBS).size()
	ContentPaths.register_mod_root("res://mods/definitely_not_installed/data/", &"ghost")
	assert_eq(ContentPaths.scan(ContentPaths.JOBS).size(), before,
			"a mod root with no such directory must cost nothing, not error")

# --- ownership ------------------------------------------------------------------

func test_base_game_paths_have_no_owning_mod() -> void:
	assert_eq(ContentPaths.mod_id_for_path("res://data/jobs/haul_resource.tres"), &"")

func test_a_mod_path_reports_its_mod() -> void:
	ContentPaths.register_mod_root(MOD_ROOT, &"testmod")
	assert_eq(ContentPaths.mod_id_for_path(MOD_ROOT + "jobs/thing.tres"), &"testmod")

func test_an_unrelated_path_reports_no_mod() -> void:
	ContentPaths.register_mod_root(MOD_ROOT, &"testmod")
	assert_eq(ContentPaths.mod_id_for_path(OTHER_ROOT + "jobs/thing.tres"), &"")

func test_the_longest_matching_root_wins() -> void:
	# A mod root nested inside another must not be read as its parent's content.
	ContentPaths.register_mod_root("res://mods/outer/data/", &"outer")
	ContentPaths.register_mod_root("res://mods/outer/data/nested/data/", &"nested")
	assert_eq(ContentPaths.mod_id_for_path("res://mods/outer/data/nested/data/jobs/x.tres"), &"nested")

# --- id namespacing -------------------------------------------------------------

func test_an_empty_id_is_rejected_anywhere() -> void:
	assert_false(ContentPaths.accept_id(&"", "res://data/jobs/x.tres", "JobData"))

func test_a_plain_base_game_id_is_accepted() -> void:
	assert_true(ContentPaths.accept_id(&"haul_resource", "res://data/jobs/haul.tres", "JobData"))

func test_a_namespaced_mod_id_is_accepted() -> void:
	ContentPaths.register_mod_root(MOD_ROOT, &"testmod")
	assert_true(ContentPaths.accept_id(&"testmod.polish", MOD_ROOT + "jobs/polish.tres", "JobData"))

func test_an_unnamespaced_mod_id_is_rejected() -> void:
	# The whole point: two mods shipping &"crystal" would otherwise collide, and
	# which one won would depend on mod load order.
	ContentPaths.register_mod_root(MOD_ROOT, &"testmod")
	assert_false(ContentPaths.accept_id(&"polish", MOD_ROOT + "jobs/polish.tres", "JobData"))

func test_a_mod_id_namespaced_to_a_DIFFERENT_mod_is_rejected() -> void:
	ContentPaths.register_mod_root(MOD_ROOT, &"testmod")
	assert_false(ContentPaths.accept_id(&"other.polish", MOD_ROOT + "jobs/polish.tres", "JobData"))

func test_a_prefix_match_alone_is_not_enough() -> void:
	# "testmodextra.thing" starts with "testmod" but is not in testmod's namespace.
	ContentPaths.register_mod_root(MOD_ROOT, &"testmod")
	assert_false(ContentPaths.accept_id(&"testmodextra.thing", MOD_ROOT + "jobs/x.tres", "JobData"))

func test_a_namespaced_base_game_id_is_kept_but_warned_about() -> void:
	# Refusing would delete shipped content, which is worse than the ambiguity.
	assert_true(ContentPaths.accept_id(&"looks.namespaced", "res://data/jobs/x.tres", "JobData"))
