extends Node


@warning_ignore("unused_signal")
signal module_added(new_module: ModuleBase)
@warning_ignore("unused_signal")
signal module_removed(removed_module: ModuleBase)
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
