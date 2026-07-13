class_name StatModifierEffect
extends UnlockEffect

## A global, module-type-wide stat improvement (e.g. "all processors run 20%
## faster"). Registers a modifier that is applied to every matching module -
## both those already built (broadcast) and those built later (queried in
## ModuleBase.ready_constructed). This is the same StatModifiers mechanism local
## upgrades use; only the scope differs.

## Modules with ANY of these tags receive the modifier. Empty = every module.
@export var module_tags: Array[String] = []
@export var stat: StringName
@export var op: StatModifiers.Op = StatModifiers.Op.MULT
@export var value: float = 1.0

func apply(manager: UnlockManager, unlock: UnlockData) -> void:
	manager.register_global_modifier(module_tags, stat, op, value, _source_id(unlock))

func revert(manager: UnlockManager, unlock: UnlockData) -> void:
	manager.unregister_global_modifier(_source_id(unlock))

## Stable source id so the modifier can be counted/removed and never
## double-registered. Distinct per (unlock, stat) so one unlock may touch
## several stats.
func _source_id(unlock: UnlockData) -> StringName:
	return StringName("unlock:%s:%s" % [unlock.id, stat])
