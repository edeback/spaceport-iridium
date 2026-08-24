class_name DialogueBridge
extends Node

## Everything a conversation may **do** to the simulation (WI-62 §3), exposed to
## dialogue under the alias `station`.
##
## This is the one seam between authored text and the game, which makes it the one
## place the simulation's own invariants get enforced. Two of them matter here and
## both have been shipped wrong before:
##
## - [method EconomyManager.record_income] returns the **net** after ARC's levy,
##   and the caller must credit *that* rather than the gross (the WI-33 money-loop
##   bug). [method credits] is the only place a conversation can move money, so
##   it is the only place that has to get it right.
## - **No silent resource loss.** [method grant_cargo] piles whatever will not fit
##   rather than dropping it, because the rule has no "too small to matter"
##   threshold.
##
## This class is the whole of what WI-62 deleted [EventEffect] for. The nine
## `data/events/effects/*.gd` subclasses are the first nine verbs below, with
## their balance numbers moved from a `.tres` into the `.dialogue` file that calls
## them - still data, and now next to the sentence that explains it.
##
## **Ids arrive as plain `String`.** Godot's [Expression] - which is what runs a
## dialogue mutation - rejects a `&"…"` literal outright, so an author could not
## write a [StringName] even if they wanted to. Same rule the Panku cheats follow.
## An unknown id is an error naming the verb and the id, never a silent no-op:
## a conversation that quietly does nothing is indistinguishable from one that
## worked.

# --- money & the books ----------------------------------------------------------

## `$> station.credits(600)` - positive pays the station, negative charges it.
##
## Going below zero is allowed: debt feeds the bankruptcy path through
## [CrewManager]'s hire check, and an event that cannot charge a broke station is
## an event that only ever happens to rich ones.
func credits(amount: int) -> void:
	if amount == 0:
		return
	var manager: ResourceManager = Global.resource_manager
	if manager == null or manager.credit_resource == null:
		push_error("station.credits: no credit resource")
		return
	manager.credit_resource.change_global_total(amount)
	if Global.economy_manager != null:
		# An event swing bypasses the levy but still shows on the economy page.
		Global.economy_manager.record_event_delta(amount)

## `$> station.loan(2500)` - an ARC loan at the standard terms. A no-op when a
## loan is already running; the Finance tab is then how it gets managed.
func loan(principal: int) -> bool:
	if Global.economy_manager == null:
		push_error("station.loan: no economy manager")
		return false
	return Global.economy_manager.take_loan(principal)

# --- crew -----------------------------------------------------------------------

## `$> station.mood("arc_levy_unrest", -0.1, 24)` - a station-wide timed happiness
## modifier. Re-using an id refreshes the duration rather than stacking, and
## [EventManager] remembers it so crew hired later get it too.
func mood(id: String, mood_value: float, duration_hours: float) -> void:
	if Global.event_manager == null:
		push_error("station.mood: no event manager")
		return
	if id.is_empty():
		push_error("station.mood: a modifier needs an id, or it cannot be refreshed")
		return
	Global.event_manager.apply_station_happiness(StringName(id), mood_value, duration_hours)

## `$> station.outbreak()` - seeds a disease outbreak from the pool unlocked at
## the current tier, capped so at least one crew member stays on their feet.
## Naming a disease forces that one instead of rolling.
func outbreak(disease_id: String = "", min_infections: int = 1, max_infections: int = 3) -> void:
	if Global.unlock_manager == null or Global.crew_manager == null:
		push_error("station.outbreak: no unlock or crew manager")
		return
	var disease: DiseaseData = null
	if disease_id.is_empty():
		var pool: Array[DiseaseData] = DiseaseData.outbreak_pool(Global.unlock_manager.current_tier)
		if pool.is_empty():
			return
		disease = pool.pick_random()
	else:
		disease = DiseaseData.by_id(StringName(disease_id))
		if disease == null:
			push_error("station.outbreak: no such disease '%s'" % disease_id)
			return
	# Only crew who could actually catch it: has a disease component (organic crew,
	# not a robot) and isn't already carrying this disease.
	var candidates: Array[PawnDiseaseComponent] = []
	for pawn: PawnBase in Global.crew_manager.get_crew():
		var component: PawnDiseaseComponent = pawn.get_component_by_type(
			PawnDiseaseComponent) as PawnDiseaseComponent
		if component != null and not component.has_disease(disease.id):
			candidates.append(component)
	if candidates.is_empty():
		return
	candidates.shuffle()
	# Leave at least one crew member uninfected by this outbreak (survivability).
	var cap: int = maxi(0, Global.crew_manager.get_crew().size() - 1)
	var count: int = clampi(randi_range(min_infections, max_infections), 0,
		mini(candidates.size(), cap))
	if count <= 0:
		return
	AlertManager.raise_alert(&"outbreak", AlertData.Priority.HIGH, "Disease outbreak",
		"%s is spreading through the station" % disease.display_name, null, &"crew")
	for index: int in count:
		candidates[index].infect(disease.id)

