## Wrapper for accessing the active IndicatorManager at runtime.
## The indicator manager creates and managers RuleCheckIndicators for the given context scope
class_name IndicatorContext
extends RefCounted

signal manager_changed(new: IndicatorManager)

var _indicator_manager: IndicatorManager

func get_manager() -> IndicatorManager:
	if _indicator_manager == null:
		push_error("IndicatorManager has not been set in IndicatorContext.")
		return null
	return _indicator_manager

func set_manager(manager: IndicatorManager) -> void:
	if _indicator_manager == manager:
		return

	_indicator_manager = manager
	manager_changed.emit(_indicator_manager)

func has_manager() -> bool:
	return _indicator_manager != null

## Delegates to the _indicator_manager to validate the placement of an object in the scene
func validate_placement() -> ValidationResults:
	return _indicator_manager.validate_placement()

func get_editor_issues() -> Array[String]:
	var issues: Array[String] = []

	# NOTE: IndicatorManager assignment is a runtime-only check

	return issues

func get_runtime_issues() -> Array[String]:
	var issues: Array[String] = []

	if _indicator_manager == null:
		issues.append("IndicatorManager is not assigned in IndicatorContext")

	return issues
