class_name TimeScale
extends Resource
## Settings for how fast time measurements progress in the game.
## Defaults are real world values.

## Number of seconds in a gameplay minute
@export var seconds_per_minute = 60

## Number of minutes in an hour
@export var minutes_per_hour = 60

## Number of hours in a day
@export var hours_per_day = 24

## How many times to progress the date time seconds for every second of delta time processed by the game engine
@export var delta_multiplier : float = 1000.0

## Returns a single hour measured in seconds
var seconds_per_hour :
	get:
		return seconds_per_minute * minutes_per_hour

## Returns a single day measured in seconds
var seconds_per_day : float :
	get:
		return seconds_per_minute * minutes_per_hour * hours_per_day