# --- the market -----------------------------------------------------------------

## `$> station.market_shock("steel", 0.3, 24)` - multiplies one resource's market
## supply for a while. Below 1 is scarcity (prices spike), above 1 a glut.
func market_shock(resource_id: String, multiplier: float, duration_hours: float) -> void:
	var resource: ResourceData = _resource(resource_id, "market_shock")
	if resource == null or Global.market_manager == null:
		return
	Global.market_manager.apply_supply_modifier(resource, multiplier, duration_hours)

## `$> station.offer_contract()` - a fresh delivery-contract offer on the board,
## rolled from the same generator trader visits use.
func offer_contract(premium_bonus: float = 0.15) -> void:
	if Global.contract_manager == null:
		push_error("station.offer_contract: no contract manager")
		return
	var contract: ContractData = Global.contract_manager.generate_offer(premium_bonus)
	if contract == null:
		# Nothing worth contracting (no stored tradeables). A silent no-op would
		# feel like the choice did nothing, so say so.
		SignalBus.station_alert.emit("The contractor found nothing worth shipping")

# --- damage & violence ----------------------------------------------------------

## `$> station.raid(-1)` - a real pirate wave. `-1` auto-scales from station value;
## a positive number forces a fixed strength for a scripted encounter.
func raid(strength: float = -1.0) -> void:
	if Global.raid_manager == null:
		push_error("station.raid: no raid manager")
		return
	Global.raid_manager.start_raid(strength)

## `$> station.breach(1)` - opens hull breaches in random pressurised modules.
## A strike on an already-breached module refreshes its timer instead of stacking.
func breach(count: int = 1, duration_hours: float = 2.0) -> void:
	if Global.atmosphere_manager == null:
		push_error("station.breach: no atmosphere manager")
		return
	for index: int in maxi(1, count):
		var target: AtmosphereComponent = Global.atmosphere_manager.get_random_breach_target()
		if target != null:
			target.start_breach(duration_hours)

## `$> station.damage_station(0.2)` - spreads a proportional shock across the
## station: every built module loses `severity` of its **maximum** HP.
##
## Proportional rather than flat, because a flat number that scratches a hab block
## flattens a solar panel. Severity is a fraction of max HP so the same authored
## 0.2 reads the same on a two-cycle station and a forty-module one.
func damage_station(severity: float) -> void:
	if severity <= 0.0 or Global.world_manager == null:
		return
	var fraction: float = clampf(severity, 0.0, 1.0)
	for node: Node in Global.world_manager.get_tree().get_nodes_in_group(Groups.MODULE):
		var module: ModuleBase = node as ModuleBase
		if module == null or not module.is_complete():
			continue
		module.apply_damage(module.max_hp() * fraction, &"event")

# --- goods ----------------------------------------------------------------------

## `$> station.salvage("steel", 15, 30, 2)` - free-floating [ResourcePile]s in
## space near the station.
##
## Piles rather than asteroids, deliberately: they bypass [AsteroidManager]'s
## population cap and post their own collection jobs on spawn, so crew sweep them
## up through the ordinary airlock flow.
func salvage(resource_id: String, min_amount: int, max_amount: int, piles: int = 2) -> void:
	var resource: ResourceData = _resource(resource_id, "salvage")
	if resource == null or piles <= 0:
		return
	var total: int = randi_range(min_amount, maxi(min_amount, max_amount))
	var bounds: Rect2 = _station_bounds()
	for index: int in piles:
		var share: int = total / piles + (1 if index < total % piles else 0)
		if share <= 0:
			continue
		var pile: ResourcePile = ResourcePile.spawn(
			Global.world_manager.pawn_layer, _roll_space_position(bounds))
		pile.add_amount(resource, share)

## `$> station.grant_cargo("steel", 20, 40)` - a docked ship offloads goods.
##
## Into the docking bay if it will take them, and **piled at the dock if it will
## not**. The station never loses what it was given: the rule is that the player
## only loses resources to an action that loses resources, and it has no "too
## small to matter" threshold.
func grant_cargo(resource_id: String, min_amount: int, max_amount: int) -> int:
	var resource: ResourceData = _resource(resource_id, "grant_cargo")
	if resource == null:
		return 0
	var amount: int = randi_range(min_amount, maxi(min_amount, max_amount))
	if amount <= 0:
		return 0
	var bay: ModuleBase = _docking_bay()
	var remainder: int = amount
	var drop: Vector2 = _roll_space_position(_station_bounds())
	if bay != null:
		drop = DockingBay.dock_position_for(bay)
		var storage: StorageComponent = bay.get_component_by_type(
			StorageComponent) as StorageComponent
		if storage != null and storage.import_priority(resource) != StorageComponent.REFUSED:
			var room: int = maxi(0, storage.space_available_for(resource))
			var taken: int = mini(room, remainder)
			if taken > 0 and storage.deposit(resource, taken, true):
				remainder -= taken
	if remainder > 0:
		var pile: ResourcePile = ResourcePile.spawn(
			Global.world_manager.pawn_layer, drop, bay)
		pile.add_amount(resource, remainder)
	return amount

