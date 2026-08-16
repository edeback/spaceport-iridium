class_name SolarPowerComponent
extends PowerGenerationComponent

@export var scales_by_surroundings: bool = true
@export var structure_component: StructureComponent

var power_scaling: float = 1.0

func _ready() -> void:
	super()
	connections_changed(structure_component.module_connections)
	structure_component.module_connections_changed.connect(connections_changed)
	
## The panel is shaded by whatever is bolted to its sides. The arithmetic moved to
## StructureComponent.open_face_fraction() in WI-60, where the heat system's
## radiation term needs the identical answer - including the implicit back face
## that keeps a fully boxed-in panel generating something rather than nothing.
## The signal hands us its own dictionary, so this reads the component directly.
func connections_changed(_new_connections: Dictionary[ModuleBase, bool]) -> void:
	power_scaling = structure_component.open_face_fraction()
		
func get_power_output()  -> float:
	# super() reads the effective (damage/upgrade-scaled) base output; the
	# surroundings scaling then applies on top of that.
	return super() * power_scaling
