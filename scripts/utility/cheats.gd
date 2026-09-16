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
##
## Reports failure rather than success when the cell won't take the module -
## add_module returns null on a blocked or overlap-cancelled placement, and this
## used to claim success regardless. Three WI-41 probe builds silently no-op'd
## onto occupied starting-station cells and looked like conversion bugs.
func build_module(id: StringName, cell: Vector2i, flipped: bool) -> String:
	var module_data := Global.save_manager.get_module_data_by_id(id)
	if module_data == null:
		return _report("Could not find module with id: %s" % id)
	# Argument order matters: add_module(data, cell, flipped, defer_ready,
	# force_complete). `flipped` used to land in the defer_ready slot, which both
	# lost the flip AND skipped the module's entire ready pass, leaving it in the
	# tree joined to no groups and connected to nothing.
	var built: ModuleBase = Global.world_manager.add_module(module_data, cell, flipped, false, true)
	if built == null:
		return _report("could not build %s at %s - cell is blocked" % [id, cell])
	if flipped and not module_data.flippable:
		return _report("built module %s at %s (not flippable - placed unflipped)" % [id, cell])
	return _report("built module %s at %s%s" % [id, cell, " flipped" if flipped else ""])

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

## Opens a hull breach on the module at `cell` for `hours` game-hours (WI-64).
##
## This used to be a "Cause Breach" button authored into the atmosphere
## component's UI. It was fine while it was buried behind an Air tab nobody
## opened by accident; folding Power/Air/Environment into one Status tab put a
## button that vents a module's atmosphere in the middle of the page a player
## lands on. A dev affordance belongs on the dev surface.
##
## Reuses `start_breach`, so it takes the same "second strike extends rather than
## restarts" rule as a pirate hit and raises the same critical alert.
func breach_module(cell: Vector2i, hours: float = 1.0) -> String:
	var module: ModuleBase = Global.world_manager.get_module_by_cell(WorldManager.StructureLayer.MODULE, cell)
	if module == null:
		return _report("breach_module found no MODULE-layer module at %s" % cell)
	var atmosphere: AtmosphereComponent = module.get_atmosphere()
	if atmosphere == null:
		return _report("%s has no atmosphere (exterior, or not built?)" % module._display_name())
	atmosphere.start_breach(hours)
	return _report("breached %s for %.1fh" % [module._display_name(), atmosphere.breach_remaining_hours])

## Seals an open breach on the module at `cell` immediately.
##
## The other half of the pair: without it a cheat-opened breach can only be
## waited out, which makes the cheat above a one-way door in a testing session.
## Goes through `advance_seal`, so it emits `module_breach_sealed` and clears the
## alert by exactly the path a repair worker would.
func seal_breach(cell: Vector2i) -> String:
	var module: ModuleBase = Global.world_manager.get_module_by_cell(WorldManager.StructureLayer.MODULE, cell)
	if module == null:
		return _report("seal_breach found no MODULE-layer module at %s" % cell)
	var atmosphere: AtmosphereComponent = module.get_atmosphere()
	if atmosphere == null or not atmosphere.is_breached():
		return _report("%s is not breached" % module._display_name())
	atmosphere.advance_seal(atmosphere.breach_remaining_hours)
	return _report("sealed the breach in %s" % module._display_name())

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

# --- heat (WI-60) -------------------------------------------------------------

## Forces the temperature of the module at `cell`, in degrees Fahrenheit.
func set_temperature(cell: Vector2i, degrees_f: float) -> String:
	var module: ModuleBase = Global.world_manager.get_module_by_cell(WorldManager.StructureLayer.MODULE, cell)
	if module == null:
		return _report("set_temperature found no MODULE-layer module at %s" % cell)
	if Global.heat_manager == null:
		return _report("heat manager unavailable")
	var component: HeatComponent = Global.heat_manager.get_component(module)
	if component == null:
		return _report("%s has no thermal body (not built?)" % module._display_name())
	component.temperature_f = degrees_f
	component.mark_temperature_known()
	component.refresh_throttle()
	return _report("set %s to %s" % [module._display_name(), HeatMath.format_temperature(degrees_f)])

