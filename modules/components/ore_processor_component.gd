# Maybe not necessary at all?

class_name OreProcessorComponent
extends ComponentBase

@export var base_resource: ResourceData
@export var input_storage: MultiStorageComponent
@export var output_storage: MultiStorageComponent
@export var time_to_process: float = 1
@export var power_consumer: PowerConsumptionComponent

var current_process_time: float = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	assert(input_storage != null, "Processor must have input_storage!")
	assert(output_storage != null, "Processor must have output_storage!")
	assert(power_consumer != null, "Processor must have power_consumer!")
	assert(time_to_process > 0, "Processor time_to_process must be > 0!")
	#add_to_group("processor")
	super()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if !power_consumer.powered:
		# Do nothing if unpowered
		last_error = "No power!"
		return
	_continuous_processing(delta)
	pass

func _continuous_processing(delta: float) -> void:
	pass
	#var fraction: float = delta / time_to_process
	#var resource_to_process: ResourceData = input_storage.find_first_stored_resource_with_base(base_resource, fraction)
	#if resource_to_process:
		#var do_process: bool = true
		#for sub_resource: ResourceData in resource_to_process.sub_resources:
			#do_process = do_process and output_storage.can_deposit(sub_resource, resource_to_process.sub_resources[sub_resource] * fraction)
		#if do_process:
			#last_error = ""
			#input_storage.withdraw(resource_to_process, fraction)
			#for sub_resource: ResourceData in resource_to_process.sub_resources:
				#output_storage.deposit(sub_resource, resource_to_process.sub_resources[sub_resource] * fraction)
		#else:
			#last_error = "Can't deposit output resources!"
	#else:
		#last_error = "No input resources!"
