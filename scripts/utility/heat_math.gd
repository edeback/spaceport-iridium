class_name HeatMath
extends RefCounted

## Every rule behind the station's thermal network (WI-60), as pure functions.
##
## Nothing here touches Global, SignalBus or the tree - HeatManager, HeatComponent
## and PawnTemperatureComponent own the state and the tunables and pass them in,
## this file owns the shape of the curves. That split is what makes the physics
## testable: "does a sealed forge reach equilibrium?" is a question about
## space_loss() and exchange_flow(), and it can be answered without a station.
##
## Balance numbers live on the manager, the components and ModuleData. The
## constants here are the ones that define the coordinate system (the temperature
## scale, the habitable band) or guard a divide-by-zero - and the tuning defaults,
## which exist as consts precisely so an @export can initialise FROM them and the
## two can never drift (the WI-59 CandidateRoller pattern).

# --- the temperature scale ----------------------------------------------------
#
# Degrees Fahrenheit, everywhere, with no second internal unit. Every threshold
# the design specifies is in F, the readout is in F, and a conversion layer would
# be two more places to get it wrong for no gameplay gain.

## What an unheated, fully exposed module tends toward. A balance knob, NOT
## physics: it is far enough below the habitable band that an unheated station
## freezes, and close enough to it that the overlay ramp and the Environment tab
## stay legible. Lowering it makes heating harder; that is its entire job.
const DEFAULT_SPACE_TEMPERATURE_F: float = -60.0

## The band crew are comfortable in, and the two thresholds past which they are
## harmed rather than merely miserable.
const DEFAULT_HABITABLE_LOW_F: float = 40.0
const DEFAULT_HABITABLE_HIGH_F: float = 90.0
const DEFAULT_DANGEROUS_LOW_F: float = 20.0
const DEFAULT_DANGEROUS_HIGH_F: float = 110.0

## What a module with no saved temperature comes back at (see
## HeatComponent.load_save_data). The middle of the habitable band, so a save
## written before this system existed loads into a station that behaves
## plausibly and then drifts to its real equilibrium - rather than one whose
## entire crew begins freezing to death on load.
const NEUTRAL_TEMPERATURE_F: float = 65.0

## Modifier ids the crew temperature bands apply. Exactly one is ever live on a
## pawn; see mood_id(). MoodCatalog carries the matching display entries.
const MOOD_TOO_COLD: StringName = &"too_cold"
const MOOD_TOO_HOT: StringName = &"too_hot"

## How a module (or a pawn's surroundings) reads at a glance. The one vocabulary
## for turning a temperature into a word - three surfaces render this, and
## PawnStatus is the precedent for what happens when they each answer separately.
enum Band { FREEZING, COLD, COMFORTABLE, WARM, SCORCHING }

## The bands, and how hard being outside them bites. A class rather than eight
## loose parameters because every caller passes the whole set, and a test that
## only wants to vary one shouldn't have to restate the rest.
class ComfortTuning extends RefCounted:
	## Inside this, nothing happens at all.
	var habitable_low_f: float = DEFAULT_HABITABLE_LOW_F
	var habitable_high_f: float = DEFAULT_HABITABLE_HIGH_F
	## Outside THIS, a pawn takes damage as well as a mood hit.
	var dangerous_low_f: float = DEFAULT_DANGEROUS_LOW_F
	var dangerous_high_f: float = DEFAULT_DANGEROUS_HIGH_F
	## Mood penalty at the dangerous threshold, ramping from 0 at the habitable
	## edge. Held (not grown) further out - past that point the health drain is
	## the thing carrying the message.
	var max_mood_penalty: float = 0.12
	## Health per game-hour lost the instant a pawn crosses a dangerous threshold.
	## Nonzero AT the threshold on purpose: a dead zone where the band has changed
	## but nothing happens reads as a bug.
	var harm_per_hour_at_edge: float = 2.0
	## Every further this-many degrees past the threshold adds another
	## harm_per_hour_at_edge. 111 F is a nuisance; 300 F is an emergency.
	var harm_ramp_degrees: float = 40.0

# --- conduction ---------------------------------------------------------------

