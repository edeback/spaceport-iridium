class_name UnlockEffect
extends Resource

## Base class for the lasting effect(s) a global unlock applies. Composed onto
## UnlockData.effects, mirroring the resource-with-virtual-method pattern used by
## PathBehavior. apply() runs once when the owning unlock is purchased; subtypes
## register their state on the manager (grant a module, register a global stat
## modifier, enable local upgrades, ...).

func apply(_manager: UnlockManager, _unlock: UnlockData) -> void:
	pass

## Undo apply() - for a future refund/respec. Default no-op.
func revert(_manager: UnlockManager, _unlock: UnlockData) -> void:
	pass
