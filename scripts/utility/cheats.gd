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

# --- modules ------------------------------------------------------------------

## Set "build anything" debug setting - true allows skipping placement checks
## and insta-building the module
func set_build_anything(value: bool) -> String:
	Global.world_manager.debug_build_anything = value
	return _report("Set build_anything: %s" % str(value))

## Force-build a module 'id' at 'cell' without cost and without needing construction
## 'flipped' only matters for modules that can be placed multiple ways (docking bay and airlock)
func build_module(id: StringName, cell: Vector2i, flipped: bool) -> String:
	var module_data := Global.save_manager.get_module_data_by_id(id)
	if module_data != null:
		Global.world_manager.add_module(module_data, cell, false, flipped, true)
		return _report("built module %s at %s" % [id, cell])
	return _report("Could not find module with id: %" % id)

## Deals `amount` HP of damage to the built module at `cell` (WI-24). At 0 HP a
## normal module is destroyed (truss replaces it); a truss becomes wreckage.
func damage_module(cell: Vector2i, amount: float) -> String:
	var module: ModuleBase = Global.world_manager.get_module_by_cell(WorldManager.StructureLayer.MODULE, cell)
	if module == null:
		return _report("damage_module found no MODULE-layer module at %s" % cell)
	module.apply_damage(amount, &"cheat")
	if is_instance_valid(module):
		return _report("dealt %.0f damage to %s (now %.0f/%.0f HP)" % [amount, module._display_name(), module.hp, module.max_hp()])
	return _report("dealt %.0f damage - module at %s destroyed" % [amount, cell])

## Restores `amount` HP to the module at `cell` (WI-24). -1 = repair to full.
func repair_module(cell: Vector2i, amount: float = -1.0) -> String:
	var module: ModuleBase = Global.world_manager.get_module_by_cell(WorldManager.StructureLayer.MODULE, cell)
	if module == null:
		return _report("repair_module found no MODULE-layer module at %s" % cell)
	if amount < 0.0:
		amount = module.max_hp()
	module.repair(amount)
	module.clear_breakdown()
	return _report("repaired %s to %.0f/%.0f HP" % [module._display_name(), module.hp, module.max_hp()])

## Prints every nonzero adjacency field (WI-30) on the module at `cell` - the
## debug readout for vibration/greenery/maintenance propagation.
func dump_adjacency(cell: Vector2i) -> String:
	var module: ModuleBase = Global.world_manager.get_module_by_cell(WorldManager.StructureLayer.MODULE, cell)
	if module == null:
		return _report("dump_adjacency found no MODULE-layer module at %s" % cell)
	if Global.adjacency_manager == null:
		return _report("adjacency manager unavailable")
	var fields: Dictionary[StringName, float] = Global.adjacency_manager.get_all_fields(module)
	if fields.is_empty():
		return _report("%s sits in no adjacency fields" % module._display_name())
	var parts: Array[String] = []
	for effect_id: StringName in fields:
		parts.append("%s=%.3f" % [effect_id, fields[effect_id]])
	return _report("%s fields: %s" % [module._display_name(), ", ".join(parts)])

## Forces a breakdown on the module at `cell` (WI-24), ignoring the hourly roll.
func break_module(cell: Vector2i) -> String:
	var module: ModuleBase = Global.world_manager.get_module_by_cell(WorldManager.StructureLayer.MODULE, cell)
	if module == null or not module.is_complete():
		return _report("break_module found no built MODULE-layer module at %s" % cell)
	module._trigger_breakdown()
	return _report("forced a breakdown on %s" % module._display_name())

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

## Sets skill `skill` to `level` (0..10) on the crew pawn nearest `cell` (WI-22).
## Pass ids as plain strings, e.g. set_skill("construction", 10, Vector2i(16, 8)).
func set_skill(skill: StringName, level: int, cell: Vector2i) -> String:
	if SkillData.by_id(skill) == null:
		return _report("no such skill id: %s" % skill)
	var pawn: PawnBase = _crew_at_or_near(cell)
	if pawn == null:
		return _report("set_skill found no crew pawn near %s" % cell)
	var skills: PawnSkillsComponent = pawn.get_component_by_type(PawnSkillsComponent) as PawnSkillsComponent
	if skills == null:
		return _report("%s has no skills component" % pawn.pawn_name)
	skills.set_level(skill, level)
	return _report("set %s's %s to level %d" % [pawn.pawn_name, skill, clampi(level, 0, SkillData.MAX_LEVEL)])

