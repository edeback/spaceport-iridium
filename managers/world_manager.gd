class_name WorldManager
extends Node

class LayerData:
	var canvas: CanvasLayer
	var cell_to_module: Dictionary[Vector2i, ModuleBase] = {}
	#var id_to_module: Dictionary[int, ModuleBase] = {}

@export var start_module: ModuleData
# Only used for setup. Use layer_data at runtime
@export var module_layers: Dictionary[ModuleBase.InteractionLayer, CanvasLayer]

var layer_data: Dictionary[ModuleBase.InteractionLayer, LayerData]

var last_id : int = 0
#var cell_to_module: Dictionary[Vector2i, ModuleBase] = {}
var id_to_module: Dictionary[int, ModuleBase] = {}
var active_layer: ModuleBase.InteractionLayer = ModuleBase.InteractionLayer.MODULE

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.world_manager = self
	for layer in module_layers:
		var new_data = LayerData.new()
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

func get_module_by_cell(layer: ModuleBase.InteractionLayer, cell: Vector2i) -> ModuleBase:
	return layer_data[layer].cell_to_module.get(cell)

func add_module(module_data: ModuleData, cell: Vector2i) -> void:
	var new_module = module_data.scene.instantiate()
	new_module.get_instance_id()
	if is_blocked(new_module.interaction_layer, cell, new_module.size):
		print("Warning, attempted to add module where one exists at: " + str(cell))
		new_module.free()
		return
	# Note this only works for one-cell modules but right now only matters for those
	var existing_module: ModuleBase = get_module_by_cell(new_module.interaction_layer, cell)
	if existing_module != null:
		var replacement_module: PackedScene = module_data.combo_scene.get(existing_module.module_data.scene)
		remove_module(existing_module)
		if replacement_module != null:
			new_module.free()
			new_module = replacement_module.instantiate()
	new_module.position = Vector2(cell * Global.CELL_SIZE)
	var module_id = _get_next_id()
	new_module.module_id = module_id
	new_module.module_cell = cell
	new_module.module_data = module_data
	module_layers[new_module.interaction_layer].add_child(new_module)
	for x in new_module.size.x:
		for y in new_module.size.y:
			layer_data[new_module.interaction_layer].cell_to_module[cell + Vector2i(x, y)] = new_module
	id_to_module[module_id] = new_module
	new_module.make_connections()

func remove_module(module: ModuleBase) -> bool:
	if module.can_delete == false:
		return false
	var replacement_module = module.replacement_on_delete
	var replacement_location = module.module_cell
	var replacement_size = module.size
	module.pre_delete()
	SignalBus.module_removed.emit(module)
	module.remove_connections()
	for x in module.size.x:
		for y in module.size.y:
			layer_data[module.interaction_layer].cell_to_module.erase(module.module_cell + Vector2i(x,y))
	id_to_module.erase(module.module_id)
	layer_data[module.interaction_layer].canvas.remove_child(module)
	module.queue_free()
	if replacement_module:
		for x in replacement_size.x:
			for y in replacement_size.y:
				add_module(replacement_module, replacement_location + Vector2i(x,y))
	return true

func remove_module_by_cell_active_layer(cell: Vector2i) -> void:
	remove_module_by_cell(active_layer, cell)
	
func remove_module_by_cell(layer: ModuleBase.InteractionLayer, cell: Vector2i) -> void:
	var module = layer_data[layer].cell_to_module.get(cell)
	if module != null:
		remove_module(module)
		
func is_blocked(layer: ModuleBase.InteractionLayer, cell: Vector2i, size: Vector2i = Vector2i(1,1)) -> bool:
	for x in size.x:
		for y in size.y:
			var module = layer_data[layer].cell_to_module.get(cell + Vector2i(x, y))
			if module != null and module.blocks_building:
				return true
	return false

func has_overlaps(layer: ModuleBase.InteractionLayer, cell: Vector2i, size: Vector2i = Vector2i(1,1)) -> bool:
	for x in size.x:
		for y in size.y:
			if layer_data[layer].cell_to_module.has(cell + Vector2i(x, y)):
				return true
	return false

func get_overlaps(layer: ModuleBase.InteractionLayer, cell: Vector2i, size: Vector2i = Vector2i(1,1), max_values: int = 0) -> Array[ModuleBase]:
	# TODO: Typed dictionaries are in Godot 4.4! Maybe someday we'll get sets too!
	var overlaps: Array[ModuleBase] = []
	for x in size.x:
		for y in size.y:
			var overlap_module = layer_data[layer].cell_to_module.get(cell + Vector2i(x, y))
			if overlap_module != null && !overlaps.has(overlap_module):
				overlaps.append(overlap_module)
				if max_values > 0:
					if overlaps.size() >= max_values:
						return overlaps
	return overlaps

func get_module_by_id(id: int) -> ModuleBase:
	return id_to_module.get(id)
	
func show_module_layer(layer: ModuleBase.InteractionLayer) -> void:
	for module_layer in module_layers:
		if module_layer == layer:
			module_layers[module_layer].visible = true
		else:
			module_layers[module_layer].visible = false

func set_module_layer_visibility(layer: ModuleBase.InteractionLayer, visibility: bool) -> void:
	module_layers[layer].visible = visibility
	if(visibility):
		active_layer = layer
	else:
		active_layer = ModuleBase.InteractionLayer.MODULE
