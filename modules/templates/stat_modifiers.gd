class_name StatModifiers
extends RefCounted

## Runtime stat-modifier layer for a single module instance.
##
## Components read effective stats through here (via ModuleBase.get_effective_stat)
## instead of their raw @export base values, so upgrades can be applied and
## removed non-destructively. Both scopes of unlock feed into the same layer:
##   - local, per-instance upgrades tag their modifiers with the upgrade id
##   - global, module-type improvements register the same way when a module is
##     built or when the improvement is unlocked
## Each modifier carries a `source` id so all of an upgrade's contributions can
## be removed cleanly on refund/teardown, and so tiers (repeat purchases) can be
## counted.
##
## Effective value = base * (product of MULT values) + (sum of ADD values)

enum Op { ADD, MULT }

class Modifier extends RefCounted:
	var stat: StringName
	var op: StatModifiers.Op
	var value: float
	var source: StringName

	func _init(p_stat: StringName, p_op: StatModifiers.Op, p_value: float, p_source: StringName) -> void:
		stat = p_stat
		op = p_op
		value = p_value
		source = p_source

## stat -> Array[Modifier]
var _modifiers: Dictionary[StringName, Array] = {}
## stat -> Vector2(mult, add); lazily rebuilt when the stat is dirty
var _cache: Dictionary[StringName, Vector2] = {}
var _dirty: Dictionary[StringName, bool] = {}

## Emitted whenever the modifiers affecting `stat` change, so components/UI can
## refresh any cached derived values.
signal changed(stat: StringName)

func add_modifier(stat: StringName, op: Op, value: float, source: StringName) -> void:
	if not _modifiers.has(stat):
		_modifiers[stat] = []
	_modifiers[stat].append(Modifier.new(stat, op, value, source))
	_dirty[stat] = true
	changed.emit(stat)

## Replace whatever `source` contributes to `stat` with a single modifier
## (WI-24). For continuously-rewritten layers like damage efficiency and
## breakdowns that keep exactly one modifier per stat and update its value in
## place, rather than piling up a new modifier each refresh.
func set_single_modifier(stat: StringName, op: Op, value: float, source: StringName) -> void:
	if _modifiers.has(stat):
		var arr: Array = _modifiers[stat]
		arr.assign(arr.filter(func(m: Modifier) -> bool: return m.source != source))
	add_modifier(stat, op, value, source)

## Remove every modifier contributed by `source`, across all stats.
func remove_source(source: StringName) -> void:
	for stat: StringName in _modifiers.keys():
		var arr: Array = _modifiers[stat]
		var before: int = arr.size()
		arr.assign(arr.filter(func(m: Modifier) -> bool: return m.source != source))
		if arr.size() != before:
			_dirty[stat] = true
			changed.emit(stat)

## How many modifiers from `source` currently affect `stat` (i.e. its tier count).
func tier_count(stat: StringName, source: StringName) -> int:
	if not _modifiers.has(stat):
		return 0
	var count: int = 0
	for m: Modifier in _modifiers[stat]:
		if m.source == source:
			count += 1
	return count

func has_modifiers(stat: StringName) -> bool:
	return _modifiers.has(stat) and not _modifiers[stat].is_empty()

func get_effective(stat: StringName, base: float) -> float:
	var agg: Vector2 = _get_aggregate(stat)
	return base * agg.x + agg.y

func _get_aggregate(stat: StringName) -> Vector2:
	if _dirty.get(stat, true) or not _cache.has(stat):
		var mult: float = 1.0
		var add: float = 0.0
		for m: Modifier in _modifiers.get(stat, []):
			match m.op:
				Op.MULT:
					mult *= m.value
				Op.ADD:
					add += m.value
		_cache[stat] = Vector2(mult, add)
		_dirty[stat] = false
	return _cache[stat]
