class_name Cheats
extends RefCounted

## Playtest/dev cheat surface (WI-19). Installed by Main as Global.cheats and
## registered with the Panku REPL, so every Phase 3 work item can be exercised
## from the console (`Global.cheats.<method>(...)`) without playing up to the
## state under test first.
##
## Design rules:
##   - Every method is fully typed and returns a human-readable result string so
##     the REPL echoes success/failure.
##   - Every call routes through _report(), which fires a "CHEAT: ..."
##     station_alert - a save touched by cheats is self-documenting, and the
##     alert strip shows what happened even when the REPL output scrolls away.
##   - No cheat state is saved; these only nudge existing managers.

## Emits the guard-rail alert and returns the message for the REPL echo.
func _report(message: String) -> String:
	SignalBus.station_alert.emit("CHEAT: " + message)
	return message

# --- resources & pawns --------------------------------------------------------

## Drops `amount` of resource `id` at `cell`. If a module there has storage with
## room it goes into the bin; otherwise it lands as a ResourcePile (owned by the
## module at the cell so crew can haul it, or free-floating in open space).
func spawn_resource(id: StringName, amount: int, cell: Vector2i) -> String:
	if amount <= 0:
		return _report("spawn_resource needs a positive amount")
	var resource: ResourceData = Global.save_manager.get_resource_by_id(id)
	if resource == null:
		return _report("no such resource id: %s" % id)
	var world: WorldManager = Global.world_manager
	var module: ModuleBase = world.get_module_by_cell(WorldManager.StructureLayer.MODULE, cell)
	if module != null:
		var storage: StorageComponent = module.get_component_by_type(StorageComponent) as StorageComponent
		if storage != null and storage.accepts_imports and storage.deposit(resource, amount, true):
			return _report("added %d %s to storage at %s" % [amount, resource.name, cell])
	var pile: ResourcePile = ResourcePile.spawn(world.pawn_layer, Global.cell_to_world(cell, true), module)
	pile.add_amount(resource, amount)
	return _report("spawned a pile of %d %s at %s" % [amount, resource.name, cell])

## Spawns one crew pawn at the module on `cell` (or the nearest built module).
func spawn_pawn(cell: Vector2i) -> String:
	var module: ModuleBase = _module_at_or_near(cell)
	if module == null:
		return _report("spawn_pawn found no module to spawn at")
	Global.crew_manager.spawn_crew(module)
	return _report("spawned a crew pawn at %s" % module.module_cell)

# --- economy & unlocks --------------------------------------------------------

## Adds (or, negative, removes) credits from the global store.
func add_credits(amount: int) -> String:
	Global.resource_manager.credit_resource.change_global_total(amount)
	return _report("adjusted credits by %d (now %d)" %
		[amount, Global.resource_manager.credit_resource.get_total()])

## Force-unlocks the global tech-tree node with the given id (no cost/prereqs).
func force_unlock(id: StringName) -> String:
	var unlock: UnlockData = Global.unlock_manager.get_unlock_by_id(id)
	if unlock == null:
		return _report("no such unlock id: %s" % id)
	Global.unlock_manager.force_unlock(unlock)
	return _report("unlocked %s" % id)

## Force-unlocks every known global unlock.
func unlock_all() -> String:
	var count: int = 0
	for unlock: UnlockData in Global.unlock_manager.get_all_unlocks():
		if unlock != null and not Global.unlock_manager.is_unlocked(unlock):
			Global.unlock_manager.force_unlock(unlock)
			count += 1
	return _report("unlocked %d remaining tech node(s)" % count)

# --- time ---------------------------------------------------------------------

## Sets the simulation speed multiplier (0 pauses gameplay; UI stays real-time).
func set_time_speed(speed: float) -> String:
	Global.time_manager.speed = speed
	return _report("time speed set to %sx" % speed)

## Jumps the calendar forward `hours` game-hours (fires hour/cycle signals).
func advance_hours(hours: int) -> String:
	Global.time_manager.advance_hours(hours)
	return _report("advanced %d hour(s) -> %s" % [hours, Global.time_manager.format_time()])

# --- events & contracts -------------------------------------------------------

## Fires the event with the given id now, ignoring pacing/cooldowns/conditions.
func fire_event(id: StringName) -> String:
	if Global.event_manager.fire_event_by_id(id):
		return _report("fired event %s" % id)
	return _report("no such event id: %s" % id)

## Rolls one contract offer scaled to current station stores.
func offer_contract() -> String:
	var contract: ContractData = Global.contract_manager.generate_offer(0.0)
	if contract == null:
		return _report("nothing stored worth contracting")
	return _report("offered contract: %d %s by cycle %d" %
		[contract.amount, contract.resource.name, contract.deadline_cycle])

# --- helpers ------------------------------------------------------------------

## The module on `cell` (MODULE layer), or the nearest module by cell distance.
func _module_at_or_near(cell: Vector2i) -> ModuleBase:
	var world: WorldManager = Global.world_manager
	var exact: ModuleBase = world.get_module_by_cell(WorldManager.StructureLayer.MODULE, cell)
	if exact != null:
		return exact
	var best: ModuleBase = null
	var best_dist: int = -1
	for node: Node in world.get_tree().get_nodes_in_group("module"):
		var module: ModuleBase = node as ModuleBase
		if module == null:
			continue
		var dist: int = module.module_cell.distance_squared_to(cell)
		if best == null or dist < best_dist:
			best = module
			best_dist = dist
	return best
