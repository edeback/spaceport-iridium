class_name Stats

## Every tunable stat key a module's [StatModifiers] layer understands, in one
## place (WI-72, F30).
##
## A stat name is a contract between three parties that never meet: an authored
## upgrade ([StatModifierSpec] in a local upgrade, [StatModifierEffect] in a
## global one) writes it, [ModuleBase]'s damage/breakdown/adjacency/heat layers
## write it, and a component reads it back through
## [method ModuleBase.get_effective_stat]. Nothing joined the three up. A typo in
## an authored `.tres` bought an upgrade that cost credits and did **nothing** -
## no error, no warning, no visible difference - because [StatModifiers] is a
## plain dictionary and an unread key is just a key nobody asked for.
##
## Same argument as [Groups], [UIType], [StoryFlags] and [TutorialTriggers], and
## the same shape: constants only, no registry, no wrappers. It was never the
## mechanism that was wrong, only that the names were invisible.
##
## Constant names mirror their string values exactly, so a grep for either finds
## every site. `tests/unit/test_stat_content.gd` holds the three rules: every
## authored stat is declared, every declared stat is actually read by something,
## and nothing names one as a bare literal any more.
##
## MODS: a mod may use a stat that is not here. Its own component reads it and
## its own upgrade writes it, and both work - [UnlockManager] only
## [method push_warning]s once so the log says what it saw. The alternative, a
## registration call, would be a step to forget for no gain; see WI-72 §0.3.

# --- machinery: processors, mining, power, pathing, breakdowns -----------------
#
# The five [ModuleBase] itself writes. Damage scales the first four by hp
# fraction and breakdowns by a flat multiplier (both MULT, on their own named
# sources so they clear independently); a nearby Maintenance Facility's
# adjacency field suppresses the fifth. Anything new that these layers should
# scale has to be added at their write sites as well as here.

## Seconds one recipe batch takes. INVERSE: a MULT below 1 means faster, which is
## why damage and breakdowns write `1.0 / efficiency` against it rather than
## `efficiency`. Also the key WI-60's heat throttle slows a hot module with.
const PROCESS_TIME: StringName = &"process_time"

## Extraction-rate multiplier on a mining bay, 1.0 base.
const MINING_RATE: StringName = &"mining_rate"

## Power a generator contributes to the grid.
const POWER_OUTPUT: StringName = &"power_output"

## Multiplier on how fast a pawn crosses this module's interior.
const TRAVERSAL_SPEED_MULT: StringName = &"traversal_speed_mult"

## Per-game-hour probability that a module with `can_break_down` breaks.
const BREAKDOWN_CHANCE: StringName = &"breakdown_chance"

# --- heat (WI-60) -------------------------------------------------------------

## Waste heat a module emits per batch-fraction of work done. Declared with the
## rest although no shipped upgrade targets it yet: it is read through
## [method ModuleBase.get_effective_stat] like every other key, which is the
## whole of what makes it upgradeable.
const HEAT_OUTPUT: StringName = &"heat_output"

# --- life support -------------------------------------------------------------

## CO2 a scrubber removes per game-hour.
const SCRUB_RATE: StringName = &"scrub_rate"

## O2 an oxygen generator releases per game-hour.
const O2_RELEASE_RATE: StringName = &"o2_release_rate"

# --- shields (WI-32) ----------------------------------------------------------

## Radius in pixels of the bubble a shield generator covers.
const SHIELD_RADIUS: StringName = &"shield_radius"

## Shield points regained per game-hour.
const SHIELD_CHARGE_RATE: StringName = &"shield_charge_rate"

## Shield points the bubble holds when full.
const SHIELD_CAPACITY: StringName = &"shield_capacity"

# --- weapons (WI-32) ----------------------------------------------------------
#
# These three reach the modifier layer through WeaponComponent's one-line `_stat`
# helper rather than naming get_effective_stat at each site, which is exactly why
# WI-72's first census missed them: they were invisible to a grep for the call.
# The sweep looks for the constant instead, so a future helper cannot hide a stat
# the same way.

