extends GutTest

## ModRegistry + ModManifest (WI-47 M1): which mods load, and in what order.
## Pure - manifests are built in code, nothing is mounted, no filesystem.

func _manifest(id: String, deps: Array[String] = [], load_after: Array[String] = [],
		game_version: String = "", version: String = "1.0.0") -> ModManifest:
	return ModManifest.from_dict({
		"id": id,
		"name": id.capitalize(),
		"version": version,
		"game_version": game_version,
		"deps": deps,
		"load_after": load_after,
	}, "user://mods/%s" % id)

func _ids(resolution: ModRegistry.Resolution) -> Array[StringName]:
	return resolution.loaded_ids()

# --- manifest parsing -----------------------------------------------------------

func test_a_well_formed_manifest_is_usable() -> void:
	var manifest: ModManifest = _manifest("coolmod")
	assert_true(manifest.is_usable())
	assert_eq(manifest.id, &"coolmod")
	assert_eq(manifest.display_name, "Coolmod")

func test_a_manifest_without_an_id_is_unusable() -> void:
	var manifest: ModManifest = ModManifest.from_dict({"version": "1.0.0"})
	assert_false(manifest.is_usable())

func test_a_manifest_without_a_version_is_unusable() -> void:
	# Version is what M11's save-mod-list compares, so a mod without one cannot
	# be reported on later.
	var manifest: ModManifest = ModManifest.from_dict({"id": "coolmod"})
	assert_false(manifest.is_usable())

func test_the_display_name_falls_back_to_the_id() -> void:
	var manifest: ModManifest = ModManifest.from_dict({"id": "coolmod", "version": "1"})
	assert_eq(manifest.display_name, "coolmod")

func test_valid_mod_ids() -> void:
	for id: String in ["a", "coolmod", "cool_mod", "mod2", "a1_b2"]:
		assert_true(ModManifest.is_valid_id(id), id)

func test_invalid_mod_ids() -> void:
	# The id is a namespace prefix AND a directory name: no dots (the separator),
	# no slashes, no case to get wrong in a bug report.
	for id: String in ["", "Cool", "cool mod", "cool.mod", "2cool", "cool/mod", "cool-mod", "_cool"]:
		assert_false(ModManifest.is_valid_id(id), id)

func test_mount_and_content_roots_are_derived_from_the_id() -> void:
	var manifest: ModManifest = _manifest("coolmod")
	assert_eq(manifest.mount_root(), "res://mods/coolmod/")
	assert_eq(manifest.content_root(), "res://mods/coolmod/data/")

func test_deps_and_load_after_parse_into_ids() -> void:
	var manifest: ModManifest = _manifest("c", ["a", " b "], ["z"])
	assert_eq(manifest.deps, [&"a", &"b"] as Array[StringName])
	assert_eq(manifest.load_after, [&"z"] as Array[StringName])

# --- rule 1: unusable manifests -------------------------------------------------

func test_an_unusable_manifest_is_dropped_with_a_reason() -> void:
	var resolution: ModRegistry.Resolution = ModRegistry.resolve(
			[ModManifest.from_dict({"name": "nameless"}, "user://mods/broken")] as Array[ModManifest])
	assert_eq(_ids(resolution), [] as Array[StringName])
	assert_eq(resolution.problems.size(), 1)
	assert_string_contains(resolution.problems[0], "user://mods/broken")

# --- rule 2: id collisions ------------------------------------------------------

func test_two_mods_with_one_id_drops_BOTH() -> void:
	# Keeping "the first" would make which mod the player gets depend on
	# directory order - the exact silent failure this replaces.
	var a: ModManifest = _manifest("coolmod")
	var b: ModManifest = _manifest("coolmod")
	b.folder = "user://mods/coolmod_v2"
	var resolution: ModRegistry.Resolution = ModRegistry.resolve([a, b] as Array[ModManifest])
	assert_eq(_ids(resolution), [] as Array[StringName])
	assert_eq(resolution.problems.size(), 1)
	assert_string_contains(resolution.problems[0], "coolmod_v2")

func test_a_collision_does_not_take_out_unrelated_mods() -> void:
	var resolution: ModRegistry.Resolution = ModRegistry.resolve(
			[_manifest("dupe"), _manifest("dupe"), _manifest("fine")] as Array[ModManifest])
	assert_eq(_ids(resolution), [&"fine"] as Array[StringName])

# --- rule 3: dependencies -------------------------------------------------------

func test_a_mod_with_a_missing_dependency_is_dropped() -> void:
	var resolution: ModRegistry.Resolution = ModRegistry.resolve(
			[_manifest("needy", ["absent"])] as Array[ModManifest])
	assert_eq(_ids(resolution), [] as Array[StringName])
	assert_string_contains(resolution.problems[0], "absent")

