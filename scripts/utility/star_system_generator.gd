class_name StarSystemGenerator
extends RefCounted

## Rolls the star and planet a run is played under (WI-66). Pure and static: no
## Global, no SignalBus, no nodes, so the whole of it is reachable from GUT.
##
## **Every roll goes through one seeded [RandomNumberGenerator]. The global RNG is
## never touched by [method generate].** That is not a style preference - it is
## deliverable 2. It is also why the vendored `set_seed()` must never be called:
## `Rivers.set_seed()` and `LandMasses.set_seed()` quietly call `randf_range()` to
## set `cloud_cover`, so a conversation with them costs you reproducibility and
## silently overwrites an authored value.
##
## Two more pieces of the vendored generator are unusable here, both for
## deliverable 3:
##   - `randomize_colors()` builds palettes from `_generate_new_colorscheme`, an
##     arbitrary cosine-hue generator. It produces exactly the green and purple
##     stars the brief forbids.
##   - `Star.randomize_colors()` is additionally **broken**: it assembles a
##     7-element array and `Star.set_colors()` slices it (0,1)/(1,6)/(6,10),
##     handing 5 colours to a `uniform vec4 colors[4]` and 1 colour to a
##     `uniform vec4[2] colors`. Silently wrong at runtime, and nothing in the
##     project has ever called it, so nobody has noticed.
##
## So the palettes are authored ([StarClass], [PlanetVariant]) and this file
## picks one and jitters it inside bands a test can check.

## The sky a game gets when nothing rolled one: a pre-WI-66 save (no `system`
## block), and a boot straight into main.tscn from the editor.
##
## A fixed constant rather than a fresh roll on purpose. An old save must look the
## same every time it is loaded, and a dev boot that changed its background on
## every run would make screenshot comparison impossible. It is NOT the sky those
## saves had - that is a deliberate one-time change, the same bargain WI-61 struck
## when every pre-WI-61 body restored as a belt asteroid.
const LEGACY_SEED: int = 19660929

# --- realism ------------------------------------------------------------------

## Hue bands (degrees) no *star* may sit in: green through cyan, and violet
## through magenta. Stars follow the blackbody locus - red, orange, yellow,
## white, blue-white - so blue is fine and green is impossible.
##
## The lower band's upper edge is what rules out the vendored `Star.gd`
## `starcolor2` "blue star", whose middle stops `77d6c1` and `1c92a7` measure at
## hue 167 and 189. It is a teal star, and teal stars are not a thing.
const STAR_FORBIDDEN_HUE_BANDS: Array[Vector2] = [
	Vector2(75.0, 195.0),
	Vector2(260.0, 330.0),
]

## Below this saturation a colour has no meaningful hue and the band check does
## not apply. Without the exemption every warm white core fails: `f5ffe8` reads
## as hue 86 - green - at saturation 0.09.
const NEUTRAL_SATURATION: float = 0.15

## Hue band every LIQUID colour must land in. This is deliverable 3's "water is
## some shade of blue" clause, and it is why the star tint in
## [method _apply_star_tint] is deliberately not applied to water.
const LIQUID_HUE_BAND: Vector2 = Vector2(185.0, 245.0)

## Nothing black, nothing neon.
const MIN_VALUE: float = 0.12
const MAX_SATURATION: float = 0.95

# --- composition --------------------------------------------------------------

