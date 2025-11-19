class_name MiningComponent
extends ComponentBase

@export var output_storage: MultiStorageComponent
@export var time_to_process: float = 1
@export var power_consumer: PowerConsumptionComponent
@export var continuous: bool = false
@export var base_output_resource: ResourceData
@export var sub_resources: Array[ResourceData]

var output_resource: ResourceData

var processing: bool = false
var current_process_time: float = 0

signal processor_progress_changed(new_progress: float)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super()
	assert(output_storage != null, "Processor must have output_storage!")
	assert(power_consumer != null, "Processor must have power_consumer!")
	assert(time_to_process > 0, "Processor time_to_process must be > 0!")
	add_to_group("processor")
	output_resource = base_output_resource.duplicate()
	output_resource.base_resource = base_output_resource
	var mutiple: float = 0.0
	for resource_data: ResourceData in sub_resources:
		mutiple += 0.1
		output_resource.sub_resources[resource_data] = mutiple


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if !power_consumer.powered:
		# Do nothing if unpowered
		last_error = "No power!"
		return
	if continuous:
		_continuous_processing(delta)
	else:
		_stepwise_processing(delta)
	pass

func _can_output(fraction: float = 1.0) -> bool:
	return output_storage.can_deposit(output_resource, fraction)
	
func _deposit_outputs(fraction: float = 1.0) -> void:
	var doublecheck: bool = output_storage.deposit(output_resource, fraction)
	assert(doublecheck, "Somehow couldn't output items when there was room!")

func _continuous_processing(delta: float) -> void:
	var fraction_of_recipe: float = delta / time_to_process
	if _can_output(fraction_of_recipe):
		_deposit_outputs(fraction_of_recipe)
	return

func _stepwise_processing(delta: float) -> void:
	if processing:
		current_process_time += delta
		processor_progress_changed.emit(current_process_time / time_to_process)
		if current_process_time >= time_to_process:
			if _can_output():
				var doublecheck: bool = output_storage.deposit(output_resource, 1)
				print("Mining completed")
				assert(doublecheck, "Somehow couldn't output items when there was room!")
				processor_progress_changed.emit(0)
				processing = false
				current_process_time = 0
			else:
				last_error = "No space for output resources!"
				return
		last_error = ""
	else:
		if _can_output():
			print("Mining starting")
			processor_progress_changed.emit(0)
			processing = true
			current_process_time = 0
			last_error = ""
		else:
			last_error = "No space for output resources!"

func has_ui() -> bool:
	return false
	
func get_ui() -> ModuleComponentUI:
	var ui: ProcessorComponentUI = ui_info_panel_element.instantiate() as ProcessorComponentUI
	return ui
