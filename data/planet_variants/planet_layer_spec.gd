class_name PlanetLayerSpec
extends Resource

## One `ColorRect` inside a vendored planet scene, and what this project is
## allowed to vary on it (WI-66).
##
## The vendored scenes are third-party and stay byte-for-byte unmodified, so
## everything here is knowledge held OUTSIDE them: which node carries which
## shader, which of its uniforms are safe to roll, and what bands they roll in.
##
## Ranges are authored per layer rather than per planet on purpose. `Rivers`
## draws its land noise at `size` 4.6 and its clouds at 7.3; those two numbers
## are not one number with a scale factor, they are two separately tuned values
## whose RATIO is part of the look. [StarSystemData] therefore stores one
## normalised 0..1 factor for the whole planet and each layer maps it into its
## own band - which also keeps the save file variant-agnostic.

## The `ColorRect` child, by name. Swept against the variant's scene in
## `test_star_systems.gd`: a typo here writes nothing and reports nothing.
@export var node_name: StringName = &""

## The layer's `colors[]` uniform, described as an ordered list of role runs.
@export var segments: Array[PlanetPaletteSegment] = []

## Band for the layer's `size` uniform - the noise scale, i.e. how large the
## continents/cloud banks are. [constant Vector2.ZERO] leaves the authored value
## alone.
##
## NOTE the collision of names: this is the *shader* `size` uniform. The vendored
## `set_pixels()` writes `ColorRect.size`, a completely unrelated node property.
## They do not interact, but reading one as the other is a good way to lose an
## afternoon.
@export var noise_size_range: Vector2 = Vector2.ZERO

## Which uniform (if any) decides how much of this layer's shape survives -
## `river_cutoff` on `Rivers`, `land_cutoff` on `LandMasses`, `lake_cutoff` on
## `IceWorld`. Empty for a layer with no such knob.
##
## **All three run backwards from their names.** Each is consumed as
## `step(cutoff, noise)`, so a HIGHER value leaves LESS land / fewer rivers /
## fewer lakes. Author the band as the raw uniform range - low end = lots of the
## feature - and let [method StellarBackground._map_threshold] do the inverting.
@export var cutoff_param: StringName = &""
@export var cutoff_range: Vector2 = Vector2.ZERO

## Band for the `cloud_cover` uniform. [constant Vector2.ZERO] means this layer
## has no cloud cover, which is how the applier knows not to write it - and is
## why the generator's "clear world" roll is stored as a normalised cloudiness
## rather than an absolute cover.
##
## Backwards from its name, exactly like [member cutoff_param]: the shader does
## `step(cloud_cover, c)`, so the LOW end of this band is heavy overcast and the
## HIGH end is a clear sky.
@export var cloud_cover_range: Vector2 = Vector2.ZERO

## How many colours this layer's uniform expects, per the segments.
func total_colors() -> int:
	var total: int = 0
	for segment: PlanetPaletteSegment in segments:
		if segment != null:
			total += maxi(segment.count, 0)
	return total

static func has_range(band: Vector2) -> bool:
	return not (is_zero_approx(band.x) and is_zero_approx(band.y))
