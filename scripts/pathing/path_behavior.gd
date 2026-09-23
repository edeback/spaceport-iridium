class_name PathBehavior
extends Resource

## Called once per module that references this resource, the first time
## it's encountered on that module. Override to create whatever per-instance
## runtime data your behavior needs — most behaviors won't need this at all.
func create_state(_pc: PathComponent) -> RefCounted:
	return null

## The three hooks return a verdict rather than awaiting (WI-75 §1): start
## whatever the crossing needs - a door swinging, a flash - and say how long the
## pawn stands still for it. The pawn's movement component does the waiting, as a
## state it can save; nothing here may `await`.
func on_enter(_pawn: PawnBase, _door_index: int, _meta: StringName, _module: ModuleBase,
		_next_node: Node2D, _state: RefCounted) -> PathHookResult:
	return PathHookResult.proceed()

func on_traverse(_pawn: PawnBase, _edge: PathComponent.PathTraversalEdgeData, _module: ModuleBase,
		_state: RefCounted) -> PathHookResult:
	return PathHookResult.proceed()

func on_exit(_pawn: PawnBase, _door_index: int, _meta: StringName, _module: ModuleBase,
		_next_node: Node2D, _state: RefCounted) -> PathHookResult:
	return PathHookResult.proceed()

## Advances this behavior's per-module state by `delta` sim-seconds - a door
## swinging, a hold running down. Returns whether anything is still moving; the
## owning [PathComponent] stops ticking once no state is.
func tick_state(_state: RefCounted, _delta: float) -> bool:
	return false

## The state a save has to carry, or {} for nothing. A door half open, or held
## open with its auto-close half run down, is the reason this exists.
func save_state(_state: RefCounted) -> Dictionary:
	return {}

func load_state(_state: RefCounted, _data: Dictionary) -> void:
	pass
