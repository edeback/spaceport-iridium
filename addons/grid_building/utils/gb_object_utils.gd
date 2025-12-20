## Utility helpers for object introspection and display names.
##
## Provides functions to derive readable names and script identifiers for objects
## and resources, intended for logging and diagnostics across the plugin.
class_name GBObjectUtils


## Finds the script name on the script attached to an object if one exists.[br][br]
## [code]p_check[/code]: [i]Object[/i] - The object to inspect for script information
static func get_script_or_base_class_name(p_check: Object) -> String:
	var script = p_check.get_script()

	if script == null:
		return p_check.get_class()

	var script_path: String = script.resource_path
	var split_path: PackedStringArray = script_path.rsplit("/")
	var script_name = split_path[split_path.size() - 1]

	return script_name


## Gets a display-friendly name for any object type.
## Returns the most appropriate identifier for logging and debugging purposes.[br][br]
## [code]obj[/code]: [i]Object[/i] - The object to get display name from
static func get_object_display_name(obj: Object) -> String:
	if obj == null:
		return "<null>"

	if obj is Node:
		# Return the node name (like "MyNode")
		return obj.name

	if obj is Resource:
		var path: String = obj.resource_path
		if path != "":
			# Return only the filename (like "MyResource.tres")
			return path.get_file()
		elif obj.has_method("get_class"):
			# Fallback: return class name if no saved path
			return obj.get_class()
		else:
			return "<Unnamed Resource>"

	if obj is RefCounted:
		# Return a class name or type
		if obj.has_method("get_class"):
			return obj.get_class()
		else:
			return "<RefCounted>"

	# Fallback for base Object or unknown types
	return obj.get_class() if obj.has_method("get_class") else "<Object>"


## Gets a readable display name for a Node, with optional fallback and custom callable.
## [code]node[/code]: [i]Node[/i] - Node to get display name for (can be null)
## [code]missing_name[/code]: [i]String[/i] - Value to return when node is null or name missing
## [code]custom_callable[/code]: [i]Callable[/i] - Optional callable that receives the node and returns a String
static func get_display_name(node: Node, missing_name: String = "<none>") -> String:
	if node == null:
		return missing_name
		
	# Use node.name converted to a readable format when possible
	if node.name != null and node.name != "":
		# Prefer GBString.convert_name_to_readable if available
		if typeof(GBString) != TYPE_NIL:
			return GBString.convert_name_to_readable(node.name)
		return node.name

	# Fallback to existing object display heuristics for nodes
	# If node has a custom method named "to_string" prefer that
	if node.has_method("to_string"):
		return String(node.call("to_string"))


	return missing_name
