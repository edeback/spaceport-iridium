## Serves as a context for connecting to the AgeState for a game object
class_name AgeingComponent
extends Node

## Emitted when the component's Age State changes
signal age_state_changed(new : AgeState, old : AgeState)

@export var age_preset: AgePreset
	
## Reference to the AgeState of this AgeingComponent
var age_state : AgeState :
	set(value):
		if age_state == value:
			return
		
		var old := age_state
		age_state = value
		
		if old != null && old != age_state: # AgeingComponent is single source of truth for AgeState reference, so if it's unset, remove it from the registry
			_registry.remove(old.id)
			
		age_state_changed.emit(age_state, old)

## Whether the ownership of the state has been transferred to a different AgeingComponent
var _transferred_ownership := false

## Whether from_dict is trying to deserialize the state onto the component
var _is_loading = false

var _registry : AgeStateRegistry

func _init(p_preset: AgePreset = null, p_registry := AgeStateRegistry.get_singleton()):
	age_preset = p_preset
	_registry = p_registry
	
func _ready() -> void:
	if not _is_loading && age_state == null:
		age_state = _registry.get_state_or_new("", age_preset, "")
		assert(_registry.has_state(age_state.id), "State must be in the registry.")
		assert(age_state != null, "AgeingComponent should hold a valid AgeState reference.")

func _exit_tree() -> void:
	if not _transferred_ownership:
		_registry.remove(age_state.id)
		prints(_registry.get_size())

# Transfers an AgeState and ownership (signals, etc) to a p_target AgeingComponent
func transfer_state(p_target : AgeingComponent, p_initial_current_age : float ) -> void:
	var transferring_state := age_state
	transferring_state.current = p_initial_current_age
	p_target.age_state = transferring_state
	_transferred_ownership = true

#region Serialization

func to_dict() -> Dictionary:
	var state := {
		Serialize.AGE_STATE_ID: age_state.id
	}
	return state

func from_dict(p_state: Dictionary) -> void:
	_is_loading = true
	var state_id := p_state.get(Serialize.AGE_STATE_ID)
	age_state = _registry.get_state(state_id)
	assert(age_state != null, "State must resolve from the registry. Load the registry first and then resolve AgeingComponent.")
	_is_loading = false

class Serialize:
	const AGE_STATE_ID := "age_state_id"

	static func get_keys() -> Array[String]:
		return [AGE_STATE_ID]

#endregion
