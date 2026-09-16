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
