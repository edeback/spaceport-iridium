class_name LightingComponent
extends Node2D

@export var power_consumption_component: PowerConsumptionComponent
@export var power_generation_component: PowerGenerationComponent
@onready var light: Sprite2D = $Sprite2D

func ready_preview() -> void:
	light.visible = false
	set_process(false)
	
func ready_blueprint() -> void:
	light.visible = false
	set_process(false)
	
func ready_constructed() -> void:
	set_process(true)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if power_consumption_component:
		light.visible = power_consumption_component.powered
	elif power_generation_component:
		light.visible = power_generation_component.powered
	else:
		light.visible = false
