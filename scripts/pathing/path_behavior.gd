class_name PathBehavior
extends Resource

## Called once per module that references this resource, the first time
## it's encountered on that module. Override to create whatever per-instance
## runtime data your behavior needs — most behaviors won't need this at all.
func create_state(_pc: PathComponent) -> RefCounted:
	return null

func on_enter(pawn: PawnBase, door_index: int, meta: StringName, module: ModuleBase, state: RefCounted) -> void:
	pass

func on_traverse(pawn: PawnBase, edge: PathComponent.PathTraversalEdgeData, module: ModuleBase, state: RefCounted) -> void:
	pass

func on_exit(pawn: PawnBase, door_index: int, meta: StringName, module: ModuleBase, next_node: Node2D, state: RefCounted) -> void:
	pass
