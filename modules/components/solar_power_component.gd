class_name SolarPowerComponent
extends PowerGenerationComponent

@export var scales_by_surroundings: bool = true
@export var structure_component: StructureComponent

var power_scaling: float = 1.0

func _ready() -> void:
	super()
	connections_changed(structure_component.module_connections)
	structure_component.module_connections_changed.connect(connections_changed)
	
func connections_changed(new_connections: Dictionary[ModuleBase, bool]) -> void:
	var possible_connections: int = structure_component.connection_points.size() + 1
	var current_connections: float = 0
	for connection_type: bool in new_connections.values():
		# Basically if it's not a cross-layer connection
		if not connection_type:
			current_connections += 1
	power_scaling = (possible_connections - current_connections) / possible_connections
		
func get_power_output()  -> float:
	# super() reads the effective (damage/upgrade-scaled) base output; the
	# surroundings scaling then applies on top of that.
	return super() * power_scaling
