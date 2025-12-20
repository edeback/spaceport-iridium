## Holds shared template packed scenes for grid building systems to use.
##
## Provides centralized template management for visual components like rule indicators and validation overlays.
class_name GBTemplates
extends GBResource

## Overlay object for validating tile placement rules on an individual tile or region.[br][br]
## [code]rule_check_indicator[/code]: [i]PackedScene[/i] - Template scene for visual placement validation feedback
@export var rule_check_indicator: PackedScene

func get_editor_issues() -> Array[String]:
    var issues: Array[String] = []
    if rule_check_indicator == null:
        issues.append("Rule check indicator is not set")
    return issues

func get_runtime_issues() -> Array[String]:
    var issues: Array[String] = []

    issues.append_array(get_editor_issues())

    return issues