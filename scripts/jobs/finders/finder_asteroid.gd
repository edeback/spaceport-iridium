class_name Finder_Asteroid
extends TargetFinder

## The next rock to fly out to (WI-44).
##
## Same three-tier preference the old mining job's get_asteroid() applied: a rock the
## player has designated wins outright, otherwise one carrying the bay's priority
## ore, otherwise whatever the shuffle turned up first. The shuffle is what stops
## every drone from a bay converging on the same asteroid.

## Slot holding the MiningComponent whose priority_ore steers the choice. An
## unset or non-mining slot just means no ore preference.
@export var bay_slot: JobTarget.Slot = JobTarget.Slot.B

func find(job: Job, pawn: PawnBase) -> JobTarget:
	var candidates: Array[Node] = pawn.get_tree().get_nodes_in_group(Groups.ASTEROID)
	candidates.shuffle()
	var priority_ore: ResourceData = _priority_ore(job)
	var ore_match: AsteroidBase = null
	var fallback: AsteroidBase = null
	for node: Node in candidates:
		var asteroid: AsteroidBase = node as AsteroidBase
		if asteroid == null or asteroid.is_empty():
			continue
		if asteroid.designated:
			return _target(asteroid)
		if ore_match == null and priority_ore != null and asteroid.has_ore(priority_ore):
			ore_match = asteroid
		if fallback == null:
			fallback = asteroid
	var chosen: AsteroidBase = ore_match if ore_match != null else fallback
	return _target(chosen) if chosen != null else null

func describe() -> String:
	return "an asteroid"

## Deliberately survivable. An asteroid that empties out mid-trip despawns, and
## the mining driver's answer to that is to come back here for another one - so
## losing it must not fail the job the way a lost storage or bay does.
func _target(asteroid: AsteroidBase) -> JobTarget:
	var target: JobTarget = JobTarget.of_asteroid(asteroid)
	target.fail_on_lost = false
	return target

func _priority_ore(job: Job) -> ResourceData:
	var bay: JobTarget = job.target(bay_slot)
	if bay == null or not bay.is_alive():
		return null
	var mining: MiningComponent = bay.component() as MiningComponent
	return mining.priority_ore if mining != null else null
