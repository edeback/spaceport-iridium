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
signal pawn_critical_need(pawn: PawnBase, need: StringName)
@warning_ignore("unused_signal")
signal crew_hired(pawn: PawnBase)
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
@warning_ignore("unused_signal")
signal game_over
## Generic station-wide alert text for the UI alerts strip.
@warning_ignore("unused_signal")
signal station_alert(message: String)
@warning_ignore("unused_signal")
signal trader_arrived(trader: TraderData)
@warning_ignore("unused_signal")
signal trader_departed(trader: TraderData)



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