## Energy moved from a to b in one step (negative when b is the hotter side).
##
## The reduced-mass form AtmosphereManager._exchange_pair already uses, for the
## same two reasons: energy is conserved exactly (one side loses precisely what
## the other gains), and a FULL step lands exactly on equal temperatures - so
## clamping step at 1.0 makes overshoot impossible at any mass ratio rather than
## merely unlikely.
##
## `step` is the fraction of the way to equilibrium this call travels; callers
## build it as min(rate_per_hour * hours, 1.0).
static func exchange_flow(t_a: float, mass_a: float, t_b: float, mass_b: float, step: float) -> float:
	if mass_a <= 0.0 or mass_b <= 0.0:
		return 0.0
	var reduced_mass: float = mass_a * mass_b / (mass_a + mass_b)
	return (t_a - t_b) * reduced_mass * clampf(step, 0.0, 1.0)

# --- radiation to space -------------------------------------------------------

## Energy a module sheds to space this step, always >= 0.
##
## Linear in (T - T_space), not Stefan-Boltzmann T^4. The design asks for "based
## on the amount of heat they have"; linear is trivially tunable, while a fourth
## power would make 200 F vs 400 F unbalanceable and 60 F vs 70 F invisible.
##
## Returned as ENERGY rather than degrees so thermal mass means the same thing
## everywhere - a heavy module cools slower, exactly as it heats slower. The
## clamp is what guarantees a pass can never carry a module below space
## temperature however large the rate or the interval.
static func space_loss(temp_f: float, space_temp_f: float, exposure: float,
		coefficient: float, thermal_mass: float, hours: float) -> float:
	var above: float = temp_f - space_temp_f
	if above <= 0.0 or thermal_mass <= 0.0 or exposure <= 0.0 or coefficient <= 0.0 or hours <= 0.0:
		return 0.0
	var loss: float = above * exposure * coefficient * hours
	# Never past equilibrium: the most that can leave is what it would take to
	# sit exactly at space temperature.
	return minf(loss, above * thermal_mass)

## The fraction of a module's faces touching nothing.
##
## Lifted verbatim from SolarPowerComponent so two systems cannot drift on what
## "surrounded" means. The `+ 1` is the module's **implicit back face**, and it is
## load-bearing for both consumers: it is what lets a solar panel boxed in on all
## four sides still generate something, and what makes a fully enclosed module
## still radiate something.
##
## That puts a hard floor of 1 / (points + 1) under exposure - 20% for a typical
## four-face module - and that floor is what structurally satisfies "modules come
## to equilibrium instead of heating up forever": a forge sealed in the middle of
## the station does not climb without bound, it settles, just five times hotter
## than the same forge on the hull. It is not an off-by-one to be tidied away.
## If a boxed-in forge reads as too survivable, the lever is the radiation
## coefficient, which scales the whole curve - never this floor.
static func exposure_fraction(connection_point_count: int, connected_count: int) -> float:
	var possible: float = float(maxi(connection_point_count, 0) + 1)
	var open: float = possible - float(maxi(connected_count, 0))
	# The clamp is inert for every reachable input (a module cannot have more
	# distinct neighbours than connection points); it makes the floor a property
	# of this function rather than of an argument about its callers.
	return clampf(open / possible, 1.0 / possible, 1.0)

# --- machines -----------------------------------------------------------------

## Multiplier a hot module applies to its own `process_time`: 1.0 while cool,
## rising to `max_mult` once fully heat-soaked.
##
## A lerp, never a step. A binary cutoff plus heat production that scales with
## work done is an oscillator - cut at the threshold, cool below it, resume,
## overshoot, repeat - and what the player sees is a progress bar stuttering once
## a second. `max_mult` is finite for the same reason: a machine that stops dead
## has no gradient for the player to read.
static func throttle_multiplier(temp_f: float, start_f: float, full_f: float, max_mult: float) -> float:
	if temp_f <= start_f or max_mult <= 1.0:
		return 1.0
	if full_f <= start_f:
		return max_mult
	var t: float = clampf((temp_f - start_f) / (full_f - start_f), 0.0, 1.0)
	return lerpf(1.0, max_mult, t)

