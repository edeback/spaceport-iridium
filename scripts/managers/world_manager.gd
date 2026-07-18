class_name WorldManager
extends Node

enum StructureLayer { MODULE, CORRIDOR, TURBOLIFT, SPACE }
enum Multiplacement { NONE, HORIZONTAL, VERTICAL, BOTH }

class LayerData:
	var canvas: CanvasLayer
	var cell_to_module: Dictionary[Vector2i, ModuleBase] = {}
	#var id_to_module: Dictionary[int, ModuleBase] = {}

@export var start_module: ModuleData
@export var docking_bay: ModuleData
# Only used for setup. Use layer_data at runtime
@export var module_layers: Dictionary[StructureLayer, CanvasLayer]

@export var pawn_layer: CanvasLayer

@export var replacement_module: ModuleData

@export var hallway_module: ModuleData

@export var module_airlock: ModuleData

var layer_data: Dictionary[StructureLayer, LayerData]

var last_id : int = 0
#var cell_to_module: Dictionary[Vector2i, ModuleBase] = {}
var id_to_module: Dictionary[int, ModuleBase] = {}
			
var modules_by_type: Dictionary = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.world_manager = self
	for layer in module_layers:
		var new_data: LayerData = LayerData.new()
		new_data.canvas = module_layers[layer]
		layer_data[layer] = new_data
	# Starting-station spawn is driven from Main._ready (WI-18): the root readies
	# after every manager, so only there is every Global.* guaranteed registered.

## New-game bootstrap: place the starting station and seed its atmosphere.
## Called from Main._ready (see WI-18) - the old _startup ran inside _ready with
## a 1.0s create_timer to paper over managers that hadn't registered yet; that
## race is gone now that the call happens after the whole tree is ready.
func spawn_starting_station() -> void:
	if SaveManager.has_pending_load():
		return # the save's world section places everything instead
	add_module(start_module, Vector2i(15,8))
	add_module(docking_bay, Vector2i(18,8), true, true, false, true)
	add_module(hallway_module, Vector2i(17, 9))
	add_module(module_airlock, Vector2i(19, 9), true, true)
	# New game only (load never reaches here): the starting station begins
	# fully O2-pressurized so the player has slack while expanding (WI-17).
	# Every starter module (and the corridors/truss they auto-place) registers
	# its AtmosphereComponent synchronously above - none defer ready_blueprint -
	# so this is a plain direct call, no registration window needed.
	Global.atmosphere_manager.seed_starting_atmosphere()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _get_next_id() -> int:
	last_id = last_id + 1
	return last_id

func get_canvas_for_layer(layer: StructureLayer) -> CanvasLayer:
	return layer_data[layer].canvas

func get_module_by_cell(layer: StructureLayer, cell: Vector2i) -> ModuleBase:
	return layer_data[layer].cell_to_module.get(cell)
	
func get_modules_by_type(module_data: ModuleData) -> Array:
	return modules_by_type.get_or_add(module_data, [])
	
func get_nearest_module_by_type(position: Vector2, module_data: ModuleData) -> ModuleBase:
	var dist: float = -1
	var closest_module: ModuleBase = null
	for module: ModuleBase in get_modules_by_type(module_data):
		var new_dist: float = module.position.distance_squared_to(position)
		if dist < 0 or new_dist < dist:
			dist = new_dist
			closest_module = module
	return closest_module
	
func purchase_and_add_module(module_data: ModuleData, cell: Vector2i, is_horizontal: bool = true, flipped: bool = false, allow_cost_overrun: bool = false) -> void:
	if not allow_cost_overrun and !module_data.can_afford():
		return
	# Place first, pay after: add_module can refuse (blocked cell, overlap
	# veto), and a failed placement must not cost anything. Can't pre-validate
	# instead - overlap_module() has side effects (truss removes itself).
	var new_module: ModuleBase = add_module(module_data, cell, is_horizontal, flipped)
	if new_module == null:
		return
	if module_data.instant_build:
		module_data.withdraw_cost()
	else:
		module_data.withdraw_credit_cost()