## Adds trait `trait_id` to the crew pawn nearest `cell` (WI-22). Bypasses the
## roll's exclusive-group rule so you can force any combination for testing,
## e.g. add_trait("optimist", Vector2i(16, 8)).
func add_trait(trait_id: StringName, cell: Vector2i) -> String:
	var trait_data: TraitData = TraitData.by_id(trait_id)
	if trait_data == null:
		return _report("no such trait id: %s" % trait_id)
	var pawn: PawnBase = _crew_at_or_near(cell)
	if pawn == null:
		return _report("add_trait found no crew pawn near %s" % cell)
	var traits: PawnTraitsComponent = pawn.get_traits_component()
	if traits == null:
		return _report("%s has no traits component" % pawn.pawn_name)
	traits.add_trait(trait_data)
	return _report("gave %s the %s trait" % [pawn.pawn_name, trait_data.display_name])

## Infects the crew pawn nearest `cell` with disease `id` (WI-31), e.g.
## infect("station_flu", Vector2i(16, 8)). Bypasses the station-tier unlock gate
## and transmission so you can force a disease for testing.
func infect(id: StringName, cell: Vector2i) -> String:
	if DiseaseData.by_id(id) == null:
		return _report("no such disease id: %s" % id)
	var pawn: PawnBase = _crew_at_or_near(cell)
	if pawn == null:
		return _report("infect found no crew pawn near %s" % cell)
	var disease: PawnDiseaseComponent = pawn.get_component_by_type(PawnDiseaseComponent) as PawnDiseaseComponent
	if disease == null:
		return _report("%s has no disease component" % pawn.pawn_name)
	if disease.infect(id):
		return _report("infected %s with %s" % [pawn.pawn_name, id])
	return _report("%s already has %s" % [pawn.pawn_name, id])

## Cures every active disease on the crew pawn nearest `cell` (WI-31).
func cure(cell: Vector2i) -> String:
	var pawn: PawnBase = _crew_at_or_near(cell)
	if pawn == null:
		return _report("cure found no crew pawn near %s" % cell)
	var disease: PawnDiseaseComponent = pawn.get_component_by_type(PawnDiseaseComponent) as PawnDiseaseComponent
	if disease == null:
		return _report("%s has no disease component" % pawn.pawn_name)
	var ids: Array[StringName] = disease.active_ids()
	for disease_id: StringName in ids:
		disease.cure(disease_id)
	return _report("cured %d disease(s) on %s" % [ids.size(), pawn.pawn_name])

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

## Sets the credit balance to exactly `amount` (negative allowed - drives the
## bankruptcy arc for testing, WI-25).
func set_credits(amount: int) -> String:
	var credits: ResourceData = Global.resource_manager.credit_resource
	credits.change_global_total(amount - credits.get_total())
	return _report("set credits to %d" % credits.get_total())

## Debug stand-in for WI-26's first ARC inspection: flips all three recurring
## cost streams (wages, upkeep, ARC levy) on or off at once (WI-25).
func set_economy_costs(enabled: bool) -> String:
	var economy: EconomyManager = Global.economy_manager
	economy.wages_enabled = enabled
	economy.upkeep_enabled = enabled
	economy.levy_enabled = enabled
	SignalBus.economy_changed.emit()
	return _report("economy cost streams %s" % ("ENABLED" if enabled else "disabled"))

## Takes an ARC loan of `principal` credits (WI-25), same as the economy page.
func take_loan(principal: int) -> String:
	if Global.economy_manager.take_loan(principal):
		return _report("took a loan of %d credits" % principal)
	return _report("could not take a loan (one already active?)")

## Promotes the station one tier (WI-26), bypassing goals and the inspection.
## Resets export progress and, on the first promotion, flips WI-25 costs on -
## the same path a passed inspection takes.
func tier_up() -> String:
	var mgr: UnlockManager = Global.unlock_manager
	if mgr.is_max_tier():
		return _report("already at the top tier (%d)" % mgr.current_tier)
	mgr.advance_tier()
	return _report("promoted to station tier %d" % mgr.current_tier)

## Credits `amount` of resource `id` toward the current tier's export goals
## (WI-26), as if it had been sold/delivered. Only counts if the resource is one
## the current tier actually asks for.
func grant_export(id: StringName, amount: int) -> String:
	var resource: ResourceData = Global.save_manager.get_resource_by_id(id)
	if resource == null:
		return _report("no such resource id: %s" % id)
	SignalBus.resources_exported.emit(resource, amount)
	return _report("credited %d %s toward tier export goals" % [amount, resource.name])

## Starts an ARC inspection immediately (WI-26), skipping the goal check and the
## offer card. Needs a docking bay for the inspector's ship to arrive at.
func start_inspection() -> String:
	Global.unlock_manager.begin_inspection()
	return _report("requested an ARC inspection now")

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

# --- combat / raids (WI-32) ---------------------------------------------------

## Starts a pirate raid now (WI-32). Pass a positive `strength` to force a wave
## size, or -1 to auto-scale from station value. Ships spawn far and fly in.
func start_raid(strength: float = -1.0) -> String:
	if Global.raid_manager == null:
		return _report("raid manager unavailable")
	if not Global.raid_manager.start_raid(strength):
		return _report("could not start a raid (one already active, or disabled?)")
	return _report("raid started with %d ship(s)" % Global.raid_manager.ship_count())

