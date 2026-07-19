class_name AnchorDef
extends Resource

## A named point inside a module's interior micro-graph (WI-16): a path_points
## index plus an optional straight-line offset from it. Module interiors are
## open boxes, so the straight tail from the index to the offset is always
## walkable. Authored in module scenes (bunks, workstations) or generated at
## runtime by subdividing path edges (hallway STAND/QUEUE slots).

enum AnchorType { WORKSTATION, BUNK, QUEUE, STAND }

@export var type: AnchorType = AnchorType.STAND
## Index into the owning PathComponent's path_points.
@export var path_index: int = 0
## Local-space offset from that path point; the pawn walks a straight tail to it.
@export var offset: Vector2 = Vector2.ZERO
## Sprite animation the pawn plays while parked on this anchor (WI-23):
## interact, interact_sit, lay_down, ... whatever the pawn's SpriteFrames
## defines. &"" (default) or an animation the sprite lacks falls back to idle.
@export var animation: StringName = &""
