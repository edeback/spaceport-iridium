class_name StorageQuery

## The one place that answers "which bin should this haul use?" (WI-40).
##
## Every job that needs to pick a storage - pull a resource, push a resource,
## collect a pile, sweep carried cargo - goes through find_source() or
## find_sink() here. They used to be four near-identical walks in three files,
## which is exactly how the cargo sweep's scoring silently drifted away
## from the haul job's (WI-38 A5). Two queries, one set of rules.
##
## Both queries are pure - no reservations, no mutation - so can_do_job() can
## call them freely.
##
## Next step, deliberately NOT done here: both walks scan the
## "resource_storage" group. ResourceData.registered_storage already indexes
## storage per resource and is maintained symmetrically by
## StorageComponent.register_component/unregister_component, so swapping the
## group scan for that index is now a two-line change in one file. It is a
## behavior-risk change though (registration timing and group-membership
## timing are not the same), so it wants its own work item and its own
## verification pass.

## Sentinel meaning "no priority floor/ceiling" - a pile or a carried-cargo
## sweep has no priority of its own to compare against, so it must accept any
## bin that will take the goods. Checked explicitly rather than relied on
## numerically, because the two filters point in opposite directions.
const ANY_PRIORITY: int = -0x7FFFFFFF

# --- queries ------------------------------------------------------------------

## Picks a reachable source of `resource` to withdraw from. Prefers a single
## source that can fill the whole trip (nearest of those); if none can, falls
## back to whichever has the most stock, so each trip empties as much as
## possible rather than the least.
##
## `below_priority` is the sink this material is headed for. The filter is
## *strict* (a source must sit strictly below its destination): equal-priority
## endpoints would let a haul flip-flop between two bins forever, each move
## re-posting the job in the opposite direction. Pass ANY_PRIORITY only when
## there genuinely is no destination priority to compare against.
static func find_source(pawn: PawnBase, resource: ResourceData, trip_cap: int,
		below_priority: int = ANY_PRIORITY) -> StorageComponent:
	if pawn == null or resource == null:
		return null
	var pawn_cell: Vector2i = Global.world_to_cell(pawn.global_position)
	var scorer := SourceScorer.new(trip_cap)
	var best: StorageComponent = null
	for node: Node in pawn.get_tree().get_nodes_in_group(Groups.RESOURCE_STORAGE):
		var storage: StorageComponent = node as StorageComponent
		# Null check: anything ever added to the group that isn't a
		# StorageComponent would otherwise be a nil-access crash here.
		if storage == null:
			continue
		# Per-resource since WI-65: one component can refuse to export iron ore
		# (it is an ingredient there) while exporting iron (it is a product).
		var source_priority: int = storage.export_priority(resource)
		# REFUSED is checked BEFORE the comparison, never as an extreme number -
		# ANY_PRIORITY skips the comparison entirely, so a refusal folded into the
		# number would be silently ignored on exactly the pile/sweep paths.
		if source_priority == StorageComponent.REFUSED:
			continue
		if below_priority != ANY_PRIORITY and source_priority >= below_priority:
			continue
		var available: int = storage.total_stored_by_resource(resource)
		if available <= 0:
			continue
		# Reachability last: it's O(1) via subgraph ids, but still the most
		# expensive test here, so let the cheap rejects run first.
		if not Global.path_manager.is_reachable(pawn, storage.owner_module):
			continue
		var dist: int = storage.owner_module.module_cell.distance_squared_to(pawn_cell)
		if scorer.offer(available, dist):
			best = storage
	return best

