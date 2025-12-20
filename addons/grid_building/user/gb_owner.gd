## Component that assigns an entity as the active owner on a user state resource.
##
## This node can automatically or manually designate an `owner_root` (such as a CharacterBody2D, NPC, or other)
## as the active entity within the system, enabling participation in grid-based logic.
class_name GBOwner
extends GBGameNode

## Emits if the root owning node ever changes
signal root_changed(new_root: Node)

#region Properties
## The root node representing the entity that owns this component.
##
## This can be a player character, AI agent, NPC, or any other node that acts as the owning entity. This node will be assigned as the active entity in the user state.
@export var owner_root: Node :
	set(value):
		if owner_root == value:
			return

		owner_root = value
		root_changed.emit(owner_root)
#endregion

#region Internal
var _context: GBOwnerContext
#endregion

## Initialize with an optional owner root node.[br][br]
## [code]p_owner_root[/code]: [i]Node[/i] - Root node that owns this building context (optional)
func _init(p_owner_root : Node = null) -> void:
	if p_owner_root:
		owner_root = p_owner_root

## Resolve dependencies from the composition container.[br][br]
## [code]p_container[/code]: [i]GBCompositionContainer[/i] - Container with system dependencies and context
func resolve_gb_dependencies(p_container: GBCompositionContainer) -> void:
	_context = p_container.get_contexts().owner
	_context.set_owner(self)
	
	var validation_issues = get_runtime_issues()
	if not validation_issues.is_empty():
		for issue in validation_issues:
			push_warning("GBOwner validation: " + issue)

## Validates that all required dependencies and properties are properly set.
## Returns validation issues if dependencies are missing, empty array if valid.[br][br]
## [code]return[/code]: [i]Array[String][/i] - List of validation issues (empty if valid)
func get_runtime_issues() -> Array[String]:
	return GBValidation.check_not_null(self, ["_context", "owner_root"])
