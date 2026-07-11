class_name MiningComponent
extends ComponentBase

@export var output_storage: StorageComponent
@export var power_consumer: PowerConsumptionComponent
var mining_drone_scene: PackedScene = preload("res://pawns/mining_drone_pawn.tscn")
@export var max_drones: int = 3
@onready var drone_respawn_timer: Timer = $DroneRespawnTimer

var drones: Array[MiningDronePawn] = []

var output_resource: ResourceData

var processing: bool = false
var current_process_time: float = 0


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super()
	assert(output_storage != null, "Processor must have output_storage!")
	assert(power_consumer != null, "Processor must have power_consumer!")
	
	drone_respawn_timer.timeout.connect(build_drone)
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
func _process(_delta: float) -> void:
	if !power_consumer.powered:
		for drone: MiningDronePawn in drones:
			drone.powered = false
		# Do nothing if unpowered
		last_error = "No power!"
		return
	last_error = ""
	for drone: MiningDronePawn in drones:
		drone.powered = true
	if drones.size() < max_drones and drone_respawn_timer.is_stopped():
		drone_respawn_timer.start()
		
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
	var ui: ProcessorComponentUI = ui_info_panel_element.instantiate() as ProcessorComponentUI
	return ui