func add_module(module_data: ModuleData, cell: Vector2i, is_horizontal: bool = true, flipped: bool = false, defer_ready: bool = false, force_complete: bool = false) -> ModuleBase:
	var module_scene: PackedScene = module_data.scene
	if flipped and module_data.flippable:
		module_scene = module_data.flipped_scene
	var new_module: ModuleBase = module_scene.instantiate()
	new_module.get_instance_id()
	if is_blocked(module_data.interaction_layer, cell, new_module.size):
		print("Warning, attempted to add module where one exists at: " + str(cell))
		new_module.free()
		return null
	# Note this only works for one-cell modules but right now only matters for those
	var cancel_add: bool = false
	for existing_module: ModuleBase in get_overlaps(module_data.interaction_layer, cell, new_module.size):
		if existing_module != null:
			cancel_add = cancel_add or existing_module.overlap_module(module_data, is_horizontal)
	if cancel_add:
		new_module.free()
		return null
	new_module.position = Vector2(cell * Global.CELL_SIZE)
	var module_id: int = _get_next_id()
	new_module.module_id = module_id
	new_module.module_cell = cell
	new_module.module_data = module_data
	new_module.is_horizontal = is_horizontal
	new_module.flipped = flipped and module_data.flippable
	for x in new_module.size.x:
		for y in new_module.size.y:
			layer_data[module_data.interaction_layer].cell_to_module[cell + Vector2i(x, y)] = new_module
	id_to_module[module_id] = new_module
	var module_array: Array = modules_by_type.get_or_add(module_data, [])
	module_array.append(new_module)
	module_layers[module_data.interaction_layer].add_child(new_module)
	# defer_ready: save-loading places every module first, then runs a second
	# ready pass per saved build state (see load_save_data) - mirroring how
	# modules were built one at a time, so door hookups stay order-safe.
	if not defer_ready:
		# TODO: Hacky, find better way
		var construction_component: ConstructionComponent = new_module.get_node_or_null("ConstructionComponent") as ConstructionComponent
		if construction_component != null and not force_complete and not module_data.instant_build:
			new_module.call_deferred("ready_blueprint")
		else:
			new_module.ready_constructed()
	return new_module

func remove_module(module: ModuleBase, structure_check: bool = true) -> bool:
	if module.can_delete == false:
		return false
	# TODO Re-enable this sometime. Right now construction means modules are not counted as connected so this fails often
	#if structure_check and module.structure_check_before_delete:
		#if not Global.structure_manager.can_remove_module(module):
			#return false
	var replacement_location: Vector2i = module.module_cell
	var replacement_points: Array[Vector2i] = []
	if module.get_structure_component() != null:
		replacement_points = module.get_structure_component().internal_points
	module.pre_delete()
	module.remove_connections()
	for x in module.size.x:
		for y in module.size.y:
			layer_data[module.module_data.interaction_layer].cell_to_module.erase(module.module_cell + Vector2i(x,y))
	id_to_module.erase(module.module_id)
	layer_data[module.module_data.interaction_layer].canvas.remove_child(module)
	SignalBus.module_removed.emit(module)
	var module_array: Array = modules_by_type.get_or_add(module.module_data, [])
	module_array.erase(module)
	module.queue_free()
	if module.module_data != replacement_module and module.module_data.interaction_layer == StructureLayer.MODULE:
		for replacement_point in replacement_points:
			add_module(replacement_module, replacement_location +replacement_point)
	return true
	
# --- persistence ------------------------------------------------------------

func get_save_data() -> Dictionary:
	var modules_out: Array = []
	# id_to_module preserves placement order, which the load replays.
	for module: ModuleBase in id_to_module.values():
		if module.module_data == null or module.module_data.id == &"":
			push_warning("Module without a save id not saved: " + module.name)
			continue
		modules_out.append(module.get_save_data())
	return {"modules": modules_out}

