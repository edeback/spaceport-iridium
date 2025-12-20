## Debug settings for logging and debugging output. Includes settings for visual debugging as well such as RuleCheckIndicator debug _draw calls to the screen.
## Note: Feature-specific logging toggles (e.g., GridPositioner2D logging flags) still only produce output when the GBLogger level is set to VERBOSE or higher.
class_name GBDebugSettings
extends GBResource

## The message verbosity level for plugin logging typically handeled through GBLogger objects resolved through the GBCompositionContainer.
enum LogLevel {
	NONE = 0,    # No logging emitted from the plugin. Not recommended because this will hide real problems.
	ERROR = 1,   # Log only error conditions that require attention
	WARNING = 2, # Log recoverable issues and unexpected states. Recommended level for games in production.
	INFO = 3,    # High-level state transitions and important lifecycle events
	DEBUG = 4,   # Developer-focused debugging information (objects, params)
	VERBOSE = 5, # Very detailed, multi-line diagnostic output
	TRACE = 6    # Extremely fine-grained tracing useful for step-by-step flow analysis
}

## Emitted when the debug level changes to a new value
signal debug_level_changed(new_level: int)
signal grid_positioner_log_mode_changed(new_mode: int)

## Global plugin log level. Keep a private backing field only for this property so
## we can emit `debug_level_changed` when the level changes at runtime.
var _level_internal: LogLevel = LogLevel.WARNING
@export var level: LogLevel = LogLevel.WARNING:
	get:
		return _level_internal
	set(value):
		if _level_internal == value:
			return
		_level_internal = value
		debug_level_changed.emit(_level_internal)

@export_group("GridPositioner2D Logging")
## Centralized logging control for GridPositioner2D diagnostics. Select exactly one mode at a time.
enum GridPositionerLogMode {
	NONE = 0,          # Disable GridPositioner2D diagnostics
	VISIBILITY = 1,    # Visibility decisions, visual state, end-of-frame summaries
	MOUSE_INPUT = 2,   # Mouse input gating, projection, and screen/tile context
	POSITIONING = 3,   # Tile movement, recenter decisions, and related positioning helpers
	STATE_FLOW = 4     # Lifecycle events: dependency resolution, input toggles, mode changes, physics tick, deprecated APIs
}

var _grid_positioner_log_mode_internal: GridPositionerLogMode = GridPositionerLogMode.NONE

@export var grid_positioner_log_mode: GridPositionerLogMode = GridPositionerLogMode.NONE:
	get:
		return _grid_positioner_log_mode_internal
	set(value):
		if _grid_positioner_log_mode_internal == value:
			return
		_grid_positioner_log_mode_internal = value
		grid_positioner_log_mode_changed.emit(_grid_positioner_log_mode_internal)

func _init(p_default_level := LogLevel.WARNING, p_default_positioner_mode := GridPositionerLogMode.NONE):
	level = p_default_level
	grid_positioner_log_mode = p_default_positioner_mode

@export_group("Indicators")
## Enable or disable drawing of RuleCheckIndicator debug overlays.
@export var draw_rule_check_indicator_debug: bool = false

## RuleCheckIndicator visual tuning exposed in debug settings so teams can centrally
## adjust debug overlays without editing code.
##
## Minimum pixel radius used when drawing collision points for indicators.
@export var indicator_collision_point_min_radius: float = 2.0

## Scale factor applied to collision point radius based on the indicator's grid size.
@export var indicator_collision_point_scale: float = 0.15

## Minimum pixel width used when drawing connection lines for indicators.
@export var indicator_connection_line_min_width: float = 1.0

## Scale factor applied to connection line width based on the indicator's grid size.
@export var indicator_connection_line_scale: float = 0.05

## Color used to draw collision points (default: red).
@export var indicator_collision_point_color: Color = Color.RED

## Color for helper connection lines (default: orange).
@export var indicator_connection_line_color: Color = Color.ORANGE

## Outline color used when drawing indicator shapes (default: white).
@export var indicator_outline_color: Color = Color.WHITE

## Change the LogLevel to the passed value. Emits the [code]debug_level_changed[/code] signal if the level changes.
func set_debug_level(value: LogLevel) -> void:
	# Convenience setter that ensures the property setter is used
	level = value

## Get any issues detected in the editor context for this resource.
func get_editor_issues() -> Array[String]:
	return []

## Get any runtime issues detected for this resource.
func get_runtime_issues() -> Array[String]:
	return []