## Sets EVERY registered module's temperature at once - for reaching an extreme
## without waiting for the station to get there on its own.
func heat_station(degrees_f: float) -> String:
	if Global.heat_manager == null:
		return _report("heat manager unavailable")
	var count: int = 0
	for module: ModuleBase in Global.world_manager.id_to_module.values():
		var component: HeatComponent = Global.heat_manager.get_component(module)
		if component == null:
			continue
		component.temperature_f = degrees_f
		component.mark_temperature_known()
		component.refresh_throttle()
		count += 1
	return _report("set %d modules to %s" % [count, HeatMath.format_temperature(degrees_f)])

## Prints the whole thermal network: temperature, mass, exposure, radiation
## multiplier and throttle per module, plus the station's total energy above
## space - which is what makes an equilibrium claim checkable by eye.
func dump_heat() -> String:
	if Global.heat_manager == null:
		return _report("heat manager unavailable")
	return _report("heat:\n" + Global.heat_manager.debug_dump())

# --- suits (WI-67) ------------------------------------------------------------

## Sets the O2 partial of the module at `cell` - WI-60's set_temperature, for gas.
## The only practical way to drive a room across each SuitRules boundary on demand.
func set_o2(cell: Vector2i, partial: float) -> String:
	var module: ModuleBase = Global.world_manager.get_module_by_cell(WorldManager.StructureLayer.MODULE, cell)
	if module == null:
		return _report("set_o2 found no MODULE-layer module at %s" % cell)
	if Global.atmosphere_manager == null:
		return _report("atmosphere manager unavailable")
	var component: AtmosphereComponent = Global.atmosphere_manager.get_component(module)
	if component == null:
		return _report("%s holds no atmosphere" % module._display_name())
	component.o2 = clampf(partial, 0.0, 200.0) * component.volume()
	return _report("set %s to O2 %.0f" % [module._display_name(), component.o2_partial()])

## Suits a crew member up as though they had just walked into a harmful room:
## suit on, full hold. `name` is a pawn name, or "all" for the whole crew.
func suit_up(pawn_name: String) -> String:
	return _set_suits(pawn_name, true)

## Takes a suit off and clears the hold. The rule may put it straight back on,
## which is the fastest way to find out WHY it wants one.
func unsuit(pawn_name: String) -> String:
	return _set_suits(pawn_name, false)

func _set_suits(pawn_name: String, on: bool) -> String:
	var touched: int = 0
	for suit: PawnSuitComponent in _suit_components():
		if pawn_name != "all" and suit.owner_pawn.pawn_name != pawn_name:
			continue
		suit.apply_change(on)
		touched += 1
	if touched == 0:
		return _report("no crew matched '%s'" % pawn_name)
	return _report("%s %d crew" % ["suited" if on else "unsuited", touched])

## One line per crew member: what they are wearing, why, and how far the nearest
## airlock is. The distance column is the point - it is what turns "my crew keep
## dying" into "my crew keep dying forty metres from an airlock".
func dump_suits() -> String:
	var lines: PackedStringArray = []
	var mandatory: bool = Global.unlock_manager != null and Global.unlock_manager.suits_mandatory()
	lines.append("tier %d, suits mandatory: %s"
		% [Global.unlock_manager.current_tier if Global.unlock_manager != null else 0, mandatory])
	for suit: PawnSuitComponent in _suit_components():
		var pawn: PawnBase = suit.owner_pawn
		var module: ModuleBase = pawn.current_module
		var where: String = module._display_name() if module != null else "outside"
		var airlock: JobTarget = Finder_Airlock.new(false).find(Job.of(&"change_suit"), pawn)
		var distance: String = "none reachable"
		if airlock != null and airlock.module() != null:
			distance = "%d cells to %s" % [
				Vector2(airlock.module().module_cell - Global.world_to_cell(pawn.global_position)).length(),
				airlock.module()._display_name()]
		lines.append("  %s: %s in %s | hold %.2fh | %s" % [
			pawn.pawn_name, "SUITED" if suit.suited else "unsuited", where,
			suit.hold_remaining(), distance])
	return _report("suits:\n" + "\n".join(lines))

