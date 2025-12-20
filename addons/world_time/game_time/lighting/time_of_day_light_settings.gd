class_name TimeOfDayLightSettings
extends Resource
## Light color and intensity settings associated with a time of day resource

## The time of day that these settings apply to
@export var time_of_day : TimeOfDay

## Base color of the light
@export var color : Color = Color.WHITE

## Intensity of the light
@export var energy : float = 1

## Height of the 2D light
@export var height : float = 0
