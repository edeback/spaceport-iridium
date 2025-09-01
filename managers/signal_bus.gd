extends Node


signal module_added(new_module: ModuleBase)
signal module_removed(removed_module: ModuleBase)
signal module_connection_added(from: ModuleBase, to: ModuleBase, distance: float) # todo maybe: distance calculated dynamically
signal module_connection_removed(from: ModuleBase, to: ModuleBase)
signal module_selected(selected_module: ModuleBase)





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