func _suit_components() -> Array[PawnSuitComponent]:
	var out: Array[PawnSuitComponent] = []
	for node: Node in Global.get_tree().get_nodes_in_group(Groups.PAWN):
		var pawn: PawnBase = node as PawnBase
		if pawn == null:
			continue
		var suit: PawnSuitComponent = pawn.get_component_by_type(PawnSuitComponent) as PawnSuitComponent
		if suit != null and not suit.static_suit:
			out.append(suit)
	return out

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
		if storage != null and storage.import_priority(resource) != StorageComponent.REFUSED 				and storage.deposit(resource, amount, true):
			return _report("added %d %s to storage at %s" % [amount, resource.name, cell])
	var pile: ResourcePile = ResourcePile.spawn(world.get_canvas_for_module(module),
			Global.cell_to_world(cell, true), module)
	pile.add_amount(resource, amount)
	return _report("spawned a pile of %d %s at %s" % [amount, resource.name, cell])

## Prints every ledger resource's total, per-cycle rate and retained sample count
## (WI-52) - the readout for tuning the rate tracker's window against a known
## production loop, and the way to tell a genuine flat line ("0.0" with a full
## buffer) apart from "no data yet" (an em dash).
func dump_rates() -> String:
	var manager: ResourceManager = Global.resource_manager
	if manager == null:
		return _report("no resource manager")
	var lines: Array[String] = []
	for resource: ResourceData in manager.ledger_resources():
		lines.append("%s: %d | %s/cyc | %d samples" % [
			resource.name, resource.get_total(),
			LedgerModel.format_per_cycle(manager.rate_per_cycle(resource)),
			manager.rates.sample_count(resource.id)])
	_report("dumped %d resource rates" % lines.size())
	return "\n".join(lines)

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

## Prints the social ledger (WI-48) of the crew pawn nearest `cell`: who they
## have spoken to, what they think of them, and when they last talked.
func dump_opinions(cell: Vector2i) -> String:
	var pawn: PawnBase = _crew_at_or_near(cell)
	if pawn == null:
		return _report("dump_opinions found no crew pawn near %s" % cell)
	var social: SocializeComponent = pawn.get_component_by_type(SocializeComponent) as SocializeComponent
	if social == null:
		return _report("%s has no socialize component" % pawn.pawn_name)
	var lines: PackedStringArray = PackedStringArray()
	for other: PawnBase in Global.crew_manager.get_crew():
		if other == pawn:
			continue
		var record: PawnOpinion = social.record_of(other.pawn_id)
		if record == null or record.chats <= 0:
			lines.append("  %s: not met" % other.pawn_name)
			continue
		lines.append("  %s: %+.1f (%s), %d chat(s), last C%d %02d:00, %s" % [
			other.pawn_name, record.value, SocialMath.opinion_label(record.value),
			record.chats, record.last_cycle, record.last_hour,
			"good" if record.last_positive else "bad"])
	if lines.is_empty():
		lines.append("  (no other crew aboard)")
	# The detail goes to the REPL echo; the alert just names whose ledger it was.
	print("%s's opinions:\n%s" % [pawn.pawn_name, "\n".join(lines)])
	return _report("dumped %s's opinions (%d chats logged) - see the console" % [
			pawn.pawn_name, social.recent_chats().size()])

## Sets what the crew pawn nearest `cell_a` thinks of the one nearest `cell_b`
## (WI-48), on the -100..+100 scale. One direction only - call it twice with the
## cells swapped for a mutual feud. Marks the pair as having spoken.
func set_opinion(cell_a: Vector2i, cell_b: Vector2i, value: float) -> String:
	var pawn_a: PawnBase = _crew_at_or_near(cell_a)
	var pawn_b: PawnBase = _crew_at_or_near(cell_b)
	if pawn_a == null or pawn_b == null:
		return _report("set_opinion needs a crew pawn near each cell")
	if pawn_a == pawn_b:
		return _report("set_opinion picked the same pawn twice - use cells nearer each crew member")
	var social: SocializeComponent = pawn_a.get_component_by_type(SocializeComponent) as SocializeComponent
	if social == null:
		return _report("%s has no socialize component" % pawn_a.pawn_name)
	social.set_opinion(pawn_b.pawn_id, value)
	return _report("%s now thinks %+.0f of %s (%s)" % [pawn_a.pawn_name, value, pawn_b.pawn_name,
			SocialMath.opinion_label(value)])

