## Encapsulates Area2D-based targeting logic as a reusable component
## Unlike ShapeCast2D which only detects PhysicsBody2D nodes, Area2D can detect other Area2D nodes
class_name TargetingArea2D
extends Area2D

## GB dependencies (typed)
var _logger: GBLogger = null
var _targeting_state: GridTargetingState = null

## Local debug flag: can be toggled per-instance in editor or by code
@export var debug_log_overlaps: bool = false

## Current target being tracked
var _current_target: Area2D = null

func _ready() -> void:
	# Connect to Area2D signals for overlap detection
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

## Resolve Grid Building dependencies (logger, targeting state)
func resolve_gb_dependencies(p_container: GBCompositionContainer) -> void:
	_logger = p_container.get_logger()
	_targeting_state = p_container.get_states().targeting

## Physics process: continuously update targeting state based on Area2D overlaps
func _physics_process(_delta: float) -> void:
	update_target()

## Update the GridTargetingState.target based on current overlaps
func update_target() -> void:
	if _targeting_state == null:
		return

	var overlapping_areas: Array[Area2D] = get_overlapping_areas()
	
	if overlapping_areas.size() > 0:
		# Get the first overlapping area as target
		var new_target: Area2D = overlapping_areas[0]
		
		if new_target != _targeting_state.target:
			if debug_log_overlaps and _logger:
				_logger.log_verbose("[TargetingArea2D] Target changed %s -> %s" % 
					[GBDiagnostics.format_node_label(_targeting_state.target), 
					 GBDiagnostics.format_node_label(new_target)])
			
			_targeting_state.target = new_target
			_current_target = new_target
	else:
		# No overlaps - clear target
		if _targeting_state.target != null:
			if debug_log_overlaps and _logger:
				_logger.log_verbose("[TargetingArea2D] Lost target %s (no overlaps)" % 
					GBDiagnostics.format_node_label(_targeting_state.target))
			
			_targeting_state.target = null
			_current_target = null

## Called when an area enters overlap
func _on_area_entered(area: Area2D) -> void:
	if debug_log_overlaps and _logger:
		_logger.log_verbose("[TargetingArea2D] Area entered: %s" % GBDiagnostics.format_node_label(area))
	
	# Update target immediately
	update_target()

## Called when an area exits overlap
func _on_area_exited(area: Area2D) -> void:
	if debug_log_overlaps and _logger:
		_logger.log_verbose("[TargetingArea2D] Area exited: %s" % GBDiagnostics.format_node_label(area))
	
	# Update target immediately
	update_target()
