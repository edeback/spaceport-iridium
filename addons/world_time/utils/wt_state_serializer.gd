class_name WTStateSerializer
extends Object

## Serializes selected properties of an object to a Dictionary.
## - Supports custom objects with `to_dict()` method.
## - Handles serialization for Vector2 and NodePath types.
##
## @param obj: The object to serialize.
## @param keys: An array of property names (as strings) to include.
## @return A dictionary representing the serialized state.
static func to_dict(obj: Object, keys: Array[String]) -> Dictionary[String, Variant]:
	var dict : Dictionary[String, Variant] = {}
	for key in keys:
		var value = obj.get(key)

		# Handle custom objects with `to_dict()`
		if typeof(value) == TYPE_OBJECT and value != null and value.has_method("to_dict"):
			dict[key] = value.to_dict()
		# Handle Vector2 serialization
		elif typeof(value) == TYPE_VECTOR2:
			dict[key] = { "x": value.x, "y": value.y }
		# Handle NodePath serialization (store the path as a string)
		elif typeof(value) == TYPE_NODE_PATH:
			dict[key] = str(value)
		else:
			dict[key] = value

	return dict

## Deserializes a Dictionary into the given object by setting specified properties.
## - Calls `from_dict()` on sub-objects if they support it.
## - Handles deserialization for Vector2 and NodePath types.
##
## @param obj: The object to update.
## @param p_state: The dictionary containing state data.
## @param keys: An array of property names (as strings) to apply.
static func from_dict(obj: Object, p_state: Dictionary, keys: Array[String]) -> void:
	if not p_state.has_all(keys):
		push_error("Missing required keys in dictionary: %s" % keys)
		return

	for key in keys:
		if not p_state.has(key):
			continue

		var raw_value = p_state[key]
		var existing_value = obj.get(key)

		# Handle Vector2 deserialization
		if typeof(existing_value) == TYPE_VECTOR2 and typeof(raw_value) == TYPE_DICTIONARY:
			if raw_value.has("x") and raw_value.has("y"):
				var loaded_vector = Vector2(raw_value.x, raw_value.y)
				obj.set(key, loaded_vector)
				continue

		# Handle NodePath deserialization (convert from string to NodePath)
		if typeof(existing_value) == TYPE_NODE_PATH and typeof(raw_value) == TYPE_STRING:
			obj.set(key, NodePath(raw_value))  # Correct way to convert string back to NodePath
			continue

		# Handle nested deserialization for custom objects
		if typeof(raw_value) == TYPE_DICTIONARY:
			var nested_obj = obj.get(key)
			nested_obj.from_dict(raw_value)
			
		if typeof(existing_value) == TYPE_OBJECT and existing_value != null and existing_value.has_method("from_dict"):
			existing_value.from_dict(raw_value)
		else:
			obj.set(key, raw_value)
