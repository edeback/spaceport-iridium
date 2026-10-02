class_name UnlockManager
extends Node

## Owns global (tech-tree) unlock state. Definitions are authored UnlockData
## resources; which of them are purchased is runtime state held here (and, later,
## saved/loaded from here) - never written back onto the shared resources.
##
## Global "module-type improvements" and local per-instance upgrades resolve to
## the same StatModifiers layer; this manager handles the global scope:
##   - broadcast: unlocking a StatModifierEffect applies it to already-built modules
##   - live query: a module applies all active global modifiers when it is built
##     (ModuleBase.ready_constructed -> apply_global_modifiers)
##
## It also owns WI-26's 1-5 station tier ladder, and since WI-57 **the player asks
## for an inspection rather than being offered one.** The `arc_inspection_offer`
## event, its Accept/Decline effect and the per-cycle roll behind them are gone;
## [method inspection_block] is the same readiness test the roll used to make, and
## it produces a sentence for the Comms panel's button instead of gating a random
## number. That converts "wait and hope" into "prepare, then commit", which is the
## shape the rest of the tier system already has - and it makes the first
## inspection, which switches [EconomyManager]'s cost streams on, a deliberate
## decision rather than something that happens to the player.

## Why the Comms panel's `REQUEST INSPECTION` button is disabled (WI-57), or
## READY. Each member names its own blocker on the button rather than leaving it
## greyed - a disabled control with no reason is the failure mode this replaces.
##
## Precedence is the order of the members, and it is deliberate: the blockers that
## are about *when* come before the ones about *what you must still build*,
## because a station in its cooldown does not need to be told about its goals.
enum InspectionBlock {
	## Nothing in the way - the button acts.
	READY,
	## The ladder is finished. Disabled with its own label, never hidden: a button
	## that vanishes at the moment the player has actually won reads as a bug.
	MAX_TIER,
	## An inspector is already aboard.
	IN_PROGRESS,
	## A failed inspection costs a few cycles before ARC will come back.
	COOLING_DOWN,
	## Export goals are not met yet.
	GOALS_UNMET,
	## Every export goal is met but a checklist facility is missing, which would
	## instant-fail the tour.
	FACILITY_MISSING,
	## Nothing to receive the ARC vessel.
	NO_BAY,
}

# --- station tiers (WI-26) tunables -------------------------------------------
## Cycles ARC stays away after a failed inspection.
##
## WI-57 deleted the per-cycle offer roll this also gated - promotion is now a
## thing the player asks for, not a coin flip that may or may not land on a cycle
## they happen to be ready for. The cooldown survives the change because a failed
## inspection costing you a few cycles is a **consequence**, not a dice roll.
@export var inspection_reoffer_cooldown_cycles: int = 2
## Sim-hours the inspector dwells at each checklist module.
@export var inspection_dwell_hours: float = 1.0
## The inspector fails (and leaves) the moment its health drops below this
## (0..100). Low O2 is the realistic path; the threshold trips well before death.
@export var inspection_health_fail_threshold: float = 70.0
## The ARC vessel and the inspector it carries, handed to each InspectionRunner
## (WI-47 M6). Authored here because the runner is created in code and has no
## scene of its own - the arrangement RaidManager and CrewManager already use for
## their spawned entities. Defaults keep the vanilla pair without a scene edit.
@export var inspection_ship_scene: PackedScene = preload("res://objects/arrival_shuttle.tscn")
@export var inspector_pawn_scene: PackedScene = preload("res://pawns/inspector_pawn.tscn")

## Bump when the save format changes incompatibly.
const SAVE_VERSION: int = 1
const SAVE_PATH: String = "user://unlocks.save"

## When true, global unlocks auto-load from SAVE_PATH at startup and auto-save
## on every purchase. Off by default so unlocks don't silently persist before a
## central save system exists / you opt in. The Dictionary API and disk helpers
## work regardless of this flag.
@export var auto_persist: bool = false

## Runtime record of one active global, type-wide stat modifier.
class GlobalStatMod extends RefCounted:
	var tags: Array[String]
	var stat: StringName
	var op: StatModifiers.Op
	var value: float
	var source: StringName

	func matches(module_data: ModuleData) -> bool:
		if module_data == null:
			return false
		if tags.is_empty():
			return true
		for tag: String in tags:
			if module_data.tags.has(tag):
				return true
		return false

