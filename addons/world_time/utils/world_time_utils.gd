## Utility for generating UUIDs for World Time systems (e.g., AgeState).
class_name WorldTimeUtils

## Generates a UUID v4-like string (36 characters). Uniqueness validated by registries (e.g., AgeRegistry).
static func generate_uuid() -> String:
	var chars = "0123456789abcdef"
	var uuid = ""
	for i in 36:
		if i == 8 or i == 13 or i == 18 or i == 23:
			uuid += "-"
		elif i == 14:
			uuid += "4"  # UUID v4 marker
		else:
			uuid += chars[randi() % 16]
	return uuid
