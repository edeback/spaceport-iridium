@tool
class_name DockingBay
extends ModuleBase

## Shared ship-approach geometry (WI-08, hoisted from CrewManager so crew
## shuttles and trader ships agree on where to dock). Static and taking any
## ModuleBase so callers that only hold a module reference (recruitment
## component owners, saved refs) don't need a cast.

## Center of the bay in world space - where ships nose up to.
static func dock_position_for(bay: ModuleBase) -> Vector2:
	return Global.cell_to_world(bay.module_cell) + Vector2(bay.size * Global.CELL_SIZE) / 2.0

## Which side ships approach from: left normally, right if flipped.
## -1 = left, +1 = right.
static func approach_sign_for(bay: ModuleBase) -> float:
	return 1.0 if bay.flipped else -1.0
