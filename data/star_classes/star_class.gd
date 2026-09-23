class_name StarClass
extends Resource

## One spectral class of star, and the palette and knob bands that make it look
## like one (WI-66).
##
## Realism here is AUTHORED, not clamped. Deliverable 3 - "no green stars, no
## purple stars" - cannot be met by restricting a random hue, because the
## allowed set is not one band: stars follow the blackbody locus (red → orange →
## yellow → white → blue-white) and skip green entirely, which is why a green
## star is impossible rather than merely rare. So the palettes are written down
## and the generator's job is to pick one and jitter it.
##
## This is also why the vendored `StellarObjectVisual.randomize_colors()` is
## unusable for this item: it builds palettes from an arbitrary cosine-hue
## generator, which produces exactly the colours the brief forbids. (On the star
## it is additionally broken - see [StarSystemGenerator].)
##
## Discovered by scan (ContentPaths.STAR_CLASSES), so a mod adds a spectral class
## with no core edit.

## Number of stops the star shader's `colors[]` uniform takes. Not a free number:
## `Star.gdshader` declares `uniform vec4 colors[4]`, and a ramp of any other
## length is silently padded or truncated.
const RAMP_LENGTH: int = 4

@export var id: StringName = &""
@export var display_name: String = ""
## Morgan-Keenan letter. Display only - `dump_system()` prints it beside the
## temperature so a screenshot can be matched back to its data.
@export var spectral_class: StringName = &""
## The physical anchor the ramp below was authored against. Also what the
## follow-on **Stars, Planets and Other Stations** item wants for its per-system
## space temperature; nothing derives anything from it yet.
@export var temperature_k: int = 5800

## Core → rim, [constant RAMP_LENGTH] stops, fed straight to the star shader's
## `colors[]`. The two remaining layers derive from it rather than being authored
## twice, exactly as the shipped `Star.tscn` does: blobs take the core colour,
## flares take [mid, core].
@export var ramp: PackedColorArray = PackedColorArray()

## Pick weight. Deliberately NOT astrophysical frequency - real space is roughly
## three-quarters M-dwarfs, which would open three runs in four on a red sky.
## Weighted for variety, with the hot classes rare so a blue giant feels found.
@export var weight: float = 1.0

# --- rolled knobs -------------------------------------------------------------

## The shader's `pixels` uniform: internal resolution. `Star.gdshader` hints
## `hint_range(10,100)`.
@export var pixels_range: Vector2i = Vector2i(70, 100)
## Integer on-screen magnification - see [member PlanetVariant.scale_range] for
## why it must not be fractional.
@export var scale_range: Vector2i = Vector2i(2, 2)

## `size` on the star's own surface noise: how fine the churn is.
@export var noise_size_range: Vector2 = Vector2(3.8, 5.6)
## `size` on the blob layer - the bright spots drifting across the disc.
@export var blob_size_range: Vector2 = Vector2(3.8, 6.2)
## `circle_amount` / `circle_size`, shared by the blob and flare layers.
@export var circle_amount_range: Vector2 = Vector2(2.0, 7.0)
@export var circle_size_range: Vector2 = Vector2(0.6, 1.0)
## `storm_width` on the flare layer: how far the corona reaches. Scaled with
## temperature in the shipped set, so a red dwarf is visibly calmer than a
## blue giant.
@export var storm_width_range: Vector2 = Vector2(0.18, 0.38)
## `time_speed`, before `update_time`'s own per-layer multipliers.
@export var time_speed_range: Vector2 = Vector2(0.035, 0.085)

## Per-stop jitter applied to [member ramp], so two G-class systems are not the
## same yellow. Kept small: the bands the realism sweep checks are checked on the
## POST-jitter colours, and a wide jitter on a stop near a band edge is how a
## star ends up teal.
@export var hue_jitter_degrees: float = 6.0
@export var value_jitter: float = 0.08
@export var saturation_jitter: float = 0.06

# --- shared registry ----------------------------------------------------------

static var _registry: Dictionary[StringName, StarClass] = {}
static var _ordered: Array[StarClass] = []
## The [member ContentPaths.generation] this cache last scanned at, -1 for never.
## A stale one rescans on the next read (WI-74 §2).
static var _scanned_generation: int = -1

static func _ensure_scanned() -> void:
	if _scanned_generation == ContentPaths.generation:
		return
	_scanned_generation = ContentPaths.generation
	_registry.clear()
	_ordered.clear()
	for path: String in ContentPaths.scan(ContentPaths.STAR_CLASSES):
		var res: Resource = ResourceLoader.load(path)
		if res is StarClass:
			var star_class := res as StarClass
			if not ContentPaths.accept_id(star_class.id, path, "StarClass"):
				continue
			_registry[star_class.id] = star_class
			_ordered.append(star_class)
	# Sorted by id so a seeded weighted roll is reproducible whatever order the
	# directory enumerated in.
	_ordered.sort_custom(func(a: StarClass, b: StarClass) -> bool:
		return String(a.id) < String(b.id))

static func all() -> Array[StarClass]:
	_ensure_scanned()
	return _ordered

static func by_id(class_id: StringName) -> StarClass:
	_ensure_scanned()
	return _registry.get(class_id, null)

static func clear_for_test() -> void:
	_registry = {}
	_ordered = []
	_scanned_generation = -1