## All known unlock definitions, keyed by id.
var _unlocks: Dictionary[StringName, UnlockData] = {}
## Ids of unlocks that have been purchased.
var _unlocked_ids: Dictionary[StringName, bool] = {}
## Modules granted via GrantModuleEffect (unlocked despite unlocked_by_default).
var _granted_modules: Dictionary[ModuleData, bool] = {}
## Active global stat modifiers, keyed by source id.
var _global_modifiers: Dictionary[StringName, GlobalStatMod] = {}
## All known local upgrade definitions, keyed by id.
var _local_upgrades: Dictionary[StringName, LocalUpgradeData] = {}

# --- station tier runtime state (WI-26) ---------------------------------------
## Known tiers keyed by tier number (1..N).
var _tiers: Dictionary[int, TierData] = {}
## The station's current tier. Gates unlock nodes (min_tier) and later WIs.
var current_tier: int = 1
## resource id -> units exported so far toward the CURRENT tier's goals. Reset on
## every tier-up (overflow doesn't carry). Populated by SignalBus.resources_exported.
var _export_progress: Dictionary[StringName, int] = {}
## Cycles left before ARC will accept another inspection request (set on a fail).
##
## **Saved** (see [method get_save_data]), and since WI-57 that matters in a way
## it did not when it only gated a dice roll: it now gates a button the player
## presses, so a cooldown that evaporated on reload would make a failed inspection
## undoable by quitting to the menu - exactly the quiet exploit a save audit
## exists to catch.
var _inspection_cooldown_cycles: int = 0
## True while an inspector is touring.
##
## Runtime-only and never saved, so a load always resolves to "no inspection" -
## the inspector pawn is the one pawn excluded from saves, so there is nothing for
## the flag to describe. **A save taken mid-tour therefore reloads with the button
## reading READY rather than `INSPECTOR ABOARD`, and that is correct rather than a
## bug**: the tour is gone, so asking for another one is the only sensible state.
var _inspection_in_progress: bool = false
## Tiers [method suits_mandatory] has already complained about (F36, WI-74).
## It is asked per crew member per slow tick and per atmosphere tick, so an
## unlatched warning wrote ~40 lines a second for one missing .tres. Runtime-only:
## a reload may warn once more, which is the point of a warning.
var _warned_missing_tiers: Dictionary[int, bool] = {}

## For the Comms panel: is an inspector currently aboard the station?
func is_inspection_active() -> bool:
	return _inspection_in_progress

## Do crew live in pressure suits at the current tier (WI-67)?
##
## The one accessor for [member TierData.suits_mandatory], shared by
## PawnSuitComponent, AtmosphereManager's alert gate, the OXYGEN vitals chip and
## the min-tier event condition - so "is this Tier 1?" has exactly one answer.
##
## A tier with no data answers false: the failure mode of a missing .tres should
## be a station that behaves like a grown-up one, not a crew sealed in suits
## forever with no way to get out.
func suits_mandatory() -> bool:
	var data: TierData = current_tier_data()
	if data == null:
		if not _warned_missing_tiers.has(current_tier):
			_warned_missing_tiers[current_tier] = true
			push_warning("UnlockManager: no TierData for tier %d" % current_tier)
		return false
	return data.suits_mandatory

func _ready() -> void:
	Global.unlock_manager = self
	# Before world: ready_constructed applies global modifiers and granted-module
	# checks as each module restores.
	SaveManager.register_section(&"unlocks", SaveManager.SECTION_ORDER[&"unlocks"], get_save_data, load_save_data)
	_load_unlocks()
	_load_local_upgrades()
	_load_tiers()
	_grant_tier_modules()
	SignalBus.resources_exported.connect(_on_resources_exported)
	# Offer pacing rides the calendar (WI-26), so it can't roll while paused.
	Global.time_manager.cycle_changed.connect(_on_cycle_changed)
	if auto_persist:
		load_from_file()

# --- loading --------------------------------------------------------------