## Pays off the active raid (WI-32) at the current hail price, ending it.
func pay_raid() -> String:
	if Global.raid_manager == null or not Global.raid_manager.active:
		return _report("no active raid to pay off")
	var price: int = Global.raid_manager.current_payoff()
	if Global.raid_manager.pay_off():
		return _report("paid off the raiders for %d credits" % price)
	return _report("could not afford the %d-credit payoff" % price)

# --- visitors (WI-33) ---------------------------------------------------------

## Spawns one paying guest at a docking bay now (WI-33), bypassing arrival pacing
## and the tier/capacity gates. Needs a built docking bay for them to arrive at.
func spawn_visitor() -> String:
	if Global.visitor_manager == null:
		return _report("visitor manager unavailable")
	var bay: ModuleBase = _find_docking_bay()
	if bay == null:
		return _report("spawn_visitor found no built docking bay")
	var visitor: VisitorPawn = Global.visitor_manager.spawn_visitor_at(bay)
	if visitor == null:
		return _report("could not spawn a visitor")
	return _report("spawned visitor %s with %d cr" % [visitor.pawn_name, visitor.personal_credits])

## Sets station reputation (WI-33), which drives the visitor arrival rate. 0..1.
func set_reputation(value: float) -> String:
	if Global.visitor_manager == null:
		return _report("visitor manager unavailable")
	Global.visitor_manager.reputation = clampf(value, 0.0, 1.0)
	SignalBus.visitors_changed.emit()
	return _report("set visitor reputation to %.2f" % Global.visitor_manager.reputation)

func _find_docking_bay() -> ModuleBase:
	for node: Node in Global.world_manager.get_tree().get_nodes_in_group(Groups.CREW_RECRUITMENT):
		var bay: CrewRecruitmentComponent = node as CrewRecruitmentComponent
		if bay != null and bay.owner_module != null and bay.owner_module.is_complete():
			return bay.owner_module
	return null

# --- difficulty (WI-37) -------------------------------------------------------

## Reports the difficulty this run is being played at and what it changes.
func show_difficulty() -> String:
	var difficulty: DifficultyData = Global.get_difficulty()
	if difficulty == null:
		return _report("no difficulty data loaded - running at neutral settings")
	return _report("difficulty %s (%s)" % [difficulty.display_name, difficulty.effect_summary()])

## Switches the run's difficulty mid-game, e.g. set_difficulty("peaceful").
## DEV ONLY: the design fixes difficulty at New Game, and this deliberately breaks
## that so the four levels can be exercised without four playthroughs. The raid
## gate and every cost multiplier pick the change up immediately (both read
## lazily); the crew mood offset does NOT - that is applied once per pawn at
## _ready - so re-check morale on a fresh save/load rather than in place.
func set_difficulty(id: StringName) -> String:
	if DifficultyData.by_id(id) == null:
		var known: Array[String] = []
		for difficulty: DifficultyData in DifficultyData.all():
			known.append(String(difficulty.id))
		return _report("no such difficulty id: %s (known: %s)" % [id, ", ".join(known)])
	Global.set_difficulty(id)
	if Global.raid_manager != null:
		Global.raid_manager.raids_enabled = Global.difficulty_raids_enabled()
	SignalBus.economy_changed.emit()
	return _report("difficulty set to %s (mood offset applies to pawns readied from now on)" %
		Global.get_difficulty().display_name)

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

## The living crew pawn (drones excluded) nearest `cell` by world distance, or
## null if the roster is empty.
func _crew_at_or_near(cell: Vector2i) -> PawnBase:
	var target: Vector2 = Global.cell_to_world(cell, true)
	var best: PawnBase = null
	var best_dist: float = -1.0
	for pawn: PawnBase in Global.crew_manager.get_crew():
		var dist: float = pawn.global_position.distance_squared_to(target)
		if best == null or dist < best_dist:
			best = pawn
			best_dist = dist
	return best

## The module on `cell` (MODULE layer), or the nearest module by cell distance.
func _module_at_or_near(cell: Vector2i) -> ModuleBase:
	var world: WorldManager = Global.world_manager
	var exact: ModuleBase = world.get_module_by_cell(WorldManager.StructureLayer.MODULE, cell)
	if exact != null:
		return exact
	var best: ModuleBase = null
	var best_dist: int = -1
	for node: Node in world.get_tree().get_nodes_in_group(Groups.MODULE):
		var module: ModuleBase = node as ModuleBase
		if module == null:
			continue
		var dist: int = module.module_cell.distance_squared_to(cell)
		if best == null or dist < best_dist:
			best = module
			best_dist = dist
	return best
