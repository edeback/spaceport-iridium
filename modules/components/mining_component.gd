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
	if _can_output(1):
		for drone: MiningDronePawn in drones:
			if drone.current_job == null:
				var mining_job: Job_MineAsteroid = Job_MineAsteroid.new()
				mining_job.setup(owner_module)
				if not mining_job.can_do_job(drone) or not drone.give_job(mining_job):
					mining_job.free()
		
func build_drone() -> void:
	var new_drone: MiningDronePawn = mining_drone_scene.instantiate() as MiningDronePawn
	Global.world_manager.pawn_layer.add_child(new_drone)
	new_drone.global_position = Global.cell_to_world(owner_module.module_cell, true)
	new_drone.current_module = owner_module
	drones.append(new_drone)

func _exit_tree() -> void:
	for drone: MiningDronePawn in drones:
		drone.self_destruct()


func _can_output(amount: int) -> bool:
	return output_storage.space_available() >= amount
	
#func _deposit_outputs(fraction: float = 1.0) -> void:
	#var doublecheck: bool = output_storage.deposit(output_resource, fraction)
	#assert(doublecheck, "Somehow couldn't output items when there was room!")
#
#func _continuous_processing(delta: float) -> void:
	#var fraction_of_recipe: float = delta / time_to_process
	#if _can_output(fraction_of_recipe):
		#_deposit_outputs(fraction_of_recipe)
	#return
#
#func _stepwise_processing(delta: float) -> void:
	#if processing:
		#current_process_time += delta
		#processor_progress_changed.emit(current_process_time / time_to_process)
		#if current_process_time >= time_to_process:
			#if _can_output():
				#var doublecheck: bool = output_storage.deposit(output_resource, 1)
				#print("Mining completed")
				#assert(doublecheck, "Somehow couldn't output items when there was room!")
				#processor_progress_changed.emit(0)
				#processing = false
				#current_process_time = 0
			#else:
				#last_error = "No space for output resources!"
				#return
		#last_error = ""
	#else:
		#if _can_output():
			#print("Mining starting")
			#processor_progress_changed.emit(0)
			#processing = true
			#current_process_time = 0
			#last_error = ""
		#else:
			#last_error = "No space for output resources!"

func has_ui() -> bool:
	return false
	
func get_ui() -> ModuleComponentUI:
	var ui: ProcessorComponentUI = ui_info_panel_element.instantiate() as ProcessorComponentUI
	return ui
