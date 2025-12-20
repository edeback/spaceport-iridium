## Used to register the IDs and Resource references for
## AgeStates in the game, with support for serialization and potential multiplayer
class_name AgeStateRegistry

## Emits whenever a state is registered
signal state_registered(id : String, state : AgeState)

## Get console prints for registry operation results
var debug = false

static var _singleton: AgeStateRegistry = null

## Gets the main singleton instance of the AgeStateRegistry
## Used internally in the World Time plugin
static func get_singleton() -> AgeStateRegistry:
	if _singleton == null:
		_singleton = AgeStateRegistry.new()
	return _singleton

## Unique world ID. Should be set before other age states to serve as the default parent
## Objects occupy the world therefore AgeStates are children of the world's AgeSatate
var world_id : String = "" : 
	set(value):
		if world_id == value: return
		
		world_id = value
		if debug:
			prints("World Age ID Set %s" % world_id)
	
## A dictionary to store AgeState resources by their UUID
var _states_dict : Dictionary[String, AgeState] = {}

## Registers an age state on the registry
## Only generate a new ID if the provided one is empty or already exists.
func register(age_state : AgeState) -> String:
	var use_id := age_state.id
	if use_id.is_empty() or _states_dict.has(use_id):
		use_id = generate_uuid()
		age_state.id = use_id
	_states_dict[use_id] = age_state
	state_registered.emit(use_id, age_state)
	return use_id

## Retrieves an existing age state or creates a new one with the ID
## and then registers it to the _states_dict
func get_state_or_new(id: String, p_preset: AgePreset = null, p_parent_id: String = "") -> AgeState:
	if _states_dict.has(id):
		return _states_dict[id]
	
	# Create a new AgeState if it doesn't exist
	var parent_id = p_parent_id if not p_parent_id.is_empty() else world_id
	var new_id = id if not id.is_empty() else generate_uuid()
	var new_state = AgeState.new(new_id, parent_id, 0.0, 0.0, 0.0, p_preset)
	register(new_state)
	return new_state

## Retrieves an AgeState by its UUID
func get_state(id : String) -> AgeState:
	return _states_dict.get(id, null)
	
## Number of entries in the registry
func get_size() -> int:
	return _states_dict.size()

## Returns all AgeState objects (e.g., for gameplay or debugging)
func get_all() -> Array[AgeState]:
	return _states_dict.values()

func has_state(p_id : String) -> bool:
	return _states_dict.has(p_id)

## Removes an AgeState from the registry
func remove(id : String) -> bool:
	return _states_dict.erase(id)

## Removes all data from the cache
##
## You may need this during loading or before the game starts but
## be very careful about calling it during gameplay (probably never)
func clear() -> void:
	_states_dict.clear()

## Generates a simplified UUID-like string (36 characters, UUID v4-like)
func generate_uuid() -> String:
	var new_id = WorldTimeUtils.generate_uuid()
	
	while _states_dict.has(new_id):
		new_id = WorldTimeUtils.generate_uuid()
		
	assert(_states_dict.has(new_id) == false, "After generation the ID must not already exist in the registry cache")
	return new_id

## Converts the registry to a serializable dictionary for saving
func to_dict() -> Dictionary[String, Dictionary]:
	var save_states_dict : Dictionary[String, Dictionary] = {}
	for uuid in _states_dict:
		save_states_dict[uuid] = _states_dict[uuid].to_dict()  # Assumes AgeState has a to_dict() method
		
		if debug:
			prints("Saved AgeState ID %s" % uuid)
		
	return save_states_dict

## Loads the registry from a serialized dictionary
func from_dict(data: Dictionary) -> void:
	clear()  # Ensure no old states remain
	assert(_states_dict.size() == 0, "Empty after clearing.")
	for id in data.keys():
		var state_states_dict = data[id]
		var new_state := AgeState.from_dict(state_states_dict)
		register(new_state)
		if debug:
			prints("Created AgeState ID %s" % new_state.id)
	
	var size := _states_dict.size()
