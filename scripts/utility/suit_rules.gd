class_name SuitRules
extends RefCounted

## When a crew member wears a pressure suit, and when they go and change out of
## one (WI-67).
##
## Pure: no Global, no SignalBus, no nodes. [PawnSuitComponent] owns the state and
## the tunables and passes them in, exactly the way [HeatMath] is used - which is
## what lets "would a pawn suit up in this room?" be answered without a station.
##
## ## The shape of the rule
##
## A room sorts into one of four [enum RoomState] answers, and the middle one is
## load-bearing. With only "fit" and "harmful" a room sitting exactly on a
## threshold would send a pawn back and forth to the airlock forever; the
## TOLERABLE band between them is the hysteresis, and it is also what the brief
## describes - a crew member in a chilly room is cold and unhappy about it, and
## does not go and suit up.
##
## Every threshold here is BORROWED, never re-declared. HARMFUL uses the numbers
## that already mean "this is hurting you" (PawnBreathingComponent.damage_o2_
## partial, HeatMath's dangerous band), and HABITABLE's O2 floor is
## AtmosphereManager.alert_o2_partial - the number the low-O2 alert and the OXYGEN
## chip already share. So "the crew will take their helmets off in here" and "the
## game is not warning you about this room" agree by construction rather than by
## two constants somebody has to keep in step.

## How a room reads to somebody deciding what to wear in it.
enum RoomState {
	## No atmosphere component, or no thermal body yet. Keeps the current state.
	##
	## This is NOT a real room: only truss, armour plate and the radiator carry
	## has_atmosphere = false and crew never stand in any of them. It exists for
	## the registration window just after a module finishes building - and it must
	## never read as HARMFUL, or every completed build would send its construction
	## crew sprinting for an airlock.
	UNKNOWN,
	## Actively harming anyone unsuited. Go and put a suit on.
	HARMFUL,
	## Neither fit to live in nor harmful. Keep wearing whatever you have on.
	TOLERABLE,
	## Fit to live in. A suit may come off here.
	HABITABLE,
}

## What the rule decided to do about the suit.
enum Action {
	## Leave everything as it is.
	NONE,
	## Put a suit on: walk to ANY reachable airlock, interrupting whatever the
	## pawn was doing.
	SUIT_UP,
	## Take the suit off: walk to a HABITABLE airlock, queued behind the current
	## job rather than interrupting it.
	TAKE_OFF,
	## Put the suit on where the pawn stands, with no trip. Going outside, and
	## Tier 1, are the only two ways this happens - both are states the pawn is
	## already in rather than something they have to travel to fix.
	SUIT_UP_IN_PLACE,
	## Take the suit off where the pawn stands. Only ever the airlock entry case:
	## a pawn coming in from outside is already standing in the airlock.
	TAKE_OFF_IN_PLACE,
}

## Why a suit went on, for the alert's subject line. Ordered so the caller can
## keep the most urgent reason when two apply at once.
enum Reason { NONE, NO_AIR, TOO_COLD, TOO_HOT }

## The thresholds the rule reads, gathered from the components that own them.
##
## A class rather than six loose parameters because every caller passes the whole
## set, and a test that only wants to vary one should not have to restate the
## rest - the [HeatMath.ComfortTuning] precedent.
class Thresholds extends RefCounted:
	## Below this O2 partial a pawn is taking suffocation damage.
	## PawnBreathingComponent.damage_o2_partial.
	var damage_o2_partial: float = 25.0
	## At or above this O2 partial the room is fit to live in.
	## AtmosphereManager.alert_o2_partial.
	var habitable_o2_partial: float = 40.0
	## The temperature bands, straight off the pawn's own PawnTemperatureComponent.
	var comfort: HeatMath.ComfortTuning = HeatMath.ComfortTuning.new()
	## False when the pawn carries no breathing component, so air is not an axis it
	## has an opinion about. Same for heat.
	var reads_air: bool = true
	var reads_heat: bool = true