## Picks a reachable sink that will take `resource`. Highest priority first,
## nearest among equals - storage priority is the routing language, so a
## delivery has to move "uphill" toward the material's eventual home rather
## than into whatever bin happens to be closest (which can be a deconstruction
## site's -99 export bin, hauled straight back out again next tick).
##
## `above_priority` is the source bin, and is strict for the same
## anti-flip-flop reason as find_source(). A pile and a carried-cargo sweep
## pass ANY_PRIORITY deliberately: they have no source bin, and a pawn holding
## goods must accept *any* bin that will take them rather than strand itself.
## PawnBase.start_job() depends on null here meaning "nowhere will take this"
## so it can fall through to a normal job.
static func find_sink(pawn: PawnBase, resource: ResourceData,
		above_priority: int = ANY_PRIORITY) -> StorageComponent:
	if pawn == null or resource == null:
		return null
	var pawn_cell: Vector2i = Global.world_to_cell(pawn.global_position)
	var scorer := SinkScorer.new()
	var best: StorageComponent = null
	for node: Node in pawn.get_tree().get_nodes_in_group(Groups.RESOURCE_STORAGE):
		var storage: StorageComponent = node as StorageComponent
		if storage == null:
			continue
		var sink_priority: int = storage.import_priority(resource)
		# Same rule as find_source: refusal first, comparison second.
		if sink_priority == StorageComponent.REFUSED:
			continue
		if above_priority != ANY_PRIORITY and sink_priority <= above_priority:
			continue
		# Probes with 1 unit, not the full load, on purpose: a bin with only
		# partial room is still a valid target - whatever doesn't fit stays on
		# the pawn and gets swept next tick.
		if not storage.can_deposit(resource, 1):
			continue
		if not Global.path_manager.is_reachable(pawn, storage.owner_module):
			continue
		var dist: int = storage.owner_module.module_cell.distance_squared_to(pawn_cell)
		if scorer.offer(sink_priority, dist):
			best = storage
	return best

## How much of `desired` this pawn can actually carry in one trip. Only the
## source query needs it (the amount narrows what counts as "fills the trip"),
## and robots/pawns without an inventory component are not a given - hence one
## null guard, here, rather than one per caller.
static func trip_cap(pawn: PawnBase, desired: int) -> int:
	if pawn == null or pawn.inventory_component == null:
		return desired
	return mini(desired, pawn.inventory_component.space_available())

# --- pure scoring rules -------------------------------------------------------
#
# The walks above can't be unit-tested (they read Global.path_manager and
# Global.world_to_cell), but the comparisons are where the drift actually
# happened, so those live down here as pure statics and pure accumulators that
# a GUT suite can drive with synthetic candidates.

## Higher priority always wins; distance only breaks a priority tie. Strictly
## greater / strictly nearer, so on a full tie the *first* candidate scanned
## keeps the slot.
static func sink_beats(cand_priority: int, cand_dist: int, best_priority: int, best_dist: int) -> bool:
	return cand_priority > best_priority \
		or (cand_priority == best_priority and cand_dist < best_dist)

## Among sources that can't fill the trip on their own: most stock wins,
## distance breaks the tie. Same strictness rule as sink_beats().
static func source_beats_partial(cand_amount: int, cand_dist: int, best_amount: int, best_dist: int) -> bool:
	return cand_amount > best_amount \
		or (cand_amount == best_amount and cand_dist < best_dist)

## Accumulates the best sink seen so far. offer() returns true when the
## candidate just offered has become the overall best, which is the walk's cue
## to remember the component alongside it.
class SinkScorer:
	var has_best: bool = false
	var best_priority: int = 0
	var best_dist: int = 0

	func offer(priority: int, dist: int) -> bool:
		if has_best and not StorageQuery.sink_beats(priority, dist, best_priority, best_dist):
			return false
		has_best = true
		best_priority = priority
		best_dist = dist
		return true

## Accumulates the best source seen so far, tracking the two tiers separately:
## any candidate that can fill the whole trip outranks every partial one, no
## matter how much stock the partial holds or how close it is. Within a tier
## the usual rules apply (nearest for full, most-stock-then-nearest for
## partial). offer() returns true only when the *overall* winner changed - a
## partial that beats other partials while a full source exists updates the
## partial tier silently and returns false.
class SourceScorer:
	var trip_cap: int
	var has_full: bool = false
	var best_full_dist: int = 0
	var has_partial: bool = false
	var best_partial_amount: int = 0
	var best_partial_dist: int = 0

	func _init(cap: int) -> void:
		trip_cap = cap

	func offer(amount: int, dist: int) -> bool:
		if amount >= trip_cap:
			if has_full and dist >= best_full_dist:
				return false
			has_full = true
			best_full_dist = dist
			# First full source displaces whatever partial was winning; a
			# nearer full source displaces the previous full one. Either way
			# it's the new overall best.
			return true
		if has_partial and not StorageQuery.source_beats_partial(amount, dist, best_partial_amount, best_partial_dist):
			return false
		has_partial = true
		best_partial_amount = amount
		best_partial_dist = dist
		# A partial can only be the overall best while no full source exists.
		return not has_full
