## Thin Node wrapper used as a common base for plugin game nodes.
##
## Provides a consistent identity and place to add plugin-wide helpers for nodes used
## in systems and tooling. Prefer deriving game objects and system nodes from GBNode
## when they participate in the Grid Building lifecycle.
@icon("res://addons/grid_building/icons/kenney/menuGrid.png")
class_name GBNode
extends Node

## Abstract method to resolve dependencies for a given GBCompositionContainer.
## This method should be overridden in derived classes to implement specific dependency resolution logic.
func resolve_gb_dependencies(p_container : GBCompositionContainer) -> void:
    pass