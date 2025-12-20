class_name AgeingSettings
extends Resource
## Settings regarding ageing within the game world

enum UpdateTime { GAME_TIME_ELAPSED, REAL_TIME_ELAPSED, DATE_CHANGED }

@export var update_timing : UpdateTime = UpdateTime.DATE_CHANGED

## The unit of time for measuring ageing in
@export var interval_unit = TimeEnums.Unit.DAY

## The amount of times the time unit must elapse for the age to increase 1 time
@export var intervals_per_age = 1.0

## Whether to allow ageing backwards if game time or game dates go in reverse / negative time directions
@export var allow_negative_age_changes = false
