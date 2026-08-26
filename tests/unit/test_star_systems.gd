extends GutTest

## Unit tests for WI-66: the star/planet generator, the realism rules that are
## deliverable 3, the save round-trip, and a content sweep over every shipped
## [StarClass] and [PlanetVariant].
##
## Pure only, per the standing rule. [StarSystemGenerator] and [StarSystemData]
## touch neither Global nor SignalBus; the sweep loads `.tres` and opens
## `PackedScene.get_state()` WITHOUT instantiating anything, the way
## `test_ui_theme.gd` already reads scene files.

## Enough samples that a band edge gets hit. The realism sweeps are the reason
## this number is not 50.
const SAMPLES: int = 2500

func _sample_seeds(count: int) -> Array[int]:
	var out: Array[int] = []
	# Deliberately not sequential-only: a generator that happened to be correct
	# for small seeds and wrong for large ones would slip through.
	for index: int in count:
		out.append(index * 7919 + 13)
	return out

# --- determinism --------------------------------------------------------------

func test_the_same_seed_produces_the_same_system() -> void:
	for seed_value: int in [0, 1, 42, 19660824, -7, 2147483647]:
		var first: StarSystemData = StarSystemGenerator.generate(seed_value)
		var second: StarSystemData = StarSystemGenerator.generate(seed_value)
		assert_true(first.equals(second), "seed %d must be reproducible" % seed_value)

func test_different_seeds_produce_different_systems() -> void:
	var seen: Dictionary[String, bool] = {}
	for seed_value: int in _sample_seeds(200):
		seen[JSON.stringify(StarSystemGenerator.generate(seed_value).to_dict())] = true
	# Not "all 200 distinct" - two seeds are allowed to collide - but a generator
	# ignoring its seed would produce exactly one.
	assert_gt(seen.size(), 150, "200 seeds must not collapse to a handful of skies")

func test_generating_between_two_calls_does_not_change_the_answer() -> void:
	# The real assertion here is that nothing reads the GLOBAL rng: if it did,
	# the interleaved call would advance it and desynchronise the second roll.
	var first: StarSystemData = StarSystemGenerator.generate(500)
	StarSystemGenerator.generate(501)
	randf()
	randi()
	var second: StarSystemData = StarSystemGenerator.generate(500)
	assert_true(first.equals(second), "generation must not depend on the global RNG")

func test_legacy_seed_is_the_shipped_default_sky() -> void:
	# The pin that a pre-WI-66 save, and a boot straight into main.tscn from the
	# editor, land somewhere RECOGNISABLE - a yellow star over the Rivers planet
	# is what the game showed before this item, so the seed is chosen to
	# reproduce it rather than being an arbitrary number.
	#
	# This is also the early warning that a generator change moved it: the
	# constant is picked against a specific sequence of rng calls, so inserting a
	# roll anywhere upstream will land LEGACY_SEED somewhere else entirely. If
	# this fails, re-pick the constant deliberately; do not relax the assertion.
	var legacy: StarSystemData = StarSystemGenerator.legacy()
	assert_eq(legacy.seed, StarSystemGenerator.LEGACY_SEED, "legacy() uses the constant")
	assert_true(legacy.equals(StarSystemGenerator.generate(StarSystemGenerator.LEGACY_SEED)),
		"legacy() is just generate(LEGACY_SEED)")
	assert_eq(legacy.star_class_id, &"yellow", "the legacy sky keeps its yellow star")
	assert_eq(legacy.planet_variant_id, &"rivers", "the legacy sky keeps the Rivers planet")

# --- save round trip ----------------------------------------------------------

func test_to_dict_from_dict_is_lossless() -> void:
	for seed_value: int in _sample_seeds(300):
		var source: StarSystemData = StarSystemGenerator.generate(seed_value)
		var restored: StarSystemData = StarSystemData.from_dict(source.to_dict())
		assert_true(source.equals(restored), "seed %d must survive a round trip" % seed_value)

func test_round_trip_survives_json() -> void:
	# The real save path stringifies, which turns every int into a float on the
	# way back. Every read in from_dict coerces for exactly this reason.
	var source: StarSystemData = StarSystemGenerator.generate(31337)
	var parsed: Variant = JSON.parse_string(JSON.stringify(source.to_dict()))
	assert_true(parsed is Dictionary, "a system block is a dictionary")
	var restored: StarSystemData = StarSystemData.from_dict(parsed as Dictionary)
	assert_true(source.equals(restored), "JSON must not change the sky")
	assert_eq(typeof(restored.star_pixels), TYPE_INT, "pixels comes back an int, not a float")
	assert_eq(typeof(restored.planet_scale), TYPE_INT, "scale comes back an int, not a float")