## Everything the decision depends on. Gathered by the component once per
## evaluation so this file never reaches for live state.
##
## The enum-typed fields are spelled `SuitRules.RoomState` rather than a bare
## `RoomState`: an inner class does not inherit the outer script's type scope, so
## the short form resolves to a DIFFERENT type of the same name and every
## assignment from outside fails to parse. The WI-64 class_name-cycle trap in a new
## costume - it reads as redundant and is not.
class Situation extends RefCounted:
	var suited: bool = true
	## current_module == null AND not being conveyed. A turbolift ride also nulls
	## the module, and a pawn mid-ride decides nothing.
	var outside: bool = false
	var conveyed: bool = false
	## Tier 1: TierData.suits_mandatory.
	var suits_mandatory: bool = false
	## The room the pawn is standing in.
	var environment: SuitRules.RoomState = SuitRules.RoomState.UNKNOWN
	## Sim-hours left before a suit put on against harm may come off.
	var hold_remaining: float = 0.0
	## The pawn just walked in from outside, and is therefore standing in whatever
	## module it entered. Only an airlock sets this - see [method decide].
	var entered_airlock_from_outside: bool = false
	## The airlock they entered, when the above is true.
	var entry_airlock_environment: SuitRules.RoomState = SuitRules.RoomState.UNKNOWN
	## A trip is already running or on the queue, so do not post a second one.
	var trip_in_progress: bool = false
	## Sim-hours of throttle left after a refused or failed trip.
	var trip_cooldown: float = 0.0

## Which O2/temperature pair a room reads as.
##
## The two axes are independent and the worse one wins: a warm room full of
## nothing to breathe is HARMFUL, and a breathable room at -40 F is too.
static func classify(o2_partial: float, temp_f: float, thresholds: SuitRules.Thresholds,
		has_atmosphere: bool, has_thermal_body: bool) -> SuitRules.RoomState:
	var air: SuitRules.RoomState = SuitRules.RoomState.UNKNOWN
	if thresholds.reads_air and has_atmosphere:
		if o2_partial < thresholds.damage_o2_partial:
			air = SuitRules.RoomState.HARMFUL
		elif o2_partial >= thresholds.habitable_o2_partial:
			air = SuitRules.RoomState.HABITABLE
		else:
			air = SuitRules.RoomState.TOLERABLE
	var heat: SuitRules.RoomState = SuitRules.RoomState.UNKNOWN
	if thresholds.reads_heat and has_thermal_body:
		# harm_per_hour() rather than a threshold comparison written out again:
		# WI-60 pinned it and band() to agree to the degree about where danger
		# begins, and a second copy here is exactly how that agreement rots.
		if HeatMath.harm_per_hour(temp_f, thresholds.comfort) > 0.0:
			heat = SuitRules.RoomState.HARMFUL
		elif temp_f >= thresholds.comfort.habitable_low_f \
				and temp_f <= thresholds.comfort.habitable_high_f:
			heat = SuitRules.RoomState.HABITABLE
		else:
			heat = SuitRules.RoomState.TOLERABLE
	return _worse(air, heat)

## The worse of two readings, treating UNKNOWN as "no opinion" rather than as a
## severity of its own. Two UNKNOWNs stay UNKNOWN; anything else ignores them.
static func _worse(a: SuitRules.RoomState, b: SuitRules.RoomState) -> SuitRules.RoomState:
	if a == SuitRules.RoomState.UNKNOWN:
		return b
	if b == SuitRules.RoomState.UNKNOWN:
		return a
	return a if _severity(a) < _severity(b) else b

static func _severity(environment: SuitRules.RoomState) -> int:
	match environment:
		SuitRules.RoomState.HARMFUL:
			return 0
		SuitRules.RoomState.TOLERABLE:
			return 1
		SuitRules.RoomState.HABITABLE:
			return 2
	return 3

