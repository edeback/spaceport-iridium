extends GutTest

## WI-73 §3: what each pawn KIND adds to its save entry, through the four PawnBase
## hooks that replaced SaveManager's `if pawn is X` chains.
##
## `test_component_save_contract.gd` pins the component blocks; this pins the layer
## above them. The keys are in every save ever written - `robot_index`,
## `mining_comp`, `logistics_bay`, `visitor` - and a rename here silently drops that
## field on every load, so each kind is built bare, given values, and read back.
## So is the ORDER a kind writes its keys in, because JSON keeps insertion order and
## a save that reorders its keys is a different file (WI-73 verification 3).
##
## Pawns and components are constructed bare and never added to a tree, so nothing
## here touches Global or SignalBus. The load half that resolves a bay needs a
## placed station and is covered by tests/integration/test_wi73_pawn_kinds.gd.

## Where the pawn section lives. After WI-73 it must name no pawn kind.
const SAVE_MANAGER: String = "res://scripts/managers/save_manager.gd"

## A bay component inside a bare module at a known cell, so component_ref() has a
## layer, a cell and a path to write.
func _component_in_module(component: ComponentBase, cell: Vector2i) -> ComponentBase:
	var module: ModuleBase = autofree(ModuleBase.new())
	module.module_data = ModuleData.new()
	module.module_data.interaction_layer = WorldManager.StructureLayer.MODULE
	module.module_cell = cell
	component.name = "Bay"
	module.add_child(component)
	component.owner_module = module
	return component

func _saved(pawn: PawnBase) -> Dictionary:
	var entry: Dictionary = {}
	pawn.save_kind_data(entry)
	return entry

# --- which pawns are saved at all -------------------------------------------------------

func _bare(pawn: PawnBase) -> PawnBase:
	return autofree(pawn) as PawnBase

func test_every_kind_is_saved_except_the_inspector() -> void:
	assert_true(_bare(PawnBase.new()).is_saved(), "crew")
	assert_true(_bare(MiningDronePawn.new()).is_saved(), "mining drone")
	assert_true(_bare(HaulerRobotPawn.new()).is_saved(), "hauler robot")
	assert_true(_bare(VisitorPawn.new()).is_saved(), "guest visitors are saved (WI-33)")
	assert_false(_bare(InspectorPawn.new()).is_saved(),
		"the ARC inspector is runtime-only (WI-26)")

# --- save: the keys ------------------------------------------------------------------------

func test_crew_add_nothing_of_their_own() -> void:
	# Everything a crew member has is common fields or component blocks.
	assert_eq(_saved(_bare(PawnBase.new())), {})

func test_a_robot_saves_its_number() -> void:
	var robot: RobotPawnBase = autofree(RobotPawnBase.new())
	robot.robot_index = 3
	assert_eq(_saved(robot), {"robot_index": 3})

func test_a_mining_drone_saves_its_number_then_its_bay() -> void:
	var drone: MiningDronePawn = autofree(MiningDronePawn.new())
	drone.robot_index = 2
	drone.parent_mining_component = _component_in_module(MiningComponent.new(), Vector2i(16, 8)) as MiningComponent
	var entry: Dictionary = _saved(drone)
	assert_eq(entry.keys(), ["robot_index", "mining_comp"], "robot keys first, then the kind's own")
	assert_eq(entry["robot_index"], 2)
	assert_eq(entry["mining_comp"], {
		"layer": WorldManager.StructureLayer.MODULE, "cell": [16, 8], "path": "Bay"})

func test_a_hauler_saves_its_number_then_its_bay() -> void:
	var hauler: HaulerRobotPawn = autofree(HaulerRobotPawn.new())
	hauler.robot_index = 5
	hauler.parent_bay = _component_in_module(LogisticsBayComponent.new(), Vector2i(20, 6)) as LogisticsBayComponent
	var entry: Dictionary = _saved(hauler)
	assert_eq(entry.keys(), ["robot_index", "logistics_bay"])
	assert_eq(entry["logistics_bay"], {
		"layer": WorldManager.StructureLayer.MODULE, "cell": [20, 6], "path": "Bay"})

