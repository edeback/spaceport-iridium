## Flags for runtime checks of the GBConfigurationValidator
class_name GBRuntimeChecks
extends Resource

## Require building system set in the GBSystems object to pass validation
@export var building_system : bool = false

## Require targeting system set in the GBSystems object to pass validation
@export var targeting_system : bool = false

## Require manipulation system set in the GBSystems object to pass validation
@export var manipulation_system : bool = false

## Require Camera2D node present in the viewport for positioning utilities
@export var camera_2d : bool = true