## Why a room is harmful, for the alert. NONE when it is not.
static func reason_for(o2_partial: float, temp_f: float, thresholds: SuitRules.Thresholds,
		has_atmosphere: bool, has_thermal_body: bool) -> SuitRules.Reason:
	# Air first: suffocation is faster than either temperature extreme, so when
	# both are true it is the one worth naming.
	if thresholds.reads_air and has_atmosphere and o2_partial < thresholds.damage_o2_partial:
		return Reason.NO_AIR
	if thresholds.reads_heat and has_thermal_body \
			and HeatMath.harm_per_hour(temp_f, thresholds.comfort) > 0.0:
		return Reason.TOO_COLD if temp_f < thresholds.comfort.dangerous_low_f else Reason.TOO_HOT
	return Reason.NONE

static func reason_text(reason: SuitRules.Reason) -> String:
	match reason:
		Reason.NO_AIR:
			return "no air"
		Reason.TOO_COLD:
			return "too cold"
		Reason.TOO_HOT:
			return "too hot"
	return ""

## What to do about this pawn's suit right now.
##
## The order of the branches IS the rule, and each one is load-bearing:
##
## 1. Conveyed pawns decide nothing - a turbolift ride nulls current_module, and
##    without this every ride would flip a helmet on and off.
## 2. Outside is always suited, at any tier, with no trip: EVA is the one place a
##    suit appears out of nowhere, because the alternative is a pawn dying in
##    vacuum while walking to an airlock they cannot reach.
## 3. Tier 1 is always suited, also with no trip. Tier 1 adds NO pawn behaviour
##    whatsoever - that is the entire point of the item.
## 4. The airlock entry case comes before the hold, because it is the one thing
##    that ends a hold early.
## 5. Harm beats everything below it: a pawn in a harmful room goes for a suit
##    even if one is already on the way for another reason.
static func decide(situation: SuitRules.Situation) -> SuitRules.Action:
	if situation.conveyed:
		return Action.NONE
	if situation.outside:
		return Action.NONE if situation.suited else Action.SUIT_UP_IN_PLACE
	if situation.suits_mandatory:
		return Action.NONE if situation.suited else Action.SUIT_UP_IN_PLACE
	if not situation.suited:
		if situation.environment == SuitRules.RoomState.HARMFUL:
			return Action.NONE if situation.trip_in_progress else Action.SUIT_UP
		return Action.NONE
	# Suited from here down.
	if situation.entered_airlock_from_outside \
			and situation.entry_airlock_environment == SuitRules.RoomState.HABITABLE:
		return Action.TAKE_OFF_IN_PLACE
	if situation.hold_remaining > 0.0 or situation.trip_cooldown > 0.0:
		return Action.NONE
	# Taking a suit off needs the pawn's OWN room to be fit, not merely the
	# airlock's. Otherwise a crew member working in a 25 F workshop walks to the
	# airlock, strips, walks back, and immediately leaves to re-suit - an
	# oscillation the player watches all day. Requiring the room they actually work
	# in to be habitable means the -10 persists exactly while that room is not,
	# which is the signal the player needs.
	if situation.environment != SuitRules.RoomState.HABITABLE:
		return Action.NONE
	return Action.NONE if situation.trip_in_progress else Action.TAKE_OFF

## Whether the "Spacesuit on inside" modifier applies.
##
## Inside, suited, and past Tier 1. It DOES apply while a hold keeps the suit on
## in a room that has since recovered: that crew member is wearing a suit indoors,
## and the brief's rule is about the suit rather than about why it is on.
static func mood_applies(suited: bool, outside: bool, suits_mandatory: bool) -> bool:
	return suited and not outside and not suits_mandatory

## The hold after meeting a harmful room: full every tick spent in one, counting
## down everywhere else.
##
## "Two hours past the LAST time they met a hostile interior" is the brief's
## wording, so this refreshes rather than only starting - and being outside does
## not refresh it, because space is not a hostile interior.
static func next_hold(current_hold: float, environment: SuitRules.RoomState, outside: bool,
		harm_hold_hours: float, elapsed_hours: float) -> float:
	if not outside and environment == SuitRules.RoomState.HARMFUL:
		return harm_hold_hours
	return maxf(0.0, current_hold - maxf(elapsed_hours, 0.0))
