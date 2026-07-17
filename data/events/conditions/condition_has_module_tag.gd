class_name EventConditionHasModuleTag
extends EventCondition

## Eligible only if at least one CONSTRUCTED module carries this tag
## (e.g. "Dock" for events that need a docking bay).

@export var tag: String = ""

func is_met() -> bool:
	if tag.is_empty():
		return true
	for node: Node in Global.world_manager.get_tree().get_nodes_in_group("module"):
		var module: ModuleBase = node as ModuleBase
		if module != null and module.is_complete() and module.module_data != null \
				and module.module_data.tags.has(tag):
			return true
	return false
