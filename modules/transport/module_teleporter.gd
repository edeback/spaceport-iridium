@tool
class_name ModuleTeleporter
extends ModuleBase

func _ready() -> void:
	add_to_group("teleporters")
	super()

func make_connections() -> void:
	super.make_connections()
	Global.path_manager.graph.change_vertex_group(self, "teleporters")
	#for node: ModuleTeleporter in get_tree().get_nodes_in_group("teleporters"):
		#if node != null and node != self:
			#SignalBus.module_path_connection_added.emit(self, node, 1)
