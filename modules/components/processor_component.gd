class_name ProcessorComponent
extends ComponentBase

@export var recipe: RecipeData
@export var input_storage: StorageComponent
@export var output_storage: StorageComponent
@export var time_to_process: float = 1
@export var power_consumer: PowerConsumptionComponent

var processing: bool = false
var current_process_time: float = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	assert(recipe != null, "Processor must have recipe!")
	assert(input_storage != null, "Processor must have input_storage!")
	assert(output_storage != null, "Processor must have output_storage!")
	assert(power_consumer != null, "Processor must have power_consumer!")
	assert(time_to_process > 0, "Processor time_to_process must be > 0!")
	add_to_group("processor")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if !power_consumer.powered:
		# Do nothing if unpowered
		return
	if processing:
		current_process_time += delta
		if current_process_time >= time_to_process:
			var can_output = true
			for ingredient in recipe.outputs:
				var amount: int = recipe.outputs[ingredient]
				if !output_storage.can_deposit(ingredient, amount):
					can_output = false
					break
			if can_output:
				var doublecheck: bool = true
				for ingredient in recipe.outputs:
					var amount: int = recipe.outputs[ingredient]
					doublecheck = doublecheck and output_storage.deposit(ingredient, amount)
				print("Processor completed with recipe " + recipe.name)
				assert(doublecheck, "Somehow couldn't output items when there was room!")
				processing = false
				current_process_time = 0
	else:
		var satisfies_recipe: bool = true
		for ingredient in recipe.inputs:
			var amount: int = recipe.inputs[ingredient]
			if !input_storage.can_withdraw(ingredient, amount):
				satisfies_recipe = false
				break
		if satisfies_recipe:
			var doublecheck: bool = true
			for ingredient in recipe.inputs:
				var amount: int = recipe.inputs[ingredient]
				doublecheck = doublecheck and input_storage.withdraw(ingredient, amount)
			print("Processor starting with recipe " + recipe.name)
			assert(doublecheck, "Somehow couldn't withdraw items that were available!")
			processing = true
			current_process_time = 0
	pass
