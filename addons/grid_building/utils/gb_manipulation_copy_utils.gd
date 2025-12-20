class_name GBManipulationCopyUtils
extends RefCounted
## Utility functions for preparing cloned objects during manipulation operations.
##
## This class provides centralized logic for disabling scripts and processing
## on duplicated nodes used in preview and manipulation workflows. This ensures
## that AI scripts, movement logic, and other gameplay code don't execute
## on temporary copies being positioned/previewed.

## Prepares a manipulated copy by disabling scripts and processing.
## This prevents AI movement, physics updates, and other gameplay logic
## from executing on the temporary copy during move/build operations.
##
## [code]p_target[/code]: [i]Node[/i] - The root node of the copied object to prepare[br]
## [code]p_type_exceptions[/code]: [i]Array[String][/i] - Script class names to preserve (e.g., "Manipulatable")
static func prepare_manipulation_copy(p_target: Node, p_type_exceptions: Array[String] = []) -> void:
	if p_target == null:
		push_warning("GBManipulationCopyUtils: Cannot prepare null target")
		return
	
	# Remove scripts that could cause unwanted behavior (AI, movement, etc.)
	remove_scripts_recursive(p_target, p_type_exceptions)
	
	# Disable processing to prevent _process/_physics_process execution
	p_target.process_mode = Node.PROCESS_MODE_DISABLED

## Removes scripts from a node and its children recursively.
## Scripts with global names in the exception list are preserved.
##
## [code]p_target[/code]: [i]Node[/i] - The node to process[br]
## [code]p_type_exceptions[/code]: [i]Array[String][/i] - Script class names to keep
static func remove_scripts_recursive(p_target: Node, p_type_exceptions: Array[String]) -> void:
	if p_target == null:
		return
	
	var script = p_target.get_script()
	if script != null:
		var global_name = script.get_global_name()
		if not global_name in p_type_exceptions:
			# Check for special keep_during_preview marker
			var keep_marker = script.get("keep_during_preview")
			if keep_marker == null or keep_marker != true:
				p_target.set_script(null)
	
	# Recursively process all children
	for child in p_target.get_children():
		remove_scripts_recursive(child, p_type_exceptions)

## Re-enables processing on a node (typically after canceling a manipulation).
## This is the inverse of prepare_manipulation_copy's process mode change.
##
## [code]p_target[/code]: [i]Node[/i] - The node to re-enable
static func restore_processing(p_target: Node) -> void:
	if p_target == null:
		return
	
	p_target.process_mode = Node.PROCESS_MODE_INHERIT
