## ManipulationTransformCalculator - Pure logic component for manipulation transform calculations.
##
## Responsibilities:
## - Calculate final transforms for placed objects after manipulation
## - Preserve flip semantics (negative scale values) during transform application
## - Provide testable, isolated transform logic separate from system dependencies
##
## This component contains NO dependencies on:
## - Scene tree
## - Signals
## - State management
## - Input handling
##
## All methods are pure functions that take inputs and return outputs.
class_name ManipulationTransformCalculator
extends RefCounted

## Calculates the final transform components for a manipulated object.
## Extracts position, rotation, and scale from the manipulation preview,
## preserving flip semantics (negative scale values).
##
## [param preview_root] The preview object root (child of ManipulationParent)
## [param manipulation_parent] The ManipulationParent containing accumulated transforms
## [return] Dictionary with keys: position (Vector2), rotation (float), scale (Vector2)
static func calculate_final_transform(preview_root: Node2D, manipulation_parent: Node2D) -> Dictionary:
	if preview_root == null:
		# Return safe defaults for null preview - no error logging as this is expected behavior
		return {"position": Vector2.ZERO, "rotation": 0.0, "scale": Vector2.ONE}
	
	if manipulation_parent == null:
		# Return safe defaults for null parent - no error logging as this is expected behavior
		return {"position": Vector2.ZERO, "rotation": 0.0, "scale": Vector2.ONE}
	
	# CRITICAL: Use ManipulationParent's global_position as final position
	# ManipulationParent follows the grid positioner, so its position is where the object should be placed
	# Using preview_root.global_position would give wrong results because it includes local offsets
	var final_position: Vector2 = manipulation_parent.global_position
	
	# CRITICAL: Capture rotation and scale from ManipulationParent directly
	# ManipulationParent accumulates user-applied transforms (rotation via R key, flips via F key)
	# Reading from ManipulationParent preserves negative scale values (flip semantics)
	var accumulated_rotation: float = manipulation_parent.rotation
	var accumulated_scale: Vector2 = manipulation_parent.scale
	
	return {
		"position": final_position,
		"rotation": accumulated_rotation,
		"scale": accumulated_scale
	}

## Validates that calculated transforms preserve flip semantics.
## Checks if negative scale values (flips) are preserved correctly.
##
## [param calculated_transforms] Dictionary from calculate_final_transform
## [return] Dictionary with keys: is_valid (bool), issues (Array[String])
static func validate_transform_preservation(calculated_transforms: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	
	if not calculated_transforms.has("position"):
		issues.append("Missing 'position' key in calculated transforms")
	
	if not calculated_transforms.has("rotation"):
		issues.append("Missing 'rotation' key in calculated transforms")
	
	if not calculated_transforms.has("scale"):
		issues.append("Missing 'scale' key in calculated transforms")
	
	if not issues.is_empty():
		return {"is_valid": false, "issues": issues}
	
	var scale: Vector2 = calculated_transforms["scale"]
	
	# Validate scale values are reasonable
	if abs(scale.x) < 0.01:
		issues.append("Scale X too small: %.4f (near zero scale will make object invisible)" % scale.x)
	
	if abs(scale.y) < 0.01:
		issues.append("Scale Y too small: %.4f (near zero scale will make object invisible)" % scale.y)
	
	# Note: Negative scale is VALID and expected for flips
	# This is the semantic flip preservation we want to maintain
	
	return {"is_valid": issues.is_empty(), "issues": issues}

## Formats transform data for diagnostic output.
## Creates human-readable string representation of transform components.
##
## [param transforms] Dictionary with position, rotation, scale keys
## [return] Formatted string for logging/debugging
static func format_transforms_debug(transforms: Dictionary) -> String:
	if not transforms.has("position") or not transforms.has("rotation") or not transforms.has("scale"):
		return "Invalid transform dictionary: %s" % str(transforms)
	
	var pos: Vector2 = transforms["position"]
	var rot: float = transforms["rotation"]
	var scale: Vector2 = transforms["scale"]
	
	return "Position: (%.2f, %.2f), Rotation: %.2f°, Scale: (%.2f, %.2f)" % [
		pos.x, pos.y,
		rad_to_deg(rot),
		scale.x, scale.y
	]

## Extracts transform components from a Transform2D for comparison.
## Breaks down a Transform2D into position, rotation, and scale for validation.
##
## NOTE: Transform2D.basis normalizes negative scale to positive scale + rotation.
## This method extracts the effective values after normalization.
##
## [param transform] The Transform2D to extract from
## [return] Dictionary with position, rotation, scale keys
static func extract_transform_components(transform: Transform2D) -> Dictionary:
	return {
		"position": transform.origin,
		"rotation": transform.get_rotation(),
		"scale": transform.get_scale()
	}

## Compares two transform component dictionaries for approximate equality.
## Uses tolerance values for floating-point comparison.
##
## [param expected] Dictionary with position, rotation, scale
## [param actual] Dictionary with position, rotation, scale
## [param position_tolerance] Maximum difference for position (default 0.1)
## [param rotation_tolerance] Maximum difference for rotation in radians (default 0.01)
## [param scale_tolerance] Maximum difference for scale (default 0.01)
## [return] Dictionary with keys: matches (bool), differences (Dictionary)
static func compare_transforms(
	expected: Dictionary,
	actual: Dictionary,
	position_tolerance: float = 0.1,
	rotation_tolerance: float = 0.01,
	scale_tolerance: float = 0.01
) -> Dictionary:
	var differences: Dictionary = {}
	
	# Compare position
	var pos_diff: Vector2 = expected["position"] - actual["position"]
	if abs(pos_diff.x) > position_tolerance or abs(pos_diff.y) > position_tolerance:
		differences["position"] = {
			"expected": expected["position"],
			"actual": actual["position"],
			"delta": pos_diff
		}
	
	# Compare rotation
	var rot_diff: float = expected["rotation"] - actual["rotation"]
	if abs(rot_diff) > rotation_tolerance:
		differences["rotation"] = {
			"expected": expected["rotation"],
			"actual": actual["rotation"],
			"delta": rot_diff
		}
	
	# Compare scale
	var scale_diff: Vector2 = expected["scale"] - actual["scale"]
	if abs(scale_diff.x) > scale_tolerance or abs(scale_diff.y) > scale_tolerance:
		differences["scale"] = {
			"expected": expected["scale"],
			"actual": actual["scale"],
			"delta": scale_diff
		}
	
	return {
		"matches": differences.is_empty(),
		"differences": differences
	}