func test_an_empty_block_restores_to_usable_defaults() -> void:
	var restored: StarSystemData = StarSystemData.from_dict({})
	assert_false(restored.has_planet(), "nothing in, no planet out")
	assert_gt(restored.star_pixels, 0, "defaults are usable, not zero")
	assert_eq(restored.palette_for(&"liquid").size(), 0, "an absent role is empty, not null")

func test_a_corrupt_colour_loses_one_stop_not_the_load() -> void:
	var source: Dictionary = StarSystemGenerator.generate(11).to_dict()
	var star: Dictionary = source["star"]
	star["ramp"] = ["ff0000ff", "not-a-colour", "00ff00ff"]
	var restored: StarSystemData = StarSystemData.from_dict(source)
	assert_eq(restored.star_ramp.size(), 2, "the unparseable stop is dropped, the rest survive")

# --- realism: stars -----------------------------------------------------------

func test_no_generated_star_is_green_or_purple() -> void:
	var checked: int = 0
	for seed_value: int in _sample_seeds(SAMPLES):
		var system: StarSystemData = StarSystemGenerator.generate(seed_value)
		for color: Color in system.star_ramp:
			checked += 1
			assert_true(StarSystemGenerator.is_plausible_star_color(color),
				"seed %d produced %s, which is not a colour a star can be"
					% [seed_value, color.to_html(false)])
	assert_gt(checked, 0, "the sweep actually looked at something")

func test_the_predicate_rejects_the_vendored_teal_star() -> void:
	# Star.gd's unused `starcolor2` is a teal star, and teal stars are not a
	# thing. A realism test that would have passed the palette we rejected is
	# testing nothing at all, so pin both of its middle stops as failures.
	assert_false(StarSystemGenerator.is_plausible_star_color(Color("77d6c1")),
		"77d6c1 (hue 167) is green-cyan")
	assert_false(StarSystemGenerator.is_plausible_star_color(Color("1c92a7")),
		"1c92a7 (hue 189) is cyan")
	assert_false(StarSystemGenerator.is_plausible_star_color(Color("8a2be2")),
		"violet is not a star colour either")
	assert_false(StarSystemGenerator.is_plausible_star_color(Color("2fbf3a")),
		"and neither is green")

func test_the_predicate_accepts_the_real_sequence() -> void:
	for html: String in ["ffd832", "ff823b", "7c191a", "a8c8ff", "5b8fe0", "ffffff", "ffb44a"]:
		assert_true(StarSystemGenerator.is_plausible_star_color(Color(html)),
			"%s is on the blackbody locus" % html)

func test_a_warm_white_core_is_exempt_by_saturation_not_by_hue() -> void:
	# f5ffe8 reads as hue 86 - green - at saturation 0.09. Without the neutral
	# exemption every star in the game fails; with a saturation jitter that could
	# raise it over the threshold, it fails intermittently, which is worse.
	var core := Color("f5ffe8")
	assert_lt(core.s, StarSystemGenerator.NEUTRAL_SATURATION, "f5ffe8 is near-neutral")
	assert_true(StarSystemGenerator.is_plausible_star_color(core), "and therefore allowed")

func test_jitter_never_lifts_a_neutral_stop_over_the_threshold() -> void:
	for seed_value: int in _sample_seeds(SAMPLES):
		var system: StarSystemData = StarSystemGenerator.generate(seed_value)
		var source: StarClass = StarClass.by_id(system.star_class_id)
		if source == null or source.ramp.size() != system.star_ramp.size():
			continue
		for index: int in source.ramp.size():
			if source.ramp[index].s >= StarSystemGenerator.NEUTRAL_SATURATION:
				continue
			assert_lt(system.star_ramp[index].s, StarSystemGenerator.NEUTRAL_SATURATION,
				"a neutral stop must stay neutral (seed %d, stop %d)" % [seed_value, index])

# --- realism: water -----------------------------------------------------------

