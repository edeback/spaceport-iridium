## Groups multiple placeable variants under a single selectable slot for UI selection.
##
## PlaceableSequence allows players to cycle through related building variants
## (e.g., Basic Tower → Heavy Tower → Rapid Tower) before placing on the grid.
## Each sequence contains an ordered array of Placeable resources that share
## a common purpose but have different properties, visuals, or functionality.
##
## Key Features:
## - Ordered variant collection with left/right cycling in UI
## - Automatic arrow button display when 2+ variants exist
## - Compatible with PlaceableList and PlaceableSequenceSelectionUI
## - Validation delegation to individual Placeable objects
##
## Usage Example:
## [codeblock]
## var tower_sequence := PlaceableSequence.new()
## tower_sequence.display_name = "Defense Towers"
## tower_sequence.placeables = [basic_tower, heavy_tower, rapid_tower]
## [/codeblock]
##
## Integration:
## - Use with PlaceableSequenceSelectionUI for tabbed variant selection
## - Compatible with existing BuildingSystem placement workflow
## - Each variant maintains its own placement rules and validation
class_name PlaceableSequence
extends GBResource

@export var display_name: String = "Sequence"
@export var placeables: Array[Placeable] = []    # Ordered variants
@export var icon: Texture2D                     # Optional representative icon (fallback to first variant's icon)

## Returns the total number of placeable variants in this sequence.
## Used by UI components to determine if variant cycling controls should be displayed.
## [return] Number of placeable variants (0 if empty)
func count() -> int:
	return placeables.size()

## Retrieves a specific placeable variant by its index position.
## [param index] Zero-based index of the variant to retrieve
## [return] Placeable resource at the specified index, or null if index is out of bounds
func get_variant(index: int) -> Resource:
	if index < 0 or index >= placeables.size():
		return null
	return placeables[index]

## Gets the display name for a specific variant, with fallback handling.
## [param index] Zero-based index of the variant to get the name for
## [return] Display name of the variant, or fallback "Variant N" if unavailable
func variant_display_name(index: int) -> String:
	# Get the variant resource at the specified index
	var variant_resource = get_variant(index)
	if variant_resource == null:
		return "<Unknown>"
	
	# Attempt to extract display_name property from the variant
	if variant_resource is Resource and variant_resource.has_method("get"):
		# Try to get the display_name property
		var display_name = variant_resource.get("display_name")
		if display_name != null and display_name != "":
			return str(display_name)
	
	# Fallback to generic variant numbering (1-indexed for user display)
	return "Variant %d" % (index + 1)


## Validates the sequence configuration and returns any editor-time issues found.
## Performs sequence-level validation and delegates individual placeable validation
## to each Placeable object for proper separation of concerns.
## [return] Array of validation issue descriptions, empty if no issues found
func get_editor_issues() -> Array[String]:
	# Collection to accumulate all validation issues found
	var validation_issues: Array[String] = []
	
	if display_name.is_empty():
		validation_issues.append("PlaceableSequence: Display name is empty")
	
	if placeables.is_empty():
		validation_issues.append("PlaceableSequence: No placeables configured in the sequence")
	
	# Validate each placeable in the sequence
	for placeable_index in range(placeables.size()):
		var current_placeable = placeables[placeable_index]
		if current_placeable == null:
			validation_issues.append("PlaceableSequence: Placeable at index %d is null" % placeable_index)
		else:
			# Delegate individual placeable validation to the Placeable object
			var placeable_validation_issues = current_placeable.get_editor_issues()
			for individual_issue in placeable_validation_issues:
				validation_issues.append("PlaceableSequence[%d]: %s" % [placeable_index, individual_issue])
	
	return validation_issues


## Validates the sequence for runtime usage and returns any issues found.
## Includes sequence-level validation plus comprehensive placeable validation.
## Note: Individual placeable.get_runtime_issues() calls already include their
## editor issues, preventing duplication while ensuring complete coverage.
## [return] Array of validation issue descriptions, empty if no issues found
func get_runtime_issues() -> Array[String]:
	# Collection to accumulate all runtime validation issues
	var runtime_validation_issues: Array[String] = []
	
	# Perform sequence-level validation (same as editor validation)
	if display_name.is_empty():
		runtime_validation_issues.append("PlaceableSequence: Display name is empty")
	
	if placeables.is_empty():
		runtime_validation_issues.append("PlaceableSequence: No placeables configured in the sequence")
	
	# Validate each placeable for runtime issues (includes editor + runtime validation)
	for placeable_index in range(placeables.size()):
		var current_placeable = placeables[placeable_index]
		if current_placeable == null:
			runtime_validation_issues.append("PlaceableSequence: Placeable at index %d is null" % placeable_index)
		else:
			# Delegate comprehensive validation to the individual Placeable
			# Note: placeable.get_runtime_issues() already includes editor issues
			var comprehensive_placeable_issues = current_placeable.get_runtime_issues()
			for individual_runtime_issue in comprehensive_placeable_issues:
				runtime_validation_issues.append("PlaceableSequence[%d]: %s" % [placeable_index, individual_runtime_issue])
	
	return runtime_validation_issues
