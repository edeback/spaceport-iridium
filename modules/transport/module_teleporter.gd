@tool
class_name ModuleTeleporter
extends ModuleBase

@export var teleporter_path_index: int = 0
@export var lightning_sprite: AnimatedSprite2D

func _ready() -> void:
	add_to_group("teleporters")
	super()

func make_connections() -> void:
	super()
	Global.path_manager.graph.change_vertex_group(self, "teleporters", teleporter_path_index)
	#var teleporter_node := Node2D.new()
	#add_child(teleporter_node)
	#get_path_component().path_points.get(teleporter_path_index)
	#teleporter_node.global_position = Vector2(get_path_component().path_points.get(teleporter_path_index)) + global_position
	#Global.path_manager.add_vertex(teleporter_node, false, "teleport")
	#Global.path_manager.add_connection(self, teleporter_node, 30)
	#get_path_component().manual_connection(teleporter_node, teleporter_path_index)

func has_custom_pathing() -> bool:
	return true

func traverse(_pawn: PawnBase, _path_edge: PathComponent.PathTraversalEdgeData) -> void:
	if _path_edge.edge_meta == &"run_teleporter":
		if _path_edge.start_index == teleporter_path_index:
			# Coming from teleportation
			lightning_sprite.visible = true
			lightning_sprite.play(&"teleport", -1, 1)
			await lightning_sprite.animation_finished
			lightning_sprite.visible = false
		else:
			# Starting teleportation
			lightning_sprite.visible = true
			lightning_sprite.play(&"teleport")
			await lightning_sprite.animation_finished
			lightning_sprite.visible = false

func path_enter(_pawn: PawnBase, _door: int, _meta: StringName) -> void:
	if _meta == &"teleporters" and _door >= 0:
		var new_position: Vector2 = global_position + Vector2(get_path_component().path_points[_door])
		_pawn.global_position = new_position

#func enter_module_from(pawn: PawnBase, _prev_module: ModuleBase = null) -> void:
	#super(pawn, _prev_module)
	#if _prev_module is ModuleTeleporter:
		#var new_position: Vector2 = global_position + Vector2(get_path_component().get_connection_point_from(_prev_module))
		#pawn.global_position = new_position
