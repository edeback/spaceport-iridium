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

## Base quality (0..1) stamped onto this recipe's outputs as FoodInstanceData
## (WI-29). -1.0 (the default) = this isn't a food recipe: outputs stay plain,
## exactly as before. Food recipes set a positive base expressing the module
## ladder (algae tank/vats < hydroponics < greenhouse); a manned producer's
## worker shifts it further via ProcessorComponent.worker_quality_shift_at_max.
@export_range(-1.0, 1.0, 0.01) var output_quality_base: float = -1.0
