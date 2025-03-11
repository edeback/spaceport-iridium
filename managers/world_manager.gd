class_name WorldManager
extends Node

@export var start_module: ModuleData

var last_id : int = 0
var cell_to_module: Dictionary[Vector2i, ModuleBase] = {}
var id_to_module: Dictionary[int, ModuleBase] = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.world_manager = self
	_startup()
	pass # Replace with function body.

func _startup() -> void:
	await get_tree().create_timer(1.0).timeout
	add_module(start_module, Vector2i(5,5))
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _get_next_id() -> int:
	last_id = last_id + 1
	return last_id

func add_module(module_data: ModuleData, cell: Vector2i) -> void:
	var new_module = module_data.scene.instantiate()
	new_module.get_instance_id()
	if is_blocked(cell, new_module.size):
		print("Warning, attempted to add module where one exists at: " + str(cell))
		return
	new_module.position = Vector2(cell * Global.CELL_SIZE)
	var module_id = _get_next_id()
	new_module.module_id = module_id
	new_module.module_cell = cell
	new_module.module_data = module_data
	add_child(new_module)
	for x in new_module.size.x:
		for y in new_module.size.y:
			cell_to_module[cell + Vector2i(x, y)] = new_module
	id_to_module[module_id] = new_module
	new_module.make_connections()

func remove_module(module: ModuleBase) -> bool:
	var replacement_module = module.replacement_on_delete
	var replacement_location = module.module_cell
	var replacement_size = module.size
	module.pre_delete()
	SignalBus.module_removed.emit(module)
	module.remove_connections()
	for x in module.size.x:
		for y in module.size.y:
			cell_to_module.erase(module.module_cell + Vector2i(x,y))
	id_to_module.erase(module.module_id)
	remove_child(module)
	module.queue_free()
	if replacement_module:
		for x in replacement_size.x:
			for y in replacement_size.y:
				add_module(replacement_module, replacement_location + Vector2i(x,y))
	return true

func remove_module_by_cell(cell: Vector2i) -> void:
	var module = cell_to_module.get(cell)
	if module != null:
		remove_module(module)
		
func is_blocked(cell: Vector2i, size: Vector2i = Vector2i(1,1)) -> bool:
	for x in size.x:
		for y in size.y:
			var module = cell_to_module.get(cell + Vector2i(x, y))
			if module != null and module.blocks_building:
				return true
	return false

func has_overlaps(cell: Vector2i, size: Vector2i = Vector2i(1,1)) -> bool:
	for x in size.x:
		for y in size.y:
			if cell_to_module.has(cell + Vector2i(x, y)):
				return true
	return false

func get_overlaps(cell: Vector2i, size: Vector2i = Vector2i(1,1), max_values: int = 0) -> Array[ModuleBase]:
	# TODO: Typed dictionaries are in Godot 4.4! Maybe someday we'll get sets too!
	var overlaps: Array[ModuleBase] = []
	for x in size.x:
		for y in size.y:
			var overlap_module = cell_to_module.get(cell + Vector2i(x, y))
			if overlap_module != null && !overlaps.has(overlap_module):
				overlaps.append(overlap_module)
				if max_values > 0:
					if overlaps.size() >= max_values:
						return overlaps
	return overlaps

func get_module_by_id(id: int) -> ModuleBase:
	return id_to_module.get(id)
	
