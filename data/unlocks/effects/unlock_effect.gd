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

## Say something, once, about any stat name this effect uses that [Stats] does not
## declare (WI-72 §0.3). Called by [UnlockManager] as it scans, so a mod's own key
## still applies and still leaves a line in the log; a vanilla typo is caught by
## `test_stat_content.gd` long before it gets this far. Default no-op - most
## effects name no stat at all.
##
## [param where] is the authored file, because the stat name alone does not say
## which `.tres` to go and fix.
func warn_on_undeclared_stats(_where: String) -> void:
	pass