## Where the two bodies sit on their parallax layers. Matched to main.tscn's
## authored placement - the star was at (200, 200) and the planet at (600, 350) -
## and widened into bands. Pure screen composition, so it lives here rather than
## on a class or a variant; tune it from a contact sheet, not from reasoning.
##
## **The station is out at the asteroid belt, far from both bodies.** That is the
## framing the whole composition serves, and it is what decides the one rule the
## sizes must obey: **the star always renders larger than the planet.** The planet
## is nearer, but a star is larger by orders of magnitude, so at belt distance it
## is the star that dominates the sky. A large planet would read as orbit, which
## is the wrong place.
##
## Enforced by the shipped bands - every [PlanetVariant] authors
## `scale_range = (1, 1)` so a planet is 60-100px, while the smallest star is
## 60px at 2x - and pinned by `test_star_systems.gd`, which asserts the smallest
## star any class can produce still out-sizes the largest planet any variant can.
## A future band tweak that inverts it fails there rather than in a screenshot
## nobody takes.
const STAR_OFFSET_MIN: Vector2 = Vector2(100.0, 100.0)
const STAR_OFFSET_MAX: Vector2 = Vector2(250.0, 300.0)
const PLANET_OFFSET_MIN: Vector2 = Vector2(400.0, 240.0)
const PLANET_OFFSET_MAX: Vector2 = Vector2(550.0, 500.0)

## Clearance kept between the star's disc and the planet's leading edge.
##
## The two offset bands overlap on their own: a hot class reaches 100px at 3x -
## a 300px disc - and starting from the right of the star band that reaches
## straight into the left of the planet band. The result is a fully lit planet
## drawn ON TOP of the star's face, which reads as a rendering error rather than
## as a transit. So the planet's band is pushed right by however much it takes,
## and only by that much: a small star leaves the authored band untouched.
##
## Measured against the DISC, not the corona. The flare layer extends half a
## diameter further in every direction, but it is sparse arcs over transparency -
## a planet inside it picks up the occasional streak, which looks like weather
## rather than like a mistake.
const STAR_PLANET_CLEARANCE: float = 40.0

## How far the star's colour bleeds into the planet's lit side and cloud tops.
## Small on purpose: it should tie the two bodies into one system, not repaint
## the planet.
const STAR_TINT_STRENGTH: float = 0.20

## The shaders all declare `uniform float seed: hint_range(1, 10)`.
const SEED_BAND: Vector2 = Vector2(1.0, 10.0)

## Degrees of headroom kept between a rolled hue and the edge of the band it was
## rolled inside.
##
## Not superstition: [method StarSystemData.quantize] snaps every channel to 8
## bits, and on a moderately saturated colour that rounding moves the hue by up
## to about 1.4 degrees. Generating right up to the edge therefore produces a
## colour that leaves the band on its way to the shader - the realism sweep
## caught exactly that, a water stop landing at hue 184.7 against a floor of 185.
## The band in the .tres is the contract; quantisation must not be allowed to
## break it, so generation keeps its distance rather than the rule being widened.
const HUE_BAND_MARGIN: float = 2.0

## Land biome bands: hue-min, hue-max, saturation centre, value centre.
##
## LAND is the one role with no realism constraint, so rather than the whole hue
## wheel it draws from a short list of things a planet actually looks like. The
## alternative - a free hue - is what makes procedural planets read as random
## rather than as places.
const LAND_BIOMES: Array[Vector4] = [
	Vector4(80.0, 140.0, 0.52, 0.66),   # temperate green
	Vector4(30.0, 55.0, 0.55, 0.70),    # arid ochre
	Vector4(8.0, 26.0, 0.58, 0.58),     # rust
	Vector4(198.0, 222.0, 0.24, 0.60),  # tundra grey-blue
]

# --- entry points -------------------------------------------------------------

## A system rolled from `seed_value`. Deterministic: the same seed produces a
## field-for-field identical result, on any machine, in any order.
static func generate(seed_value: int) -> StarSystemData:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out := StarSystemData.new()
	out.seed = seed_value
	_roll_star(rng, out)
	_roll_planet(rng, out)
	return out

## A system for a brand new game. The single place the global RNG is read - and
## only to choose a seed, never to roll anything.
static func generate_random() -> StarSystemData:
	return generate(randi())

## The fallback sky (see [constant LEGACY_SEED]).
static func legacy() -> StarSystemData:
	return generate(LEGACY_SEED)

# --- star ---------------------------------------------------------------------