## Two-phase: place every module with ready deferred, then run the ready pass
## (built vs blueprint) + per-module state restore in placement order.
func load_save_data(data: Dictionary) -> void:
	var placed_modules: Array[ModuleBase] = []
	var placed_entries: Array[Dictionary] = []
	for entry: Dictionary in data.get("modules", []):
		var module_data: ModuleData = Global.save_manager.get_module_data_by_id(StringName(String(entry.get("id", ""))))
		if module_data == null:
			push_warning("Unknown module id in save, skipping: " + str(entry.get("id")))
			continue
		var cell_arr: Array = entry.get("cell", [])
		if cell_arr.size() != 2:
			push_warning("Saved module has no cell, skipping: " + str(entry.get("id")))
			continue
		var cell := Vector2i(int(cell_arr[0]), int(cell_arr[1]))
		var module: ModuleBase = add_module(module_data, cell, bool(entry.get("horizontal", true)), bool(entry.get("flipped", false)), true)
		if module == null:
			# Usually an auto-placed companion (e.g. a turbolift's truss) beat
			# the saved copy to the cell - equivalent state, safe to skip.
			continue
		placed_modules.append(module)
		placed_entries.append(entry)
	for index: int in placed_modules.size():
		var module: ModuleBase = placed_modules[index]
		var entry: Dictionary = placed_entries[index]
		if bool(entry.get("built", true)):
			module.ready_constructed()
		else:
			module.ready_blueprint()
		module.load_save_data(entry)

func remove_module_by_cell(layer: StructureLayer, cell: Vector2i) -> void:
	var module: ModuleBase = layer_data[layer].cell_to_module.get(cell)
	if module != null:
		remove_module(module)
		
func is_blocked(layer: StructureLayer, cell: Vector2i, size: Vector2i = Vector2i(1,1)) -> bool:
	for x in size.x:
		for y in size.y:
			var module: ModuleBase = layer_data[layer].cell_to_module.get(cell + Vector2i(x, y))
			if module != null and module.blocks_building:
				return true
	return false

func has_overlaps(layer: StructureLayer, cell: Vector2i, size: Vector2i = Vector2i(1,1)) -> bool:
	for x in size.x:
		for y in size.y:
			if layer_data[layer].cell_to_module.has(cell + Vector2i(x, y)):
				return true
	return false

func get_overlaps(layer: StructureLayer, cell: Vector2i, size: Vector2i = Vector2i(1,1), max_values: int = 0) -> Array[ModuleBase]:
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

## Everything stacked on one cell across the clickable layers (a cell can hold
## a corridor, a turbolift and a room at once). Order is the click-cycle order.
func get_stack_at_cell(cell: Vector2i) -> Array[ModuleBase]:
	var stack: Array[ModuleBase] = []
	for layer: StructureLayer in [StructureLayer.CORRIDOR, StructureLayer.TURBOLIFT, StructureLayer.MODULE]:
		var module: ModuleBase = layer_data[layer].cell_to_module.get(cell)
		if module != null and not stack.has(module):
			stack.append(module)
	return stack

func get_module_by_id(id: int) -> ModuleBase:
	return id_to_module.get(id)
	
func show_module_layer(layer: StructureLayer) -> void:
	if layer == StructureLayer.MODULE:
		var module_mod: CanvasModulate = module_layers[StructureLayer.MODULE].get_node("CanvasModulate") as CanvasModulate
		module_mod.color.a = 1
		var corridor_mod: CanvasModulate = module_layers[StructureLayer.CORRIDOR].get_node("CanvasModulate") as CanvasModulate
		corridor_mod.color.a = 0.3
		var turbolift_mod: CanvasModulate = module_layers[StructureLayer.TURBOLIFT].get_node("CanvasModulate") as CanvasModulate
		turbolift_mod.color.a = 0.3
	elif layer == StructureLayer.CORRIDOR:
		var module_mod: CanvasModulate = module_layers[StructureLayer.MODULE].get_node("CanvasModulate") as CanvasModulate
		module_mod.color.a = 1
		var corridor_mod: CanvasModulate = module_layers[StructureLayer.CORRIDOR].get_node("CanvasModulate") as CanvasModulate
		corridor_mod.color.a = 1
		var turbolift_mod: CanvasModulate = module_layers[StructureLayer.TURBOLIFT].get_node("CanvasModulate") as CanvasModulate
		turbolift_mod.color.a = 1
	#for module_layer in module_layers:
		#if module_layer == layer:
			#module_layers[module_layer].visible = true
			#var mod: CanvasModulate = module_layers[module_layer].get_node("CanvasModulate") as CanvasModulate
			#mod.color.a = 1
		#else:
			#module_layers[module_layer].visible = true
			#var mod: CanvasModulate = module_layers[module_layer].get_node("CanvasModulate") as CanvasModulate
			#mod.color.a = 0.3
