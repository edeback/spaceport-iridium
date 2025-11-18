class_name ProcessorComponent
extends ComponentBase

@export var recipe: RecipeData
@export var input_storage: MultiStorageComponent
@export var output_storage: MultiStorageComponent
@export var time_to_process: float = 1
@export var power_consumer: PowerConsumptionComponent
@export var continuous: bool = false

var processing: bool = false
var current_process_time: float = 0

var last_error: String = ""

signal processor_progress_changed(new_progress: float)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	assert(recipe != null, "Processor must have recipe!")
	assert(input_storage != null, "Processor must have input_storage!")
	assert(output_storage != null, "Processor must have output_storage!")
	assert(power_consumer != null, "Processor must have power_consumer!")
	assert(time_to_process > 0, "Processor time_to_process must be > 0!")
	add_to_group("processor")
	super()


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

func _satisfies_recipe(fraction: float = 1.0) -> bool:
	for ingredient in recipe.inputs:
		var amount: float = recipe.inputs[ingredient] * fraction
		if !input_storage.can_withdraw(ingredient, amount):
			last_error = "Missing input!"
			return false
	for output in recipe.outputs:
		var amount: float = recipe.outputs[output] * fraction
		if !output_storage.can_deposit(output, amount):
			last_error = "No space for output!"
			return false
	return true
	
func _withdraw_inputs(fraction: float = 1.0) -> void:
	var doublecheck: bool = true
	for ingredient in recipe.inputs:
		var amount: float = recipe.inputs[ingredient] * fraction
		doublecheck = doublecheck and input_storage.withdraw(ingredient, amount)
	assert(doublecheck, "Somehow couldn't withdraw items that were available!")
	
func _deposit_outputs(fraction: float = 1.0) -> void:
	var doublecheck: bool = true
	for ingredient in recipe.outputs:
		var amount: float = recipe.outputs[ingredient] * fraction
		doublecheck = doublecheck and output_storage.deposit(ingredient, amount)
	assert(doublecheck, "Somehow couldn't output items when there was room!")

func _continuous_processing(delta: float) -> void:
	var fraction_of_recipe: float = delta / time_to_process
	if _satisfies_recipe(fraction_of_recipe):
		_withdraw_inputs(fraction_of_recipe)
		_deposit_outputs(fraction_of_recipe)
	return

func _stepwise_processing(delta: float) -> void:
	if processing:
		current_process_time += delta
		processor_progress_changed.emit(current_process_time / time_to_process)
		if current_process_time >= time_to_process:
			var can_output: bool = true
			for ingredient in recipe.outputs:
				var amount: float = recipe.outputs[ingredient]
				if !output_storage.can_deposit(ingredient, amount):
					last_error = "No space for output!"
					can_output = false
					break
			if can_output:
				var doublecheck: bool = true
				for ingredient in recipe.outputs:
					var amount: float = recipe.outputs[ingredient]
					doublecheck = doublecheck and output_storage.deposit(ingredient, amount)
				print("Processor completed with recipe " + recipe.name)
				assert(doublecheck, "Somehow couldn't output items when there was room!")
				processor_progress_changed.emit(0)
				processing = false
				current_process_time = 0
	else:
		if _satisfies_recipe():
			_withdraw_inputs()
			print("Processor starting with recipe " + recipe.name)
			processor_progress_changed.emit(0)
			processing = true
			current_process_time = 0

func has_ui() -> bool:
	return true
	
func get_ui() -> ModuleComponentUI:
	var ui: ProcessorComponentUI = ui_info_panel_element.instantiate() as ProcessorComponentUI
	ui.set_processor_component(self)
	return ui
