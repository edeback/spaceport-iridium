@tool
class_name ModuleBase
extends Node2D

@export var sprite: Sprite2D
@onready var footprint: Area2D = $Offset/Footprint
@onready var nameplate: Label = $Offset/Sprite/Nameplate

@export var size: Vector2i = Vector2i(1, 1)
@export var show_debug: bool = true:
	set(new_show_debug):
		show_debug = new_show_debug
		queue_redraw()
@export var connection_points: Array[Vector2i]:
	set(new_points):
		connection_points = new_points
		queue_redraw()

var module_id: int = -1
var module_cell: Vector2i
var module_data: ModuleData
var components: Array[ComponentBase]

var module_connections = {}


const SHADER_PARAM_PREVIEW = "PREVIEW"
const SHADER_PARAM_PLACEABLE = "PLACEABLE"
const SHADER_PARAM_SELECTED = "SELECTED"

var previewing: bool = false:
	get:
		return previewing
	set(new_value):
		previewing = new_value
		_update_shader()

var can_place: bool = true:
	get:
		return can_place
	set(new_value):
		if can_place != new_value:
			can_place = new_value
			_update_shader()
			
var selected: bool = false:
	get:
		return selected
	set(new_value):
		if selected != new_value:
			selected = new_value
			_update_shader()
			SignalBus.module_selected.emit(self)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print(module_id)
	if (sprite && sprite.material != null):
		sprite.material = sprite.material.duplicate()
	_update_shader()
	if module_data != null:
		nameplate.text = module_data.name
	else:
		nameplate.text = ""
	SignalBus.module_added.emit(self)


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
	#if previewing:
		#can_place = _check_if_placeable()
	#else:
		#can_place = true
	#pass
	
func _physics_process(delta: float) -> void:
	pass
	
func _update_shader() -> void:
	if (sprite && sprite.material != null):
		sprite.material.set_shader_parameter(SHADER_PARAM_PREVIEW, previewing)
		sprite.material.set_shader_parameter(SHADER_PARAM_PLACEABLE, can_place)
		sprite.material.set_shader_parameter(SHADER_PARAM_SELECTED, selected)
		
func update_placeable() -> void:
	# Footprint must not overlap
	if Global.world_manager.has_overlaps(module_cell, size):
		can_place = false
		return
	# Must be connected to at least one other module
	can_place = _has_possible_connections()
	return 

func _has_possible_connections() -> bool:
	for point in connection_points:
		if Global.world_manager.has_overlaps(module_cell + point):
			return true
	return false

func _find_connections() -> Array[ModuleBase]:
	var connected_modules:Array[ModuleBase] = []
	for point in connection_points:
		for module in Global.world_manager.get_overlaps(module_cell + point):
			if module != self:
				connected_modules.append(module)
	return connected_modules
	
func make_connections() -> void:
	var connected_modules = _find_connections()
	for module in connected_modules:
		module_connections[module] = 1
		module.connect_to(self)
		SignalBus.module_connection_added.emit(module_id, module.module_id)

func remove_connections() -> void:
	for module in module_connections:
		Global.path_manager.astar.disconnect_points(module_id, module.module_id)
		module.disconnect_from(self)
		SignalBus.module_connection_removed.emit(module_id, module.module_id)
	module_connections.clear()

func connect_to(other_module: ModuleBase) -> void:
	module_connections[other_module] = 1
	
func disconnect_from(other_module: ModuleBase) -> void:
	module_connections.erase(other_module)
	
	
func _draw() -> void:
	if show_debug && Engine.is_editor_hint():
		for point in connection_points:
			draw_circle(Vector2(point * Vector2i(64, 64)) +  Vector2(32, 32), 16, Color.GREEN)