## Hands the slot back (WI-71 §7). Godot 4.7 reports a freed object as `== null`,
## so the guards around the game already take their null branch after a Quit to
## Menu - but `is_instance_valid(Global.unlock_manager)` and the debugger both lie until
## the slot is actually cleared. `== self` because a second scene can register
## before this one leaves.
func _exit_tree() -> void:
	if Global.unlock_manager == self:
		Global.unlock_manager = null


func _load_unlocks() -> void:
	for file_path: String in ContentPaths.scan(ContentPaths.UNLOCKS):
		var res: Resource = ResourceLoader.load(file_path)
		if res is UnlockData:
			var unlock := res as UnlockData
			if not ContentPaths.accept_id(unlock.id, file_path, "UnlockData"):
				continue
			for effect: UnlockEffect in unlock.effects:
				if effect != null:
					effect.warn_on_undeclared_stats(file_path)
			_unlocks[unlock.id] = unlock
			if unlock.unlocked_by_default:
				force_unlock(unlock)

func _load_local_upgrades() -> void:
	for file_path: String in ContentPaths.scan(ContentPaths.LOCAL_UPGRADES):
		var res: Resource = ResourceLoader.load(file_path)
		if res is LocalUpgradeData:
			var upgrade := res as LocalUpgradeData
			if not ContentPaths.accept_id(upgrade.id, file_path, "LocalUpgradeData"):
				continue
			upgrade.warn_on_undeclared_stats(file_path)
			_local_upgrades[upgrade.id] = upgrade

func _load_tiers() -> void:
	for file_path: String in ContentPaths.scan(ContentPaths.TIERS):
		var res: Resource = ResourceLoader.load(file_path)
		if res is TierData:
			var tier := res as TierData
			if _tiers.has(tier.tier):
				push_warning("Duplicate TierData for tier %d, keeping the first: %s" % [tier.tier, file_path])
				continue
			_tiers[tier.tier] = tier

# --- queries --------------------------------------------------------------

func get_all_unlocks() -> Array[UnlockData]:
	var out: Array[UnlockData] = []
	out.assign(_unlocks.values())
	return out

## Local upgrades applicable to this module's type and currently unlocked
## globally. Still includes maxed-out / unaffordable ones - the module itself
## (can_apply_local_upgrade) decides purchasability from its per-instance tiers.
func get_local_upgrade_catalog(module: ModuleBase) -> Array[LocalUpgradeData]:
	var out: Array[LocalUpgradeData] = []
	if module == null:
		return out
	for upgrade: LocalUpgradeData in _local_upgrades.values():
		if upgrade.matches_module(module.module_data) and upgrade.is_globally_unlocked():
			out.append(upgrade)
	return out

func is_unlocked(unlock: UnlockData) -> bool:
	return unlock != null and _unlocked_ids.has(unlock.id)

func is_module_granted(module: ModuleData) -> bool:
	return _granted_modules.has(module)

func get_unlock_by_id(id: StringName) -> UnlockData:
	return _unlocks.get(id)

func get_local_upgrade_by_id(id: StringName) -> LocalUpgradeData:
	return _local_upgrades.get(id)

## True if every (non-null) prerequisite of this unlock is already owned.
func prerequisites_met(unlock: UnlockData) -> bool:
	if unlock == null:
		return false
	for prereq: UnlockData in unlock.prerequisites:
		# Null entries are placeholders in authored data - ignore them.
		if prereq != null and not is_unlocked(prereq):
			return false
	return true

## True if the station tier is high enough to purchase this node (WI-26). A
## node's min_tier is authored on the .tres (default 1 = always available).
func meets_tier(unlock: UnlockData) -> bool:
	return unlock != null and unlock.available_at_tier(current_tier)

## Purchasable = not already owned, tier reached, all prerequisites owned, affordable.
func can_unlock(unlock: UnlockData) -> bool:
	if unlock == null or is_unlocked(unlock):
		return false
	return meets_tier(unlock) and prerequisites_met(unlock) and unlock.can_afford()

## Is there anything the player could buy right now? The predicate behind the R&D
## console button's readiness dot (WI-50), which the console used to recompute
## from `can_unlock` over the whole catalog itself.
##
## It belongs here rather than in the console: it is a question about the tech
## tree, the manager already owns every term in it, and a second consumer - the
## panel's own header - would otherwise write the same loop again.
func has_affordable_unlock() -> bool:
	for unlock: UnlockData in _unlocks.values():
		if can_unlock(unlock):
			return true
	return false

