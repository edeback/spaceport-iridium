class_name AdjacencyManager
extends Node

## Adjacency effect fields (WI-30). Emitter modules radiate named effects
## (&"vibration", &"greenery", &"maintenance", ...) that propagate over the
## StructureManager graph - physical attachment, not straight-line distance -
## with per-hop falloff. A receiving module's field level for an effect is the
## sum over sources of intensity * falloff^hops (BFS within each source's range).
## Truss conducts because it's a normal structural vertex; vacuum separation
## (no edge) breaks the field.
##
## Fields are pure derived state: never saved, rebuilt from the graph. Recompute
## happens on topology / emitter / build changes ONLY - never per-frame, never on
## a slow_tick scan. Multiple changes in one frame coalesce into a single
## deferred rebuild (blueprint spam, world load placing hundreds of modules).
##
## Receivers read get_field() live and/or refresh on the fields_changed(module)
## signal; the manager never pushes stat modifiers itself - consumers translate
## a field level into their own local meaning.

## A module's field level for one or more effects changed. Carries the affected
## module so receivers can filter to their own owner cheaply.
signal fields_changed(module: ModuleBase)

## Built emitter components currently radiating. A module may host more than one.
var _emitters: Array[AdjacencyEmitterComponent] = []

## effect_id -> { ModuleBase: level }. Only nonzero entries are stored.
var _field: Dictionary[StringName, Dictionary] = {}

## Coalescing guard: many topology signals in one frame schedule exactly one
## deferred rebuild.
var _flush_queued: bool = false

func _ready() -> void:
	Global.adjacency_manager = self
	SignalBus.module_removed.connect(_on_module_removed)
	SignalBus.module_structure_connection_added.connect(_on_structure_topology_changed)
	SignalBus.module_structure_connection_removed.connect(_on_structure_topology_changed)
	# After a load, the world section places every module (and re-forms every
	# structural edge) before the game is declared ready; rebuild once here so
	# fields are correct even if a deferred flush somehow slipped an earlier frame.
	SignalBus.game_bootstrapped.connect(_mark_dirty)

# --- emitter registration -----------------------------------------------------

## Called by an AdjacencyEmitterComponent when its module finishes construction.
func register_emitter(emitter: AdjacencyEmitterComponent) -> void:
	if emitter == null or _emitters.has(emitter):
		return
	_emitters.append(emitter)
	_mark_dirty()

# --- queries ------------------------------------------------------------------

## Aggregate level of `effect_id` at `module` (0.0 if none). Cheap dictionary
## lookups - safe to call every tick from a receiver.
func get_field(module: ModuleBase, effect_id: StringName) -> float:
	var per_module: Dictionary = _field.get(effect_id, {})
	return per_module.get(module, 0.0)

## Every nonzero field at `module` as { effect_id: level }. For the Environment
## UI panel and the debug dump; not a per-tick call.
func get_all_fields(module: ModuleBase) -> Dictionary[StringName, float]:
	var out: Dictionary[StringName, float] = {}
	for effect_id: StringName in _field:
		var level: float = _field[effect_id].get(module, 0.0)
		if level > 0.0:
			out[effect_id] = level
	return out

# --- change handling ----------------------------------------------------------

func _on_module_removed(module: ModuleBase) -> void:
	# Drop any emitter(s) this module hosted so a freed instance can't radiate.
	_emitters = _emitters.filter(func(e: AdjacencyEmitterComponent) -> bool:
		return is_instance_valid(e) and e.owner_module != module)
	_mark_dirty()

func _on_structure_topology_changed(_from: ModuleBase, _to: ModuleBase, _distance: float = 0.0) -> void:
	_mark_dirty()

## Schedule a single rebuild at idle. Coalesces a burst of topology signals into
## one recompute; never rebuilds synchronously inside a signal (mid-teardown the
## graph can be half-updated).
func _mark_dirty() -> void:
	if _flush_queued:
		return
	_flush_queued = true
	_flush.call_deferred()

func _flush() -> void:
	_flush_queued = false
	var old_field: Dictionary[StringName, Dictionary] = _field
	_field = _recompute()
	_emit_changes(old_field, _field)

## Rebuild every field from scratch. Stations are hundreds of modules with a
## handful of emitters, so a full recompute per topology change is cheap and
## dodges the bookkeeping of scoped neighborhood invalidation.
func _recompute() -> Dictionary[StringName, Dictionary]:
	var new_field: Dictionary[StringName, Dictionary] = {}
	if Global.structure_manager == null:
		return new_field
	var graph: ModuleGraph = Global.structure_manager.graph
	# Purge emitters whose module was freed without a module_removed (defensive).
	_emitters = _emitters.filter(func(e: AdjacencyEmitterComponent) -> bool:
		return is_instance_valid(e) and is_instance_valid(e.owner_module))
	for emitter: AdjacencyEmitterComponent in _emitters:
		var source: ModuleBase = emitter.owner_module
		# Only Built modules radiate; a mid-deconstruct source goes quiet.
		if not source.is_complete():
			continue
		for spec: AdjacencyEffectSpec in emitter.active_specs():
			var reached: Dictionary[Node2D, int] = graph.bfs_hops(source, spec.range_hops)
			for node: Node2D in reached:
				var receiver: ModuleBase = node as ModuleBase
				if receiver == null:
					continue
				var level: float = spec.level_at_hops(reached[node])
				if level <= 0.0:
					continue
				var per_module: Dictionary = new_field.get_or_add(spec.effect_id, {})
				per_module[receiver] = float(per_module.get(receiver, 0.0)) + level
	return new_field

## Emit fields_changed for every module whose level moved on any effect between
## the old and new snapshots. Freed modules (removed this pass) are skipped.
func _emit_changes(old_field: Dictionary[StringName, Dictionary], new_field: Dictionary[StringName, Dictionary]) -> void:
	var changed: Dictionary[ModuleBase, bool] = {}
	var effect_ids: Dictionary[StringName, bool] = {}
	for effect_id: StringName in old_field:
		effect_ids[effect_id] = true
	for effect_id: StringName in new_field:
		effect_ids[effect_id] = true
	for effect_id: StringName in effect_ids:
		var old_per: Dictionary = old_field.get(effect_id, {})
		var new_per: Dictionary = new_field.get(effect_id, {})
		for module: ModuleBase in old_per:
			if not is_equal_approx(old_per[module], new_per.get(module, 0.0)):
				changed[module] = true
		for module: ModuleBase in new_per:
			if not old_per.has(module):
				changed[module] = true
	for module: ModuleBase in changed:
		if is_instance_valid(module):
			fields_changed.emit(module)
