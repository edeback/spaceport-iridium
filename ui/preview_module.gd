class_name PreviewModule
extends Node2D

@onready var sprite: Sprite2D = $Sprite2D
@export var default_texture: Texture2D

const SHADER_PARAM_PLACEABLE = "PLACEABLE"

var module_size: Vector2i
var connection_points: Array[Vector2i]
var internal_points: Array[Vector2i]
var must_be_clear_points: Array[Vector2i]
var module_layer: WorldManager.StructureLayer
var module_connection_layer: WorldManager.StructureLayer
var last_cell: Vector2i
var offset: Vector2 = Vector2(0, 0)
var is_horizontal: bool = true:
	set(new_value):
		if new_value != is_horizontal:
			is_horizontal = new_value
			if module_data != null:
				update_from_module_data()

var module_data: ModuleData:
	get:
		return module_data
	set(new_value):
		if module_data != new_value:
			module_data = new_value
			if module_data == null:
				sprite.texture = default_texture
				sprite.visible = false
			else:
				update_from_module_data()

var flipped: bool:
	set(new_value):
		if flipped != new_value:
			flipped = new_value
			update_from_module_data()

var can_place: bool = true:
	get:
		return can_place
	set(new_value):
		if can_place != new_value:
			can_place = new_value
			_update_shader()

func update_from_module_data() -> void:
	var temp_scene: PackedScene =  module_data.scene
	if flipped and module_data.flippable:
		temp_scene = module_data.flipped_scene
	var temp_module: ModuleBase = temp_scene.instantiate() as ModuleBase
	module_size = temp_module.size
	temp_module.is_horizontal = is_horizontal
	connection_points = temp_module.get_structure_component().connection_points
	internal_points = temp_module.get_structure_component().internal_points
	must_be_clear_points = temp_module.get_structure_component().must_be_clear_points
	module_layer = module_data.interaction_layer
	module_connection_layer = module_data.connection_layer
	var temp_sprite: Sprite2D = temp_module.get_sprite()
	sprite.texture = temp_sprite.texture
	sprite.offset = temp_sprite.offset
	sprite.region_enabled = temp_sprite.region_enabled
	sprite.region_rect = temp_sprite.region_rect
	sprite.transform = temp_sprite.transform
	sprite.centered = true
	sprite.visible = true
	sprite.flip_h = temp_sprite.flip_h
	sprite.flip_v = temp_sprite.flip_v
	offset = temp_module.offset.position
	%ErrorLabel.position.x = -offset.x
	%ErrorLabel.position.y = -offset.y - 32
	temp_module.queue_free()

func _update_shader() -> void:
	if (sprite && sprite.material != null):
		sprite.material.set_shader_parameter(SHADER_PARAM_PLACEABLE, can_place)


func update_placeable(module_cell: Vector2i, ignore_connections: bool = false) -> void:
	# Must be able to pay
	if !module_data.can_afford():
		%ErrorLabel.visible = true
		%ErrorLabel.text = "Can't afford!"
		can_place = false
		return
	# Footprint must not overlap
	if Global.world_manager.is_blocked(module_layer, module_cell, module_size):
		%ErrorLabel.visible = true
		%ErrorLabel.text = "Blocked!"
		can_place = false
		return
	for point: Vector2i in must_be_clear_points:
		if Global.world_manager.has_overlaps(module_layer, module_cell + point):
			%ErrorLabel.visible = true
			%ErrorLabel.text = "Blocked!"
			can_place = false
			return
	# Must be connected to at least one other module
	if ignore_connections:
		can_place = true
	else:
		can_place = _has_possible_connections(module_cell)
	if can_place:
		%ErrorLabel.visible = false
		last_cell = module_cell
	else:
		%ErrorLabel.visible = true
		%ErrorLabel.text = "Not connected to anything!"

func _has_possible_connections(module_cell: Vector2i) -> bool:
	# Explicit connection points
	for point in connection_points:
		var test_module: ModuleBase = Global.world_manager.get_module_by_cell(module_connection_layer, module_cell + point)
		if test_module != null:
			var struct_component: StructureComponent = test_module.get_structure_component()
			if struct_component != null:
				for internal_point in internal_points:
					if struct_component.can_connect_to(module_cell + internal_point):
						return true
	return false

func _ready() -> void:
	sprite.texture = default_texture
	if (sprite && sprite.material != null):
		sprite.material = sprite.material.duplicate()
