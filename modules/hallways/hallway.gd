@tool
class_name CorridorModule
extends ModuleBase

enum CorridorType { NONE, HALLWAY, SHAFT, HALLWAY_AND_SHAFT }

@export var corridor_dictionary: Dictionary[CorridorType, CorridorData] = {}

@export var current_type: CorridorType = CorridorType.NONE:
	set(new_type):
		current_type = new_type
		queue_redraw()
		
@export var door: Node2D

func get_sprite() -> Sprite2D:
	if current_type != CorridorType.NONE:
		return corridor_dictionary[current_type].get_node("Sprite2D")
	if is_horizontal:
		return corridor_dictionary[CorridorType.HALLWAY].get_node("Sprite2D")
	return corridor_dictionary[CorridorType.SHAFT].get_node("Sprite2D")

func overlap_module(new_module: ModuleData, new_horizontal: bool) -> bool:
	if new_module == module_data:
		apply_corridor_type(CorridorType.HALLWAY if new_horizontal else CorridorType.SHAFT)
	return true

func _ready() -> void:
	apply_corridor_type(CorridorType.HALLWAY if is_horizontal else CorridorType.SHAFT)
	for corridor_data: CorridorData in corridor_dictionary.values():
		var sub_sprite: Sprite2D = corridor_data.get_node("Sprite2D")
		if (sub_sprite && sub_sprite.material != null):
			sub_sprite.material = sub_sprite.material.duplicate()
	super()
	
func apply_corridor_type(new_type: CorridorType) -> void:
	if new_type == current_type:
		return
	if current_type == CorridorType.HALLWAY_AND_SHAFT:
		return
	if current_type == CorridorType.NONE:
		current_type = new_type
		corridor_dictionary[new_type].visible = true
		return
	corridor_dictionary[current_type].visible = false
	current_type = CorridorType.HALLWAY_AND_SHAFT
	corridor_dictionary[current_type].visible = true
	make_connections()

func get_connection_points() -> Array[Vector2i]:
	if current_type == CorridorType.NONE:
		return connection_points
	return corridor_dictionary[current_type].connection_points

func connect_door_to(other_module: ModuleBase) -> void:
	super(other_module)
	door.visible = true

func disconnect_door_to(other_module: ModuleBase) -> void:
	super(other_module)
	door.visible = false
