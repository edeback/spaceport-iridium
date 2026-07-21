class_name LogisticsBayComponent
extends ComponentBase

## Produces and owns hauler robots (WI-27). Patterned on MiningComponent's drone
## ownership, but robots are bought manually with credits (up to an upgradable
## max) rather than auto-respawned on a timer, and they claim HAUL jobs from the
## shared board instead of from this component. The bay is each robot's "home":
## it powers them, pushes upgrade-derived speed/capacity onto them, and tears them
## down (dumping their cargo as a pile) when the bay itself is removed.

@export var power_consumer: PowerConsumptionComponent

## Loaded by path at first spawn and cached statically (shared across all bays).
## Deliberately load() not preload(): the robot scene is authored alongside this
## script, and a runtime load resolves it from disk without a compile-time
## dependency edge.
const HAULER_ROBOT_SCENE_PATH: String = "res://pawns/hauler_robot.tscn"
static var _hauler_robot_scene: PackedScene = null

static func _get_hauler_robot_scene() -> PackedScene:
	if _hauler_robot_scene == null:
		_hauler_robot_scene = load(HAULER_ROBOT_SCENE_PATH) as PackedScene
	return _hauler_robot_scene

## Base cap on owned robots; upgrades raise the effective cap via STAT_MAX_ROBOTS.
@export var max_robots: int = 3
## Credits to buy one robot.
@export var robot_cost: int = 250
## Base movement speed / carrying capacity handed to a fresh robot; upgrades scale
## these through STAT_ROBOT_SPEED / STAT_ROBOT_CAPACITY.
@export var robot_base_speed: float = 80.0
@export var robot_base_capacity: int = 10

var robots: Array[HaulerRobotPawn] = []

## Stat keys (WI-27) read through owner_module.get_effective_stat so local
## upgrades scale them non-destructively. Independent of the damage/breakdown
## MULT layers, which don't touch these keys.
const STAT_ROBOT_SPEED := &"robot_speed"
const STAT_ROBOT_CAPACITY := &"robot_capacity"
const STAT_MAX_ROBOTS := &"logistics_max_robots"

func _ready() -> void:
	super()
	assert(power_consumer != null, "LogisticsBayComponent must have power_consumer!")

func ready_preview() -> void:
	set_process(false)

func ready_blueprint() -> void:
	set_process(false)

func ready_constructed() -> void:
	set_process(true)
	# Re-push robot stats whenever this module is upgraded (filtered to us).
	if not SignalBus.module_upgraded.is_connected(_on_module_upgraded):
		SignalBus.module_upgraded.connect(_on_module_upgraded)
	_apply_robot_stats()

func _process(delta: float) -> void:
	var sim_delta: float = Global.time_manager.scale(delta)
	if sim_delta <= 0.0:
		return
	var powered: bool = power_consumer == null or power_consumer.powered
	last_error = "" if powered else "No power!"
	# Reflect bay power onto robots each frame (WI-28): no longer a freeze - robots
	# run on their own battery - it tracks whether the bay's implicit charger is
	# available. Stat changes are rarer and handled via the upgrade signal.
	for robot: HaulerRobotPawn in robots:
		robot.powered = powered

## Effective robot cap after upgrades (STAT_MAX_ROBOTS is an additive tier bump).
func effective_max_robots() -> int:
	if owner_module != null:
		return int(owner_module.get_effective_stat(STAT_MAX_ROBOTS, float(max_robots)))
	return max_robots

## True when another robot can be bought right now: room under the cap and the
## credits to pay for it.
func can_buy_robot() -> bool:
	if robots.size() >= effective_max_robots():
		return false
	return _credit_resource() != null and _credit_resource().get_total() >= robot_cost

## Buys and spawns one robot, spending its credit cost. No-op (returns false) if
## the cap is reached or credits are short.
func buy_robot() -> bool:
	if not can_buy_robot():
		return false
	_credit_resource().force_withdraw(robot_cost)
	_spawn_robot()
	return true

func _spawn_robot() -> HaulerRobotPawn:
	var robot: HaulerRobotPawn = _get_hauler_robot_scene().instantiate() as HaulerRobotPawn
	robot.parent_bay = self
	# Add to the tree before assigning current_module: its setter reparents to the
	# module canvas, which needs a parent to exist (same order as SaveManager's
	# pawn restore).
	Global.world_manager.pawn_layer.add_child(robot)
	robot.global_position = Global.cell_to_world(owner_module.module_cell, true)
	robot.current_module = owner_module
	robots.append(robot)
	_apply_robot_stats_to(robot)
	return robot

## Pushes upgrade-derived speed/capacity onto every owned robot.
func _apply_robot_stats() -> void:
	for robot: HaulerRobotPawn in robots:
		_apply_robot_stats_to(robot)

func _apply_robot_stats_to(robot: HaulerRobotPawn) -> void:
	if owner_module == null:
		return
	robot.speed = owner_module.get_effective_stat(STAT_ROBOT_SPEED, robot_base_speed)
	robot.carrying_capacity = int(owner_module.get_effective_stat(STAT_ROBOT_CAPACITY, float(robot_base_capacity)))

func _on_module_upgraded(module: ModuleBase) -> void:
	if module == owner_module:
		_apply_robot_stats()

## Add a robot to the tracked list from outside (save/load re-registration).
func register_robot(robot: HaulerRobotPawn) -> void:
	robots.append(robot)
	_apply_robot_stats_to(robot)

## A robot was destroyed (WI-28): drop it from the roster so a slot frees under the
## cap and the player can buy a replacement. Called before the robot frees itself.
func notify_robot_destroyed(robot: HaulerRobotPawn) -> void:
	robots.erase(robot)

func _exit_tree() -> void:
	# Robots die with the bay; each dumps carried cargo as a pile via PawnBase's
	# PREDELETE handler (resource invariant), then frees.
	for robot: HaulerRobotPawn in robots:
		if is_instance_valid(robot):
			robot.self_destruct()
	robots.clear()

func _credit_resource() -> ResourceData:
	if Global.resource_manager != null:
		return Global.resource_manager.credit_resource
	return null

func has_ui() -> bool:
	return true

func get_ui() -> ModuleComponentUI:
	var ui := LogisticsBayComponentUI.new()
	ui.set_logistics_bay(self)
	return ui
