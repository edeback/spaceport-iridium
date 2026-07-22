class_name Groups

## Every SceneTree group name the game uses, in one place (WI-41).
##
## Groups are the one contract in this codebase that was invisible: a joiner in
## one file and a scanner in another, tied together by a bare string literal
## that nothing checks. A misspelling on either side is silent - the group just
## comes back empty and the feature looks broken rather than typo'd. These
## constants make the surface greppable and make the typo a parse error.
##
## Constants only, deliberately. No Groups.has(), no join/scan wrappers - the
## SceneTree group API is fine, it was only ever the names that were the
## problem.
##
## Constant names mirror their string values exactly, so a grep for either the
## constant or the raw name finds every site.
##
## Not covered here, because they are a different namespace that happens to
## also be called "groups": ModuleGraph vertex groups (turboshaft_N,
## "teleporters"), which are keys into PathManager's graph, not the SceneTree.

# --- world & structure --------------------------------------------------------

## Joined by ModuleBase for every module including previews and blueprints;
## scanners that only want finished modules must filter on is_complete().
const MODULE: StringName = &"module"

const ASTEROID: StringName = &"asteroid"

## Also authored scene-side: module_airlock_left.tscn and
## module_airlock_right.tscn carry it in ModuleBase.add_to_groups, where the
## editor stores it as a plain string this constant cannot reach. Renaming here
## means renaming there too.
const AIRLOCK: StringName = &"airlock"

# The next three are joined but nothing scans them (WI-41 surfaced this). Kept
# as-is rather than deleted, since the joins are free and a "which transport
# modules exist?" scan is the obvious future reader.

const TURBOLIFTS: StringName = &"turbolifts"

## Distinct from the ModuleGraph vertex group of the same name that
## ModuleTeleporter.make_connections uses for pathing - same word, different
## namespace, on purpose.
const TELEPORTERS: StringName = &"teleporters"

const STAIRS: StringName = &"stairs"

# --- pawns --------------------------------------------------------------------

## Every PawnBase: crew, robots, visitors, and the runtime-only inspector.
## Scanners that mean "crew" must filter (is_visitor, RobotPawnBase).
const PAWN: StringName = &"pawn"

# --- storage & logistics ------------------------------------------------------

## StorageComponent joins/leaves this as accepts_exports flips, so membership
## is not the same as "has a StorageComponent". Read it through StorageQuery.
const RESOURCE_STORAGE: StringName = &"resource_storage"

## Loose ResourcePiles on the floor. Left on pile depletion, so membership
## tracks "still collectable".
const RESOURCE_DEBRIS: StringName = &"resource_debris"

## Joined by ProcessorComponent and MiningComponent. Nothing scans it today
## (WI-41); both systems are reached through their owning module instead.
const PROCESSOR: StringName = &"processor"

# --- needs providers ----------------------------------------------------------
#
# One group per provider component, each scanned by the job that consumes it
# (and by CrewManager, which reads bunk capacity off SLEEP_COMPONENT to gate
# hiring). Slot-holding providers are all in here, so an empty group is the
# same as "this station has no such facility yet".

const SLEEP_COMPONENT: StringName = &"sleep_component"
const SUSTENANCE_COMPONENT: StringName = &"sustenance_component"
const RECREATION_PROVIDER: StringName = &"recreation_provider"
const CREW_RECRUITMENT: StringName = &"crew_recruitment"
const SHOP: StringName = &"shop"
const MEDICAL_BAY: StringName = &"medical_bay"
const ROBOT_REPAIR: StringName = &"robot_repair"
const RECHARGER: StringName = &"recharger"

# --- combat -------------------------------------------------------------------

## RaidManager owns the authoritative live ship array; this group exists for
## the scanners that predate it (see C10).
const PIRATE_SHIP: StringName = &"pirate_ship"

const SHIELD: StringName = &"shield"

# --- UI -----------------------------------------------------------------------

## Anything that should draw as a ship marker on the minimap - pirate raiders
## and the arrival shuttle. Joined by the object itself, not by the minimap.
const MINIMAP_TRACKED: StringName = &"minimap_tracked"

## Gameplay AnimatedSprite2Ds whose playback tracks sim speed (WI-20), resynced
## on every speed/pause change. UI animation must never join this group - it
## stays real-time. Joined through TimeManager.sync_animation rather than
## directly; the most likely group to get hand-added to a .tscn later, which
## would bypass that helper's initial speed_scale.
const SIM_ANIMATION: StringName = &"sim_animation"