## Forces a chat (WI-48) between the crew pawns nearest each cell, ignoring both
## cooldowns and whether they share a module. The outcome is still rolled, so
## repeated calls are the fast way to watch a relationship form.
func force_chat(cell_a: Vector2i, cell_b: Vector2i) -> String:
	var pawn_a: PawnBase = _crew_at_or_near(cell_a)
	var pawn_b: PawnBase = _crew_at_or_near(cell_b)
	if pawn_a == null or pawn_b == null:
		return _report("force_chat needs a crew pawn near each cell")
	if pawn_a == pawn_b:
		return _report("force_chat picked the same pawn twice - use cells nearer each crew member")
	var social_a: SocializeComponent = pawn_a.get_component_by_type(SocializeComponent) as SocializeComponent
	var social_b: SocializeComponent = pawn_b.get_component_by_type(SocializeComponent) as SocializeComponent
	if social_a == null or social_b == null:
		return _report("both pawns need a socialize component to chat")
	if not social_a.force_chat(social_b):
		return _report("could not resolve a chat between %s and %s" % [pawn_a.pawn_name, pawn_b.pawn_name])
	var record: PawnOpinion = social_a.record_of(pawn_b.pawn_id)
	return _report("%s and %s chatted - it went %s (%s now %+.1f)" % [
			pawn_a.pawn_name, pawn_b.pawn_name,
			"well" if record.last_positive else "badly",
			pawn_a.pawn_name, record.value])

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

# --- mineable bodies (WI-61) --------------------------------------------------

## Force a comet in now, ignoring both its spawn gap and its population cap.
## The one this work item lives on: the natural gap is 18-60 game-hours.
func spawn_comet() -> String:
	return spawn_body(&"comet")

## Force one body of any profile. Ignores the cap, so this can push a kind past
## its normal population - which is the point of a cheat.
func spawn_body(profile_id: StringName) -> String:
	var manager: AsteroidManager = Global.asteroid_manager
	if manager == null:
		return _report("no asteroid manager")
	var profile: SpaceBodyProfile = manager.profile_by_id(profile_id)
	if profile == null:
		return _report("no such space body profile: %s" % profile_id)
	var body: AsteroidBase = manager.spawn_body(profile)
	if body == null:
		# The only way a spawn declines: a CROSSING profile with nothing built to
		# cross. Say which, or this reads as a broken cheat.
		return _report("%s declined to spawn - the station has no modules to cross"
				% profile.display_name)
	return _report("spawned %s #%d at %s heading %s"
			% [profile.display_name, body.asteroid_id, body.position.round(),
			body.direction.round()])

