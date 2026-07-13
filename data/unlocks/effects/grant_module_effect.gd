class_name GrantModuleEffect
extends UnlockEffect

## Unlocks a module for building. The granted ModuleData should have
## unlocked_by_default = false so it stays hidden until this effect runs.

@export var module: ModuleData

func apply(manager: UnlockManager, _unlock: UnlockData) -> void:
	if module != null:
		manager.grant_module(module)
