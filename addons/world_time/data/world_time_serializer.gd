## WorldTimeSerializer is responsible for serializing and deserializing the time-related data in the game, including
## the TimeState, WorldAgeSystem, and AgeStateRegistry. It provides methods to convert these components to and
## from dictionary representations, enabling their storage and loading from external sources like files.
##
## The serializer handles the following:
## - Converts TimeState, WorldAgeSystem, and AgeStates to dictionaries for saving.
## - Loads TimeState, WorldAgeSystem, and AgeStates from dictionaries to restore the game state.
##
## This class allows for easy persistence and retrieval of the time system, which includes game time and world age,
## through a unified interface.
class_name WorldTimeSerializer
extends Node

## Constant keys for the serialized data to represent TimeState, AgeStates, and WorldAgeSystemState
const TIME_STATE := "time_state"
const AGE_STATES := "age_states"
const WORLD_AGE_SYSTEM_STATE := "world_age_system_state"

## The TimeState instance to be serialized and deserialized
@export var time_state: TimeState

## The WorldAgeSystem instance to be serialized and deserialized
@export var world_age_system: WorldAgeSystem

## Converts the time-related components (TimeState, WorldAgeSystem, and AgeStates) to a dictionary for saving or serialization.
##
## Returns:
## - A Dictionary containing serialized data for TimeState, WorldAgeSystem, and AgeStates.
func to_dict() -> Dictionary:
	var registry := AgeStateRegistry.get_singleton()
	
	return {
		TIME_STATE: time_state.to_dict(),
		AGE_STATES: registry.to_dict(),
		WORLD_AGE_SYSTEM_STATE: world_age_system.to_dict()
	}

## Loads the time-related components (TimeState, WorldAgeSystem, and AgeStates) from a dictionary to restore the game state.
##
## Parameters:
## - data: The dictionary containing the serialized time-related data.
##
## This function checks if the necessary data exists in the dictionary and then calls the appropriate
## methods to restore the TimeState, WorldAgeSystem, and AgeStateRegistry from the data.
func from_dict(data: Dictionary) -> void:
	var time_state_data : Dictionary = data.get(TIME_STATE, {})
	time_state.from_dict(time_state_data)

	var age_states := data.get(AGE_STATES, {})
	var registry := AgeStateRegistry.get_singleton()
	registry.from_dict(age_states)
	var size := registry.get_size()

	if data.has(WORLD_AGE_SYSTEM_STATE):
		world_age_system.from_dict(data[WORLD_AGE_SYSTEM_STATE])