func test_missing_dependencies_cascade() -> void:
	# c needs b needs a; a isn't installed, so neither b nor c may load.
	var resolution: ModRegistry.Resolution = ModRegistry.resolve(
			[_manifest("b", ["a"]), _manifest("c", ["b"])] as Array[ModManifest])
	assert_eq(_ids(resolution), [] as Array[StringName])
	assert_eq(resolution.problems.size(), 2)

func test_a_satisfied_dependency_loads_both() -> void:
	var resolution: ModRegistry.Resolution = ModRegistry.resolve(
			[_manifest("b", ["a"]), _manifest("a")] as Array[ModManifest])
	assert_eq(_ids(resolution), [&"a", &"b"] as Array[StringName])
	assert_eq(resolution.problems.size(), 0)

# --- rule 4: game version -------------------------------------------------------

func test_a_version_mismatch_warns_but_still_loads() -> void:
	var resolution: ModRegistry.Resolution = ModRegistry.resolve(
			[_manifest("coolmod", [], [], "0.0.9")] as Array[ModManifest], "0.1.0-dev")
	assert_eq(_ids(resolution), [&"coolmod"] as Array[StringName])
	assert_eq(resolution.warnings.size(), 1)
	assert_eq(resolution.problems.size(), 0)

func test_a_matching_version_says_nothing() -> void:
	var resolution: ModRegistry.Resolution = ModRegistry.resolve(
			[_manifest("coolmod", [], [], "0.1.0-dev")] as Array[ModManifest], "0.1.0-dev")
	assert_eq(resolution.warnings.size(), 0)

func test_a_manifest_that_declares_no_game_version_is_not_nagged_about() -> void:
	var resolution: ModRegistry.Resolution = ModRegistry.resolve(
			[_manifest("coolmod")] as Array[ModManifest], "0.1.0-dev")
	assert_eq(resolution.warnings.size(), 0)

# --- rules 5 & 6: ordering ------------------------------------------------------

func test_load_after_orders_without_requiring() -> void:
	var resolution: ModRegistry.Resolution = ModRegistry.resolve(
			[_manifest("zebra"), _manifest("apple", [], ["zebra"])] as Array[ModManifest])
	assert_eq(_ids(resolution), [&"zebra", &"apple"] as Array[StringName])

func test_load_after_an_absent_mod_is_harmless() -> void:
	var resolution: ModRegistry.Resolution = ModRegistry.resolve(
			[_manifest("apple", [], ["not_installed"])] as Array[ModManifest])
	assert_eq(_ids(resolution), [&"apple"] as Array[StringName])
	assert_eq(resolution.problems.size(), 0)

func test_independent_mods_load_alphabetically() -> void:
	# Reproducible run to run: dictionary order must never decide load order.
	var resolution: ModRegistry.Resolution = ModRegistry.resolve(
			[_manifest("c"), _manifest("a"), _manifest("b")] as Array[ModManifest])
	assert_eq(_ids(resolution), [&"a", &"b", &"c"] as Array[StringName])

func test_a_dependency_chain_orders_deepest_first() -> void:
	var resolution: ModRegistry.Resolution = ModRegistry.resolve(
			[_manifest("top", ["mid"]), _manifest("mid", ["base"]), _manifest("base")] as Array[ModManifest])
	assert_eq(_ids(resolution), [&"base", &"mid", &"top"] as Array[StringName])

func test_a_cycle_is_reported_and_loaded_anyway() -> void:
	# Fail soft: dropping a cycle cascades into everything that depends on it.
	var resolution: ModRegistry.Resolution = ModRegistry.resolve(
			[_manifest("b", ["a"]), _manifest("a", ["b"])] as Array[ModManifest])
	assert_eq(_ids(resolution), [&"a", &"b"] as Array[StringName])
	assert_eq(resolution.problems.size(), 1)
	assert_string_contains(resolution.problems[0], "circular")

func test_a_mod_outside_a_cycle_still_orders_normally() -> void:
	var resolution: ModRegistry.Resolution = ModRegistry.resolve(
			[_manifest("b", ["a"]), _manifest("a", ["b"]), _manifest("free")] as Array[ModManifest])
	assert_eq(_ids(resolution), [&"free", &"a", &"b"] as Array[StringName])

func test_nothing_in_yields_nothing_out() -> void:
	var resolution: ModRegistry.Resolution = ModRegistry.resolve([] as Array[ModManifest])
	assert_eq(_ids(resolution), [] as Array[StringName])
	assert_eq(resolution.problems.size(), 0)
	assert_eq(resolution.warnings.size(), 0)
