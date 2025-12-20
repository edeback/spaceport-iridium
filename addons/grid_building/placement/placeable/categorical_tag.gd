## Tag resource for categorizing placeables into groups for gameplay and UI.
class_name CategoricalTag
extends Resource

## Multiline description with BBCode support for UI display.
@export_multiline var description: String

## Display name for UI and gameplay.
@export var display_name: StringName

## Small image representing the tag in UI elements.
@export var icon: Texture2D
