## Contains contexts for resolving references to current objects within the grid building system instance
class_name GBContexts
extends RefCounted

## Holds reference to current indicator manager object
var indicator: IndicatorContext

## Holds reference to the currently owning game node for the instance of the grid building system and related modules
var owner: GBOwnerContext

## Holds references to the systems used in grid building operations.
## This context allows for easy access to the systems without needing to
## pass them around manually.
var systems: GBSystemsContext

func _init(p_logger: GBLogger) -> void:
	indicator = IndicatorContext.new()
	owner = GBOwnerContext.new()
	systems = GBSystemsContext.new(p_logger)

## Ensures all runtime contexts are properly initialized.
## Contexts may need to have their properties defined by game objects like GBLevelContext and GBOwner
func get_runtime_issues(p_checks: GBRuntimeChecks) -> Array[String]:
	var issues: Array[String] = []
	if indicator:
		issues.append_array(indicator.get_runtime_issues())
	else:
		issues.append("IndicatorContext is null")
	
	if owner:
		issues.append_array(owner.get_runtime_issues())
	else:
		issues.append("GBOwnerContext is null")
	
	if systems:
		issues.append_array(systems.get_runtime_issues(p_checks))
	else:
		issues.append("GBSystemsContext is null")
	
	return issues

## Validates editor configuration before nodes are set up.
## This should be called during the editor setup phase.[br]
## Returns:[br]
##   [b]Array[String][/b] - List of editor configuration issues (empty if valid)
func get_editor_issues() -> Array[String]:
	var issues: Array[String] = []
	issues.append_array(indicator.get_editor_issues())
	issues.append_array(owner.get_editor_issues())
	issues.append_array(systems.get_editor_issues())
	return issues