# --- saying things --------------------------------------------------------------

## `$> station.transmit("Kestrel", "Debt paid", "…")` - something worth re-reading
## later. Lands in the Comms feed and raises a LOW alert alongside it.
func transmit(sender: String, subject: String, body: String = "") -> void:
	AlertManager.transmit(StringName("dialogue_%s" % subject.to_snake_case()),
		AlertData.Priority.LOW, subject, body, &"event", sender, body)

## `$> station.alert("Raiders inbound", "…")` - something worth looking at now,
## and not worth keeping. HIGH, so it stays until it is clicked.
func alert(title: String, detail: String = "") -> void:
	AlertManager.raise_alert(StringName("dialogue_%s" % title.to_snake_case()),
		AlertData.Priority.HIGH, title, detail)

# --- queries --------------------------------------------------------------------
#
# Read-only, for a `[if …]` on a line or a response. A query never changes
# anything, which is why they are grouped apart from the verbs above.

## `[if station.dock_is_free() /]` - there is a finished docking bay and nothing
## is using it. The prerequisite the brief's distress-hail event needs.
func dock_is_free() -> bool:
	if _docking_bay() == null:
		return false
	var trader: TraderManager = Global.trader_manager
	if trader == null:
		return true
	return not trader.visit_active and not trader.is_inbound()

## `if station.credits_held() > 500`.
func credits_held() -> int:
	var manager: ResourceManager = Global.resource_manager
	if manager == null or manager.credit_resource == null:
		return 0
	return manager.credit_resource.get_total()

## `if station.stock("steel") >= 40`.
func stock(resource_id: String) -> int:
	var resource: ResourceData = _resource(resource_id, "stock")
	return resource.get_total() if resource != null else 0

## `if station.crew_count() >= 3`.
func crew_count() -> int:
	if Global.crew_manager == null:
		return 0
	return Global.crew_manager.get_crew().size()

## `if station.tier() >= 2`.
func tier() -> int:
	if Global.unlock_manager == null:
		return 1
	return Global.unlock_manager.current_tier

## `if station.under_attack()`.
func under_attack() -> bool:
	return Global.raid_manager != null and Global.raid_manager.active

## `if station.has_module("Defense")` - a finished module carrying that gameplay
## tag. Note `tags`, not `ui_category`: never gate gameplay on presentation.
func has_module(tag: String) -> bool:
	if tag.is_empty() or Global.world_manager == null:
		return false
	for node: Node in Global.world_manager.get_tree().get_nodes_in_group(Groups.MODULE):
		var module: ModuleBase = node as ModuleBase
		if module != null and module.is_complete() and module.module_data != null \
				and module.module_data.tags.has(tag):
			return true
	return false

# --- internals ------------------------------------------------------------------

func _resource(resource_id: String, verb: String) -> ResourceData:
	if Global.save_manager == null:
		return null
	var resource: ResourceData = Global.save_manager.get_resource_by_id(StringName(resource_id))
	if resource == null:
		push_error("station.%s: no such resource id '%s'" % [verb, resource_id])
	return resource

## First constructed docking bay. Same rule [TraderManager] uses.
func _docking_bay() -> ModuleBase:
	if Global.trader_manager != null:
		return Global.trader_manager.find_trade_bay()
	return null

## The gather that feeds [SpaceGeometry]. Lives here rather than in that file
## because it needs the SceneTree and [Global], and SpaceGeometry is pure.
func _station_bounds() -> Rect2:
	var positions: Array[Vector2] = []
	for node: Node in Global.world_manager.get_tree().get_nodes_in_group(Groups.MODULE):
		var module: ModuleBase = node as ModuleBase
		if module == null:
			continue
		positions.append(Global.cell_to_world(module.module_cell, true))
	return SpaceGeometry.station_bounds(positions)

## A point offset outward from a random edge of the station's bounding box, so
## goods land in open space rather than inside modules.
func _roll_space_position(bounds: Rect2) -> Vector2:
	var direction := Vector2.from_angle(randf() * TAU)
	return SpaceGeometry.outward_point(bounds, direction, randf_range(200.0, 500.0))
