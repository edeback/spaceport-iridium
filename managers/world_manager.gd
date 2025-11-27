class_name WorldManager
extends Node

enum InteractionLayer { MODULE, CORRIDOR }

class LayerData:
	var canvas: CanvasLayer
	var cell_to_module: Dictionary[Vector2i, ModuleBase] = {}
	#var id_to_module: Dictionary[int, ModuleBase] = {}

@export var start_module: ModuleData
# Only used for setup. Use layer_data at runtime
@export var module_layers: Dictionary[InteractionLayer, CanvasLayer]

@export var replacement_module: ModuleData

var layer_data: Dictionary[InteractionLayer, LayerData]

var last_id : int = 0
#var cell_to_module: Dictionary[Vector2i, ModuleBase] = {}
var id_to_module: Dictionary[int, ModuleBase] = {}
var active_layer: InteractionLayer = InteractionLayer.MODULE:
	set(new_layer):
		if active_layer != new_layer:
			active_layer = new_layer
			active_layer_changed.emit(active_layer)
			
var modules_by_type: Dictionary = {}
		
signal active_layer_changed(new_layer: InteractionLayer)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.world_manager = self
	for layer in module_layers:
		var new_data: LayerData = LayerData.new()
		new_data.canvas = module_layers[layer]
		layer_data[layer] = new_data
	_startup()
	pass # Replace with function body.

func _startup() -> void:
	await get_tree().create_timer(1.0).timeout
	add_module(start_module, Vector2i(15,8))
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _get_next_id() -> int:
	last_id = last_id + 1
	return last_id
	
func get_module_by_cell_active_layer(cell: Vector2i) -> ModuleBase:
	return get_module_by_cell(active_layer, cell)

func get_module_by_cell(layer: InteractionLayer, cell: Vector2i) -> ModuleBase:
	return layer_data[layer].cell_to_module.get(cell)
	
func get_modules_by_type(module_data: ModuleData) -> Array[ModuleBase]:
	return modules_by_type.get_or_add(module_data)
	
func get_nearest_module_by_type(position: Vector2, module_data: ModuleData) -> ModuleBase:
	var dist: float = -1
	var closest_module: ModuleBase = null
	for module: ModuleBase in get_modules_by_type(module_data):
		var new_dist: float = module.position.distance_squared_to(position)
		if dist < 0 or new_dist < dist:
			dist = new_dist
			closest_module = module
	return closest_module

func add_module(module_data: ModuleData, cell: Vector2i, is_horizontal: bool = true) -> void:
	var new_module: ModuleBase = module_data.scene.instantiate()
	new_module.get_instance_id()
	if is_blocked(module_data.interaction_layer, cell, new_module.size):
		print("Warning, attempted to add module where one exists at: " + str(cell))
		new_module.free()
		return
	# Note this only works for one-cell modules but right now only matters for those
	var cancel_add: bool = false
	for existing_module: ModuleBase in get_overlaps(module_data.interaction_layer, cell, new_module.size):
		if existing_module != null:
			cancel_add = cancel_add or existing_module.overlap_module(module_data, is_horizontal)
	if cancel_add:
		new_module.free()
		return
	new_module.position = Vector2(cell * Global.CELL_SIZE)
	var module_id: int = _get_next_id()
	new_module.module_id = module_id
	new_module.module_cell = cell
	new_module.module_data = module_data
	new_module.is_horizontal = is_horizontal
	module_layers[module_data.interaction_layer].add_child(new_module)
	for x in new_module.size.x:
		for y in new_module.size.y:
			layer_data[module_data.interaction_layer].cell_to_module[cell + Vector2i(x, y)] = new_module
	id_to_module[module_id] = new_module
	var module_array: Array = modules_by_type.get_or_add(module_data, [])
	module_array.append(new_module)
	new_module.make_connections()

func remove_module(module: ModuleBase) -> bool:
	if module.can_delete == false:
		return false
	var replacement_location: Vector2i = module.module_cell
	var replacement_size: Vector2i = module.size
	module.pre_delete()
	SignalBus.module_removed.emit(module)
	module.remove_connections()
	for x in module.size.x:
		for y in module.size.y:
			layer_data[module.module_data.interaction_layer].cell_to_module.erase(module.module_cell + Vector2i(x,y))
	id_to_module.erase(module.module_id)
	layer_data[module.module_data.interaction_layer].canvas.remove_child(module)
	var module_array: Array = modules_by_type.get_or_add(module.module_data, [])
	module_array.erase(module)
	module.queue_free()
	if module.module_data != replacement_module and module.module_data.interaction_layer == InteractionLayer.MODULE:
		for x in replacement_size.x:
			for y in replacement_size.y:
				add_module(replacement_module, replacement_location + Vector2i(x,y))
	return true

func remove_module_by_cell_active_layer(cell: Vector2i) -> void:
	remove_module_by_cell(active_layer, cell)
	
func remove_module_by_cell(layer: InteractionLayer, cell: Vector2i) -> void:
	var module: ModuleBase = layer_data[layer].cell_to_module.get(cell)
	if module != null:
		remove_module(module)
		
func is_blocked(layer: InteractionLayer, cell: Vector2i, size: Vector2i = Vector2i(1,1)) -> bool:
	for x in size.x:
		for y in size.y:
			var module: ModuleBase = layer_data[layer].cell_to_module.get(cell + Vector2i(x, y))
			if module != null and module.blocks_building:
				return true
	return false

func has_overlaps(layer: InteractionLayer, cell: Vector2i, size: Vector2i = Vector2i(1,1)) -> bool:
	for x in size.x:
		for y in size.y:
			if layer_data[layer].cell_to_module.has(cell + Vector2i(x, y)):
				return true
	return false

func get_overlaps(layer: InteractionLayer, cell: Vector2i, size: Vector2i = Vector2i(1,1), max_values: int = 0) -> Array[ModuleBase]:
	# TODO: Typed dictionaries are in Godot 4.4! Maybe someday we'll get sets too!
	var overlaps: Array[ModuleBase] = []
	for x in size.x:
		for y in size.y:
			var overlap_module: ModuleBase = layer_data[layer].cell_to_module.get(cell + Vector2i(x, y))
			if overlap_module != null && !overlaps.has(overlap_module):
				overlaps.append(overlap_module)
				if max_values > 0:
					if overlaps.size() >= max_values:
						return overlaps
	return overlaps

func get_module_by_id(id: int) -> ModuleBase:
	return id_to_module.get(id)
	
func show_module_layer(layer: InteractionLayer) -> void:
	active_layer = layer
	for module_layer in module_layers:
		if module_layer == layer:
			module_layers[module_layer].visible = true
			var mod: CanvasModulate = module_layers[module_layer].get_node("CanvasModulate") as CanvasModulate
			mod.color.a = 1
		else:
			module_layers[module_layer].visible = true
			var mod: CanvasModulate = module_layers[module_layer].get_node("CanvasModulate") as CanvasModulate
			mod.color.a = 0.3

func set_module_layer_visibility(layer: InteractionLayer, visibility: bool) -> void:
	module_layers[layer].visible = visibility
	if visibility:
		active_layer = layer
	else:
		active_layer = InteractionLayer.MODULE
