## Factory utilities for creating and normalizing PlaceableSequence collections.
##
## This factory implements the "Helper Factory (Suggested)" pattern mentioned in the
## UI PlaceableSequence guide documentation. It provides convenient methods for:
## - Converting individual Placeables into single-item sequences
## - Normalizing mixed arrays of Placeables and PlaceableSequences
## - Reducing UI wiring code when working with PlaceableList components
##
## Usage Context:
## These utilities are designed for cases where you have existing Placeable
## collections but need to use them with PlaceableSequenceSelectionUI or
## PlaceableList components that expect PlaceableSequence objects.
##
## Note: Currently not used in the main plugin demos, but provided as
## convenience utilities for game developers who need sequence normalization.
class_name PlaceableSequenceFactory
extends RefCounted

## Converts an array of individual Placeables into single-item PlaceableSequences.
## Each Placeable becomes a sequence containing only that one item, preserving
## the original display name and allowing it to work with sequence-based UI components.
##
## [param placeables] Array of Placeable resources to convert
## [return] Array of PlaceableSequence objects, each containing one original Placeable
##
## Usage Example:
## [codeblock]
## var individual_buildings: Array[Placeable] = [tower, wall, gate]
## var sequences: Array[PlaceableSequence] = PlaceableSequenceFactory.from_placeables(individual_buildings)
## placeable_sequence_ui.sequences = sequences
## [/codeblock]
##
## Note: Null placeables are automatically filtered out during conversion.
static func from_placeables(placeables: Array[Placeable]) -> Array[PlaceableSequence]:
	# Output collection for converted sequences
	var converted_sequences: Array[PlaceableSequence] = []
	
	for original_placeable in placeables:
		if original_placeable == null:
			continue
		
		# Create a new sequence containing only this placeable
		var single_item_sequence := PlaceableSequence.new()
		single_item_sequence.display_name = original_placeable.display_name
		single_item_sequence.placeables.append(original_placeable)
		converted_sequences.append(single_item_sequence)
	
	return converted_sequences

## Normalizes a mixed array of Placeables and PlaceableSequences into sequences only.
## This implements the "normalize_sequences" pattern suggested in the documentation,
## allowing flexible input while ensuring consistent sequence-based output for UI components.
##
## [param mixed] Array containing any combination of Placeable and PlaceableSequence objects
## [return] Array containing only PlaceableSequence objects (singles wrapped, sequences preserved)
##
## Usage Example:
## [codeblock]
## var mixed_items: Array = [single_tower, wall_sequence, gate_placeable, defense_sequence]
## var normalized: Array[PlaceableSequence] = PlaceableSequenceFactory.ensure_sequences(mixed_items)
## placeable_list.populate_with_sequences(normalized)
## [/codeblock]
##
## Behavior:
## - PlaceableSequence objects are preserved as-is
## - Placeable objects are wrapped in single-item sequences
## - Null items are automatically filtered out
## - Maintains original display names and properties
static func ensure_sequences(mixed: Array) -> Array[PlaceableSequence]:
	# Output collection for normalized sequences
	var normalized_sequences: Array[PlaceableSequence] = []
	
	for mixed_item in mixed:
		if mixed_item == null:
			continue
		
		if mixed_item is PlaceableSequence:
			# Already a sequence - preserve as-is
			normalized_sequences.append(mixed_item)
		elif mixed_item is Placeable:
			# Individual placeable - wrap in single-item sequence
			var wrapper_sequence := PlaceableSequence.new()
			wrapper_sequence.display_name = mixed_item.display_name
			wrapper_sequence.placeables.append(mixed_item)
			normalized_sequences.append(wrapper_sequence)
			# Note: Other types are silently ignored (could add warning if needed)
	
	return normalized_sequences
