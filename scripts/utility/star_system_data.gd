class_name StarSystemData
extends RefCounted

## The star and planet one run is played under (WI-66): a rolled result, not a
## recipe. Pure data - no nodes, no Global, no shader calls.
##
## **The resolved parameters are what gets saved, not the seed.** Saving the seed
## alone would be one integer and would make "reload looks identical" free, right
## up until the first patch that retunes [StarSystemGenerator] - which would then
## silently repaint the sky of every existing save. It is also what this codebase
## already does everywhere it rolls something: an asteroid saves its rolled
## contents and richness, a [HireCandidate] saves its rolled name, skills and
## traits. The standing "derived state is re-derived, never saved" rule is about
## state derivable from LIVE state; a one-time roll is not derivable from
## anything. [member seed] rides along as provenance and nothing reads it back.
##
## Three planet fields are stored NORMALISED (0..1) rather than absolute:
## cloudiness, coverage and noise scale. Each vendored planet has differently tuned
## per-layer values whose ratio is part of the look - `Rivers` draws land noise at
## `size` 4.6 and clouds at 7.3 - so the variant's [PlanetLayerSpec] bands decide
## what 0.72 means and this stays variant-agnostic. That matters for the save
## file: a block written for `rivers` has the same shape as one written for
## `dry_terran`, which has one layer and no clouds at all.

## Provenance only. Nothing re-derives from it; it exists so a screenshot can be
## matched back to a `reroll_system` call.
var seed: int = 0

# --- star ---------------------------------------------------------------------

var star_class_id: StringName = &""
## Core → rim, post-jitter, [constant StarClass.RAMP_LENGTH] long.
var star_ramp: PackedColorArray = PackedColorArray()
var star_pixels: int = 100
var star_scale: int = 2
var star_offset: Vector2 = Vector2.ZERO
var star_seed: float = 1.0
var star_noise_size: float = 4.5
var star_blob_size: float = 4.9
var star_circle_amount: float = 2.0
var star_circle_size: float = 1.0
var star_storm_width: float = 0.3
var star_time_speed: float = 0.05

# --- planet -------------------------------------------------------------------

## Empty means this system has no planet. Nothing rolls that today; the follow-on
## item's "planet (optional)" does, and tolerating it costs one guard in
## [StellarBackground].
var planet_variant_id: StringName = &""
## Role id (see [PlanetPaletteSegment.ROLE_IDS]) -> that role's ramp.
var planet_palette: Dictionary[StringName, PackedColorArray] = {}
var planet_pixels: int = 100
var planet_scale: int = 2
var planet_offset: Vector2 = Vector2.ZERO
var planet_seed: float = 1.0
var planet_rotation: float = 0.0
## How much weather this world has: 0 is clear, 1 is overcast. SEMANTIC, not the
## shader value - the uniform it ends up in is a threshold that runs the other
## way. See [method StellarBackground._map_threshold].
var planet_cloudiness: float = 0.5
## How much of the shaped feature there is - land on a continental world, rivers
## on a river world, lakes on an ice world. 0 is barely any, 1 is lots. Semantic
## in the same way, and inverted in the same place.
var planet_coverage: float = 0.5
## 0..1 into each layer's own `noise_size_range`.
var planet_noise_scale: float = 0.5
## Multiplier on each layer's authored `time_speed`.
var planet_time_scale: float = 1.0

func has_planet() -> bool:
	return planet_variant_id != &""

## The ramp for `role_id`, or an empty array. Never null, so the applier's
## concatenation loop needs no guard of its own.
func palette_for(role_id: StringName) -> PackedColorArray:
	return planet_palette.get(role_id, PackedColorArray())

# --- serialisation ------------------------------------------------------------
# Colours travel as `Color.to_html(true)` strings: lossless, and readable in the
# save file, which matters when the only way to debug this feature is to look at
# it.

func to_dict() -> Dictionary:
	return {
		"seed": seed,
		"star": {
			"class": String(star_class_id),
			"ramp": _colors_to_html(star_ramp),
			"pixels": star_pixels,
			"scale": star_scale,
			"offset": [star_offset.x, star_offset.y],
			"seed": star_seed,
			"noise_size": star_noise_size,
			"blob_size": star_blob_size,
			"circle_amount": star_circle_amount,
			"circle_size": star_circle_size,
			"storm_width": star_storm_width,
			"time_speed": star_time_speed,
		},
		"planet": {
			"variant": String(planet_variant_id),
			"palette": _palette_to_dict(),
			"pixels": planet_pixels,
			"scale": planet_scale,
			"offset": [planet_offset.x, planet_offset.y],
			"seed": planet_seed,
			"rotation": planet_rotation,
			"cloudiness": planet_cloudiness,
			"coverage": planet_coverage,
			"noise_scale": planet_noise_scale,
			"time_scale": planet_time_scale,
		},
	}

