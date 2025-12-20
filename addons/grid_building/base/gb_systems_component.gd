## Base category for a Node class that serves as an dependency injectable child of a GBSystem
@icon("res://addons/grid_building/icons/kenney/wrench.png")
class_name GBSystemsComponent
extends GBNode

func resolve_gb_dependencies(p_container : GBCompositionContainer) -> void:
	push_warning("Abstract function. Implement in inheriting class.")
