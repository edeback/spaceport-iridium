## Global validation helpers used across systems and tests.
##
## Provide common assertions and property checks so that systems can validate their injected dependencies and runtime state.
class_name GBValidation
## Global helper class to make validating object properties easier

## Checks that the property values of each property name are not null.
## Returns an array of issues found.[br][br]
## [code]p_obj[/code]: [i]Object[/i] - Object to validate properties on[br]
## [code]p_property_names[/code]: [i]Array[String][/i] - Array of property names to check for null values
static func check_not_null(p_obj: Object, p_property_names: Array[String]) -> Array[String]:
	var issues: Array[String] = []
	var obj_path: String = ""

	if p_obj is Node:
		if not p_obj.is_inside_tree():
			issues.append("%s is not inside the scene tree. It is currently an orphan node." % [p_obj.name])
			# Avoid calling get_path() when not in scene tree; provide safe descriptor
			obj_path = "[Node not in tree: %s]" % GBObjectUtils.get_object_display_name(p_obj)
		else:
			obj_path = str(p_obj.get_path())
	elif p_obj is Resource:
		if p_obj.resource_path != "":
			obj_path = p_obj.resource_path
		else:
			# Use GBObjectUtils for a better description
			obj_path = "[%s: %s]" % [GBObjectUtils.get_script_or_base_class_name(p_obj), p_obj, ]
	else:
		obj_path = GBObjectUtils.get_object_display_name(p_obj)

	var property_names = p_obj.get_property_list().map(func(p): return p.name)

	for prop in p_property_names:
		if not property_names.has(prop):
			issues.append("Property [%s] does not exist at %s" % [prop, obj_path])
		elif p_obj.get(prop) == null:
			issues.append("Property [%s] is NULL at %s" % [prop, obj_path])

	return issues
