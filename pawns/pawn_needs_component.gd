class_name PawnNeedsComponent
extends PawnComponentBase

var sustanance_level: float = 100.0
var social_level: float = 100.0
var entertainment_level: float = 100.0

@export var percent_to_look_for_needs: float = 20

@export var has_health_need: bool = false
@export var health_value: float = 100:
	set(new_health):
		if health_value != new_health:
			health_value = new_health
			health_changed.emit(health_value)
signal health_changed(new_health: float)

@export var has_sleep_need: bool = false
@export var sleep_value: float = 100:
	set(new_sleep):
		if sleep_value != new_sleep:
			sleep_value = new_sleep
			sleep_changed.emit(sleep_value)
signal sleep_changed(new_sleep: float)

@export var has_hunger_need: bool = false
@export var hunger_value: float = 100:
	set(new_hunger):
		if hunger_value != new_hunger:
			hunger_value = new_hunger
			hunger_changed.emit(hunger_value)
signal hunger_changed(new_hunger: float)
@export var hunger_duration_seconds: float = 600

@export var has_entertainment_need: bool = false
@export var entertainment_value: float = 100:
	set(new_entertainment):
		if entertainment_value != new_entertainment:
			entertainment_value = new_entertainment
			entertainment_changed.emit(entertainment_value)
signal entertainment_changed(new_entertainment: float)
@export var entertainment_duration_seconds: float = 900

@export var has_social_need: bool = false
@export var social_value: float = 100:
	set(new_social):
		if social_value != new_social:
			social_value = new_social
			social_changed.emit(social_value)
signal social_changed(new_social: float)
@export var social_duration_seconds: float = 1200

func _process(delta: float) -> void:
	if has_hunger_need and hunger_duration_seconds > 0:
		sustanance_level -= delta / hunger_duration_seconds
		if sustanance_level < percent_to_look_for_needs:
			pass
	if has_social_need and social_duration_seconds > 0:
		social_level -= delta / social_duration_seconds
		if social_level < percent_to_look_for_needs:
			pass
	if has_entertainment_need and entertainment_duration_seconds > 0:
		entertainment_level -= delta / entertainment_duration_seconds
		if entertainment_level < percent_to_look_for_needs:
			pass