## Every live body: kind, id, where it is, how far through its route, what is
## left in it. The debugging tool this work item actually runs on.
func dump_bodies() -> String:
	var manager: AsteroidManager = Global.asteroid_manager
	if manager == null:
		return _report("no asteroid manager")
	var lines: Array[String] = []
	for body: AsteroidBase in manager.asteroids:
		if not is_instance_valid(body):
			continue
		var travelled: float = body.position.distance_to(body.despawn_anchor)
		var contents: Array[String] = []
		for resource: ResourceData in body.resource_weighted_values:
			if resource != null:
				contents.append("%s %.1f" % [resource.id, body.resource_weighted_values[resource]])
		lines.append("%s #%d %s  %.0f/%.0f px  %d/%d chunks  [%s]%s"
				% [body.profile_id, body.asteroid_id, body.position.round(),
				travelled, body.despawn_distance, body.cur_resources, body.max_resources,
				", ".join(contents), "  DESIGNATED" if body.designated else ""])
	if lines.is_empty():
		return _report("no mineable bodies alive")
	print("
".join(lines))
	return _report("%d bodies (listed in the console)" % lines.size())

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

## Starts an ARC inspection immediately (WI-26), skipping every readiness check
## the Comms panel's button makes (WI-57). Needs a docking bay for the inspector's
## ship to arrive at - that is the one precondition the runner cannot do without,
## so it is not a gate this can skip.
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

# --- dialogue (WI-62) -----------------------------------------------------------
#
# How stages 1-3 got driven before a single event was converted, and how a chain
# gets tested without waiting four game-hours for its follow-up. Pass ids as plain
# strings - Godot's Expression, which is what the REPL runs, rejects `&"..."`.

## Runs any `.dialogue` file from anywhere, e.g.
## start_dialogue("res://data/dialogue/events/damaged_ship.dialogue", "hail").
func start_dialogue(path: String, cue: String = "") -> String:
	if Global.dialogue_runner == null:
		return _report("no dialogue runner")
	var resource: DialogueResource = ResourceLoader.load(path) as DialogueResource
	if resource == null:
		return _report("no dialogue resource at %s" % path)
	if not cue.is_empty() and not resource.get_cues().has(cue):
		return _report("%s has no cue '%s' (has %s)" % [path, cue, str(resource.get_cues())])
	Global.dialogue_runner.run(resource, cue)
	return _report("running %s%s" % [path, "" if cue.is_empty() else " from " + cue])

## Sets a declared story flag. Values are bools or ints, e.g. set_flag("kestrel_docked", true).
func set_flag(id: String, value: Variant) -> String:
	if Global.story_state == null:
		return _report("no story state")
	if not Global.story_state.flags.set_flag(StringName(id), value):
		return _report("no such flag '%s' - declare it in StoryFlags.DECLARED" % id)
	return _report("story flag %s = %s" % [id, str(value)])

## Prints every declared flag and its current value, set or not.
func dump_flags() -> String:
	if Global.story_state == null:
		return _report("no story state")
	var flags: StoryFlags = Global.story_state.flags
	var lines: Array[String] = []
	for id: StringName in StoryFlags.DECLARED:
		lines.append("%s = %s" % [id, str(flags.flag(id))])
	_report("dumped %d story flags" % lines.size())
	return "
".join(lines)

## Sets an absolute faction standing in -1..+1, e.g. set_standing("authority", -0.7).
func set_standing(id: String, value: float) -> String:
	if Global.story_state == null:
		return _report("no story state")
	if Global.story_state.faction(StringName(id)) == null:
		return _report("no such faction '%s'" % id)
	var landed: float = Global.story_state.standing.set_standing(StringName(id), value)
	return _report("standing with %s = %+.2f (%s)" % [id, landed,
		FactionStanding.band_name(FactionStanding.band_for(landed))])

## Prints every faction, scored or not, with its standing and band.
func dump_standing() -> String:
	if Global.story_state == null:
		return _report("no story state")
	var lines: Array[String] = []
	for faction: FactionData in Global.story_state.factions():
		if not faction.scored:
			lines.append("%s: not scored (tier ladder)" % faction.display_name)
			continue
		var value: float = Global.story_state.standing.standing(faction.id)
		lines.append("%s: %+.2f (%s)" % [faction.display_name, value,
			FactionStanding.band_name(FactionStanding.band_for(value))])
	_report("dumped %d factions" % lines.size())
	return "
".join(lines)

## Promises an event `delay_hours` from now, exactly as a conversation would.
func queue_event(id: String, delay_hours: int) -> String:
	if Global.story_state == null:
		return _report("no story state")
	Global.story_state.queue_event(id, delay_hours)
	return _report("queued event %s in %d hours" % [id, delay_hours])

## Prints the scheduled-event queue with each entry's due time.
func dump_schedule() -> String:
	if Global.story_state == null:
		return _report("no story state")
	var lines: Array[String] = []
	for entry: EventSchedule.Entry in Global.story_state.schedule.entries():
		lines.append(str(entry))
	_report("dumped %d scheduled events" % lines.size())
	return "
".join(lines) if not lines.is_empty() else "(nothing scheduled)"

## Rolls one contract offer scaled to current station stores.
func offer_contract() -> String:
	var contract: ContractData = Global.contract_manager.generate_offer(0.0)
	if contract == null:
		return _report("nothing stored worth contracting")
	return _report("offered contract: %d %s by cycle %d" %
		[contract.amount, contract.resource.name, contract.deadline_cycle])

# --- tutorial (WI-63) -----------------------------------------------------------

## Runs SAI's introduction now, from any state. Does not touch the ledger - a
## replay is not a first run.
func start_onboarding() -> String:
	if Global.tutorial_manager == null:
		return _report("no tutorial manager")
	Global.tutorial_manager.replay_onboarding()
	return _report("running the onboarding")

## Fires one advisory regardless of its trigger or whether it has already been
## given, e.g. fire_hint("module_unpowered"). Spends it, exactly as the real
## trigger would.
func fire_hint(id: String) -> String:
	var manager: TutorialManager = Global.tutorial_manager
	if manager == null:
		return _report("no tutorial manager")
	var hint: TutorialHintData = manager.hint(StringName(id))
	if hint == null:
		return _report("no such hint '%s'" % id)
	# A subject-carrying hint fired by hand still needs one, or its first line
	# renders "that has not eaten". The nearest crew member is the honest guess;
	# a module hint gets the module nearest the origin of the station.
	var subject: Node = null
	if hint.has_subject:
		subject = _crew_at_or_near(Vector2i.ZERO)
		if String(hint.trigger).begins_with("module_"):
			subject = _module_at_or_near(Vector2i.ZERO)
	manager.fire(hint.id, subject)
	return _report("fired hint %s" % id)

## Un-gives everything. The next new-game bootstrap would run the introduction
## again, and every watcher re-arms on the next call to arm them.
func reset_tutorial() -> String:
	if Global.tutorial_manager == null:
		return _report("no tutorial manager")
	Global.tutorial_manager.ledger.clear()
	return _report("tutorial ledger cleared")

## What has been given, what is armed, and what the player is being waited on.
func dump_tutorial() -> String:
	if Global.tutorial_manager == null:
		return _report("no tutorial manager")
	_report("dumped tutorial state")
	return Global.tutorial_manager.describe()

## The skip path, from outside: ends any conversation, spends every hint, drops
## every watcher.
func skip_tutorial() -> String:
	if Global.tutorial_manager == null:
		return _report("no tutorial manager")
	Global.tutorial_manager.skip_tutorial()
	return _report("tutorial skipped")

# --- alerts (WI-53) -----------------------------------------------------------

## Raises a test alert at `priority` (0 low, 1 high, 2 critical).
##
## Criticals are otherwise hard to provoke on demand - the tier exists precisely
## because almost nothing qualifies - and the pause latch is the one part of this
## game that has to be exercised deliberately rather than waited for.
##
## The `CHEAT: ` prefix keeps it out of the history log ([method AlertManager._log]),
## so a session spent testing the latch does not leave a log full of fake breaches.
func fire_alert(priority: int = 2, subject_cell: Vector2i = Vector2i(-9999, -9999)) -> String:
	var tier: AlertData.Priority = AlertData._priority_from(priority)
	var subject: ModuleBase = null
	if subject_cell != Vector2i(-9999, -9999):
		subject = _module_at_or_near(subject_cell)
	var alert: AlertData = AlertManager.raise_alert(
		AlertRules.make_id(&"cheat_alert", subject if subject != null else randi()),
		tier, "CHEAT: test alert",
		"Raised at %s priority" % AlertRules.priority_label(tier).to_lower(), subject)
	if alert == null:
		return "no AlertManager in the tree"
	return "raised a %s alert%s" % [AlertRules.priority_label(tier).to_lower(),
		" on %s" % subject._display_name() if subject != null else ""]

## Acknowledges every live alert, including outstanding criticals - the escape
## hatch for a latch that will not release because its alert scrolled out of a
## capped feed.
func clear_alerts() -> String:
	var manager: AlertManager = Global.alert_manager
	if manager == null:
		return "no AlertManager in the tree"
	var live: Array[AlertData] = manager.live()
	for alert: AlertData in live:
		manager.acknowledge(alert)
	return _report("acknowledged %d alert(s)" % live.size())

## Live alerts and the pause state, so "why is the game frozen" has an answer
## that does not require reading the feed.
func dump_alerts() -> String:
	var manager: AlertManager = Global.alert_manager
	if manager == null:
		return "no AlertManager in the tree"
	var lines: Array[String] = ["outstanding: %d, holding pause: %s, holders: %s" % [
		manager.outstanding_count(), str(manager.is_holding_pause()),
		str(Global.time_manager.pause_holders()) if Global.time_manager != null else "?"]]
	for alert: AlertData in AlertRules.order(manager.live()):
		lines.append("  [%s] %s - %s%s" % [AlertRules.priority_label(alert.priority),
			alert.title, alert.detail, "  (ack)" if alert.acknowledged else ""])
	lines.append("history: %d entry(s)" % manager.history().size())
	return "\n".join(lines)

# --- star system (WI-66) ------------------------------------------------------

## The layer a contact sheet sits on: above every UI CanvasLayer in main.tscn, so
## the console does not sit on top of the thing being photographed.
const CONTACT_SHEET_LAYER: int = 128
const CONTACT_SHEET_CELL: Vector2 = Vector2(310.0, 250.0)
const CONTACT_SHEET_MARGIN: Vector2 = Vector2(30.0, 40.0)
## Shrinks a whole system - which the generator composes across roughly
## 1000x500px - into one cell, proportions intact, so relative body sizes stay
## readable.
const CONTACT_SHEET_ZOOM: float = 0.29

var _contact_sheet: CanvasLayer

## Regenerate the background star and planet and re-apply them live. A
## `seed_value` of 0 rolls a fresh random seed. The one cheat that makes this
## item testable at all - the sky is otherwise chosen once, before the run starts.
##
## Note this replaces the system the CURRENT run is playing under, so a save
## taken afterwards keeps what you are looking at.
func reroll_system(seed_value: int = 0) -> String:
	var system: StarSystemData = StarSystemGenerator.generate(seed_value) if seed_value != 0 \
			else StarSystemGenerator.generate_random()
	_apply_system(system)
	return _report("Rerolled system %d: %s / %s"
			% [system.seed, system.star_class_id, system.planet_variant_id])

## Roll systems until one lands on `class_id`, then apply it. Everything else
## stays a real roll - pinning one axis by re-rolling rather than by a special
## generator path means the sky you end up looking at is one the game could
## actually have produced on its own.
func set_star_class(class_id: StringName) -> String:
	if StarClass.by_id(class_id) == null:
		return _report("No such star class: %s (have: %s)" % [class_id, _star_class_ids()])
	var system: StarSystemData = _roll_until(class_id, &"")
	if system == null:
		return _report("Could not roll a %s system" % class_id)
	_apply_system(system)
	return _report("Star class %s (seed %d)" % [class_id, system.seed])

## Same, for the planet.
func set_planet_variant(variant_id: StringName) -> String:
	if PlanetVariant.by_id(variant_id) == null:
		return _report("No such planet variant: %s (have: %s)" % [variant_id, _planet_variant_ids()])
	var system: StarSystemData = _roll_until(&"", variant_id)
	if system == null:
		return _report("Could not roll a %s system" % variant_id)
	_apply_system(system)
	return _report("Planet variant %s (seed %d)" % [variant_id, system.seed])

## Everything about the current system as text, palettes included - so a
## screenshot can be matched back to the data that produced it.
func dump_system() -> String:
	var system: StarSystemData = Global.get_star_system()
	var star_class: StarClass = StarClass.by_id(system.star_class_id)
	var variant: PlanetVariant = PlanetVariant.by_id(system.planet_variant_id)
	var lines: Array[String] = []
	lines.append("seed %d" % system.seed)
	lines.append("star: %s (%s, %dK)" % [
		system.star_class_id,
		star_class.display_name if star_class != null else "?",
		star_class.temperature_k if star_class != null else 0])
	lines.append("  ramp %s" % _html(system.star_ramp))
	lines.append("  pixels %d x%d at %s, seed %.2f" % [
		system.star_pixels, system.star_scale, system.star_offset, system.star_seed])
	lines.append("  noise %.2f blob %.2f circles %.2f/%.2f storm %.2f speed %.3f" % [
		system.star_noise_size, system.star_blob_size, system.star_circle_amount,
		system.star_circle_size, system.star_storm_width, system.star_time_speed])
	if not system.has_planet():
		lines.append("planet: none")
	else:
		lines.append("planet: %s (%s)" % [system.planet_variant_id,
			variant.display_name if variant != null else "?"])
		for role_id: StringName in system.planet_palette:
			lines.append("  %s %s" % [role_id, _html(system.planet_palette[role_id])])
		lines.append("  pixels %d x%d at %s, seed %.2f, tilt %.2f" % [
			system.planet_pixels, system.planet_scale, system.planet_offset,
			system.planet_seed, system.planet_rotation])
		lines.append("  cloudiness %.2f coverage %.2f noise %.2f drift x%.2f" % [
			system.planet_cloudiness, system.planet_coverage,
			system.planet_noise_scale, system.planet_time_scale])
	var text: String = "\n".join(lines)
	print(text)
	_report("Dumped system %d (see console)" % system.seed)
	return text

## Lay `count` freshly generated systems out in a grid over the whole screen, for
## one screenshot.
##
## This is the artefact the item is actually verified by: headless renders no
## shaders at all, so "does this look like a real sky", "is anything green or
## purple", "is every ocean blue" and "do two dozen of these genuinely differ"
## are all questions only a picture answers. It drives the real
## [StellarBackground] applier, so what the sheet shows is what the game shows.
func system_contact_sheet(count: int = 24, columns: int = 6) -> String:
	clear_contact_sheet()
	var root: Node = Global.world_manager.get_tree().current_scene
	if root == null:
		return _report("No scene to hang a contact sheet on")
	_contact_sheet = CanvasLayer.new()
	_contact_sheet.layer = CONTACT_SHEET_LAYER
	root.add_child(_contact_sheet)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.02, 0.04)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_contact_sheet.add_child(backdrop)
	for index: int in count:
		var cell := Node2D.new()
		cell.position = Vector2(
			CONTACT_SHEET_MARGIN.x + float(index % columns) * CONTACT_SHEET_CELL.x,
			CONTACT_SHEET_MARGIN.y + float(index / columns) * CONTACT_SHEET_CELL.y)
		cell.scale = Vector2(CONTACT_SHEET_ZOOM, CONTACT_SHEET_ZOOM)
		_contact_sheet.add_child(cell)
		var star_holder := Node2D.new()
		var planet_holder := Node2D.new()
		cell.add_child(star_holder)
		cell.add_child(planet_holder)
		var preview := StellarBackground.new()
		preview.is_preview = true
		preview.star_layer = star_holder
		preview.planet_layer = planet_holder
		cell.add_child(preview)
		preview.apply(StarSystemGenerator.generate_random())
	return _report("Contact sheet: %d systems (clear_contact_sheet() to dismiss)" % count)

