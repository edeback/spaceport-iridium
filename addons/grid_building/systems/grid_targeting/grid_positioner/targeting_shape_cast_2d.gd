## Encapsulates ShapeCast2D-based targeting logic as a reusable component
class_name TargetingShapeCast2D
extends ShapeCast2D

## GB dependencies (typed)
var _logger: GBLogger = null
var _targeting_state: GridTargetingState = null

## Local debug flag: can be toggled per-instance in editor or by code
@export var debug_log_collisions: bool = false

## Resolve Grid Building dependencies (logger, targeting state)
func resolve_gb_dependencies(p_container: GBCompositionContainer) -> void:
	_logger = p_container.get_logger()
	_targeting_state = p_container.get_states().targeting
	
	# Log collision configuration diagnostics
	if _logger:
		var config_msg := "[TargetingShapeCast2D] Configuration: "
		config_msg += "collide_with_bodies=%s, " % str(collide_with_bodies)
		config_msg += "collide_with_areas=%s, " % str(collide_with_areas)
		config_msg += "collision_mask=%d (%s)" % [collision_mask, _format_collision_layers(collision_mask)]
		_logger.log_verbose(config_msg)

## Physics process: continuously update targeting state based on ShapeCast2D collisions
func _physics_process(_delta: float) -> void:
	update_target()

## Update the GridTargetingState.target based on current collisions
## Skips automatic updates when manipulation is active (target set manually)
func update_target() -> void:
	if _targeting_state == null:
		return
	
	# Skip automatic targeting updates during active manipulation/build mode
	# The target is manually set and maintained by ManipulationSystem/BuildingSystem
	if _targeting_state.is_manual_targeting_active:
		return

	var old_target: Node2D = _targeting_state.target

	if is_colliding():
		if debug_log_collisions and _logger:
			_log_collisions()

		var raw_collider: Node = get_collider(0)
		var promoted_target: Node2D = _promote_to_targetable_root(raw_collider)
		if is_instance_valid(promoted_target) and promoted_target != old_target:
			if _logger:
				_logger.log_verbose("[TargetingShapeCast2D] Target changed %s -> %s" % [GBDiagnostics.format_node_label(old_target), GBDiagnostics.format_node_label(promoted_target)])
			_targeting_state.target = promoted_target
	else:
		if debug_log_collisions and _logger:
			_log_collisions()
		if old_target != null and _logger:
			_logger.log_verbose("[TargetingShapeCast2D] Lost target %s (is_colliding=false)" % GBDiagnostics.format_node_label(old_target))
		_targeting_state.target = null

## Log current collisions for diagnostics
func _log_collisions() -> void:
	if _logger == null:
		return
	var formatted: String = GBDiagnostics.format_shape_cast_collisions(self)
	_logger.log_verbose("[TargetingShapeCast2D] %s" % formatted)

## Format collision mask as layer names or numbers
func _format_collision_layers(mask: int) -> String:
	var layer_names: Array[String] = []
	
	# Check each of the 32 possible physics layers
	for bit in range(32):
		var layer_value := 1 << bit
		if mask & layer_value:
			var layer_number := bit + 1  # Layers are 1-indexed in Godot
			var layer_name := ProjectSettings.get_setting("layer_names/2d_physics/layer_%d" % layer_number, "")
			
			if layer_name != "":
				layer_names.append("%s (bit %d)" % [layer_name, bit])
			else:
				layer_names.append("bit %d" % bit)
	
	if layer_names.is_empty():
		return "none"
	
	return ", ".join(layer_names)

## Promote a raw collider (which may be a child physics body) to its root Area2D if that root
## represents the intended gameplay target. This handles scenes like the Smithy where the
## visual/physics StaticBody2D is a child of an Area2D which carries the targetable layer.
## [param raw] The collider returned by ShapeCast2D.
## [return] A Node2D to use as targeting root (prefer Area2D on targetable layer) or the original if no promotion needed.
func _promote_to_targetable_root(raw: Object) -> Node2D:
	if raw == null or not is_instance_valid(raw):
		return null
	if raw is Area2D:
		# Already an Area2D (ideal root)
		return raw
	# If collider is a StaticBody2D or other Node2D child, climb parents to find an Area2D.
	if raw is Node2D:
		var node: Node = raw
		# Limit climb depth to prevent accidental long traversals on malformed hierarchies.
		var depth := 0
		while node != null and depth < 5:
			if node is Area2D:
				return node
			node = node.get_parent()
			depth += 1
		# Fallback: return original raw node if no Area2D ancestor discovered.
		return raw
	return null
