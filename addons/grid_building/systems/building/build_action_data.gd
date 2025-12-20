class_name BuildActionData
extends RefCounted
## Values for an attempted build action

## The resource defining the rules and scene to instance for a placeable object
var placeable: Placeable

## The placement report from the attempted action
var report : PlacementReport

## Type of build operation (SINGLE, DRAG, or AREA)
var build_type: GBEnums.BuildType = GBEnums.BuildType.SINGLE

func _init(
	p_placeable: Placeable,
	p_report: PlacementReport,
	p_build_type: GBEnums.BuildType = GBEnums.BuildType.SINGLE
):
	placeable = p_placeable
	report = p_report
	build_type = p_build_type

## Returns the preview instance from the build action if it exists
func get_preview() -> Node:
	return report.preview_instance if report != null && report.preview_instance != null else null

func get_placed_position() -> Vector2:
	assert(report != null, "Report must be set properly to pull the placed position from report.placed")
	return report.placed.global_position
