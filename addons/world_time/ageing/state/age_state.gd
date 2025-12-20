class_name AgeState
extends RefCounted
## Represents the age of one or more objects whether that is the age of a game
## world or a specific object within the scene. Share the resource to other objects
## to reference the same data as it changes.

## Emitted whenever the whole values of the current age changes (ex 1.0, 2.0, 3.0)
signal age_reached(current : float)

## Emitted whenever the current changes (decimals included)
signal age_changed(new : float, difference : float)

## Emitted whenever the whole number values of the total age changes (ex 1.0, 2.0, 3.0)
signal total_age_reached(total : float)

## Emitted whenever the total age changes
signal total_age_changed(total : float)

## Emitted whenever the created age changes
signal created_age_changed(created : float)

## The age of the current object instance not including any past scene
## versions of the object
var current : float = 0.0 :
	set(value):
		if value == current:
			return 
			
		var last_age = current
		current = value
		var difference = current - last_age
		age_changed.emit(current, difference)
		
		if int(last_age) != int(current):
			age_reached.emit(current)

## The total amount that the object including all past versions of the same
## object have accumulated since the initial instance
var total : float = 0.0 :
	set(value):
		if total == value:
			return
		
		var last_age = total
		total = value
		total_age_changed.emit(total)
		
		if int(last_age) != int(value):
			total_age_reached.emit(value)

## The age of the world when this age state
## was created
var created : float :
	set(value):
		if value == current:
			return
		
		created = value
		created_age_changed.emit(created)
		

## The state that this object exists within. Generally a world AgeState
var parent_id : String :
	set(value):
		parent_id = value

## Unique identifier representing this age state for serialization
var id : String

func _init(
	p_id: String,
	p_parent_id: String = "",
	p_current: float = 0.0,
	p_total: float = 0.0,
	p_created: float = 0.0,
	p_preset: AgePreset = null
):
	id = p_id
	parent_id = p_parent_id
	current = p_current
	total = p_total
	created = p_created
	if p_preset:
		current = p_preset.current
		total = p_preset.total
	_connect_to_parent()

## Adds age to the age data
## Updates both the current and total
func add_age(amount : float):
	current += amount
	total += amount

## Gets the total age of this age data for the objects it represents
func get_total_elapsed() -> float:
	return created - total
	
func _on_parent_age_changed(_new : float, difference : float):
	add_age(difference)

# Serialization Methods
func to_dict() -> Dictionary:
	return WTStateSerializer.to_dict(self, Keys.get_keys())

## Constructs an AgeState instance from saved dictionary data
static func from_dict(dict: Dictionary) -> AgeState:
	var id : String = dict.get(Keys.ID, "")
	
	if id.is_empty():
		push_error("Cannot reconstruct an AgeState with no ID.")
		return null
	
	var state := AgeState.new(
		id,
		dict.get(Keys.PARENT_ID, ""),
		dict.get(Keys.CURRENT, 0.0),
		dict.get(Keys.TOTAL, 0.0),
		dict.get(Keys.CREATED, 0.0)
	)
	return state

func _connect_to_parent():
	assert(not id.is_empty(), "Do not call before id is set.")
	if parent_id == "":
		return

	var registry := AgeStateRegistry.get_singleton()
	var parent_state := registry.get_state(parent_id)
	
	
	if parent_state:
		if created == 0.0: # Never set after initial set
			created = parent_state.total
			
		if not parent_state.age_changed.is_connected(_on_parent_age_changed):
			parent_state.age_changed.connect(_on_parent_age_changed)
		
		if registry.state_registered.is_connected(_on_state_registered):
			registry.state_registered.disconnect(_on_state_registered)
			
	else:
		registry.state_registered.connect(_on_state_registered)


# Wait for parent state to be created, assign it, and then disconnect
func _on_state_registered(created_id: String, state : AgeState):
	if created_id == parent_id:
		var registry := AgeStateRegistry.get_singleton()
		var parent_state := state
		if parent_state:
			created = parent_state.total
			
			if not parent_state.age_changed.is_connected(_on_parent_age_changed):
				parent_state.age_changed.connect(_on_parent_age_changed)
		
		if registry.state_registered.is_connected(_on_state_registered):
			registry.state_registered.disconnect(_on_state_registered)

class Keys:
	const CURRENT := "current"
	const TOTAL := "total"
	const CREATED := "created"
	const PARENT_ID := "parent_id"
	const ID := "id"
	
	static func get_keys() -> Array[String]:
		return [CURRENT,TOTAL,CREATED,PARENT_ID,ID]
