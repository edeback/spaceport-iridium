class_name PathBehaviorContext
extends RefCounted

var next_node: Node2D = null   ## only populated for on_exit
var state: RefCounted = null   ## from create_state(), shared per (behavior, module)
var cancelled: Signal          ## emits if the overall action gets invalidated mid-hook