func test_every_generated_liquid_is_blue() -> void:
	var planets_with_water: int = 0
	for seed_value: int in _sample_seeds(SAMPLES):
		var system: StarSystemData = StarSystemGenerator.generate(seed_value)
		var liquid: PackedColorArray = system.palette_for(
			PlanetPaletteSegment.role_id(PlanetPaletteSegment.Role.LIQUID))
		if liquid.is_empty():
			continue
		planets_with_water += 1
		for color: Color in liquid:
			assert_true(StarSystemGenerator.is_plausible_liquid_color(color),
				"seed %d produced water at %s" % [seed_value, color.to_html(false)])
	assert_gt(planets_with_water, 0, "some of the sample actually has water")

func test_the_liquid_predicate_rejects_the_vendored_mint_ocean() -> void:
	# LandMasses ships its ocean at 8ce8c0 - mint green. It is the exact reason
	# the LIQUID role has a band rather than inheriting whatever looks nice.
	assert_false(StarSystemGenerator.is_plausible_liquid_color(Color("8ce8c0")),
		"8ce8c0 is mint, not water")
	assert_true(StarSystemGenerator.is_plausible_liquid_color(Color("4fa4b8")),
		"4fa4b8 is water")

func test_nothing_generated_is_black_or_neon() -> void:
	for seed_value: int in _sample_seeds(600):
		var system: StarSystemData = StarSystemGenerator.generate(seed_value)
		var every: Array[Color] = []
		for color: Color in system.star_ramp:
			every.append(color)
		for role_id: StringName in system.planet_palette:
			for color: Color in system.planet_palette[role_id]:
				every.append(color)
		for color: Color in every:
			assert_gte(color.v, StarSystemGenerator.MIN_VALUE - 0.01,
				"seed %d produced %s, which is black" % [seed_value, color.to_html(false)])
			assert_lte(color.s, StarSystemGenerator.MAX_SATURATION + 0.01,
				"seed %d produced %s, which is neon" % [seed_value, color.to_html(false)])

# --- rolled bands -------------------------------------------------------------

func test_scale_is_always_an_integer_in_band() -> void:
	# A pixel-art shader at scale 2.4 renders uneven pixels, which reads as a
	# rendering defect rather than as variety.
	for seed_value: int in _sample_seeds(400):
		var system: StarSystemData = StarSystemGenerator.generate(seed_value)
		assert_between(system.star_scale, 1, 4, "star scale stays sane")
		assert_between(system.planet_scale, 1, 4, "planet scale stays sane")

func test_the_star_always_renders_larger_than_the_planet() -> void:
	# The station sits out at the asteroid belt, far from both bodies. The planet
	# is the nearer of the two, but a star is larger by orders of magnitude, so at
	# that distance the star is what dominates the sky - a planet that out-sized
	# it would read as orbit, which is the wrong place entirely.
	#
	# Asserted over the BANDS rather than over samples, so it holds for every seed
	# that could ever be rolled rather than for the few thousand tried here.
	var smallest_star: int = -1
	for star_class: StarClass in StarClass.all():
		var low: int = star_class.pixels_range.x * star_class.scale_range.x
		if smallest_star < 0 or low < smallest_star:
			smallest_star = low
	var largest_planet: int = -1
	for variant: PlanetVariant in PlanetVariant.all():
		largest_planet = maxi(largest_planet, variant.pixels_range.y * variant.scale_range.y)
	assert_gt(smallest_star, 0, "some star class ships")
	assert_gt(largest_planet, 0, "some planet variant ships")
	assert_gt(smallest_star, largest_planet,
		"the smallest star any class can roll (%dpx) must still out-size the largest planet any variant can roll (%dpx)"
			% [smallest_star, largest_planet])

func test_the_planet_never_lands_on_the_star() -> void:
	# The two authored offset bands overlap by themselves: a hot class reaches a
	# 300px disc, and from the right of the star band that runs into the left of
	# the planet band. Unfixed, that draws a fully lit planet on top of the star's
	# face - which reads as a rendering error, not as a transit, and which only a
	# screenshot of the worst case ever showed.
	for seed_value: int in _sample_seeds(SAMPLES):
		var system: StarSystemData = StarSystemGenerator.generate(seed_value)
		if not system.has_planet():
			continue
		var star_right: float = system.star_offset.x \
				+ float(system.star_pixels * system.star_scale)
		assert_gte(system.planet_offset.x,
			star_right + StarSystemGenerator.STAR_PLANET_CLEARANCE - 0.01,
			"seed %d puts the planet at x=%.0f against a star ending at x=%.0f"
				% [seed_value, system.planet_offset.x, star_right])

