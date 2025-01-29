class_name PowerConsumptionComponent
extends ComponentBase

@export var power_consumption: float = 10.0
@export var capacitator: float = 0.0

var powered: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("power_consumer")
	super()

	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func consume_power(delta: float, input_power: float) -> float:
	var consumption = delta * power_consumption
	if input_power >= consumption:
		powered = true
		return consumption
	powered = false
	return input_power
