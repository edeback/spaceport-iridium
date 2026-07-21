class_name AdjacencyEmitterComponent
extends ComponentBase

## Radiates one or more adjacency effects (WI-30) over the physical structure
## graph. Registers with AdjacencyManager the moment its module finishes
## construction and unregisters when the module is removed (the manager watches
## module_removed), so only Built modules radiate - a blueprint or preview
## contributes nothing to any field. Balance (intensity / range / falloff) is
## authored per spec in the scene.

## Effects this module emits. Most modules emit exactly one (forge -> vibration,
## garden -> greenery, maintenance facility -> maintenance); the array leaves
## room for a module that radiates several at once.
@export var effects: Array[AdjacencyEffectSpec] = []

func ready_constructed() -> void:
	if Engine.is_editor_hint():
		return
	# The manager is a sibling node under Managers/; if the game is mid-boot and
	# it hasn't registered yet, register_emitter is a no-op we retry via the
	# manager's own game_bootstrapped rebuild.
	if Global.adjacency_manager != null:
		Global.adjacency_manager.register_emitter(self)

## Valid, non-empty effect specs to actually radiate (skips unfilled inspector
## rows and specs with no effect_id).
func active_specs() -> Array[AdjacencyEffectSpec]:
	var out: Array[AdjacencyEffectSpec] = []
	for spec: AdjacencyEffectSpec in effects:
		if spec != null and spec.effect_id != &"" and spec.range_hops > 0:
			out.append(spec)
	return out
