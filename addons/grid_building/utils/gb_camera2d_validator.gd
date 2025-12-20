@tool
class_name GBCamera2DValidator
extends RefCounted

## Camera2D Setup Validator for Grid Building Plugin
##
## This validation tool helps developers verify that their Camera2D setup meets
## the requirements for the Grid Building plugin's coordinate conversion system.
##
## [b]Usage:[/b]
## [codeblock]
## # In your scene setup or debugging code:
## var validator = GBCamera2DValidator.new()
## var is_valid = validator.validate_scene_setup(get_tree().current_scene)
## if not is_valid:
##     print("❌ Camera2D setup issues found - check console for details")
## [/codeblock]
##
## [b]Purpose:[/b]
## The Grid Building plugin requires Camera2D for pixel-perfect coordinate conversion.
## This validator ensures your scene setup meets these requirements.

## Validates Camera2D setup for a given scene tree.
## [param scene_root] The root node to validate (typically your main scene)
## [return] True if setup is valid, false if issues found
static func validate_scene_setup(scene_root: Node) -> bool:
	print("🔍 Grid Building Camera2D Validation Starting...")
	print("   Scene: %s" % scene_root.name)
	
	var issues: Array[String] = []
	var warnings: Array[String] = []
	
	# Find viewport
	var viewport: Viewport = scene_root.get_viewport()
	if not viewport:
		issues.append("No viewport found for scene root")
		_print_results([], [], issues)
		return false
	
	# Check for Camera2D
	var camera: Camera2D = viewport.get_camera_2d()
	if not camera:
		issues.append("❌ CRITICAL: No Camera2D found in viewport")
		issues.append("   Solution: Add Camera2D node to your scene hierarchy")
		_print_results([], [], issues)
		return false
	
	var successes: Array[String] = []
	
	# Validate Camera2D configuration
	successes.append("✅ Camera2D found: %s" % camera.name)
	
	# Check enabled state
	if not camera.enabled:
		issues.append("❌ Camera2D is disabled (enabled = false)")
		issues.append("   Solution: Set camera.enabled = true")
	else:
		successes.append("✅ Camera2D is enabled")
	
	# Check if current
	if not camera.is_current():
		issues.append("❌ Camera2D is not current")
		issues.append("   Solution: Call camera.make_current()")
	else:
		successes.append("✅ Camera2D is current camera")
	
	# Check zoom settings
	var zoom = camera.zoom
	if zoom.x <= 0 or zoom.y <= 0:
		issues.append("❌ Invalid zoom settings: %s" % zoom)
		issues.append("   Solution: Set positive zoom values (e.g., Vector2(2, 2))")
	else:
		successes.append("✅ Camera2D zoom: %s" % zoom)
		
		# Check if zoom is power of 2 (recommended for pixel-perfect)
		var zoom_x_log2 = log(zoom.x) / log(2.0)
		var zoom_y_log2 = log(zoom.y) / log(2.0)
		if abs(zoom_x_log2 - round(zoom_x_log2)) > 0.01 or abs(zoom_y_log2 - round(zoom_y_log2)) > 0.01:
			warnings.append("⚠️ Zoom is not power of 2 - may affect pixel-perfect rendering")
			warnings.append("   Recommendation: Use powers of 2 (0.25, 0.5, 1, 2, 4, 8)")
	
	# Test coordinate conversion
	var test_result = _test_coordinate_conversion(viewport, camera)
	if test_result.success:
		successes.append("✅ Coordinate conversion test passed")
		successes.append("   Test accuracy: %.3f pixels" % test_result.accuracy)
	else:
		issues.append("❌ Coordinate conversion test failed")
		issues.append("   Error: %s" % test_result.error)
	
	# Check for multiple cameras (potential conflict)
	var all_cameras = _find_all_camera2d_nodes(scene_root)
	if all_cameras.size() > 1:
		var enabled_cameras = all_cameras.filter(func(cam): return cam.enabled)
		if enabled_cameras.size() > 1:
			warnings.append("⚠️ Multiple enabled Camera2D nodes found (%d)" % enabled_cameras.size())
			warnings.append("   This may cause coordinate conversion conflicts")
			for cam in enabled_cameras:
				warnings.append("     - %s (path: %s)" % [cam.name, cam.get_path()])
	
	_print_results(successes, warnings, issues)
	
	return issues.is_empty()

