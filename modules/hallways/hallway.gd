@tool
extends ModuleBase


enum CorrodorType {NONE, HALLWAY, SHAFT, HALLWAY_AND_SHAFT}

@export var corrodor_dictionary: Dictionary[CorrodorType, Node2D] = {}

var current_type: CorrodorType = CorrodorType.NONE

func get_sprite(new_horizontal: bool = true) -> Sprite2D:
	if new_horizontal:
		return corrodor_dictionary[CorrodorType.HALLWAY].get_node("Sprite2D")
	return corrodor_dictionary[CorrodorType.SHAFT].get_node("Sprite2D")

func overlap_module(new_module: ModuleData, new_horizontal: bool) -> void:
	if new_module == module_data:
		apply_corrodor_type(CorrodorType.HALLWAY if new_horizontal else CorrodorType.SHAFT)

func _ready() -> void:
	apply_corrodor_type(CorrodorType.HALLWAY if is_horizontal else CorrodorType.SHAFT)
	super()
	
func apply_corrodor_type(new_type: CorrodorType) -> void:
	if new_type == current_type:
		return
	if current_type == CorrodorType.HALLWAY_AND_SHAFT:
		return
	if current_type == CorrodorType.NONE:
		current_type = new_type
		corrodor_dictionary[new_type].visible = true
		return
	corrodor_dictionary[current_type].visible = false
	current_type = CorrodorType.HALLWAY_AND_SHAFT
	corrodor_dictionary[current_type].visible = true