func test_pixels_stay_inside_the_shader_hint_range() -> void:
	# Every one of these shaders declares `uniform float pixels : hint_range(10,100)`.
	for seed_value: int in _sample_seeds(400):
		var system: StarSystemData = StarSystemGenerator.generate(seed_value)
		assert_between(system.star_pixels, 10, 100, "star pixels within hint_range")
		assert_between(system.planet_pixels, 10, 100, "planet pixels within hint_range")

func test_seeds_stay_inside_the_shader_hint_range() -> void:
	for seed_value: int in _sample_seeds(400):
		var system: StarSystemData = StarSystemGenerator.generate(seed_value)
		assert_between(system.star_seed, 1.0, 10.0, "star seed within hint_range(1,10)")
		assert_between(system.planet_seed, 1.0, 10.0, "planet seed within hint_range(1,10)")

func test_normalised_planet_factors_are_normalised() -> void:
	for seed_value: int in _sample_seeds(400):
		var system: StarSystemData = StarSystemGenerator.generate(seed_value)
		if not system.has_planet():
			continue
		assert_between(system.planet_cloudiness, 0.0, 1.0, "cloudiness is a factor")
		assert_between(system.planet_coverage, 0.0, 1.0, "coverage is a factor")
		assert_between(system.planet_noise_scale, 0.0, 1.0, "noise scale is a factor")

func test_rolled_values_respect_the_variant_bands() -> void:
	for seed_value: int in _sample_seeds(400):
		var system: StarSystemData = StarSystemGenerator.generate(seed_value)
		var variant: PlanetVariant = PlanetVariant.by_id(system.planet_variant_id)
		if variant == null:
			continue
		assert_between(system.planet_rotation, variant.rotation_range.x, variant.rotation_range.y,
			"tilt stays in its band")
		assert_between(system.planet_time_scale, variant.time_scale_range.x,
			variant.time_scale_range.y, "drift multiplier stays in its band")
		assert_between(system.planet_pixels, variant.pixels_range.x, variant.pixels_range.y,
			"pixels stays in its band")
		assert_between(system.planet_scale, variant.scale_range.x, variant.scale_range.y,
			"scale stays in its band")

func test_some_planets_roll_nearly_cloudless() -> void:
	var clear: int = 0
	for seed_value: int in _sample_seeds(1000):
		if StarSystemGenerator.generate(seed_value).planet_cloudiness < 0.13:
			clear += 1
	assert_gt(clear, 0, "the clear-sky roll actually fires")
	assert_lt(clear, 400, "and it is the exception, not the rule")

func test_every_shipped_variant_and_class_gets_picked() -> void:
	var classes: Dictionary[StringName, bool] = {}
	var variants: Dictionary[StringName, bool] = {}
	for seed_value: int in _sample_seeds(1000):
		var system: StarSystemData = StarSystemGenerator.generate(seed_value)
		classes[system.star_class_id] = true
		variants[system.planet_variant_id] = true
	assert_eq(classes.size(), StarClass.all().size(),
		"a class nothing ever rolls is a class nobody will ever see")
	assert_eq(variants.size(), PlanetVariant.all().size(),
		"all four planet types must be reachable - that is deliverable 4")

# --- palette shape ------------------------------------------------------------

func test_the_palette_covers_every_role_its_variant_uses() -> void:
	for seed_value: int in _sample_seeds(300):
		var system: StarSystemData = StarSystemGenerator.generate(seed_value)
		var variant: PlanetVariant = PlanetVariant.by_id(system.planet_variant_id)
		if variant == null:
			continue
		for role: PlanetPaletteSegment.Role in variant.roles_used():
			var ramp: PackedColorArray = system.palette_for(PlanetPaletteSegment.role_id(role))
			assert_gt(ramp.size(), 0, "%s needs a %s ramp"
				% [variant.id, PlanetPaletteSegment.role_id(role)])

func test_a_dry_world_has_no_water_ramp_at_all() -> void:
	# The reason the realism rule is per ROLE and not per planet.
	var variant: PlanetVariant = PlanetVariant.by_id(&"dry_terran")
	assert_not_null(variant, "dry_terran ships")
	assert_false(variant.roles_used().has(PlanetPaletteSegment.Role.LIQUID),
		"a dry world has no liquid")

func test_role_ids_round_trip() -> void:
	for role: PlanetPaletteSegment.Role in PlanetPaletteSegment.ROLE_IDS:
		var id: StringName = PlanetPaletteSegment.role_id(role)
		assert_ne(id, &"", "every role has an id")
		assert_eq(PlanetPaletteSegment.role_from_id(id), role, "%s round trips" % id)
	assert_eq(PlanetPaletteSegment.role_from_id(&"nonsense"), -1,
		"an unknown role id is -1, never a substituted role")

