extends Node
## Temporary script attached to objects being built in place of their gameplay script [br][br]
## Removed after the object is built


## Custom display for objects being built
func _to_string() -> String:
	return GBString.convert_name_to_readable(name)