## The tier the R&D panel opens at - [method UnlockData.research_opens_at] over
## the loaded catalog, mods included. Ownership plays no part, so buying out a
## tier can never shut the panel again.
func research_opens_at_tier() -> int:
	return UnlockData.research_opens_at(get_all_unlocks())

## How many of a tree's nodes are researched, as `[done, total]`. The R&D panel's
## per-tab subtitle; here because "which unlocks are in this tree" is catalog
## state and the panel should not have to re-scan for a headline.
func tree_progress(tree_id: StringName) -> Vector2i:
	var done: int = 0
	var total: int = 0
	for unlock: UnlockData in _unlocks.values():
		if unlock.tree_id != tree_id:
			continue
		total += 1
		if is_unlocked(unlock):
			done += 1
	return Vector2i(done, total)

# --- mutation -------------------------------------------------------------

func try_unlock(unlock: UnlockData) -> bool:
	if not can_unlock(unlock):
		return false
	unlock.withdraw_cost()
	_unlocked_ids[unlock.id] = true
	for effect: UnlockEffect in unlock.effects:
		if effect != null:
			effect.apply(self, unlock)
	SignalBus.global_unlock_changed.emit(unlock)
	if auto_persist:
		save_to_file()
	return true
	
## Set unlocked without going through cost or prereq checks (starting nodes, or
## a future load-from-save path).
func force_unlock(unlock: UnlockData) -> void:
	if unlock == null or is_unlocked(unlock):
		return
	_unlocked_ids[unlock.id] = true
	for effect: UnlockEffect in unlock.effects:
		if effect != null:
			effect.apply(self, unlock)
	SignalBus.global_unlock_changed.emit(unlock)

# --- station tiers (WI-26) ----------------------------------------------------

func get_tier_data(tier: int) -> TierData:
	return _tiers.get(tier)

func current_tier_data() -> TierData:
	return _tiers.get(current_tier)

## Highest defined tier - the cap, past which no advancement happens.
func max_tier() -> int:
	var top: int = 1
	for tier: int in _tiers:
		top = maxi(top, tier)
	return top

func is_max_tier() -> bool:
	return current_tier >= max_tier()

## Units exported so far toward the current tier's goal for `resource_id`.
func export_progress_for(resource_id: StringName) -> int:
	return _export_progress.get(resource_id, 0)

## How many built modules currently carry `tag`. Used both by the goal check
## (at least one per checklist tag) and by the inspector's checklist targeting.
func built_module_count_with_tag(tag: String) -> int:
	var count: int = 0
	for module: ModuleBase in _constructed_modules():
		if module.module_data != null and module.module_data.tags.has(tag):
			count += 1
	return count

## True when every export goal is met AND at least one built module exists for
## each inspection checklist tag (so accepting can't instant-fail on a missing
## facility - WI-26 edge case). Vacuously false at the cap tier (empty goals, but
## advancement is separately gated by is_max_tier).
func tier_goals_met() -> bool:
	var data: TierData = current_tier_data()
	if data == null:
		return false
	var tag_counts: Dictionary = {}
	for tag: String in data.inspection_tags:
		tag_counts[tag] = built_module_count_with_tag(tag)
	return data.goals_reached(_export_progress, tag_counts)

## Accumulates exported goods against the current tier's goals (SignalBus hook).
## Counts every export additively; overflow past a goal is harmless (display caps).
func _on_resources_exported(resource: ResourceData, amount: int) -> void:
	if resource == null or amount <= 0 or resource.id == &"":
		return
	var data: TierData = current_tier_data()
	# Only track resources this tier actually asks for - keeps progress bounded
	# and the tier panel uncluttered.
	if data == null or not data.export_goals.has(resource.id):
		return
	_export_progress[resource.id] = _export_progress.get(resource.id, 0) + amount
	SignalBus.station_tier_progress_changed.emit()

