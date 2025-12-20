class_name WorldAgeSystem
extends Node
## Controls world age values and emits world_age_changed signals
## whenever new age thresholds are met so AgeableComponents can age.
## Can be used with either real time elapsing or game time signals

enum TIME_UNIT { SECOND, MINUTE, HOUR, DAY}

@export var id : String = "world_age_system"

## Where the age system tells about changes to the world age
@export var starting_age = AgePreset.new()

## Defines how ageing operates inside the system
@export var ageing_settings : AgeingSettings

## State of time that the system operates on
@export var time_state : TimeState:
	set(value):
		if time_state != null:
			time_state.time_elapsed.disconnect(_on_time_elapsed)
			time_state.date_changed.disconnect(_on_date_changed)
		
		time_state = value
		
		if time_state != null:
			time_state.time_elapsed.connect(_on_time_elapsed)
			time_state.date_changed.connect(_on_date_changed)

var age_state_id : String

func _init(p_ageing_settings : AgeingSettings = null, p_time_state : TimeState = null):
	ageing_settings = p_ageing_settings
	time_state = p_time_state
	var registry := AgeStateRegistry.get_singleton()
	age_state_id = registry.get_state_or_new(age_state_id, starting_age, age_state_id).id
	registry.world_id = age_state_id
	
func _ready():
	_validate_setup()
	
func _process(delta):
	if ageing_settings != null && ageing_settings.update_timing == AgeingSettings.UpdateTime.REAL_TIME_ELAPSED:
		progress_world_age(delta)

func _on_time_elapsed(p_amount : float, p_total : float):
	if ageing_settings.update_timing in [AgeingSettings.UpdateTime.GAME_TIME_ELAPSED, AgeingSettings.UpdateTime.REAL_TIME_ELAPSED]:
		progress_world_age(p_amount)
		
func _on_date_changed(event : DateChangeEvent):
	if ageing_settings.update_timing in [AgeingSettings.UpdateTime.DATE_CHANGED]:
		var seconds_change = event.change * time_state.get_scale().seconds_per_day
		progress_world_age(seconds_change, true)

## Adds the change in age to the world age state. Use p_whole_units_only
## as true if you want only full change_in_units to be processed for the age (Example,
## full date change at days end)
func progress_world_age(p_seconds_progressed : float, p_whole_units_only : bool = false):
	var change_in_units : float
	
	if ageing_settings.update_timing == AgeingSettings.UpdateTime.REAL_TIME_ELAPSED:
		change_in_units = seconds_to_real_time_units(p_seconds_progressed)
	else:
		change_in_units = seconds_to_game_units(p_seconds_progressed)
		
	if p_whole_units_only:
		change_in_units = change_in_units as int
		
	if not ageing_settings.allow_negative_age_changes && change_in_units < 0.0:
		push_warning("Tried to add negative age but allow_negative_age_changes is false")
		return
		
	var change_in_age = change_in_units / ageing_settings.intervals_per_age
	
	var registry := AgeStateRegistry.get_singleton()
	var state := registry.get_state(age_state_id)
	state.add_age(change_in_age)

func seconds_to_game_units(p_seconds_progressed : float):
	var change_in_units : float
	
	match ageing_settings.interval_unit:
		TIME_UNIT.SECOND:
			change_in_units = p_seconds_progressed
		TIME_UNIT.MINUTE:
			change_in_units = p_seconds_progressed / time_state.get_scale().seconds_per_minute
		TIME_UNIT.HOUR:
			change_in_units = p_seconds_progressed / time_state.get_scale().seconds_per_hour
		TIME_UNIT.DAY:
			change_in_units = p_seconds_progressed / time_state.get_scale().seconds_per_day
		_:
			push_warning("Unimplemented interval unit " + ageing_settings.interval_unit + ". No change_in_units added.")
			return
	
	return change_in_units

func seconds_to_real_time_units(p_delta : float):
	var change_in_units : float
		
	match ageing_settings.interval_unit:
		TIME_UNIT.SECOND:
			change_in_units = p_delta
		TIME_UNIT.MINUTE:
			change_in_units = p_delta / 60
		TIME_UNIT.HOUR:
			change_in_units = p_delta / (60*60)
		TIME_UNIT.DAY:
			change_in_units = p_delta / (60*60*24)
		_:
			push_warning("Unimplemented interval unit " + ageing_settings.interval_unit + ". No change_in_units added.")
			return
			
	return change_in_units
	
func _validate_setup() -> bool:
	var no_setup_errors = true
	
	if time_state == null:
		push_warning("%s has no TimeState set. Can't connect to signals date_time_changed and date_changed." % get_path())
		no_setup_errors = false

	if ageing_settings == null:
		push_warning("[ageing_settings] is not set and is required to operate properly. Make sure it's set in %s before running" % get_path())
		no_setup_errors = false
		
	return no_setup_errors

func to_dict() -> Dictionary:
	return WTStateSerializer.to_dict(self, Keys.get_keys())
	
func from_dict(p_state : Dictionary) -> void:
	WTStateSerializer.from_dict(self, p_state, Keys.get_keys())

class Keys: # For serialization
	const ID = "id"
	const AGE_STATE_ID = "age_state_id"
	
	static func get_keys() -> Array[String]:
		return [ID, AGE_STATE_ID]
