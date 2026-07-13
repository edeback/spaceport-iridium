class_name StatModifierSpec
extends Resource

## A single authored stat modification (stat key + operation + value), used by
## local upgrades to describe what a purchased tier does. Feeds directly into a
## module's StatModifiers layer:
##   effective = base * product(MULT values) + sum(ADD values)

@export var stat: StringName
@export var op: StatModifiers.Op = StatModifiers.Op.MULT
## For MULT: e.g. 0.8 = -20% (faster/cheaper), 1.2 = +20% (more output).
## For ADD: a flat offset added after multipliers.
@export var value: float = 1.0