func clear_contact_sheet() -> String:
	if _contact_sheet != null and is_instance_valid(_contact_sheet):
		_contact_sheet.queue_free()
	_contact_sheet = null
	return "Contact sheet cleared"

func _apply_system(system: StarSystemData) -> void:
	Global.stage_star_system(system)
	if Global.stellar_background != null and is_instance_valid(Global.stellar_background):
		Global.stellar_background.apply(system)

## Rolls until the system matches whichever axis was asked for. Bounded, because
## a weight of zero on the requested entry would otherwise spin forever.
func _roll_until(class_id: StringName, variant_id: StringName) -> StarSystemData:
	for attempt: int in 4000:
		var system: StarSystemData = StarSystemGenerator.generate_random()
		if class_id != &"" and system.star_class_id != class_id:
			continue
		if variant_id != &"" and system.planet_variant_id != variant_id:
			continue
		return system
	return null

func _star_class_ids() -> String:
	var ids: Array[String] = []
	for star_class: StarClass in StarClass.all():
		ids.append(String(star_class.id))
	return ", ".join(ids)

func _planet_variant_ids() -> String:
	var ids: Array[String] = []
	for variant: PlanetVariant in PlanetVariant.all():
		ids.append(String(variant.id))
	return ", ".join(ids)

func _html(colors: PackedColorArray) -> String:
	var out: Array[String] = []
	for color: Color in colors:
		out.append(color.to_html(false))
	return " ".join(out)

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