## Advances the station one tier (a passed inspection or the tier_up cheat).
## Resets export progress to the new tier's goals and, on the FIRST promotion
## (tier 1 -> 2), switches on WI-25's recurring costs. No-op at the cap.
func advance_tier() -> void:
	if is_max_tier():
		return
	var was_first: bool = current_tier == 1
	current_tier += 1
	_export_progress.clear()
	_inspection_cooldown_cycles = 0
	if was_first and Global.economy_manager != null:
		Global.economy_manager.enable_recurring_costs()
	# Before the tier signal, so the build menu's re-derivation on it already
	# sees this tier's modules as buildable.
	_grant_tier_modules()
	var data: TierData = current_tier_data()
	var label: String = data.display_name if data != null and data.display_name != "" else str(current_tier)
	SignalBus.station_tier_changed.emit(current_tier)
	var body: String = ("This station is rated Tier %d%s. New licences follow; so does a heavier"
		+ " share of the Corporation's overheads.") \
		% [current_tier, (" — " + label) if label != "" else ""]
	# A module that appears in the build menu unannounced is easy to miss, and
	# nothing else tells the player a promotion brought one.
	var licensed: PackedStringArray = []
	if data != null:
		for module: ModuleData in data.granted_modules:
			if module != null:
				licensed.append(module.name)
	if not licensed.is_empty():
		body += " Licensed for construction from today: %s." % ", ".join(licensed)
	# WI-67: the one line a player who skipped the tutorial still sees about the
	# suits coming off. Only on the promotion that changes the rule - this body is
	# shared by every tier-up, and saying it at Tier 4 would be noise.
	if current_tier == 2:
		body += " Crew quarters are now held to habitable standards, and your crew will" \
			+ " expect habitable interior conditions."
	AlertManager.transmit(&"tier_promoted", AlertData.Priority.HIGH,
		"Station promoted to Tier %d" % current_tier, label,
		&"arc", InspectionRunner.ARC_SENDER, body, &"comms")
	# Nudge every listener that gates on tier (unlock cards, tier panel).
	SignalBus.station_tier_progress_changed.emit()

# --- inspection lifecycle (WI-26, player-initiated since WI-57) ---------------

## Once per cycle: tick the cooldown after a failed inspection.
##
## That is all this does now. It used to also roll `inspection_offer_chance_per_cycle`
## and fire an offer card, which meant the player met promotion as a coin flip that
## might not land on a cycle they happened to be ready for. WI-57 deletes the dice
## and keeps the readiness checks, which is what [method inspection_block] is.
## (No is_loading() guard: cycle_changed isn't replayed on load any more - WI-38 A3.)
func _on_cycle_changed(_cycle: int) -> void:
	if _inspection_cooldown_cycles <= 0:
		return
	_inspection_cooldown_cycles -= 1
	# The button prints the remaining cycles, so it has to repaint as they tick.
	SignalBus.station_tier_progress_changed.emit()

## Why `REQUEST INSPECTION` cannot be pressed right now, or READY.
##
## The readiness checks are the ones the deleted per-cycle roll used to make, in
## the same order and with the same meanings - the change is that they now produce
## a *sentence on a button* instead of gating a random number.
func inspection_block() -> InspectionBlock:
	if is_max_tier():
		return InspectionBlock.MAX_TIER
	if _inspection_in_progress:
		return InspectionBlock.IN_PROGRESS
	if _inspection_cooldown_cycles > 0:
		return InspectionBlock.COOLING_DOWN
	var goals: Vector2i = export_goal_progress()
	if goals.x < goals.y:
		return InspectionBlock.GOALS_UNMET
	# Exports are all in but a checklist facility is missing - the tour would
	# instant-fail on arrival, which is the WI-26 edge case this check exists for.
	if missing_inspection_tag() != "":
		return InspectionBlock.FACILITY_MISSING
	# The ARC ship needs a bay; no bay means no way to run the tour.
	if Global.trader_manager == null or Global.trader_manager.find_trade_bay() == null:
		return InspectionBlock.NO_BAY
	return InspectionBlock.READY

func can_request_inspection() -> bool:
	return inspection_block() == InspectionBlock.READY

## Export goals reached out of the total this tier asks for, as `[met, total]`.
## The `n OF m EXPORT GOALS MET` figure on the disabled button.
func export_goal_progress() -> Vector2i:
	var data: TierData = current_tier_data()
	if data == null:
		return Vector2i.ZERO
	var met: int = 0
	var total: int = 0
	for resource_id: StringName in data.export_goals:
		total += 1
		if export_progress_for(resource_id) >= int(data.export_goals[resource_id]):
			met += 1
	return Vector2i(met, total)

