class_name OverlayPalette
extends RefCounted

## Pure value->color mapping for the WI-35 station overlays. No nodes, no
## Global, no world state - every function turns a single already-read number
## (O2 partial, hp fraction, a field level, a priority) into the tint the
## OverlayController hands to ModuleBase.set_overlay_color(). Kept separate and
## side-effect-free so the gradient math is unit-tested on its own.
##
## Convention: the returned Color's ALPHA is the shader tint strength, so
## untinted() (alpha 0) means "leave this module rendering normally". A opaque
## overlay would hide the plating entirely, so tinted colors sit around TINT.

## Default tint strength for a fully-tinted module. Below 1 so the sprite's own
## plating luminance still shows through and the silhouette stays readable.
const TINT: float = 0.82

## O2 partial pressure (kPa-ish units, see AtmosphereComponent) that reads full
## red / full green. Between them the gradient runs red->yellow->green. RED_AT
## sits at the suffocation-damage threshold, GREEN_AT comfortably breathable.
const O2_RED_AT: float = 25.0
const O2_GREEN_AT: float = 60.0

## Priority magnitude mapped to a full-saturation logistics tint. The routing
## band runs roughly -99 (deconstruction source) .. +99 (construction sink).
const LOGISTICS_REF: float = 99.0

# --- gradient endpoints (rgb; alpha filled in per call) -----------------------
const _GOOD := Color(0.24, 0.86, 0.36)   # healthy / powered / breathable
const _WARN := Color(0.95, 0.82, 0.22)   # marginal
const _BAD := Color(0.95, 0.24, 0.18)    # failing / unpowered / suffocating
const _COOL := Color(0.30, 0.55, 0.95)   # logistics source (exports out)
const _NEUTRAL := Color(0.55, 0.57, 0.60) # logistics neutral / zero priority
const _WRECK := Color(0.85, 0.5, 0.15)   # damaged truss / wreckage (distinct)

## Fully transparent: the module renders with no overlay tint.
static func untinted() -> Color:
	return Color(0.0, 0.0, 0.0, 0.0)

## Two-segment red->yellow->green (or any low/mid/high) blend at strength `a`.
## t is clamped to [0,1]; t=0 -> low, 0.5 -> mid, 1 -> high.
static func gradient3(t: float, low: Color, mid: Color, high: Color, a: float = TINT) -> Color:
	t = clampf(t, 0.0, 1.0)
	var rgb: Color
	if t < 0.5:
		rgb = low.lerp(mid, t / 0.5)
	else:
		rgb = mid.lerp(high, (t - 0.5) / 0.5)
	return Color(rgb.r, rgb.g, rgb.b, a)

# --- per-mode mappings --------------------------------------------------------

## Power: a module that needs power reads green when it has it, red when it
## doesn't (same for a generator: on vs. offline).
static func power_color(powered: bool) -> Color:
	return Color(_GOOD.r, _GOOD.g, _GOOD.b, TINT) if powered else Color(_BAD.r, _BAD.g, _BAD.b, TINT)

## O2: red at/under the suffocation threshold, green once comfortably
## breathable, yellow between. Callers skip modules that hold no atmosphere.
static func o2_color(o2_partial: float) -> Color:
	var t: float = (o2_partial - O2_RED_AT) / (O2_GREEN_AT - O2_RED_AT)
	return gradient3(t, _BAD, _WARN, _GOOD)

## Integrity: full HP green, low HP red. A damaged structural placeholder
## (truss/wreckage) gets a distinct orange so it never reads as a low-HP real
## module; an undamaged truss has nothing to show, so it stays untinted.
static func integrity_color(hp_fraction: float, is_truss: bool) -> Color:
	if is_truss:
		if hp_fraction < 1.0:
			return Color(_WRECK.r, _WRECK.g, _WRECK.b, TINT)
		return untinted()
	return gradient3(hp_fraction, _BAD, _WARN, _GOOD)

## Vibration: no field -> untinted; otherwise green (tolerable) through yellow
## to red (high) as the level approaches `ref`. Higher is worse.
static func vibration_color(field: float, ref: float) -> Color:
	if field <= 0.0 or ref <= 0.0:
		return untinted()
	var t: float = clampf(field / ref, 0.0, 1.0)
	# Reuse the 3-stop blend but reversed: low field -> good (green), high -> bad.
	return gradient3(1.0 - t, _BAD, _WARN, _GOOD)

## Logistics: diverging by priority sign. Sinks (positive, imports/construction)
## run warm; sources (negative, exports/deconstruction) run cool; zero is
## neutral grey. Magnitude scales saturation toward `ref`.
static func logistics_color(priority: int, ref: float = LOGISTICS_REF) -> Color:
	if ref <= 0.0:
		return Color(_NEUTRAL.r, _NEUTRAL.g, _NEUTRAL.b, TINT)
	var t: float = clampf(float(priority) / ref, -1.0, 1.0)
	var rgb: Color
	if t >= 0.0:
		rgb = _NEUTRAL.lerp(_BAD, t)
	else:
		rgb = _NEUTRAL.lerp(_COOL, -t)
	return Color(rgb.r, rgb.g, rgb.b, TINT)
