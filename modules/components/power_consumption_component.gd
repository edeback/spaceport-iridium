class_name PowerConsumptionComponent
extends ComponentBase

@export var power_consumption: float = 10.0
@export var capacitator: float = 0.0
@export var animation_player: AnimationPlayer

var powered: bool = true

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("power_consumer")
	super()

	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func desired_power(delta: float) -> float:
	return delta * power_consumption

func consume_power(delta: float, input_power: float) -> float:
	var consumption = delta * power_consumption
	if input_power >= consumption:
		set_power(true)
		return consumption
	set_power(false)
	return input_power

func set_power(power: bool) -> void:
	if powered:
		if !power:
			powered = false
			animation_player.play("no_power")
	else:
		if power:
			powered = true
			animation_player.play("RESET")