func test_a_robot_with_no_bay_writes_no_bay_key() -> void:
	# Absent reads back as no owner, which is the truth; an empty ref would too,
	# but the old chain never wrote one, and neither does this.
	var drone: MiningDronePawn = autofree(MiningDronePawn.new())
	drone.robot_index = 1
	assert_eq(_saved(drone), {"robot_index": 1})
	var hauler: HaulerRobotPawn = autofree(HaulerRobotPawn.new())
	hauler.robot_index = 1
	assert_eq(_saved(hauler), {"robot_index": 1})

func test_a_visitor_saves_its_visit() -> void:
	var guest: VisitorPawn = autofree(VisitorPawn.new())
	guest.stay_hours_remaining = 12.5
	guest._leaving = true
	guest._departure_reported = true
	assert_eq(_saved(guest), {"visitor": {"stay": 12.5, "leaving": true, "reported": true}})

# --- load ----------------------------------------------------------------------------------

func test_a_robot_number_is_read_before_the_tree() -> void:
	# _ready allocates a number only when it arrives unset, so this is the hook
	# that has to carry it.
	var robot: RobotPawnBase = autofree(RobotPawnBase.new())
	robot.load_kind_data_before_tree({"robot_index": 4})
	assert_eq(robot.robot_index, 4)

func test_a_robot_saved_before_robots_had_numbers_arrives_unnumbered() -> void:
	# 0 is "unallocated": _ready numbers it in load order, as if it were just built.
	var robot: RobotPawnBase = autofree(RobotPawnBase.new())
	robot.robot_index = 9
	robot.load_kind_data_before_tree({})
	assert_eq(robot.robot_index, 0)

func test_a_visit_round_trips_through_json() -> void:
	var guest: VisitorPawn = autofree(VisitorPawn.new())
	guest.stay_hours_remaining = 7.25
	guest._leaving = true
	guest._departure_reported = false
	# Through JSON, as a real save goes: every number comes back a float.
	var entry: Dictionary = JSON.parse_string(JSON.stringify(_saved(guest)))
	var loaded: VisitorPawn = autofree(VisitorPawn.new())
	loaded.load_kind_data(entry)
	assert_eq(loaded.stay_hours_remaining, 7.25)
	assert_true(loaded._leaving)
	assert_false(loaded._departure_reported)

func test_a_visitor_with_no_visit_block_keeps_its_defaults() -> void:
	# A pre-WI-33 entry: a fresh stay, not leaving, nothing reported.
	var loaded: VisitorPawn = autofree(VisitorPawn.new())
	var default_stay: float = loaded.stay_hours_remaining
	loaded.load_kind_data({})
	assert_eq(loaded.stay_hours_remaining, default_stay)
	assert_false(loaded._leaving)
	assert_false(loaded._departure_reported)

# --- the pawn section names no kind --------------------------------------------------------

func test_the_pawn_section_names_no_pawn_kind() -> void:
	# The chains this replaced were `pawn is RobotPawnBase`, `(pawn as VisitorPawn)`
	# and so on. PawnBase itself is fine - it is what the section walks.
	var kind := RegEx.create_from_string("\\b(?:is|as)\\s+(?!PawnBase\\b)\\w*Pawn\\w*")
	var offenders := PackedStringArray()
	var lines: PackedStringArray = FileAccess.get_file_as_string(SAVE_MANAGER).split("\n")
	for index: int in lines.size():
		var line: String = lines[index]
		if line.strip_edges().begins_with("#"):
			continue
		if kind.search(line) != null:
			offenders.append("%d: %s" % [index + 1, line.strip_edges()])
	assert_eq(offenders, PackedStringArray(), "a pawn kind belongs on its class's hooks")
