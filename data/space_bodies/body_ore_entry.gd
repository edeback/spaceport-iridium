class_name BodyOreEntry
extends Resource

## One row of a [SpaceBodyProfile]'s FIXED_LIST ore mix (WI-61).
##
## `weight` is a *share*, not a count: it lands straight in the body's
## `resource_weighted_values`, which [AsteroidBase.mine_resource] rolls against
## and the Contents tab renders as an approximate percentage. `chance` is rolled
## once per body, so an entry at 0.35 is on roughly a third of them and absent
## from the rest entirely - which is how "sometimes, a little" differs from
## "always, a little".

@export var resource: ResourceData
## Relative share of this body's contents, against the other entries that made it.
@export var weight: float = 1.0
## Probability this entry appears on any given body. 1.0 = always.
@export var chance: float = 1.0