static func _roll_star(rng: RandomNumberGenerator, out: StarSystemData) -> void:
	var star_class: StarClass = _pick_star_class(rng)
	if star_class == null:
		# No data at all: a mod mounting badly, an export filter mistake. Degrade
		# to a visible star rather than an empty sky.
		out.star_class_id = &""
		out.star_ramp = _fallback_star_ramp()
	else:
		out.star_class_id = star_class.id
		out.star_ramp = _jitter_star_ramp(rng, star_class)
		out.star_pixels = rng.randi_range(star_class.pixels_range.x, star_class.pixels_range.y)
		out.star_scale = rng.randi_range(star_class.scale_range.x, star_class.scale_range.y)
		out.star_noise_size = _in(rng, star_class.noise_size_range)
		out.star_blob_size = _in(rng, star_class.blob_size_range)
		out.star_circle_amount = _in(rng, star_class.circle_amount_range)
		out.star_circle_size = _in(rng, star_class.circle_size_range)
		out.star_storm_width = _in(rng, star_class.storm_width_range)
		out.star_time_speed = _in(rng, star_class.time_speed_range)
	out.star_seed = _in(rng, SEED_BAND)
	out.star_offset = _in_box(rng, STAR_OFFSET_MIN, STAR_OFFSET_MAX)

static func _pick_star_class(rng: RandomNumberGenerator) -> StarClass:
	var options: Array[StarClass] = StarClass.all()
	var weights: Array[float] = []
	for option: StarClass in options:
		weights.append(option.weight)
	var index: int = _pick_weighted(rng, weights)
	return options[index] if index >= 0 else null

## The authored ramp with per-stop jitter, so two G-class systems are not the
## same yellow.
##
## A near-neutral stop is jittered on VALUE ONLY. Raising the saturation of a
## warm white core pushes it over [constant NEUTRAL_SATURATION] and therefore
## into the hue check - and `f5ffe8`'s hue is 86 degrees, which is green. That is
## the "jitter across a band edge" failure, and it is a one-line rule to avoid.
static func _jitter_star_ramp(rng: RandomNumberGenerator, star_class: StarClass) -> PackedColorArray:
	var out: PackedColorArray = PackedColorArray()
	for source: Color in star_class.ramp:
		var value: float = clampf(source.v + rng.randf_range(-star_class.value_jitter,
				star_class.value_jitter), MIN_VALUE, 1.0)
		if source.s < NEUTRAL_SATURATION:
			out.append(StarSystemData.quantize(Color.from_hsv(source.h, source.s, value)))
			continue
		var hue: float = wrapf(source.h * 360.0 + rng.randf_range(-star_class.hue_jitter_degrees,
				star_class.hue_jitter_degrees), 0.0, 360.0)
		var saturation: float = clampf(source.s + rng.randf_range(-star_class.saturation_jitter,
				star_class.saturation_jitter), NEUTRAL_SATURATION, MAX_SATURATION)
		out.append(StarSystemData.quantize(Color.from_hsv(hue / 360.0, saturation, value)))
	return out

## The vendored `Star.gd` `starcolor1`, which is also what the shipped `yellow`
## class carries. Built rather than declared `const`: a `const PackedColorArray`
## cannot be read from another script (WI-59), and the tests want this.
static func _fallback_star_ramp() -> PackedColorArray:
	return PackedColorArray([Color("f5ffe8"), Color("ffd832"), Color("ff823b"), Color("7c191a")])

# --- planet -------------------------------------------------------------------

