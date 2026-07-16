class_name MiningComponent
extends ComponentBase

@export var output_storage: StorageComponent
@export var power_consumer: PowerConsumptionComponent
var mining_drone_scene: PackedScene = preload("res://pawns/mining_drone_pawn.tscn")
@export var max_drones: int = 3
@export var drone_respawn_seconds: float = 5.0

var drones: Array[MiningDronePawn] = []

## Sim-seconds until the next drone builds; < 0 = not currently counting.
## Only ticks while powered, so it pauses and fast-forwards with the game.
var _respawn_time_left: float = -1.0

var output_resource: ResourceData

var processing: bool = false
var current_process_time: float = 0


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super()
	assert(output_storage != null, "Processor must have output_storage!")
	assert(power_consumer != null, "Processor must have power_consumer!")
	#output_resource = base_output_resource.duplicate()
	#output_resource.base_resource = base_output_resource
	#var mutiple: float = 0.0
	#for resource_data: ResourceData in sub_resources:
		#mutiple += 0.1
		#output_resource.sub_resources[resource_data] = mutiple

func ready_preview() -> void:
	set_process(false)
	
func ready_blueprint() -> void:
	set_process(false)
	
func ready_constructed() -> void:
	set_process(true)
	add_to_group("processor")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var sim_delta: float = Global.time_manager.scale(delta)
	if sim_delta <= 0.0:
		return
	if !power_consumer.powered:
		for drone: MiningDronePawn in drones:
			drone.powered = false
		# Do nothing if unpowered
		last_error = "No power!"
		return
	last_error = ""
	for drone: MiningDronePawn in drones:
		drone.powered = true
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
	new_drone.current_module = owner_module
	new_drone.parent_mining_component = self
	Global.world_manager.pawn_layer.add_child(new_drone)
	drones.append(new_drone)

func _exit_tree() -> void:
	for drone: MiningDronePawn in drones:
		drone.self_destruct()

func _can_output(amount: int) -> bool:
	return output_storage.space_available(true) >= amount
	
## Intentionally not offer_followup_job or else construction workers end up picking this up
func get_next_job(_pawn: PawnBase) -> JobBase:
	if power_consumer.powered:
		if _can_output(1):
			var mining_job: Job_MineAsteroid = Job_MineAsteroid.new()
			mining_job.setup(self)
			mining_job.output_storage = output_storage
			return mining_job
		elif _pawn.current_module != owner_module:
			var move_job: Job_MoveToLocation = Job_MoveToLocation.new()
			move_job.destination_module = owner_module
			return move_job
	# Unpowered or unneeded, just idle for a bit
	return Job_Idle.new()

func has_ui() -> bool:
	return false
	
func get_ui() -> ModuleComponentUI:
	return null
