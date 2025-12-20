## Groups related plugin states together for centralized access.
##
## Provides a single container for all grid building system states including building, mode, targeting, and manipulation.
class_name GBStates
extends RefCounted

## Resource tracking build success/failure signals.
var building: BuildingState

## Tracks current mode (e.g., build mode, demolish mode).
var mode: ModeState

## Holds references to target node and tilemap.
var targeting: GridTargetingState

## State of manipulation actions (move, demolish, etc).
var manipulation: ManipulationState

func _init(p_owner_context: GBOwnerContext):
	building = BuildingState.new(p_owner_context)
	mode = ModeState.new()
	targeting = GridTargetingState.new(p_owner_context)
	manipulation = ManipulationState.new(p_owner_context)

func get_runtime_issues() -> Array[String]:
	var issues: Array[String] = []
	
	if building == null:
		issues.append("Building state is not set")
	else:
		issues.append_array(building.get_runtime_issues())

	if mode == null:
		issues.append("Mode state is not set")
	else:
		issues.append_array(mode.get_runtime_issues())

	if targeting == null:
		issues.append("Targeting state is not set")
	else:
		issues.append_array(targeting.get_runtime_issues())

	if manipulation == null:
		issues.append("Manipulation state is not set")
	else:
		issues.append_array(manipulation.get_runtime_issues())

	return issues
