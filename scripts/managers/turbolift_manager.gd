class_name TurboliftManager
extends Node

@export var default_cab: PackedScene
## Credits charged per extra cab bought from the shaft panel (WI-11).
@export var cab_cost: int = 500

var _turbolift_shafts: Array[TurboliftShaft] = []

var last_turboshaft: int = 0

func _ready() -> void:
	Global.turbolift_manager = self
	# After world: shafts have re-merged from module adjacency by now.
	SaveManager.register_section(&"turbolifts", SaveManager.SECTION_ORDER[&"turbolifts"], get_save_data, load_save_data)

## Hands the slot back (WI-71 §7). Godot 4.7 reports a freed object as `== null`,
## so the guards around the game already take their null branch after a Quit to
## Menu - but `is_instance_valid(Global.turbolift_manager)` and the debugger both lie until
## the slot is actually cleared. `== self` because a second scene can register
## before this one leaves.
func _exit_tree() -> void:
	if Global.turbolift_manager == self:
		Global.turbolift_manager = null


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
	var lift: ModuleTurbolift = module as ModuleTurbolift
	if lift != null and lift.shaft != null:
		return lift.shaft
	return null

# --- persistence ------------------------------------------------------------

## Per-shaft state (cab count, force shutdown, and the cabs themselves), keyed by
## the shaft's topmost floor cell. Shafts rebuild from module adjacency during the
## world load, so group ids regenerate fresh - nothing persists them, which also
## sidesteps any id-collision worries between runs. floor_enabled travels in each
## module's own save entry.
##
## The cabs are saved as they stand since WI-75: where each is in the shaft, what
## it is doing, how long its door has left and the order its rides are in. Before,
## a load rebuilt none and a pawn aboard one reloaded standing on a floor; now the
## ride carries on from where it was, which is what `cab_list` is for. `cabs` keeps
## its old meaning, the budget.
func get_save_data() -> Dictionary:
	var shafts_out: Array = []
	for shaft: TurboliftShaft in _turbolift_shafts:
		if shaft.floors.is_empty():
			continue
		var entry: Dictionary = {
			"cell": [shaft.floors[0].module_cell.x, shaft.floors[0].module_cell.y],
			"cabs": shaft.max_cabs,
			"force_shutdown": shaft.force_shutdown,
		}
		var cab_list: Array = []
		for cab: TurboliftCab in shaft.cabs:
			if is_instance_valid(cab):
				cab_list.append(cab.to_dict())
		if not cab_list.is_empty():
			entry["cab_list"] = cab_list
		shafts_out.append(entry)
	return {"shafts": shafts_out}

## Runs after the world section: modules are placed and shafts re-merged, so
## each saved entry resolves to exactly one rebuilt shaft. Restored cabs are
## free - they were paid for when bought.
func load_save_data(data: Dictionary) -> void:
	for entry: Dictionary in data.get("shafts", []):
		var cell_arr: Array = entry.get("cell", [])
		if cell_arr.size() != 2:
			continue
		var shaft: TurboliftShaft = _get_shaft_at_cell(Vector2i(int(cell_arr[0]), int(cell_arr[1])))
		if shaft == null:
			push_warning("Saved turboshaft has no rebuilt shaft at " + str(cell_arr) + ", skipping")
			continue
		if bool(entry.get("force_shutdown", false)):
			shaft.set_force_shutdown(true)
		# Assign, never accumulate: the shaft arrived here rebuilt from module
		# adjacency, and TurboliftShaft.merge sums max_cabs, so it already carries
		# one cab per floor. The save is the authority. Floored at 1 because a
		# shaft with no cab budget serves nobody, and a pre-WI-45 save has no key.
		shaft.max_cabs = maxi(int(entry.get("cabs", 1)), 1)
		# The cabs as they stood (WI-75), in the shaft's order - _best_cab_for
		# breaks ties by it. Their rides come back with their pawns, which load
		# after this section, and slot into the order each cab saved.
		for cab_data: Dictionary in entry.get("cab_list", []):
			shaft.create_new_cab()
			shaft.cabs[shaft.cabs.size() - 1].load_dict(cab_data)

## A save's name for a cab: its shaft's topmost floor cell and its place in that
## shaft's list. A ride holds its cab through this (WI-75).
func cab_ref(cab: Variant) -> Dictionary:
	if not is_instance_valid(cab):
		return {}
	var live_cab: TurboliftCab = cab as TurboliftCab
	if live_cab == null or live_cab.shaft == null or live_cab.shaft.floors.is_empty():
		return {}
	var top: Vector2i = live_cab.shaft.floors[0].module_cell
	return {"shaft": [top.x, top.y], "index": live_cab.shaft.cabs.find(live_cab)}

func resolve_cab_ref(ref: Dictionary) -> TurboliftCab:
	var cell_arr: Array = ref.get("shaft", [])
	if cell_arr.size() != 2:
		return null
	var shaft: TurboliftShaft = _get_shaft_at_cell(Vector2i(int(cell_arr[0]), int(cell_arr[1])))
	var index: int = int(ref.get("index", -1))
	if shaft == null or index < 0 or index >= shaft.cabs.size():
		return null
	return shaft.cabs[index]

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