## Damage one shot deals to the ship it hits.
const WEAPON_DAMAGE: StringName = &"weapon_damage"

## Seconds between shots. INVERSE, like [constant PROCESS_TIME]: lower is faster.
const WEAPON_FIRE_INTERVAL: StringName = &"weapon_fire_interval"

## Range in pixels at which a turret will engage.
const WEAPON_RANGE: StringName = &"weapon_range"

# --- crew and commerce --------------------------------------------------------

## How well a bunk restores the rest need.
const SLEEP_QUALITY: StringName = &"sleep_quality"

## Credits a visitor pays for a night in a hotel room (WI-33). Rounded to a whole
## credit at the register, so a MULT that moves it by less than half a credit
## buys nothing - balance it with that in mind.
const HOTEL_RATE: StringName = &"hotel_rate"

## Mood a visitor gains from a night's stay.
const HOTEL_MOOD: StringName = &"hotel_mood"

# --- logistics (WI-27) --------------------------------------------------------

## Movement speed handed to a hauler robot when a logistics bay builds it.
const ROBOT_SPEED: StringName = &"robot_speed"

## Units a hauler robot carries per trip.
const ROBOT_CAPACITY: StringName = &"robot_capacity"

## How many robots one logistics bay may run at once. Read as an int, so the
## same rounding caveat as [constant HOTEL_RATE] applies.
const LOGISTICS_MAX_ROBOTS: StringName = &"logistics_max_robots"

## Parallel lanes a conveyor moves stacks along. Also read as an int.
const CONVEYOR_LANES: StringName = &"conveyor_lanes"

# --- the vocabulary -----------------------------------------------------------

## Every stat the base game declares. Order is the order above, which is the
## order a reader meets them in; nothing depends on it.
const DECLARED: Array[StringName] = [
	PROCESS_TIME, MINING_RATE, POWER_OUTPUT, TRAVERSAL_SPEED_MULT, BREAKDOWN_CHANCE,
	HEAT_OUTPUT,
	SCRUB_RATE, O2_RELEASE_RATE,
	SHIELD_RADIUS, SHIELD_CHARGE_RATE, SHIELD_CAPACITY,
	WEAPON_DAMAGE, WEAPON_FIRE_INTERVAL, WEAPON_RANGE,
	SLEEP_QUALITY, HOTEL_RATE, HOTEL_MOOD,
	ROBOT_SPEED, ROBOT_CAPACITY, LOGISTICS_MAX_ROBOTS, CONVEYOR_LANES,
]

## Stats already warned about, so a mod's own key costs one line in the log
## rather than one per authored upgrade that names it. Static because the content
## scan runs once per [UnlockManager], and a Quit to Menu followed by a New Game
## is the same content being read a second time, not a new thing to report.
static var _warned: Dictionary[StringName, bool] = {}

## True when `stat` is part of the base game's vocabulary.
static func is_declared(stat: StringName) -> bool:
	return DECLARED.has(stat)

## The runtime half of the rule (WI-72 §0.3): an undeclared stat still works, and
## says so once. A vanilla typo is caught by `test_stat_content.gd` long before
## this fires, so anything that reaches here is either a mod's own key - fine, and
## the warning is the only way to tell it apart from a typo - or a `.tres` that
## was edited after the suite last ran.
##
## [param where] names the authored file, because the stat name alone does not say
## which upgrade to go and fix.
static func warn_if_undeclared(stat: StringName, where: String) -> void:
	if stat == &"" or is_declared(stat) or _warned.has(stat):
		return
	_warned[stat] = true
	push_warning(("Stats: '%s' is not a declared stat (%s). It will still apply, but"
		+ " nothing in the base game reads it - check for a typo.") % [stat, where])

## Forgets what has been warned about. For tests only; the game has no reason to
## re-report a key it has already reported.
static func clear_warnings_for_test() -> void:
	_warned.clear()

## What has been reported so far, for tests. The suite's real assertion is that
## running the shipped content through this path reports NOTHING.
static func has_warned_for_test() -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(_warned.keys())
	return out