## Tests coordinate conversion accuracy
## [param viewport] The viewport to test
## [param camera] The Camera2D to test with
## [return] Dictionary with success, accuracy, and error info
static func _test_coordinate_conversion(viewport: Viewport, camera: Camera2D) -> Dictionary:
	# Test screen position (viewport center)
	var viewport_size = viewport.get_visible_rect().size
	var test_screen_pos = viewport_size * 0.5
	
	# Convert using Grid Building utilities
	var world_pos = GBPositioning2DUtils.convert_screen_to_world_position(test_screen_pos, viewport)
	
	if world_pos == Vector2.ZERO:
		return {"success": false, "error": "Coordinate conversion returned Vector2.ZERO"}
	
	# Calculate expected world position (approximate validation)
	var canvas_transform = viewport.get_canvas_transform()
	var expected_world_pos = canvas_transform.affine_inverse() * test_screen_pos
	
	# Check accuracy
	var accuracy = world_pos.distance_to(expected_world_pos)
	var success = accuracy < 1.0  # Within 1 pixel is acceptable
	
	return {
		"success": success, 
		"accuracy": accuracy,
		"world_pos": world_pos,
		"expected": expected_world_pos,
		"error": "" if success else "Accuracy too low: %.3f pixels" % accuracy
	}

## Finds all Camera2D nodes in scene tree
## [param root] Root node to search from
## [return] Array of Camera2D nodes
static func _find_all_camera2d_nodes(root: Node) -> Array[Camera2D]:
	var cameras: Array[Camera2D] = []
	_collect_cameras_recursive(root, cameras)
	return cameras

## Helper function for recursive camera collection
static func _collect_cameras_recursive(node: Node, cameras: Array[Camera2D]) -> void:
	if node is Camera2D:
		cameras.append(node)
	for child in node.get_children():
		_collect_cameras_recursive(child, cameras)

## Prints validation results in organized format
static func _print_results(successes: Array[String], warnings: Array[String], issues: Array[String]):
	print("📋 Grid Building Camera2D Validation Results:")
	print("")
	
	# Print successes
	if not successes.is_empty():
		for success in successes:
			print("  %s" % success)
		print("")
	
	# Print warnings  
	if not warnings.is_empty():
		print("  ⚠️ WARNINGS:")
		for warning in warnings:
			print("  %s" % warning)
		print("")
	
	# Print issues
	if not issues.is_empty():
		print("  ❌ ISSUES FOUND:")
		for issue in issues:
			print("  %s" % issue)
		print("")
	
	# Summary
	if issues.is_empty():
		if warnings.is_empty():
			print("🎉 VALIDATION PASSED: Camera2D setup is optimal for Grid Building!")
		else:
			print("✅ VALIDATION PASSED: Camera2D setup is functional (with warnings)")
	else:
		print("❌ VALIDATION FAILED: Camera2D setup has critical issues")
		print("   👉 See Camera2D Setup Requirements guide for help:")
		print("      https://gridbuilding.pages.dev/v5-0-0/guides/camera2d-requirements/")
	
	print("")

## Quick validation function for editor scripts
## Call this from an @tool script in the editor to validate current scene
static func validate_current_scene() -> bool:
	if not Engine.is_editor_hint():
		push_warning("validate_current_scene() should only be called in editor")
		return false
	
	var edited_scene = EditorInterface.get_edited_scene_root() if Engine.is_editor_hint() else null
	if not edited_scene:
		print("❌ No scene currently open in editor")
		return false
	
	return validate_scene_setup(edited_scene)

## Runtime validation for game startup
## Call this during game initialization to verify setup
static func validate_runtime_setup(main_scene: Node) -> bool:
	if Engine.is_editor_hint():
		push_warning("validate_runtime_setup() should only be called at runtime")
		return false
	
	return validate_scene_setup(main_scene)