## Rebuilds from a saved block. Every read coerces, because JSON has one number
## type and an int comes back a float - the same obligation every other
## load_save_data in the project is under.
static func from_dict(data: Dictionary) -> StarSystemData:
	var out := StarSystemData.new()
	out.seed = int(data.get("seed", 0))

	var star: Dictionary = data.get("star", {})
	out.star_class_id = StringName(String(star.get("class", "")))
	out.star_ramp = _html_to_colors(star.get("ramp", []))
	out.star_pixels = int(star.get("pixels", out.star_pixels))
	out.star_scale = int(star.get("scale", out.star_scale))
	out.star_offset = _to_vector2(star.get("offset", []), out.star_offset)
	out.star_seed = float(star.get("seed", out.star_seed))
	out.star_noise_size = float(star.get("noise_size", out.star_noise_size))
	out.star_blob_size = float(star.get("blob_size", out.star_blob_size))
	out.star_circle_amount = float(star.get("circle_amount", out.star_circle_amount))
	out.star_circle_size = float(star.get("circle_size", out.star_circle_size))
	out.star_storm_width = float(star.get("storm_width", out.star_storm_width))
	out.star_time_speed = float(star.get("time_speed", out.star_time_speed))

	var planet: Dictionary = data.get("planet", {})
	out.planet_variant_id = StringName(String(planet.get("variant", "")))
	var palette: Dictionary = planet.get("palette", {})
	for key: Variant in palette:
		out.planet_palette[StringName(String(key))] = _html_to_colors(palette[key])
	out.planet_pixels = int(planet.get("pixels", out.planet_pixels))
	out.planet_scale = int(planet.get("scale", out.planet_scale))
	out.planet_offset = _to_vector2(planet.get("offset", []), out.planet_offset)
	out.planet_seed = float(planet.get("seed", out.planet_seed))
	out.planet_rotation = float(planet.get("rotation", out.planet_rotation))
	out.planet_cloudiness = float(planet.get("cloudiness", out.planet_cloudiness))
	out.planet_coverage = float(planet.get("coverage", out.planet_coverage))
	out.planet_noise_scale = float(planet.get("noise_scale", out.planet_noise_scale))
	out.planet_time_scale = float(planet.get("time_scale", out.planet_time_scale))
	return out

func _palette_to_dict() -> Dictionary:
	var out: Dictionary = {}
	for role_id: StringName in planet_palette:
		out[String(role_id)] = _colors_to_html(planet_palette[role_id])
	return out

## Snaps a colour to what [method to_dict] can actually represent.
##
## `to_html` writes 8 bits per channel, so an un-snapped colour comes back from a
## save up to 1/255 away from where it started - small enough to be invisible and
## large enough to fail every exact round-trip assertion. Quantising at
## generation time instead means the save is genuinely lossless and the test can
## say so, rather than the test carrying a tolerance that hides real drift.
static func quantize(color: Color) -> Color:
	return Color.html(color.to_html(true))

static func _colors_to_html(colors: PackedColorArray) -> Array:
	var out: Array = []
	for color: Color in colors:
		out.append(color.to_html(true))
	return out

static func _html_to_colors(raw: Variant) -> PackedColorArray:
	var out: PackedColorArray = PackedColorArray()
	if not raw is Array:
		return out
	for entry: Variant in raw as Array:
		var text: String = String(entry)
		# html_is_valid rather than a try/echo: a hand-edited save with a typo
		# should lose one stop, not abort the whole load.
		if Color.html_is_valid(text):
			out.append(Color.html(text))
	return out

static func _to_vector2(raw: Variant, fallback: Vector2) -> Vector2:
	if not raw is Array or (raw as Array).size() < 2:
		return fallback
	var values: Array = raw as Array
	return Vector2(float(values[0]), float(values[1]))

## Field-for-field equality, used by the save round-trip test and the probe.
## Floats compare approximately because they have been through JSON.
func equals(other: StarSystemData) -> bool:
	if other == null:
		return false
	if seed != other.seed or star_class_id != other.star_class_id:
		return false
	if planet_variant_id != other.planet_variant_id:
		return false
	if star_pixels != other.star_pixels or star_scale != other.star_scale:
		return false
	if planet_pixels != other.planet_pixels or planet_scale != other.planet_scale:
		return false
	if not _colors_equal(star_ramp, other.star_ramp):
		return false
	if planet_palette.size() != other.planet_palette.size():
		return false
	for role_id: StringName in planet_palette:
		if not _colors_equal(planet_palette[role_id], other.palette_for(role_id)):
			return false
	var mine: Array[float] = _scalars()
	var theirs: Array[float] = other._scalars()
	for index: int in mine.size():
		if not is_equal_approx(mine[index], theirs[index]):
			return false
	return true

func _scalars() -> Array[float]:
	return [
		star_offset.x, star_offset.y, star_seed, star_noise_size, star_blob_size,
		star_circle_amount, star_circle_size, star_storm_width, star_time_speed,
		planet_offset.x, planet_offset.y, planet_seed, planet_rotation,
		planet_cloudiness, planet_coverage, planet_noise_scale, planet_time_scale,
	] as Array[float]

static func _colors_equal(a: PackedColorArray, b: PackedColorArray) -> bool:
	if a.size() != b.size():
		return false
	for index: int in a.size():
		# to_html round-trips through 8-bit channels, so an exact float compare
		# would fail on a value that survived the save perfectly well.
		if not a[index].is_equal_approx(b[index]):
			return false
	return true