## The first checklist tag this station has no built module for, or "". The
## inspector tours one module per tag, so a missing one is a guaranteed fail.
func missing_inspection_tag() -> String:
	var data: TierData = current_tier_data()
	if data == null:
		return ""
	for tag: String in data.inspection_tags:
		if built_module_count_with_tag(tag) <= 0:
			return tag
	return ""

## Cycles until ARC will consider another request.
func inspection_cooldown_remaining() -> int:
	return _inspection_cooldown_cycles

## Docks the ARC ship and starts the tour - the `REQUEST INSPECTION` button's
## action since WI-57, called directly rather than through an event card's Accept
## choice. Aborts harmlessly if the bay vanished between the button being painted
## and pressed.
##
## Deliberately **not** gated on [method can_request_inspection]: the button asks
## first, and `Cheats.start_inspection` is supposed to be able to skip the ladder.
## The bay check stays here because it is not a gate, it is the one precondition
## the runner physically cannot do without.
func begin_inspection() -> void:
	if _inspection_in_progress:
		return
	var bay: ModuleBase = Global.trader_manager.find_trade_bay() if Global.trader_manager != null else null
	if bay == null:
		# No cooldown here any more (WI-57). It made sense when this was the Accept
		# branch of an offer - the offer had been consumed - but the player now
		# presses a button that says NO DOCKING BAY when there is none, so the only
		# way to reach this is a bay lost between the paint and the press. Charging
		# two cycles for that would be a penalty for something they did not do.
		AlertManager.raise_alert(&"inspection_no_bay", AlertData.Priority.HIGH,
			"ARC inspection postponed",
			"No docking bay to receive the inspector · ask again once one is built",
			null, &"comms")
		SignalBus.station_tier_progress_changed.emit()
		return
	var data: TierData = current_tier_data()
	var checklist: Array[String] = []
	if data != null:
		checklist.assign(data.inspection_tags)
	_inspection_in_progress = true
	var runner := InspectionRunner.new()
	runner.ship_scene = inspection_ship_scene
	runner.inspector_scene = inspector_pawn_scene
	add_child(runner)
	runner.setup(bay, checklist, inspection_dwell_hours, inspection_health_fail_threshold)
	runner.begin()
	SignalBus.station_tier_progress_changed.emit()

## Called by InspectionRunner when the tour completes successfully.
func on_inspection_passed() -> void:
	_inspection_in_progress = false
	advance_tier()

## Called by InspectionRunner on any fail (harmed, ejected, unreachable target).
func on_inspection_failed(_reason: String) -> void:
	_inspection_in_progress = false
	_inspection_cooldown_cycles = inspection_reoffer_cooldown_cycles
	SignalBus.station_tier_progress_changed.emit()

## Grants every module licensed by a tier at or below the current one
## ([member TierData.granted_modules]). Idempotent - [method grant_module] skips a
## module already granted - so it runs wherever the tier is set: at boot, on a
## promotion, and after a load has cleared the granted set and restored the tier.
func _grant_tier_modules() -> void:
	var ladder: Array[TierData] = []
	ladder.assign(_tiers.values())
	for module: ModuleData in TierData.modules_granted_through(ladder, current_tier):
		grant_module(module)

## Called by GrantModuleEffect and by tier grants. Marks a module buildable and
## notifies its UI.
func grant_module(module: ModuleData) -> void:
	if module == null or _granted_modules.has(module):
		return
	_granted_modules[module] = true
	# The build-menu button group listens to this to reveal the button.
	module.module_lock_changed.emit(true)

## Called by StatModifierEffect. Registers a global modifier and broadcasts it to
## every already-constructed module that matches.
func register_global_modifier(tags: Array[String], stat: StringName, op: StatModifiers.Op, value: float, source: StringName) -> void:
	if _global_modifiers.has(source):
		return
	var mod := GlobalStatMod.new()
	mod.tags = tags.duplicate()
	mod.stat = stat
	mod.op = op
	mod.value = value
	mod.source = source
	_global_modifiers[source] = mod
	for module: ModuleBase in _constructed_modules():
		if mod.matches(module.module_data):
			module.stat_modifiers.add_modifier(mod.stat, mod.op, mod.value, mod.source)