# --- content sweep: star classes ----------------------------------------------

func test_star_classes_ship() -> void:
	assert_gt(StarClass.all().size(), 0, "data/star_classes/ is discoverable")

func test_every_star_class_is_well_formed() -> void:
	var ids: Dictionary[StringName, bool] = {}
	for star_class: StarClass in StarClass.all():
		assert_ne(star_class.id, &"", "a class needs an id")
		assert_false(ids.has(star_class.id), "duplicate star class id %s" % star_class.id)
		ids[star_class.id] = true
		assert_ne(star_class.display_name, "", "%s needs a name" % star_class.id)
		assert_gt(star_class.weight, 0.0, "%s would never be picked" % star_class.id)
		assert_gt(star_class.temperature_k, 0, "%s needs its anchor" % star_class.id)
		assert_eq(star_class.ramp.size(), StarClass.RAMP_LENGTH,
			"%s must have exactly %d stops - Star.gdshader declares colors[%d] and silently pads or truncates anything else"
				% [star_class.id, StarClass.RAMP_LENGTH, StarClass.RAMP_LENGTH])

func test_every_authored_star_ramp_is_already_realistic() -> void:
	# The generator only jitters; if the authored palette is wrong, so is
	# everything downstream.
	for star_class: StarClass in StarClass.all():
		for color: Color in star_class.ramp:
			assert_true(StarSystemGenerator.is_plausible_star_color(color),
				"%s authors %s" % [star_class.id, color.to_html(false)])

func test_the_yellow_class_is_the_vendored_ramp_verbatim() -> void:
	# The pin behind WI-66 step 2: the applier is supposed to reproduce a look the
	# asset's own author signed off on, and this is that look.
	var yellow: StarClass = StarClass.by_id(&"yellow")
	assert_not_null(yellow, "the G class ships")
	var expected: PackedColorArray = PackedColorArray([
		Color("f5ffe8"), Color("ffd832"), Color("ff823b"), Color("7c191a")])
	assert_eq(yellow.ramp.size(), expected.size(), "same length as Star.gd's starcolor1")
	for index: int in expected.size():
		assert_true(yellow.ramp[index].is_equal_approx(expected[index]),
			"stop %d matches starcolor1" % index)

func test_hot_classes_are_rarer_than_cool_ones() -> void:
	# The deliberate departure from astrophysical frequency runs one way: hot
	# stars are the find. It must not silently invert.
	var hottest: StarClass = null
	for star_class: StarClass in StarClass.all():
		if hottest == null or star_class.temperature_k > hottest.temperature_k:
			hottest = star_class
	assert_not_null(hottest, "there is a hottest class")
	for star_class: StarClass in StarClass.all():
		assert_lte(hottest.weight, star_class.weight,
			"%s must not be more common than %s" % [hottest.id, star_class.id])

# --- content sweep: planet variants -------------------------------------------

func test_all_four_planet_variants_ship() -> void:
	var ids: Array[StringName] = []
	for variant: PlanetVariant in PlanetVariant.all():
		ids.append(variant.id)
	for required: StringName in [&"rivers", &"land_masses", &"ice_world", &"dry_terran"]:
		assert_true(ids.has(required), "deliverable 4 requires %s" % required)

func test_every_planet_variant_is_well_formed() -> void:
	var ids: Dictionary[StringName, bool] = {}
	for variant: PlanetVariant in PlanetVariant.all():
		assert_ne(variant.id, &"", "a variant needs an id")
		assert_false(ids.has(variant.id), "duplicate variant id %s" % variant.id)
		ids[variant.id] = true
		assert_gt(variant.weight, 0.0, "%s would never be picked" % variant.id)
		assert_not_null(variant.scene, "%s needs a scene" % variant.id)
		assert_gt(variant.layers.size(), 0, "%s needs layers" % variant.id)
		assert_lte(variant.pixels_range.y, 100,
			"%s exceeds the shaders' hint_range(10,100)" % variant.id)
		for layer: PlanetLayerSpec in variant.layers:
			assert_not_null(layer, "%s has a null layer" % variant.id)
			assert_ne(layer.node_name, &"", "%s has an unnamed layer" % variant.id)
			assert_gt(layer.total_colors(), 0,
				"%s/%s declares no colours" % [variant.id, layer.node_name])

