## Injectable control for display grid building related information for the owning object.
@icon("res://addons/grid_building/icons/gb_control.svg")
class_name GBControl
extends Control

func resolve_gb_dependencies(p_container: GBCompositionContainer) -> void:
	push_warning("Abstract function. Implement in inheriting script.")
