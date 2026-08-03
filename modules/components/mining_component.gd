class_name MiningComponent
extends ComponentBase

@export var output_storage: StorageComponent
@export var power_consumer: PowerConsumptionComponent
## Exported so a mod's mining module can fly its own drone (WI-47 M6); the vanilla
## scene is the default, so no existing module scene needed touching.
@export var mining_drone_scene: PackedScene = preload("res://pawns/mining_drone_pawn.tscn")
@export var max_drones: int = 3
@export var drone_respawn_seconds: float = 5.0

var drones: Array[MiningDronePawn] = []

## Sim-seconds until the next drone builds; < 0 = not currently counting.
## Only ticks while powered, so it pauses and fast-forwards with the game.
## Deliberately unsaved (WI-45 A6): a load restarts at most one <=5s respawn.
var _respawn_time_left: float = -1.0

## Player-selected ore this bay's drones seek out once no designated
## asteroids remain (see FinderAsteroid). Null = no preference, random asteroid.
## Per-bay, and persisted since WI-45 A6 - it's a player setting like the
## processor's recipe or a storefront's shop type, both of which have keys.
var priority_ore: ResourceData = null

## Stat key for the bay's extraction rate (WI-24): damage/upgrades scale this
## and the mining job folds it into its per-unit timing. 1.0 base = no-op.
const STAT_MINING_RATE := &"mining_rate"

## Effective extraction-rate multiplier for this bay's drones. Reads the module's
## modifier layer so a damaged mining bay measurably slows.
func get_mining_rate() -> float:
	if owner_module != null:
		return maxf(owner_module.get_effective_stat(STAT_MINING_RATE, 1.0), 0.05)
	return 1.0


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super()
	assert(output_storage != null, "MiningComponent must have output_storage!")
	assert(power_consumer != null, "MiningComponent must have power_consumer!")

func ready_preview() -> void:
	set_process(false)

func ready_blueprint() -> void:
	set_process(false)

func ready_constructed() -> void:
	set_process(true)
	add_to_group(Groups.PROCESSOR)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var sim_delta: float = Global.time_manager.scale(delta)
	if sim_delta <= 0.0:
		return
	# Reflect bay power onto drones (WI-28): this no longer freezes them - drones
	# run on their own battery - it just tracks whether the bay's implicit charger
	# is available. An unpowered bay still can't build a new drone, so respawn
	# pauses while the drones themselves keep flying (and draining).
	var bay_powered: bool = power_consumer.powered
	for drone: MiningDronePawn in drones:
		drone.powered = bay_powered
	if !bay_powered:
		last_error = "No power!"
		_respawn_time_left = -1.0
		return
	last_error = ""
	if drones.size() < max_drones:
		if _respawn_time_left < 0.0:
			_respawn_time_left = drone_respawn_seconds
		_respawn_time_left -= sim_delta
		if _respawn_time_left <= 0.0:
			_respawn_time_left = -1.0
			build_drone()
	else:
		_respawn_time_left = -1.0

func build_drone() -> void:
	var new_drone: MiningDronePawn = mining_drone_scene.instantiate() as MiningDronePawn
	new_drone.global_position = Global.cell_to_world(owner_module.module_cell, true)
	new_drone.parent_mining_component = self
	Global.world_manager.pawn_layer.add_child(new_drone)
	new_drone.current_module = owner_module
	drones.append(new_drone)

## Add a drone to tracked drones externally, used for save/load
func register_drone(drone: MiningDronePawn) -> void:
	drones.append(drone)

## A drone was destroyed (WI-28): drop it from the roster so the respawn timer
## rebuilds one (up to max_drones). Called before the drone frees itself.
func notify_drone_destroyed(drone: MiningDronePawn) -> void:
	drones.erase(drone)

func _exit_tree() -> void:
	for drone: MiningDronePawn in drones:
		drone.self_destruct()

func _can_output(amount: int) -> bool:
	return output_storage.space_available(true) >= amount

## Intentionally not offer_followup_job or else construction workers end up picking this up
func get_next_job(_pawn: PawnBase) -> Job:
	if power_consumer.powered:
		if _can_output(1):
			var mining_job: Job = Job.of(&"mine_asteroid")
			mining_job.target_b = JobTarget.of_component(self)
			# One trip's quota: the drone's own hold. Action_Mine counts it down.
			mining_job.count = _pawn.carrying_capacity
			return mining_job
		elif _pawn.current_module != owner_module:
			var move_job: Job = Job.of(&"move_to_location")
			move_job.target_a = JobTarget.of_module(owner_module)
			return move_job
	# Unpowered or unneeded, just idle for a bit
	return Job.of(&"idle")

# --- persistence -------------------------------------------------------------
# Only the player's ore preference. Drones save themselves (they're pawns) and
# re-register with this bay by component ref; the respawn timer is deliberately
# dropped. Empty dict = no preference, so the common case costs nothing.

## Player-selected priority ore only (WI-45 A6). Drones restore separately, as pawns.
func save_order() -> int:
	return 130

func save_key() -> StringName:
	return &"mining"

func get_save_data() -> Dictionary:
	if priority_ore == null or priority_ore.id == &"":
		return {}
	return {"priority_ore": String(priority_ore.id)}

func load_save_data(data: Dictionary) -> void:
	var id_str: String = String(data.get("priority_ore", ""))
	if id_str == "":
		return
	var resource: ResourceData = Global.save_manager.get_resource_by_id(StringName(id_str))
	if resource == null:
		# Falls back to null (no preference) rather than an arbitrary ore.
		push_warning("Unknown priority ore in saved mining bay, ignoring: " + id_str)
		return
	priority_ore = resource

func has_ui() -> bool:
	return true

func get_ui() -> ModuleComponentUI:
	var ui: MiningComponentUI = ui_info_panel_element.instantiate() as MiningComponentUI
	ui.set_mining_component(self)
	return ui