static func _roll_planet(rng: RandomNumberGenerator, out: StarSystemData) -> void:
	var variant: PlanetVariant = _pick_planet_variant(rng)
	if variant == null:
		# No planet. Nothing rolls this today; StellarBackground tolerates it so
		# the follow-on item's "planet (optional)" is a data change, not a rewrite.
		out.planet_variant_id = &""
		return
	out.planet_variant_id = variant.id
	out.planet_pixels = rng.randi_range(variant.pixels_range.x, variant.pixels_range.y)
	out.planet_scale = rng.randi_range(variant.scale_range.x, variant.scale_range.y)
	out.planet_offset = _in_box(rng, _planet_offset_min(out), PLANET_OFFSET_MAX)
	out.planet_seed = _in(rng, SEED_BAND)
	out.planet_rotation = _in(rng, variant.rotation_range)
	out.planet_time_scale = _in(rng, variant.time_scale_range)
	out.planet_coverage = rng.randf()
	out.planet_noise_scale = rng.randf()
	# A "clear world" roll, so not every planet in the game has weather.
	out.planet_cloudiness = rng.randf_range(0.0, 0.12) if rng.randf() < variant.clear_sky_chance \
			else rng.randf_range(0.20, 1.0)
	out.planet_palette = _roll_palette(rng, variant, out.star_ramp)

## The authored planet band, pushed right if the star already occupies its left
## edge (see [constant STAR_PLANET_CLEARANCE]). Takes the star fields off `out`,
## which is why the star must be rolled first.
static func _planet_offset_min(out: StarSystemData) -> Vector2:
	var star_right: float = out.star_offset.x + float(out.star_pixels * out.star_scale)
	return Vector2(maxf(PLANET_OFFSET_MIN.x, star_right + STAR_PLANET_CLEARANCE),
			PLANET_OFFSET_MIN.y)

static func _pick_planet_variant(rng: RandomNumberGenerator) -> PlanetVariant:
	var options: Array[PlanetVariant] = PlanetVariant.all()
	var weights: Array[float] = []
	for option: PlanetVariant in options:
		weights.append(option.weight)
	var index: int = _pick_weighted(rng, weights)
	return options[index] if index >= 0 else null

## One ramp per role the variant actually uses, at the longest length any of its
## layers asks for. Layers slice what they need, so `Rivers` taking four LAND
## stops and `LandMasses` taking four is one rule rather than two.
static func _roll_palette(rng: RandomNumberGenerator, variant: PlanetVariant,
		star_ramp: PackedColorArray) -> Dictionary[StringName, PackedColorArray]:
	var out: Dictionary[StringName, PackedColorArray] = {}
	var tint: Color = star_ramp[0] if not star_ramp.is_empty() else Color.WHITE
	# Rolled in enum order, never in the order the layers happen to mention them:
	# the sequence of rng calls IS the determinism contract, and layer order is a
	# property of the .tres.
	for role: PlanetPaletteSegment.Role in PlanetPaletteSegment.ROLE_IDS:
		var count: int = _longest_run(variant, role)
		if count <= 0:
			continue
		var ramp: PackedColorArray = _roll_role(rng, variant, role, count)
		# The star's light bleeds into everything except the water. Tinting LIQUID
		# would be defensible physically and would push it straight out of
		# LIQUID_HUE_BAND under a red star, which is deliverable 3 losing to a
		# nicety - so water keeps its own colour.
		if role != PlanetPaletteSegment.Role.LIQUID:
			ramp = _apply_star_tint(ramp, tint)
		out[PlanetPaletteSegment.role_id(role)] = ramp
	return out

## The most colours any single layer asks of `role`.
static func _longest_run(variant: PlanetVariant, role: PlanetPaletteSegment.Role) -> int:
	var longest: int = 0
	for layer: PlanetLayerSpec in variant.layers:
		if layer == null:
			continue
		for segment: PlanetPaletteSegment in layer.segments:
			if segment != null and segment.role == role:
				longest = maxi(longest, segment.count)
	return longest

static func _roll_role(rng: RandomNumberGenerator, variant: PlanetVariant,
		role: PlanetPaletteSegment.Role, count: int) -> PackedColorArray:
	match role:
		PlanetPaletteSegment.Role.LIQUID:
			return _roll_banded(rng, variant, role, count, Vector2(4.0, 16.0), 0.12, 0.42)
		PlanetPaletteSegment.Role.SURFACE:
			return _roll_banded(rng, variant, role, count, Vector2(-10.0, 10.0), 0.10, 0.38)
		PlanetPaletteSegment.Role.LAND:
			return _roll_land(rng, count)
		_:
			return _roll_cloud(rng, count)

