## 2D variant of `GBNode` providing a common base for Scene2D plugin nodes.
##
## Use this base for Node2D-derived components that are part of plugin systems, so
## they receive consistent DI and lifecycle behavior expected across the project.
@icon("res://addons/grid_building/icons/kenney/menuGrid.png")
class_name GBNode2D
extends Node2D

func resolve_gb_dependencies(p_container : GBCompositionContainer) -> void:
	push_warning("Abstract function. Implement in inheriting script.")
