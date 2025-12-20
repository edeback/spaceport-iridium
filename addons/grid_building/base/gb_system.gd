## Base class for plugin subsystems.
##
## Derive system implementations (placement, manipulation, targeting, etc.) from this
## class to gain standard lifecycle hooks and DI integration. Systems should validate
## dependencies and expose well-defined public methods for coordination with other systems.
@icon("res://addons/grid_building/icons/kenney/gear.png")
class_name GBSystem
extends GBNode

## Injects dependencies from the composition container (fail-fast: no default body).
func resolve_gb_dependencies(p_config : GBCompositionContainer) -> void:
	push_warning("Resolve GB Dependencies is an abstract function. Implement it in inheriting class to override")


## Validates that all required dependencies are properly set.
## Returns list of validation issue messages (empty if valid). Fail-fast abstract.
func get_runtime_issues() -> Array[String]:
	push_warning("Resolve GB Dependencies is an abstract function. Implement it in inheriting class to override")
	return []
