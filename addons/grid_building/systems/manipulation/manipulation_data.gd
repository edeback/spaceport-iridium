class_name ManipulationData
extends RefCounted
## Holds the data for manipulating a Manipulatable object in the game scene
## Abstract class. Inherit to a [ActionName]Data script

## Emitted when the status of the action is set to a new value
signal status_changed(status: GBEnums.Status)

## The character or object currently using the system to do manipulations
var manipulator: Node

## The manipulatable node that was selected as the basis for this manipulation
var source: Manipulatable

## The manipulatable component of the object to be manipulated.
## In many cases this may be a copy of the object used
## to determine the final manipulation before applying it to the original.
var target: Manipulatable

## The general message sent as part of the manipulation data
## for whether the manipulation fails or succeeds
var message: String

## The results of rule check validation on the manipulation.
##
## Should be provided for manipulations that had to evaluate rules
## and have generated results
var results: ValidationResults

## The manipulation that is / was attempting to be done
var action: GBEnums.Action

## Status of the action
var status = GBEnums.Status.CREATED:
	set(value):
		if status == value:
			return

		status = value
		status_changed.emit(status)


func _init(
	p_manipulator: Node, p_source: Manipulatable, p_target: Manipulatable, p_action: GBEnums.Action
):
	manipulator = p_manipulator
	source = p_source
	target = p_target
	action = p_action


## Calls queue free on objects of the manipulation
func queue_free_manipulation_objects():
	if target == null:
		return

	if target.root != null:
		target.root.queue_free()
		target.root = null

	target.queue_free()
	target = null


## Determines if the data has a valid setup
func is_valid() -> bool:
	var passing = true

	if target == null:
		push_warning("No target set in the data %s" % to_string())
		passing = false

	if source == null:
		push_warning("No source set in the data %s" % to_string())
		passing = false

	if manipulator == null:
		push_warning("No manipulator set in the data %s" % to_string())
		passing = false

	return passing