func unregister_global_modifier(source: StringName) -> void:
	if not _global_modifiers.erase(source):
		return
	for module: ModuleBase in _constructed_modules():
		module.stat_modifiers.remove_source(source)

## Live query on build: apply every active global modifier this module qualifies
## for. Call once, when the module becomes constructed.
func apply_global_modifiers(module: ModuleBase) -> void:
	if module == null:
		return
	for mod: GlobalStatMod in _global_modifiers.values():
		if mod.matches(module.module_data):
			module.stat_modifiers.add_modifier(mod.stat, mod.op, mod.value, mod.source)

func _constructed_modules() -> Array[ModuleBase]:
	var out: Array[ModuleBase] = []
	for node: Node in get_tree().get_nodes_in_group(Groups.MODULE):
		if node is ModuleBase and (node as ModuleBase).is_complete():
			out.append(node)
	return out

# --- persistence ----------------------------------------------------------
# Only the set of unlocked ids is stored; granted modules and global stat
# modifiers are derived by re-running each unlock's effects on load, plus the
# grants of every tier up to the saved one. A central
# save system can call get_save_data()/load_save_data() and fold the result into
# its own file; the *_file helpers are a self-contained convenience.

func get_save_data() -> Dictionary:
	var ids: Array[String] = []
	for id: StringName in _unlocked_ids:
		ids.append(String(id))
	# Tier state (WI-26): current tier, per-goal export progress (id-keyed, so
	# JSON-safe), and the re-offer cooldown. An in-progress inspection is NOT
	# saved - it cancels cleanly on load and the offer re-rolls (WI-26 v1).
	var progress: Dictionary = {}
	for resource_id: StringName in _export_progress:
		progress[String(resource_id)] = _export_progress[resource_id]
	return {
		"version": SAVE_VERSION,
		"unlocked": ids,
		"tier": current_tier,
		"export_progress": progress,
		"inspection_cooldown": _inspection_cooldown_cycles,
	}

func load_save_data(data: Dictionary) -> void:
	_clear_unlock_state()
	for id_str: String in data.get("unlocked", []):
		var unlock := get_unlock_by_id(StringName(id_str))
		if unlock != null:
			# force_unlock re-marks it owned and re-runs effects, regenerating
			# granted modules and global modifiers.
			force_unlock(unlock)
		else:
			push_warning("Unknown unlock id in save, skipping: " + id_str)
	# Tier state (WI-26). Pre-WI-26 saves lack these keys -> tier 1, fresh goals,
	# no cooldown. Already-purchased nodes above the new tier stay purchased
	# (force_unlock above ignores min_tier); the tier gate only blocks NEW buys.
	current_tier = int(data.get("tier", 1))
	_export_progress.clear()
	var progress: Dictionary = data.get("export_progress", {})
	for id_str: String in progress:
		_export_progress[StringName(id_str)] = int(progress[id_str])
	_inspection_cooldown_cycles = int(data.get("inspection_cooldown", 0))
	# _clear_unlock_state dropped the tier grants with the rest; the saved tier
	# is all they need to come back.
	_grant_tier_modules()
	SignalBus.station_tier_changed.emit(current_tier)

## Reset all owned/derived global-unlock state. Intended for a fresh load; if
## called mid-game it also strips applied global modifiers from live modules and
## re-hides granted module buttons.
func _clear_unlock_state() -> void:
	for source: StringName in _global_modifiers.keys():
		for module: ModuleBase in _constructed_modules():
			module.stat_modifiers.remove_source(source)
	_global_modifiers.clear()
	for module_data: ModuleData in _granted_modules.keys():
		module_data.module_lock_changed.emit(false)
	_granted_modules.clear()
	_unlocked_ids.clear()

func save_to_file(path: String = SAVE_PATH) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not open unlock save for writing: " + path)
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(get_save_data()))
	file.close()
	return OK

## Returns true if a save was found and applied.
func load_from_file(path: String = SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Could not open unlock save for reading: " + path)
		return false
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_warning("Unlock save file is malformed: " + path)
		return false
	load_save_data(parsed)
	return true
