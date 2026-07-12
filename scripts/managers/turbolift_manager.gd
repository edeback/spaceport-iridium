class_name TurboliftManager
extends Node

@export var default_cab: PackedScene

var _turbolift_shafts: Array[TurboliftShaft] = []

var last_turboshaft: int = 0

func _ready() -> void:
	Global.turbolift_manager = self

func add_turbolift_module(module: ModuleTurbolift) -> void:
	var module_cell := module.module_cell
	var module_above_cell := module_cell + Vector2i(0, -1)
	var module_below_cell := module_cell + Vector2i(0, 1)

	var shaft_above: TurboliftShaft = _get_shaft_at_cell(module_above_cell)
	var shaft_below: TurboliftShaft = _get_shaft_at_cell(module_below_cell)

	if shaft_above == null and shaft_below == null:
		# Case 1: No adjacent shafts, create a new one
		create_new_shaft().register_floor(module)
	elif shaft_above != null and shaft_below == null:
		# Case 2: Connects to shaft above
		shaft_above.register_floor(module)
	elif shaft_above == null and shaft_below != null:
		# Case 2: Connects to shaft below
		shaft_below.register_floor(module)
	elif shaft_above != null and shaft_below != null:
		# Case 3: Connects to two different shafts, merge smaller into larger
		_merge_shafts(shaft_above, shaft_below).register_floor(module)
		

func create_new_shaft() -> TurboliftShaft:
	var new_shaft := TurboliftShaft.new()
	new_shaft.group_id = "turboshaft_" + str(last_turboshaft)
	Global.path_manager.graph.set_group_multiple(new_shaft.group_id, 0.5)
	last_turboshaft += 1
	_turbolift_shafts.append(new_shaft)
	return new_shaft
	

func remove_turbolift_module(module: ModuleTurbolift) -> bool:
	var shaft: TurboliftShaft = module.shaft
	shaft.split_at(module)

	if shaft.floors.is_empty():
		# Shaft is empty, remove it
		shaft.clear()
		_turbolift_shafts.erase(shaft)

	return true
	
	
	

func _get_shaft_at_cell(cell: Vector2i) -> TurboliftShaft:
	# Check if a module exists at the given cell and if it's a turbolift module
	var module := Global.world_manager.get_module_by_cell(WorldManager.StructureLayer.TURBOLIFT, cell)
	if module is ModuleTurbolift and module.shaft != null:
		return module.shaft
	return null

func _merge_shafts(primary_shaft: TurboliftShaft, secondary_shaft: TurboliftShaft) -> TurboliftShaft:
	if primary_shaft == secondary_shaft:
		return primary_shaft # Already merged
		
	if primary_shaft.floors.size() >= secondary_shaft.floors.size():
		primary_shaft.merge(secondary_shaft)
		_turbolift_shafts.erase(secondary_shaft)
		return primary_shaft
	else:
		secondary_shaft.merge(primary_shaft)
		_turbolift_shafts.erase(primary_shaft)
		return secondary_shaft
