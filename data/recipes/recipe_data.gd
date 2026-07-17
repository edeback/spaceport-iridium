class_name RecipeData
extends Resource

@export var name: String = ""
@export var inputs: Dictionary[ResourceData, int] = {}
@export var outputs: Dictionary[ResourceData, int] = {}

## Output scaling across input richness: a batch of richness 0.0 yields
## outputs × min_yield_mult, richness 1.0 yields × max_yield_mult (lerped
## between). Both 1.0 (the default) = outputs are always exactly recipe-sized,
## which is correct for recipes whose inputs carry no variance.
@export var min_yield_mult: float = 1.0
@export var max_yield_mult: float = 1.0