## LIQUID and SURFACE: hue, saturation and value bands come from the variant,
## because "realistic" for those two is a per-planet judgement - an ice world's
## meltwater is a paler, narrower blue than an ocean, and its surface is
## near-white rather than the ochre of a dry world.
static func _roll_banded(rng: RandomNumberGenerator, variant: PlanetVariant,
		role: PlanetPaletteSegment.Role, count: int, drift_band: Vector2,
		saturation_rise: float, value_floor_factor: float) -> PackedColorArray:
	var bands: Array[Vector2] = variant.palette_band(role)
	if bands.is_empty():
		return _roll_cloud(rng, count)
	var drift: float = _in(rng, drift_band)
	var base_hue: float = _base_hue_for_drift(rng, bands[0], drift)
	var base_saturation: float = _in(rng, bands[1])
	var base_value: float = _in(rng, bands[2])
	return _build_ramp(count, base_hue, drift,
			Vector2(base_saturation, minf(base_saturation + saturation_rise, MAX_SATURATION)),
			Vector2(base_value, maxf(base_value * value_floor_factor, MIN_VALUE)))

## LAND: a biome hue, then a large deliberate drift toward slate as the ramp
## darkens - highlands green down to lowland shadow. The vendored `Rivers` land
## ramp does the same thing (it runs 100 degrees to 205), and it is most of why
## that planet reads as a planet.
static func _roll_land(rng: RandomNumberGenerator, count: int) -> PackedColorArray:
	var biome: Vector4 = LAND_BIOMES[rng.randi_range(0, LAND_BIOMES.size() - 1)]
	var base_hue: float = rng.randf_range(biome.x, biome.y)
	var drift: float = rng.randf_range(30.0, 70.0)
	var base_saturation: float = clampf(biome.z + rng.randf_range(-0.08, 0.08), 0.1, MAX_SATURATION)
	var base_value: float = clampf(biome.w + rng.randf_range(-0.08, 0.08), 0.2, 1.0)
	return _build_ramp(count, base_hue, drift,
			Vector2(base_saturation, maxf(base_saturation - 0.20, 0.12)),
			Vector2(base_value, maxf(base_value * 0.36, MIN_VALUE)))

## CLOUD: near-white down to a dark blue-grey, every time. Real clouds are white,
## and the variety here comes from cover and shape rather than colour.
static func _roll_cloud(rng: RandomNumberGenerator, count: int) -> PackedColorArray:
	var base_hue: float = rng.randf_range(206.0, 236.0)
	return _build_ramp(count, base_hue, rng.randf_range(-6.0, 6.0),
			Vector2(rng.randf_range(0.02, 0.07), rng.randf_range(0.36, 0.50)),
			Vector2(rng.randf_range(0.95, 1.0), rng.randf_range(0.26, 0.36)))

## A base hue such that `base + drift` still lands inside `band`. Callers with a
## realism constraint use this; LAND does not, because its drift is the point.
static func _base_hue_for_drift(rng: RandomNumberGenerator, band: Vector2, drift: float) -> float:
	var centre: float = (band.x + band.y) * 0.5
	# Inset first, so a band narrower than twice the margin collapses to its
	# centre rather than inverting.
	var low: float = minf(band.x + HUE_BAND_MARGIN, centre)
	var high: float = maxf(band.y - HUE_BAND_MARGIN, centre)
	if drift >= 0.0:
		high = maxf(high - drift, low)
	else:
		low = minf(low - drift, high)
	return rng.randf_range(low, high)

