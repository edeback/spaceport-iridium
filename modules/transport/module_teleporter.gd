@tool
class_name ModuleTeleporter
extends ModuleBase

func _ready() -> void:
	add_to_group("teleporters")
	super()

func make_connections() -> void:
	super.make_connections()
	Global.path_manager.graph.change_vertex_group(self, "teleporters")
