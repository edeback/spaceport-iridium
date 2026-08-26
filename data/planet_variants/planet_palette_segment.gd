class_name PlanetPaletteSegment
extends Resource

## One run of colours inside a single planet layer's `colors[]` uniform (WI-66).
##
## The four vendored planet scenes have incompatible shapes: different layer
## counts, different node names, and different array lengths per layer. Worse,
## `Rivers` packs TWO conceptual ramps into one uniform - its `Land` layer takes
## six colours that are four land shades followed by two river shades.
##
## A four-way `match` on the variant id would cover it, and is exactly the kind
## of dispatch table WI-47 deleted three of. Instead a layer declares an ordered
## list of segments, each naming a [enum Role] and how many colours that role
## contributes. The generator fills a ramp per role; the applier concatenates the
## segments in order and writes the result.
##
## The payoff is that "water is blue" becomes one assertion over one role, and
## a mod's fifth planet type is a .tres drop rather than a fifth branch.

## What a run of colours *means*, which is what decides how it is generated.
##
## Deliberately about the physical thing, not the node it lands on: `IceWorld`'s
## `Land` layer and `LandMasses`' `Water` layer run the SAME shader
## (`PlanetUnder`, which paints the whole sphere), and they are a snowfield and
## an ocean respectively. The node name cannot tell you that; the role can.
enum Role {
	## The whole-sphere ramp for a planet with no separate ocean layer - the ice
	## sheet on `IceWorld`, the bare rock on `DryTerran`.
	SURFACE,
	## Landmasses sitting on top of something else.
	LAND,
	## Water, in whatever form: oceans, rivers, meltwater lakes. The role the
	## realism rule actually constrains.
	LIQUID,
	## Cloud deck. Always white to grey-blue, because real clouds are.
	CLOUD,
}

## Stable string per role, for [StarSystemData]'s palette dictionary keys and
## therefore for the save file. Never write the enum's integer value out: a role
## inserted in the middle would silently re-map every existing save's palette.
const ROLE_IDS: Dictionary[Role, StringName] = {
	Role.SURFACE: &"surface",
	Role.LAND: &"land",
	Role.LIQUID: &"liquid",
	Role.CLOUD: &"cloud",
}

@export var role: Role = Role.SURFACE
## How many colours this run contributes. Must sum, across a layer's segments,
## to the length of that layer's authored `colors[]` uniform - `test_star_systems.gd`
## sweeps every shipped variant for exactly that, because a mismatch is silent at
## runtime (Godot pads or truncates) and is the bug already sitting unnoticed in
## the vendored `Star.randomize_colors()`.
@export var count: int = 1

static func role_id(value: Role) -> StringName:
	return ROLE_IDS.get(value, &"")

## The role `id` names, or -1 for an unknown one. Callers treat -1 as "skip this
## entry" rather than substituting a role, so a save written by a mod that added
## a role loses that ramp instead of painting it as something else.
static func role_from_id(id: StringName) -> int:
	for value: Role in ROLE_IDS:
		if ROLE_IDS[value] == id:
			return value
	return -1
