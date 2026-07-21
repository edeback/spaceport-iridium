class_name AdjacencyEffectSpec
extends Resource

## One adjacency effect radiated by an AdjacencyEmitterComponent (WI-30).
## Authored per emitter in the scene inspector so balance lives in data, not
## code. A receiving module's field level for `effect_id` sums, over every
## source in range, `intensity * falloff^hops` (BFS hop distance over the
## physical structure graph). Sources never affect themselves - the nearest
## receiver is one hop out, already scaled by falloff once.

## Which field this contributes to (e.g. &"vibration", &"greenery",
## &"maintenance", &"purified_air"). Receivers read it by the same id.
@export var effect_id: StringName = &""
## Base strength before per-hop falloff.
@export var intensity: float = 1.0
## Maximum hop distance the effect reaches (BFS depth). 0 = no propagation.
@export var range_hops: int = 3
## Per-hop multiplier: field at `hops` = intensity * falloff^hops. 1.0 = no
## falloff (flat within range); 0.5 halves each hop.
@export_range(0.0, 1.0) var falloff: float = 0.5

## Field contribution at a receiver `hops` away (hops >= 1). Beyond range or at
## the source itself, zero.
func level_at_hops(hops: int) -> float:
	if hops <= 0 or hops > range_hops:
		return 0.0
	return intensity * pow(falloff, hops)
