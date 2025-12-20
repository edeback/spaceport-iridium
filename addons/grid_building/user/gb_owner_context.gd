## The owner of a GBCompositionContainer
## All systems, settings, templates, etc contained within correlated with the owners setup.
## You can have multiple GBCompositionContainers and GBOwners within a game if you need multiple full systems running at the same time (multiplayer etc)
class_name GBOwnerContext
extends RefCounted

signal owner_changed(owner: GBOwner)

var allow_overriding_owner: bool = true
var output_change_fail: bool = true

var _owner: GBOwner = null

func _init(p_owner: GBOwner = null) -> void:
	if p_owner:
		set_owner(p_owner)

## Sets the owner for this context.
## Respects the allow_overriding_owner setting when changing from an existing owner.[br][br]
## [code]value[/code]: [i]GBOwner[/i] - The new owner to set for this context
func set_owner(value: GBOwner) -> void:
	if _owner == value:
		return

	if allow_overriding_owner or _owner == null:
		_owner = value
		owner_changed.emit(_owner)
	elif output_change_fail:
		push_warning(
			(
				"User %s is already set on GBOwnerContext %s and changing is not currently allowed when active owner is set."
				% [_owner.to_string(), to_string()]
			)
		)

## Returns the current owner of this context.
## May return null if no owner has been set.
func get_owner() -> GBOwner:
	return _owner
	
## Returns the owner root or null if not set
func get_owner_root() -> Node:
	if _owner == null: 
		return null
	
	return _owner.owner_root

## Returns the origin node associated with the active owner (usually the owner_root).
## [return] The origin node when an owner is assigned, otherwise null.
func get_origin() -> Node:
	if _owner == null:
		return null
	return _owner.owner_root

## Validates the editor configuration before nodes are set up.
## [code]@return[/code]: [i]Array[String][/i] - List of editor validation issues.
func get_editor_issues() -> Array[String]:
	return []

## Validates the runtime configuration after nodes are set up.
## [code]@return[/code]: [i]Array[String][/i] - List of runtime validation issues.
func get_runtime_issues() -> Array[String]:
	var issues : Array[String] = []
	
	issues.append_array(get_editor_issues())

	if _owner == null:
		issues.append("GBOwner is not assigned in GBOwnerContext")
	
	return issues