## How much a room's temperature scales an activity that wants to be comfortable
## - sleep quality today, recreation if it ever wants the same treatment.
##
## Exactly 1.0 across the whole comfortable band (an ordinary room must be
## byte-for-byte unaffected), then the same 1/(1 + x*k) shape SleepComponent
## already uses for vibration, measured per 10 degrees outside the band so `k`
## reads as "how much one notch of discomfort costs".
static func comfort_multiplier(temp_f: float, low_f: float, high_f: float, k: float) -> float:
	var outside: float = maxf(maxf(low_f - temp_f, temp_f - high_f), 0.0)
	if outside <= 0.0 or k <= 0.0:
		return 1.0
	return 1.0 / (1.0 + k * outside / 10.0)

# --- crew ---------------------------------------------------------------------

static func band(temp_f: float, tuning: ComfortTuning) -> Band:
	if temp_f < tuning.dangerous_low_f:
		return Band.FREEZING
	if temp_f < tuning.habitable_low_f:
		return Band.COLD
	if temp_f <= tuning.habitable_high_f:
		return Band.COMFORTABLE
	if temp_f <= tuning.dangerous_high_f:
		return Band.WARM
	return Band.SCORCHING

## Signed happiness offset, <= 0 always. Zero across the entire habitable band,
## ramping to -max_mood_penalty at the dangerous threshold and holding there.
static func mood_offset(temp_f: float, tuning: ComfortTuning) -> float:
	var outside: float = 0.0
	var span: float = 0.0
	if temp_f < tuning.habitable_low_f:
		outside = tuning.habitable_low_f - temp_f
		span = tuning.habitable_low_f - tuning.dangerous_low_f
	elif temp_f > tuning.habitable_high_f:
		outside = temp_f - tuning.habitable_high_f
		span = tuning.dangerous_high_f - tuning.habitable_high_f
	else:
		return 0.0
	if span <= 0.0:
		return -tuning.max_mood_penalty
	return -tuning.max_mood_penalty * clampf(outside / span, 0.0, 1.0)

## Which happiness modifier a pawn in this temperature carries, or &"" for none.
## Exactly one can be live at a time, which is what stops a pawn walking from a
## freezer into an oven and holding both.
static func mood_id(temp_f: float, tuning: ComfortTuning) -> StringName:
	if temp_f < tuning.habitable_low_f:
		return MOOD_TOO_COLD
	if temp_f > tuning.habitable_high_f:
		return MOOD_TOO_HOT
	return &""

## Health lost per game-hour. Zero anywhere inside the dangerous thresholds -
## INCLUDING exactly on them, so this and band() agree to the degree about where
## "dangerous" begins; the thresholds themselves are the last survivable reading.
## Past one, harm_per_hour_at_edge immediately (no dead zone), growing by that
## much again every harm_ramp_degrees further out.
static func harm_per_hour(temp_f: float, tuning: ComfortTuning) -> float:
	var past: float = maxf(tuning.dangerous_low_f - temp_f, temp_f - tuning.dangerous_high_f)
	if past <= 0.0:
		return 0.0
	if tuning.harm_ramp_degrees <= 0.0:
		return tuning.harm_per_hour_at_edge
	return tuning.harm_per_hour_at_edge * (1.0 + past / tuning.harm_ramp_degrees)

# --- vocabulary ---------------------------------------------------------------
#
# The one place a temperature becomes a word, and the one place it becomes a
# string. The overlay legend, the Environment tab and the crew alert all render
# temperature; PawnStatus and StoresModel are the precedent for what happens when
# three surfaces each answer that separately.

static func band_label(temperature_band: Band) -> String:
	match temperature_band:
		Band.FREEZING:
			return "Freezing"
		Band.COLD:
			return "Cold"
		Band.COMFORTABLE:
			return "Comfortable"
		Band.WARM:
			return "Warm"
		Band.SCORCHING:
			return "Scorching"
	return "Unknown"

static func format_temperature(temp_f: float) -> String:
	return "%d°F" % int(round(temp_f))
