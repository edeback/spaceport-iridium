## Lightweight interface for RefCounted objects that require DI.
##
## Use this base class to mark RefCounted helpers as eligible for dependency injection
## via the project's composition container. Subclasses must implement `resolve_gb_dependencies`
## and `get_dependency_issues` to receive and verify required services.
@icon("res://addons/grid_building/icons/kenney/wrench.png")
class_name GBInjectable
extends RefCounted

## Override this method to receive injected dependencies.
## This method will be called during initialization or when explicitly injected.[br][br]
## [b]Fail‑fast policy:[/b] This abstract method intentionally provides NO stub implementation (no silent `pass`).
## Any subclass must implement it; omission will surface immediately at runtime when injection occurs.[br][br]
## [code]container[/code]: [i]GBCompositionContainer[/i] - The dependency container with all services
## [return]bool - True if dependencies were successfully resolved, false otherwise
func resolve_gb_dependencies(container: GBCompositionContainer) -> bool:
	push_warning("Abstract function. Implement in inheriting class.")
	return false

## Validates that all required dependencies have been properly injected.
## Returns list of validation issue messages (empty if valid).[br][br]
## This is abstract & body-less to avoid masking missing overrides with a default [] return.
func get_runtime_issues() -> Array[String]:
	push_warning("Abstract function. Implement in inheriting class.")
	return []

## Helper method to manually inject dependencies into this object.
## Useful when creating RefCounted objects that need injection outside of the normal flow.[br][br]
## [code]container[/code]: [i]GBCompositionContainer[/i] - The dependency container
func inject_dependencies(container: GBCompositionContainer) -> GBInjectable:
	resolve_gb_dependencies(container)
	var issues = get_runtime_issues()
	if not issues.is_empty():
		var logger = container.get_logger() if container else null
		var warning_message = "Dependency validation issues in %s: %s" % [get_script().get_global_name(), str(issues)]
		
		if logger:
			logger.log_warning( warning_message)
		else:
			push_warning(warning_message)
	return self
