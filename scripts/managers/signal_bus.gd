extends Node


@warning_ignore("unused_signal")
signal module_added(new_module: ModuleBase)
@warning_ignore("unused_signal")
signal module_removed(removed_module: ModuleBase)
@warning_ignore("unused_signal")
signal module_group_changed(module: ModuleBase)
@warning_ignore("unused_signal")
signal special_path_connection_added(from: Node2D, group: StringName)
@warning_ignore("unused_signal")
signal module_path_connection_removed(from: ModuleBase, to: ModuleBase)
@warning_ignore("unused_signal")
signal module_structure_connection_added(from: ModuleBase, to: ModuleBase, distance: float)
@warning_ignore("unused_signal")
signal module_structure_connection_removed(from: ModuleBase, to: ModuleBase)
@warning_ignore("unused_signal")
signal module_selected(selected_module: ModuleBase)
@warning_ignore("unused_signal")
signal set_up_trade(trade_component: TradeComponent)
@warning_ignore("unused_signal")
signal global_unlock_changed(unlock: UnlockData)
@warning_ignore("unused_signal")
signal module_upgraded(module: ModuleBase)
@warning_ignore("unused_signal")
signal module_breach_started(module: ModuleBase)
@warning_ignore("unused_signal")
signal module_breach_sealed(module: ModuleBase)
## Module durability (WI-24). damaged fires on every hp loss (amount > 0),
## repaired on every hp gain, destroyed the instant a non-truss module hits 0
## (right before remove_module tears it down). Truss never emits destroyed - it
## enters its damaged state instead so the station can't split.
@warning_ignore("unused_signal")
signal module_damaged(module: ModuleBase, amount: float)
@warning_ignore("unused_signal")
signal module_repaired(module: ModuleBase, amount: float)
@warning_ignore("unused_signal")
signal module_destroyed(module: ModuleBase)
## Pirate raids (WI-32). raid_started fires when a wave spawns (carries its
## strength); raid_ended when the last ship leaves - by payoff, flight, or
## destruction - carrying how the raid resolved so the banner/alerts can react.
## ship_destroyed fires the instant a pirate ship hits 0 HP (before it frees), so
## salvage drops and kill alerts hang off one place.
@warning_ignore("unused_signal")
signal raid_started(strength: float)
@warning_ignore("unused_signal")
signal raid_ended(outcome: StringName)
@warning_ignore("unused_signal")
signal ship_destroyed(ship: Node2D)
## Raid banner state changed (WI-32): ship count, payoff price, or warning phase
## moved. The raid banner refreshes off this without a full start/end cycle.
@warning_ignore("unused_signal")
signal raid_state_changed
@warning_ignore("unused_signal")
signal pawn_critical_need(pawn: PawnBase, need: StringName)
@warning_ignore("unused_signal")
signal crew_hired(pawn: PawnBase)
## A pawn's skill just leveled up (WI-22) - for UI flavor / alerts.
@warning_ignore("unused_signal")
signal pawn_skill_leveled(pawn: PawnBase, skill: StringName, new_level: int)
## The recruitment candidate pool changed (WI-22): refreshed on a trader visit
## or a candidate hired. The open recruitment window re-reads on this.
@warning_ignore("unused_signal")
signal hire_candidates_changed
@warning_ignore("unused_signal")
signal crew_resigning(pawn: PawnBase, grace_hours: float)
@warning_ignore("unused_signal")
signal crew_resignation_cancelled(pawn: PawnBase)
## The grace window expired: the decision is final, CrewManager sends them off.
@warning_ignore("unused_signal")
signal crew_resigned(pawn: PawnBase)
## The pawn is actually gone (despawned at the bay or by escape pod).
@warning_ignore("unused_signal")
signal crew_departed(pawn: PawnBase)
## Game over (WI-07/WI-25): carries a player-facing reason so the end screen can
## explain how the run ended (crew abandonment, ARC repossession, ...). "" =
## keep the screen's default text.
@warning_ignore("unused_signal")
signal game_over(reason: String)
## Any economy ledger/loan/toggle state changed (WI-25). The economy page
## refreshes off this while open; charges, skims, and settlement all emit it.
@warning_ignore("unused_signal")
signal economy_changed
## The game world is up and ready to play (WI-18): emitted by Main once the
## starting station has spawned (new game) or SaveManager has applied a pending
## load. A single defined "game ready" moment for systems that need one
## (deterministic tests, loading screens) instead of guessing at boot timing.
@warning_ignore("unused_signal")
signal game_bootstrapped
## Generic station-wide alert text for the UI alerts strip.
@warning_ignore("unused_signal")
signal station_alert(message: String)
@warning_ignore("unused_signal")
signal trader_arrived(trader: TraderData)
@warning_ignore("unused_signal")
signal trader_departed(trader: TraderData)
## A random event fired (WI-13). Card events queue on EventManager; the UI
## shows them sequentially. Notification-only events already applied.
@warning_ignore("unused_signal")
signal event_triggered(event: EventData)
@warning_ignore("unused_signal")
signal contract_offered(contract: ContractData)
@warning_ignore("unused_signal")
signal contract_accepted(contract: ContractData)
@warning_ignore("unused_signal")
signal contract_completed(contract: ContractData)
@warning_ignore("unused_signal")
signal contract_failed(contract: ContractData)
## Goods physically left the station (WI-26): trader sell fulfillment and
## contract deliveries both emit this the moment stock leaves the export bin.
## UnlockManager accumulates it against the current station tier's export goals.
@warning_ignore("unused_signal")
signal resources_exported(resource: ResourceData, amount: int)
## The station tier advanced (WI-26): a passed ARC inspection (or the tier_up
## cheat) bumped UnlockManager.current_tier. The unlock panel re-evaluates
## tier-locked nodes off this; later WIs read current_tier for tier-gated systems.
@warning_ignore("unused_signal")
signal station_tier_changed(new_tier: int)
## Export-goal progress or inspection state changed (WI-26): the tier panel in
## the unlock screen refreshes off this without a full tier-up.
@warning_ignore("unused_signal")
signal station_tier_progress_changed
## Visitors (WI-33). arrived fires when a guest disembarks; departed when one
## walks out, carrying whether it left happy (reputation moved). visitors_changed
## is the coarse "something about the visitor economy moved" nudge the UI reads
## (count, reputation, arrival/departure) without caring which.
@warning_ignore("unused_signal")
signal visitor_arrived(pawn: PawnBase)
@warning_ignore("unused_signal")
signal visitor_departed(pawn: PawnBase, happy: bool)
@warning_ignore("unused_signal")
signal visitors_changed



#signal node_grouped(node, new_group: String)
#signal node_ungrouped(node, old_group: String)
#
#func add_node_to_group(node: Node, group: String, persistent: bool = false) -> void:
	#node.add_to_group(group, persistent)
	#node_grouped.emit(node, group)
	#
#func remove_node_from_group(node: Node, group: String) -> void:
	#node.remove_from_group(group)
	#node_ungrouped.emit(node, group)
