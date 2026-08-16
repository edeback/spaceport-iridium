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

## Temperatures that read as full blue and full red (WI-60).
##
## These are the two DANGEROUS thresholds, not the physical extremes of the
## station, and that is deliberate. Calibrating the ramp to the real range
## (space at -60 F, a worked forge past 200 F) puts the entire habitable band
## inside a few percent of the gradient - a screenshot of that version showed a
## freezing module, a comfortable one and a legend of five identical green
## squares. The ramp exists to answer "is this room all right", so it spends its
## whole range on the band where that question has an answer, and saturates on
## either side where the answer is just "no".
##
## Their midpoint is 65 F, which is HeatMath.NEUTRAL_TEMPERATURE_F - so a station
## sitting at its neutral seed reads as exactly the middle of the ramp.
const HEAT_COLD_AT: float = HeatMath.DEFAULT_DANGEROUS_LOW_F
const HEAT_HOT_AT: float = HeatMath.DEFAULT_DANGEROUS_HIGH_F

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

## Heat: a DIVERGING ramp, unlike every other mode here. Cold reads blue, the
## habitable band reads green, hot reads red - because too cold and too hot are
## two different problems with two different fixes, and a single-ended ramp
## would paint a freezing corridor and a comfortable one the same shade of
## "fine". The midpoint of the two reference temperatures is the comfortable
## middle, which is what puts green where the crew are happy.
static func heat_color(temp_f: float, cold_at: float = HEAT_COLD_AT, hot_at: float = HEAT_HOT_AT) -> Color:
	if hot_at <= cold_at:
		return untinted()
	var t: float = (temp_f - cold_at) / (hot_at - cold_at)
	return gradient3(t, _COOL, _GOOD, _BAD)

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

# --- legend (WI-54) -----------------------------------------------------------

## Stable key for one overlay mode. The controller's `Mode` enum is a property of
## a [Control]; these are what the pure side keys on, so the legend table can be
## tested without a node and so a saved/printed mode name is never an enum
## ordinal.
const MODE_POWER: StringName = &"power"
const MODE_O2: StringName = &"o2"
const MODE_INTEGRITY: StringName = &"integrity"
const MODE_VIBRATION: StringName = &"vibration"
const MODE_LOGISTICS: StringName = &"logistics"
const MODE_HEAT: StringName = &"heat"

## One entry in an overlay's legend: the swatch the player sees beside a phrase.
class LegendStop extends RefCounted:
	var label: String
	var color: Color

	func _init(stop_label: String, stop_color: Color) -> void:
		label = stop_label
		# The mode functions return the *tint strength* in alpha, which is not an
		# opacity a UI swatch should inherit - a 0.82-alpha square over a dark
		# panel reads as a different colour from the module it is explaining.
		color = Color(stop_color.r, stop_color.g, stop_color.b, 1.0)

## The legend for one mode, low reading to high.
##
## Every stop is produced by calling that mode's own colour function at a
## representative value rather than by naming a colour, which is the whole point:
## the swatch beside "breathable" is *the tint a breathable module gets*, so the
## legend cannot drift from the paint when a gradient is retuned. An unknown key
## (a mode with nothing to explain, or NONE) returns empty.
static func legend_stops(mode_key: StringName) -> Array[LegendStop]:
	match mode_key:
		MODE_POWER:
			return [
				LegendStop.new("Powered", power_color(true)),
				LegendStop.new("No power", power_color(false)),
			] as Array[LegendStop]
		MODE_O2:
			return [
				LegendStop.new("Suffocating", o2_color(O2_RED_AT)),
				LegendStop.new("Marginal", o2_color((O2_RED_AT + O2_GREEN_AT) * 0.5)),
				LegendStop.new("Breathable", o2_color(O2_GREEN_AT)),
			] as Array[LegendStop]
		MODE_INTEGRITY:
			return [
				LegendStop.new("Critical", integrity_color(0.0, false)),
				LegendStop.new("Damaged", integrity_color(0.5, false)),
				LegendStop.new("Intact", integrity_color(1.0, false)),
				LegendStop.new("Wreckage", integrity_color(0.5, true)),
			] as Array[LegendStop]
		MODE_VIBRATION:
			# `ref` is the controller's calibration export, so the stops are stated
			# as *fractions* of it - a legend that hardcoded absolute field levels
			# would stop matching the station the moment that export is retuned.
			# Zero is deliberately not a stop: no field means no tint at all, and
			# a swatch for "transparent" is a black square. The note says so.
			return [
				LegendStop.new("Quiet", vibration_color(0.1, 1.0)),
				LegendStop.new("Noticeable", vibration_color(0.5, 1.0)),
				LegendStop.new("Loud", vibration_color(1.0, 1.0)),
			] as Array[LegendStop]
		MODE_LOGISTICS:
			return [
				LegendStop.new("Source", logistics_color(-int(LOGISTICS_REF))),
				LegendStop.new("Neutral", logistics_color(0)),
				LegendStop.new("Sink", logistics_color(int(LOGISTICS_REF))),
			] as Array[LegendStop]
		MODE_HEAT:
			# Stops are named by the temperatures they stand for, and produced by
			# calling heat_color at those temperatures - so a retune of the ramp
			# moves the legend with it. The two habitable bounds are stops in
			# their own right because they are the numbers the player is actually
			# managing toward.
			return [
				LegendStop.new("Freezing", heat_color(HeatMath.DEFAULT_DANGEROUS_LOW_F)),
				LegendStop.new("Cool", heat_color(HeatMath.DEFAULT_HABITABLE_LOW_F)),
				LegendStop.new("Habitable", heat_color(HeatMath.NEUTRAL_TEMPERATURE_F)),
				LegendStop.new("Warm", heat_color(HeatMath.DEFAULT_HABITABLE_HIGH_F)),
				LegendStop.new("Scorching", heat_color(HeatMath.DEFAULT_DANGEROUS_HIGH_F)),
			] as Array[LegendStop]
	return [] as Array[LegendStop]

## One-line footnote under a mode's ramp, for the parts of a mode that are not a
## colour: the O2 breach pulse, the logistics arrows the flow layer draws.
static func legend_note(mode_key: StringName) -> String:
	match mode_key:
		MODE_O2:
			return "A pulsing module is breached."
		MODE_LOGISTICS:
			return "Arrows are active hauls; numbers are storage priority."
		MODE_VIBRATION:
			return "Modules with no vibration field are left untinted."
		MODE_HEAT:
			return "Crew are comfortable between %s and %s." % [
				HeatMath.format_temperature(HeatMath.DEFAULT_HABITABLE_LOW_F),
				HeatMath.format_temperature(HeatMath.DEFAULT_HABITABLE_HIGH_F)]
	return ""