func test_every_variant_that_has_water_authors_a_blue_band() -> void:
	for variant: PlanetVariant in PlanetVariant.all():
		if not variant.roles_used().has(PlanetPaletteSegment.Role.LIQUID):
			continue
		assert_gte(variant.liquid_hue_range.x, StarSystemGenerator.LIQUID_HUE_BAND.x,
			"%s authors water below the blue band" % variant.id)
		assert_lte(variant.liquid_hue_range.y, StarSystemGenerator.LIQUID_HUE_BAND.y,
			"%s authors water above the blue band" % variant.id)
		assert_lt(variant.liquid_hue_range.x, variant.liquid_hue_range.y,
			"%s authors an inverted water band" % variant.id)

# --- content sweep: the .tres against the vendored scenes ---------------------
#
# The one that catches the class of bug already sitting unnoticed in the vendored
# `Star.randomize_colors()`: a layer's declared colour count not matching the
# shader's array length. Godot pads or truncates silently, so it can only be
# found by reading both sides. Scenes are read through SceneState rather than
# instantiated - no nodes enter the tree.

func _layer_material(state: SceneState, node_name: StringName) -> ShaderMaterial:
	for index: int in state.get_node_count():
		if state.get_node_name(index) != node_name:
			continue
		for property: int in state.get_node_property_count(index):
			if state.get_node_property_name(index, property) != &"material":
				continue
			return state.get_node_property_value(index, property) as ShaderMaterial
	return null

func test_every_declared_layer_exists_in_its_scene() -> void:
	for variant: PlanetVariant in PlanetVariant.all():
		if variant.scene == null:
			continue
		var state: SceneState = variant.scene.get_state()
		var names: Array[StringName] = []
		for index: int in state.get_node_count():
			names.append(state.get_node_name(index))
		for layer: PlanetLayerSpec in variant.layers:
			assert_true(names.has(layer.node_name),
				"%s names a layer '%s' its scene does not have - the applier would write nothing and report nothing"
					% [variant.id, layer.node_name])

func test_declared_colour_counts_match_the_authored_uniforms() -> void:
	var checked: int = 0
	for variant: PlanetVariant in PlanetVariant.all():
		if variant.scene == null:
			continue
		var state: SceneState = variant.scene.get_state()
		for layer: PlanetLayerSpec in variant.layers:
			var material: ShaderMaterial = _layer_material(state, layer.node_name)
			assert_not_null(material,
				"%s/%s carries no ShaderMaterial" % [variant.id, layer.node_name])
			if material == null:
				continue
			var authored: Variant = material.get_shader_parameter(&"colors")
			assert_true(authored is PackedColorArray,
				"%s/%s has no colors uniform" % [variant.id, layer.node_name])
			if not authored is PackedColorArray:
				continue
			checked += 1
			assert_eq(layer.total_colors(), (authored as PackedColorArray).size(),
				"%s/%s declares %d colours but its shader takes %d"
					% [variant.id, layer.node_name, layer.total_colors(),
						(authored as PackedColorArray).size()])
	assert_gt(checked, 0, "the sweep actually read some materials")

func test_a_declared_cutoff_names_a_real_uniform() -> void:
	for variant: PlanetVariant in PlanetVariant.all():
		if variant.scene == null:
			continue
		var state: SceneState = variant.scene.get_state()
		for layer: PlanetLayerSpec in variant.layers:
			if layer.cutoff_param == &"":
				continue
			var material: ShaderMaterial = _layer_material(state, layer.node_name)
			if material == null:
				continue
			assert_not_null(material.get_shader_parameter(layer.cutoff_param),
				"%s/%s declares cutoff '%s', which its shader does not have"
					% [variant.id, layer.node_name, layer.cutoff_param])

func test_a_declared_cloud_cover_names_a_real_uniform() -> void:
	var found: int = 0
	for variant: PlanetVariant in PlanetVariant.all():
		if variant.scene == null:
			continue
		var state: SceneState = variant.scene.get_state()
		for layer: PlanetLayerSpec in variant.layers:
			if not PlanetLayerSpec.has_range(layer.cloud_cover_range):
				continue
			found += 1
			var material: ShaderMaterial = _layer_material(state, layer.node_name)
			if material == null:
				continue
			assert_not_null(material.get_shader_parameter(&"cloud_cover"),
				"%s/%s declares a cloud band but its shader has no cloud_cover"
					% [variant.id, layer.node_name])
	assert_gt(found, 0, "some variant has clouds")