## Index 0 is the lightest stop and the last is the darkest, matching every
## authored ramp in the vendored scenes.
static func _build_ramp(count: int, base_hue: float, hue_drift: float,
		saturation_ramp: Vector2, value_ramp: Vector2) -> PackedColorArray:
	var out: PackedColorArray = PackedColorArray()
	var last: int = maxi(count - 1, 1)
	for index: int in count:
		var t: float = float(index) / float(last)
		var hue: float = wrapf(base_hue + hue_drift * t, 0.0, 360.0)
		var saturation: float = clampf(lerpf(saturation_ramp.x, saturation_ramp.y, t), 0.0, MAX_SATURATION)
		var value: float = clampf(lerpf(value_ramp.x, value_ramp.y, t), MIN_VALUE, 1.0)
		out.append(StarSystemData.quantize(Color.from_hsv(hue / 360.0, saturation, value)))
	return out

## Bleeds `tint` into the lit end of a ramp, fading out toward the shadow end.
static func _apply_star_tint(ramp: PackedColorArray, tint: Color) -> PackedColorArray:
	var out: PackedColorArray = PackedColorArray()
	var last: int = maxi(ramp.size() - 1, 1)
	for index: int in ramp.size():
		var t: float = float(index) / float(last)
		var blended: Color = ramp[index].lerp(tint, STAR_TINT_STRENGTH * (1.0 - t))
		out.append(StarSystemData.quantize(blended))
	return out

# --- realism predicates -------------------------------------------------------
# Public because they ARE deliverable 3, and `test_star_systems.gd` asserts them
# over a few thousand generated systems. Keeping them here rather than in the
# test means the rule has one home rather than two that can drift.

## Whether `color` could belong to a real star.
static func is_plausible_star_color(color: Color) -> bool:
	if color.v < MIN_VALUE or color.s > MAX_SATURATION:
		return false
	if color.s < NEUTRAL_SATURATION:
		return true
	var hue: float = color.h * 360.0
	for band: Vector2 in STAR_FORBIDDEN_HUE_BANDS:
		if hue > band.x and hue < band.y:
			return false
	return true

## Whether `color` could be water.
static func is_plausible_liquid_color(color: Color) -> bool:
	if color.v < MIN_VALUE or color.s > MAX_SATURATION:
		return false
	if color.s < NEUTRAL_SATURATION:
		# Near-white meltwater under a thin ice crust is fine; it has no hue to
		# be wrong about.
		return true
	var hue: float = color.h * 360.0
	return hue >= LIQUID_HUE_BAND.x and hue <= LIQUID_HUE_BAND.y

# --- helpers ------------------------------------------------------------------

static func _in(rng: RandomNumberGenerator, band: Vector2) -> float:
	return rng.randf_range(band.x, band.y)

## Always consumes exactly two rng calls. `high` is floored at `low` rather than
## trusted: a band raised past its own ceiling (which is what the star-clearance
## rule does to the planet's x when the star is very large) would otherwise roll
## somewhere between the two and land back inside the clearance.
static func _in_box(rng: RandomNumberGenerator, low: Vector2, high: Vector2) -> Vector2:
	return Vector2(rng.randf_range(low.x, maxf(high.x, low.x)),
			rng.randf_range(low.y, maxf(high.y, low.y)))

## Index into `weights`, or -1 when there is nothing to pick. Always consumes
## exactly one rng call, so an empty pool does not desynchronise everything
## rolled after it.
static func _pick_weighted(rng: RandomNumberGenerator, weights: Array[float]) -> int:
	var total: float = 0.0
	for weight: float in weights:
		if weight > 0.0:
			total += weight
	var roll: float = rng.randf()
	if total <= 0.0:
		return -1
	var target: float = roll * total
	var running: float = 0.0
	for index: int in weights.size():
		if weights[index] <= 0.0:
			continue
		running += weights[index]
		if target < running:
			return index
	# Float drift on the last bucket only.
	for index: int in range(weights.size() - 1, -1, -1):
		if weights[index] > 0.0:
			return index
	return -1
