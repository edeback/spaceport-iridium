class_name PreviewModule
extends Node2D

@onready var sprite: Sprite2D = $Sprite2D
@export var default_texture: Texture2D

const SHADER_PARAM_PLACEABLE = "PLACEABLE"

var module_size: Vector2i
var connection_points: Array[Vector2i]
var module_layer: WorldManager.InteractionLayer
var last_cell: Vector2i
var offset: Vector2 = Vector2(0, 0)
var is_horizontal: bool = true

var module_data: ModuleData:
	get:
		return module_data
	set(new_value):
		module_data = new_value
		if module_data == null:
			sprite.texture = default_texture
			sprite.visible = false
		else:
			var temp_module: ModuleBase = module_data.scene.instantiate() as ModuleBase
			module_size = temp_module.size
			temp_module.is_horizontal = is_horizontal
			connection_points = temp_module.get_structure_component().connection_points
			module_layer = module_data.interaction_layer
			var temp_sprite: Sprite2D = temp_module.get_sprite()
			sprite.texture = temp_sprite.texture
			sprite.offset = temp_sprite.offset
			sprite.region_enabled = temp_sprite.region_enabled
			sprite.region_rect = temp_sprite.region_rect
			sprite.transform = temp_sprite.transform
			sprite.centered = true
			sprite.visible = true
			offset = temp_module.offset.position
			temp_module.queue_free()
		

var can_place: bool = true:
	get:
		return can_place
	set(new_value):
		if can_place != new_value:
			can_place = new_value
			_update_shader()

func _update_shader() -> void:
	if (sprite && sprite.material != null):
		sprite.material.set_shader_parameter(SHADER_PARAM_PLACEABLE, can_place)


func update_placeable(module_cell: Vector2i, ignore_connections: bool = false) -> void:
	# Must be in right layer
	if Global.world_manager.active_layer != module_layer:
		can_place = false
		return
	# Footprint must not overlap
	if Global.world_manager.is_blocked(module_layer, module_cell, module_size):
		can_place = false
		return
	# Must be connected to at least one other module
	if ignore_connections:
		can_place = true
	else:
		can_place = _has_possible_connections(module_cell)
	if can_place:
		last_cell = module_cell

func _has_possible_connections(module_cell: Vector2i) -> bool:
	# Explicit connection points
	for point in connection_points:
		if Global.world_manager.has_overlaps(module_layer, module_cell + point):
			return true
	
	# Cross-layer connections (overlaps)
	return Global.world_manager.has_overlaps(1 - module_layer, module_cell, module_size)

func _ready() -> void:
	sprite.texture = default_texture
	if (sprite && sprite.material != null):
		sprite.material = sprite.material.duplicate()
