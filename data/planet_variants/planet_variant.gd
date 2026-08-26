class_name PlanetVariant
extends Resource

## One kind of planet the background can show (WI-66): which vendored scene it
## is, which layers that scene has, and the bands its look is rolled inside.
##
## Discovered by scan (ContentPaths.PLANET_VARIANTS), not registered - a mod adds
## a fifth planet type by dropping a .tres, with no core edit, which is the WI-47
## bar and the same bargain [SpaceBodyProfile] made in WI-61.
##
## Colour bands live here rather than in the generator for the two roles where
## "realistic" is a per-planet judgement: an ice world's meltwater is a paler,
## narrower blue than an ocean, and its surface is near-white rather than the
## ochre of a dry world. LAND and CLOUD stay generator-owned because they are the
## same rule everywhere - land is a biome roll, clouds are white.
##
## Every number here is balance-of-a-kind, so it is data, not a code constant.

## Stable id. Saved in the `system` envelope block; renaming one orphans existing
## saves back to the fallback variant.
@export var id: StringName = &""
@export var display_name: String = ""
## Falls back to the [StellarBackground]'s own default when null, so a
## half-authored .tres degrades to a visible planet rather than an empty sky.
@export var scene: PackedScene
## Pick weight. Zero or below takes the variant out of the roll without deleting
## it - useful for a variant being worked on.
@export var weight: float = 1.0

@export var layers: Array[PlanetLayerSpec] = []

# --- apparent size ------------------------------------------------------------

## The shader's `pixels` uniform: the art's internal resolution. Every planet
## shader hints `hint_range(10,100)`, so do not author above 100.
@export var pixels_range: Vector2i = Vector2i(60, 100)
## On-screen magnification, and it is an INTEGER band on purpose. A pixel-art
## shader drawn at scale 2.4 renders some pixels two screen-pixels wide and some
## three, which reads as a rendering defect rather than as variety.
##
## Defaults to 1 - and every shipped variant authors 1 - because **the star must
## render larger than the planet**: the station sits out at the asteroid belt,
## far from both, and at that distance the star dominates however much nearer the
## planet is. See [constant StarSystemGenerator.STAR_OFFSET_MIN] for the full
## reasoning and the test that pins it. A variant authoring 2 or more here would
## have to be checked against every [StarClass].
##
## One consequence worth knowing: at scale 1, [member pixels_range] is the whole
## apparent-size axis AND the whole resolution axis, so a small planet is
## necessarily a chunky one. That is the vendored default behaviour and it reads
## correctly - less detail at a greater distance - but the two cannot be varied
## independently any more.
@export var scale_range: Vector2i = Vector2i(1, 1)

# --- palette bands ------------------------------------------------------------

## Hue band, in degrees, for the LIQUID role. This is deliverable 3's "water is
## some shade of blue" clause, and `test_star_systems.gd` sweeps every shipped
## variant to assert it sits inside the blue band.
@export var liquid_hue_range: Vector2 = Vector2(190.0, 240.0)
@export var liquid_saturation_range: Vector2 = Vector2(0.38, 0.78)
@export var liquid_value_range: Vector2 = Vector2(0.42, 0.78)

## Same three, for the SURFACE role. Ignored by a variant with no SURFACE
## segment (`Rivers` and `LandMasses` have none - their sphere is water).
@export var surface_hue_range: Vector2 = Vector2(25.0, 45.0)
@export var surface_saturation_range: Vector2 = Vector2(0.35, 0.70)
@export var surface_value_range: Vector2 = Vector2(0.55, 0.92)

# --- rolled shape -------------------------------------------------------------

## Axial tilt, radians, written to every layer's `rotation` uniform.
@export var rotation_range: Vector2 = Vector2(0.0, 0.6)
## Multiplier applied to each layer's AUTHORED `time_speed`, so two worlds do not
## drift in lockstep. Relative, not absolute, because the authored per-layer
## speeds are tuned against each other.
@export var time_scale_range: Vector2 = Vector2(0.8, 1.25)

## Chance that a planet rolls as nearly cloudless. Without it, uniform cloudiness
## means every world in the game has weather.
@export var clear_sky_chance: float = 0.15

## Every role this variant actually paints. Derived, so a variant cannot declare
## a role it has no segment for.
func roles_used() -> Array[PlanetPaletteSegment.Role]:
	var out: Array[PlanetPaletteSegment.Role] = []
	for layer: PlanetLayerSpec in layers:
		if layer == null:
			continue
		for segment: PlanetPaletteSegment in layer.segments:
			if segment != null and not out.has(segment.role):
				out.append(segment.role)
	return out

## Hue/saturation/value bands for `role`, or an empty array for a role this
## resource does not carry bands for (LAND and CLOUD, which the generator owns).
func palette_band(role: PlanetPaletteSegment.Role) -> Array[Vector2]:
	match role:
		PlanetPaletteSegment.Role.LIQUID:
			return [liquid_hue_range, liquid_saturation_range, liquid_value_range] as Array[Vector2]
		PlanetPaletteSegment.Role.SURFACE:
			return [surface_hue_range, surface_saturation_range, surface_value_range] as Array[Vector2]
		_:
			return [] as Array[Vector2]

# --- shared registry ----------------------------------------------------------
# Scan once, cache id -> PlanetVariant, the DifficultyData/SkillData pattern.
# Static rather than manager-owned because the roll happens in the main menu,
# before any manager node exists, and statics survive the scene swap.

static var _registry: Dictionary[StringName, PlanetVariant] = {}
static var _ordered: Array[PlanetVariant] = []
static var _scanned: bool = false

static func _ensure_scanned() -> void:
	if _scanned:
		return
	_scanned = true
	for path: String in ContentPaths.scan(ContentPaths.PLANET_VARIANTS):
		var res: Resource = ResourceLoader.load(path)
		if res is PlanetVariant:
			var variant := res as PlanetVariant
			if not ContentPaths.accept_id(variant.id, path, "PlanetVariant"):
				continue
			_registry[variant.id] = variant
			_ordered.append(variant)
	# Sorted by id, never by whatever order the directory enumerated: a weighted
	# roll has to reach the same answer from the same seed on every machine.
	_ordered.sort_custom(func(a: PlanetVariant, b: PlanetVariant) -> bool:
		return String(a.id) < String(b.id))

static func all() -> Array[PlanetVariant]:
	_ensure_scanned()
	return _ordered

static func by_id(variant_id: StringName) -> PlanetVariant:
	_ensure_scanned()
	return _registry.get(variant_id, null)

## Test seam, mirroring JobDataRegistry.clear_for_test: the cache is static and
## therefore shared by every suite in a run.
static func clear_for_test() -> void:
	_registry = {}
	_ordered = []
	_scanned = false
