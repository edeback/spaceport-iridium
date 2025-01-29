class_name PowerGenerationComponent
extends ComponentBase

@export var power_output: float = 100.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("power_generator")
	super()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func generate_power(delta: float) -> float:
	return power_output * delta
