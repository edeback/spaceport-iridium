class_name LogisticsBayComponent
extends ComponentBase

## Produces and owns hauler robots (WI-27). Patterned on MiningComponent's drone
## ownership, but robots are bought manually with credits (up to an upgradable
## max) rather than auto-respawned on a timer, and they claim HAUL jobs from the
## shared board instead of from this component. The bay is each robot's "home":
## it powers them, pushes upgrade-derived speed/capacity onto them, and tears them
## down (dumping their cargo as a pile) when the bay itself is removed.

@export var power_consumer: PowerConsumptionComponent

## Which robot this bay builds. Exported so a mod's logistics module can ship its
## own hauler (WI-47 M6) - it was a hardcoded res:// path string with a static
## cache, which nothing outside this file could reach. Left empty, the bay builds
## the vanilla hauler, so no existing module scene needed touching.
##
## Empty rather than a preload of the vanilla scene (WI-73): hauler_robot.gd names
## this class, so a preload here made the two scripts a load cycle, and loading the
## robot's script first failed with "Busy" on hauler_robot.tscn. Nothing loaded it
## first until WI-73 - SaveManager's pawn section named every pawn kind and pulled
## this bay in ahead of it - so the cycle was there all along, hidden by load order.
@export var hauler_robot_scene: PackedScene = null
const DEFAULT_HAULER_SCENE: String = "res://pawns/hauler_robot.tscn"

## Base cap on owned robots; upgrades raise the effective cap via Stats.LOGISTICS_MAX_ROBOTS.
@export var max_robots: int = 3
## Credits to buy one robot.
@export var robot_cost: int = 250
## Base movement speed / carrying capacity handed to a fresh robot; upgrades scale
## these through Stats.ROBOT_SPEED / Stats.ROBOT_CAPACITY.
@export var robot_base_speed: float = 80.0
@export var robot_base_capacity: int = 10

var robots: Array[HaulerRobotPawn] = []

## What this bay's scene needs and does not have (WI-72 §2). Was an `assert`.
func wiring_fault() -> String:
	if power_consumer == null:
		return "a logistics bay with no power_consumer runs its robots for free"
	return ""

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

## Effective robot cap after upgrades (Stats.LOGISTICS_MAX_ROBOTS is an additive tier bump).
func effective_max_robots() -> int:
	if owner_module != null:
		return int(owner_module.get_effective_stat(Stats.LOGISTICS_MAX_ROBOTS, float(max_robots)))
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
	if hauler_robot_scene == null:
		hauler_robot_scene = load(DEFAULT_HAULER_SCENE) as PackedScene
	var robot: HaulerRobotPawn = hauler_robot_scene.instantiate() as HaulerRobotPawn
	robot.parent_bay = self
	# Add to the tree before assigning current_module: its setter reparents to the
	# module canvas, which needs a parent to exist (same order as SaveManager's
	# pawn restore).
	Global.world_manager.get_canvas_for_layer(WorldManager.StructureLayer.SPACE).add_child(robot)
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
	robot.speed = owner_module.get_effective_stat(Stats.ROBOT_SPEED, robot_base_speed)
	robot.carrying_capacity = int(owner_module.get_effective_stat(Stats.ROBOT_CAPACITY, float(robot_base_capacity)))

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
