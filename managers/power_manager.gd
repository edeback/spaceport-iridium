class_name PowerManager
extends Node

var power_generators: Array[PowerGenerationComponent]
var power_consumers: Array[PowerConsumptionComponent]

signal power_updated(desired: float, generated: float)

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
	var consumers: Array[Node] = get_tree().get_nodes_in_group("power_consumer")
	var desired_power: float = 0
	for node in consumers:
		var consumer: PowerConsumptionComponent = node as PowerConsumptionComponent
		if consumer != null:
			desired_power += consumer.desired_power(delta)
		
	var generators: Array[Node] = get_tree().get_nodes_in_group("power_generator")
	var power_generated: float = 0
	for node in generators:
		var generator: PowerGenerationComponent = node as PowerGenerationComponent
		if generator != null:
			power_generated += generator.generate_power(delta)
	
	power_updated.emit(desired_power, power_generated)
	
	var power_needed: float = desired_power - power_generated
	var batteries: Array[Node] = get_tree().get_nodes_in_group("battery")
	if power_needed > 0:
		for node in batteries:
			var battery: BatteryComponent = node as BatteryComponent
			if battery != null:
				var battery_generated: float = battery.generate_power(delta, power_needed)
				power_needed -= battery_generated
				power_generated += battery_generated
				if power_needed < 0.000001:
					break
	
	# Fudge factor that is apparently needed after all this float math
	power_generated += 0.000001
	for node in consumers:
		var consumer: PowerConsumptionComponent = node as PowerConsumptionComponent
		if consumer != null:
			power_generated -= consumer.consume_power(delta, power_generated)
	
	if power_generated > 0:
		for node in batteries:
			var battery: BatteryComponent = node as BatteryComponent
			if battery != null:
				power_generated -= battery.store_power(delta, power_generated)
				if power_generated < 0.000001:
					break
				

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
