class_name TierData
extends Resource

## One station tier (WI-26). Authored as a .tres under res://data/tiers/, one per
## tier, scanned by UnlockManager via ResourceScanner. Definition only - the
## current tier and per-goal export progress are runtime state on UnlockManager,
## never written back onto this shared resource.
##
## A tier's export_goals and inspection_tags describe what must be met to advance
## FROM this tier to the next: the station works toward the CURRENT tier's goals,
## and on tier-up progress resets to the new tier's. The final (max) tier carries
## empty goals - it's the cap, nothing to advance to.

## Which tier this is (1..N). Must match the file's position in the ladder; the
## manager keys tiers by this number.
@export var tier: int = 1
@export var display_name: String = ""
@export_multiline var flavor: String = ""

## Units of each resource that must physically leave the station (trader sells +
## contract deliveries, tracked via SignalBus.resources_exported) before an ARC
## inspection can be requested. Keyed by resource id (matching the .tres stem) so
## the tier file needs no ext_resource references and progress round-trips as
## plain ids. Empty on the cap tier.
@export var export_goals: Dictionary[StringName, int] = {}

## Whether crew live in pressure suits at this tier (WI-67).
##
## True only on Tier 1, where it does three things at once: crew are suited
## everywhere and feel ideal air and temperature, the low-O2 alert and the OXYGEN
## chip's amber stay quiet, and hull breaches cannot fire. The point is that a new
## player is not asked to run life support and thermals on day one.
##
## Data rather than a `current_tier < 2` test in code, for the WI-26 reason: what a
## tier IS lives in its .tres, so a mod reshaping the ladder decides where the
## suits come off. Read it through UnlockManager.suits_mandatory(), which is the
## one accessor every consumer shares.
@export var suits_mandatory: bool = false

## Module *tags* the inspector must visit, one built instance of each (tags
## already live on ModuleData - "Industrial", "Crew", "Power", "Dock", ...). The
## station must hold at least one built module per tag before goals count as met,
## so accepting an inspection can't instant-fail on a missing facility.
@export var inspection_tags: Array[String] = []

## Modules licensed the moment the station reaches this tier (2026-10-02): no
## research node, no cost. Each should be authored `unlocked_by_default = false`,
## or the grant has nothing to unlock (`test_station_tiers.gd` sweeps for that).
##
## A promotion is the one thing every station does, so this is where a module
## the whole ladder expects belongs. A module the player may *choose* to buy
## stays an [UnlockData] with a [GrantModuleEffect].
##
## Derived, never saved: [UnlockManager] re-grants every tier at or below the
## saved one on load, the way it re-runs an owned unlock's effects.
@export var granted_modules: Array[ModuleData] = []

## True on the highest tier: no further advancement, goals ignored.
func is_max_goal() -> bool:
	return export_goals.is_empty() and inspection_tags.is_empty()

## Pure goal check (WI-26), extracted so it's unit-testable without Global:
## every export goal reached in `export_progress` (resource id -> units), and
## every checklist tag has at least one built module in `tag_counts` (tag ->
## count). Vacuously false on the cap tier (nothing left to reach).
func goals_reached(export_progress: Dictionary, tag_counts: Dictionary) -> bool:
	if is_max_goal():
		return false
	for resource_id: StringName in export_goals:
		if int(export_progress.get(resource_id, 0)) < export_goals[resource_id]:
			return false
	for tag: String in inspection_tags:
		if int(tag_counts.get(tag, 0)) <= 0:
			return false
	return true

## Every module licensed by a tier at or below `tier` - what a station at that
## tier holds by right, so a load can rebuild it from the tier number alone.
## Pure, so it's unit-testable without Global. Ladder order, each module once;
## null entries (in the ladder or in a tier's list) are skipped.
static func modules_granted_through(tiers: Array[TierData], tier: int) -> Array[ModuleData]:
	var ladder: Array[TierData] = []
	for data: TierData in tiers:
		if data != null and data.tier <= tier:
			ladder.append(data)
	ladder.sort_custom(func(a: TierData, b: TierData) -> bool: return a.tier < b.tier)
	var out: Array[ModuleData] = []
	for data: TierData in ladder:
		for module: ModuleData in data.granted_modules:
			if module != null and not out.has(module):
				out.append(module)
	return out
