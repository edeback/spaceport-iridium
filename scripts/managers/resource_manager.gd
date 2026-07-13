class_name ResourceManager
extends Node

@export var storable_resources: Array[ResourceData] = []

# Because so many use it directly
@export var credit_resource: ResourceData

func _ready() -> void:
	Global.resource_manager = self
	Global.time_manager.slow_tick.connect(_on_slow_tick)

func _on_slow_tick(_interval: float) -> void:
	for resource: ResourceData in storable_resources:
		resource._recalc_resource()
	
