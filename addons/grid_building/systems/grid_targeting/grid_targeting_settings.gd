## Settings related to targeting tiles and the pathing that goes between them
class_name GridTargetingSettings
extends GBResource

## Emitted when the show_debug property changes value
## Note: Per-property legacy signals were removed; use notify_property_list_changed for change observation.

## When set, limits tile section to only the character adjacent tile that is in the direction of the cirspr location
@export var limit_to_adjacent = false

## The number of tiles distance away from the limit target (if one is set)
## that the pointer tile can be
@export_range(0,20,1,"or_greater") var max_tile_distance : int = 3

## Makes it so the cursor can only move to areas with valid tiles on the target map layer
## or can move freely with snapping when false
@export var restrict_to_map_area = false

## Whether to show debug information for targeting systems
@export var show_debug : bool = false :
	set(value):
		if show_debug == value:
			return
		
		show_debug = value
		notify_property_list_changed()
		
		if(show_debug):
			print("Show Debug [ON] for TargetingSettings " + resource_name)

@export_group("GridPositioner2D Settings")
## Toggle whether the GridPositioner2D will move with mouse input or not
@export var enable_mouse_input : bool = true

## Toggle whether the GridPositioner will move with keyboard input or not. You must define the
## positioner input actions defined in the GBActions resource
@export var enable_keyboard_input : bool = false

## Toggle whether the GridPositioner2D can rotate objects with rotation input (if a target object is present)
## When enabled, rotate_left and rotate_right actions will rotate the targeted object in 90-degree increments
@export var enable_rotation_input : bool = false

## Controls whether GridPositioner2D remains active during OFF mode
## 
## When true: The positioner continues to respond to mouse/keyboard input and can move/recenter
##           even when the targeting mode is set to OFF. Useful for demo scenes, level editors,
##           or debug tools where the cursor should remain interactive outside of build mode.
##
## When false: The positioner ignores all input and positioning commands when in OFF mode,
##            effectively disabling cursor movement and recentering until a different mode 
##            (MOVE, DEMOLISH, etc.) is activated.
##
## Default: false (positioner disabled in OFF mode for typical gameplay)
@export var remain_active_in_off_mode : bool = false

## Manual recenter mode for GridPositioner2D input actions
@export var manual_recenter_mode: GBEnums.CenteringMode = GBEnums.CenteringMode.CENTER_ON_SCREEN

## Recenter policy on enable: choose where to place the positioner when input is (re)enabled
## NONE:        Do nothing (no recenter)
## LAST_SHOWN:  Use last known/cached world position if available; fallback to mouse/camera per input settings
## VIEW_CENTER: Center on the viewport/camera center
## MOUSE_CURSOR:Center on the mouse cursor (uses cached event world if available; may fallback to camera center)
enum RecenterOnEnablePolicy { NONE, LAST_SHOWN, VIEW_CENTER, MOUSE_CURSOR }
@export var position_on_enable_policy: RecenterOnEnablePolicy = RecenterOnEnablePolicy.MOUSE_CURSOR

## Controls whether the grid positioner hides when mouse input is handled by UI.
##
## When [code]true[/code], the positioner will hide if:
## - Mouse input is enabled ([member enable_mouse_input] is [code]true[/code])
## - A mouse event was consumed/handled by UI elements (not reaching the game world)
##
## When [code]false[/code] or when mouse input is disabled, the positioner remains
## visible regardless of UI mouse handling.
##
## [b]Note:[/b] This setting only applies when [member enable_mouse_input] is [code]true[/code].
## If mouse input is disabled, [code]hide_on_handled[/code] has no effect.
##
## [b]Behavior Examples:[/b]
## - Mouse enabled + hide_on_handled=true + UI consumes mouse = Hidden
## - Mouse enabled + hide_on_handled=false + UI consumes mouse = Visible
## - Mouse disabled + hide_on_handled=true + any mouse state = Visible (ignored)
@export var hide_on_handled : bool = true


@export_group("AStarGrid2D Settings")
@export var region_size = Vector2i(50, 50): # Testing size
	set(value):
		if region_size == value:
			return
		
		region_size = value
		notify_property_list_changed()
		
@export var cell_shape = AStarGrid2D.CellShape.CELL_SHAPE_SQUARE:
	set(value):
		if cell_shape == value:
			return
		
		cell_shape = value
		notify_property_list_changed()

## What moves are allowed in a single change of grid space for grid pathing
@export var diagonal_mode = AStarGrid2D.DiagonalMode.DIAGONAL_MODE_ALWAYS :
	set(value):
		if diagonal_mode == value:
			return
		
		diagonal_mode = value
		notify_property_list_changed()
		
## Formula for calculating AStarGrid2D movement cost
## When created, sets the default_default_compute_heuristic on the AStarGrid2D of the GridTargetingSystem
@export var default_compute_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN :
	set(value):
		if default_compute_heuristic == value:
			return
		
		default_compute_heuristic = value
		notify_property_list_changed()

## Formula for calculating AStarGrid2D movement cost
## When created, sets the default_default_estimate_heuristic on the AStarGrid2D of the GridTargetingSystem
@export var default_estimate_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN :
	set(value):
		if default_estimate_heuristic == value:
			return
		
		default_estimate_heuristic = value
		notify_property_list_changed()

func get_editor_issues() -> Array[String]:
	var issues : Array[String] = []

	if max_tile_distance < 0:
		issues.append("Max tile distance must be a positive value on %s" % self)

	return issues

func get_runtime_issues() -> Array[String]:
	return get_editor_issues()
