class_name PowerManager
extends Node

var power_generators: Array[PowerGenerationComponent]
var power_consumers: Array[PowerConsumptionComponent]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.power_manager = self
	#SignalBus.node_grouped.connect(node_added_to_group)
	#SignalBus.node_ungrouped.connect(node_removed_from_group)
	pass # Replace with function body.


#func node_added_to_group(node: Node, group: String) -> void:
	#match group:
		#"power_generator":
			#pass
		#"power_consumer":
			#pass
	#
#func node_removed_from_group(node: Node, group: String) -> void:
	#match group:
		#"power_generator":
			#pass
		#"power_consumer":
			#pass
			
func power_modules(delta: float) -> void:
	var generators = get_tree().get_nodes_in_group("power_generator")
	var power_generated = 0.01
	for node in generators:
		var generator = node as PowerGenerationComponent
		if generator != null:
			power_generated += generator.generate_power(delta)
	var consumers = get_tree().get_nodes_in_group("power_consumer")
	for node in consumers:
		var consumer = node as PowerConsumptionComponent
		if consumer != null:
			power_generated -= consumer.consume_power(delta, power_generated)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
