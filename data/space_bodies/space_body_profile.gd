class_name SpaceBodyProfile
extends Resource

## One kind of mineable body and every knob that makes it different from the
## others (WI-61). The asteroid belt is one of these; a comet is another.
##
## Before this, all of it lived as @exports on the AsteroidManager node in
## main.tscn. A second spawn track would have doubled that list and put two
## bodies' balance in a scene file, against the standing rule that balance lives
## in .tres - so the per-track knobs became data and the manager kept only what
## is genuinely global (the ore pool, the belt markers, the layer).
##
## Discovered by scan (ContentPaths.SPACE_BODIES), not registered: a mod adds its
## own kind of body by dropping a .tres, with no core edit (the WI-47 bar).
##
## Rolling lives here where it is pure, so it can be unit-tested without a
## manager; anything needing Global (the belt's ore pool, the SceneTree) stays on
## AsteroidManager.

## How a body gets from its spawn point to its despawn point.
enum Trajectory {
	## The original asteroid belt: a jittered line between two authored markers,
	## despawning a fixed distance from the start marker.
	BELT,
	## Straight across the play area from well outside the station to well
	## outside on the far side. See [SpaceGeometry.crossing].
	CROSSING,
}

## How a body's contents are rolled.
enum MixMode {
	## The belt's rule: 1-3 distinct ores drawn without replacement from the
	## station's global ore pool, weighted so rare ores stay rare. Reads
	## AsteroidManager's pool, which is why this mode's inputs are not here.
	WEIGHTED_PICK,
	## An authored list, each row with its own appearance chance. See [BodyOreEntry].
	FIXED_LIST,
}

## Stable id. Saved on every body so a load rebuilds it from the right profile,
## and the key the manager tracks population and spawn cadence under.
@export var id: StringName = &""
## The player-facing noun. One place a body becomes a word: the inspector's
## header caption and its subject name both read this through
## [member AsteroidBase.body_name].
@export var display_name: String = "Asteroid"
## Falls back to AsteroidManager.asteroid_scene when null.
@export var scene: PackedScene

# --- population ---------------------------------------------------------------

## How many of this kind may exist at once.
@export var max_population: int = 1
## Game-hours between spawns, rolled fresh after each one. A flat range (min ==
## max) reproduces a fixed cadence; a wide one is what gives comets real gaps at
## zero rather than sitting permanently at the cap.
@export var spawn_gap_hours: Vector2 = Vector2(0.5, 0.5)

# --- movement -----------------------------------------------------------------

## Pixels per sim-second. Keep this well under [member PawnBase.speed] (80):
## mining drones chase a moving target, and a body outrunning a meaningful
## fraction of that turns every trip into a stern chase.
@export var speed_range: Vector2 = Vector2(10.0, 30.0)
@export var trajectory: Trajectory = Trajectory.BELT

## BELT: how far from the belt's start marker a body drifts before it is gone.
@export var belt_despawn_distance: float = 2000.0
## BELT: how far a body's spawn and aim points are jittered off the markers.
@export var belt_jitter: float = 200.0

## CROSSING: band of px beyond the station's bounds to appear at.
@export var entry_margin: Vector2 = Vector2(600.0, 1200.0)
## CROSSING: px past the far side before the body despawns.
@export var exit_margin: float = 600.0
## CROSSING: how far off-centre a crossing may aim, as a fraction of the
## station's half-extent. 0 = always through the middle.
@export var lateral_spread: float = 0.9

# --- contents -----------------------------------------------------------------

@export var mix_mode: MixMode = MixMode.WEIGHTED_PICK
## WEIGHTED_PICK: how many distinct ore types one body carries (min, max),
## clamped to the size of the available pool.
@export var weighted_type_count: Vector2i = Vector2i(1, 3)
## FIXED_LIST: the authored rows.
@export var fixed_ores: Array[BodyOreEntry] = []

## Band that per-body richness centres are drawn from.
@export var richness_band: Vector2 = Vector2(0.15, 1.0)
## Half-width of one body's richness range around its rolled centre.
@export var richness_spread: float = 0.1
## Exponent skewing centres toward the poor end; > 1 makes rich bodies rarer.
@export var richness_skew: float = 1.6

# --- presentation -------------------------------------------------------------

## Dust bloom for this kind's break-up puff. Fully transparent (the default)
## leaves [AsteroidDispersal]'s own colour, so there is exactly one place the
## default grey-brown is written down.
@export var dispersal_dust: Color = Color(0.0, 0.0, 0.0, 0.0)

# --- rolling ------------------------------------------------------------------

## One body's ore mix, for FIXED_LIST profiles. Empty for any other mode (the
## belt's roll needs the manager's pool) and empty when every row's chance
## failed - both of which leave the body's authored scene mix in place, which is
## the same fallback spawn_asteroid has always had.
func roll_fixed_mix() -> Dictionary[ResourceData, float]:
	var mix: Dictionary[ResourceData, float] = {}
	if mix_mode != MixMode.FIXED_LIST:
		return mix
	for entry: BodyOreEntry in fixed_ores:
		if entry == null or entry.resource == null or entry.weight <= 0.0:
			continue
		if randf() > entry.chance:
			continue
		mix[entry.resource] = entry.weight
	return mix

## One body's richness range, drawn from this profile's band.
func roll_richness_range() -> Vector2:
	var centre: float = lerpf(richness_band.x, richness_band.y, pow(randf(), richness_skew))
	return Vector2(clampf(centre - richness_spread, 0.0, 1.0),
			clampf(centre + richness_spread, 0.0, 1.0))

## One body's speed, in px per sim-second.
func roll_speed() -> float:
	return randf_range(speed_range.x, speed_range.y)

## Sim-seconds until the next spawn attempt of this kind.
func roll_spawn_gap_seconds() -> float:
	return randf_range(spawn_gap_hours.x, spawn_gap_hours.y) * TimeManager.SECONDS_PER_HOUR

## Every resource a body of this kind could ever yield, for the FIXED_LIST case.
## Feeds AsteroidManager.spawnable_yields(), which is what stops a comet-only
## resource being unpickable as a mining bay's priority ore.
func declared_yields() -> Array[ResourceData]:
	var out: Array[ResourceData] = []
	for entry: BodyOreEntry in fixed_ores:
		if entry != null and entry.resource != null and not out.has(entry.resource):
			out.append(entry.resource)
	return out
