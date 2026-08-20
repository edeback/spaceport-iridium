class_name EventEffectSpawnSalvage
extends EventEffect

## Spawns free-floating ResourcePiles in space near the station. Piles, not
## asteroids, deliberately: they bypass AsteroidManager's population cap
## (WI-13 edge case) and post their own collection jobs on spawn, so crew
## sweep them up through the ordinary airlock flow.

@export var resource: ResourceData
@export var min_amount: int = 10
@export var max_amount: int = 20
## How many separate piles the total is split across.
@export var pile_count: int = 2
## Distance band from the station's edge where piles appear, in px.
@export var spawn_distance: Vector2 = Vector2(200.0, 500.0)

func apply(_event: EventData) -> void:
	if resource == null or pile_count <= 0:
		return
	var total: int = randi_range(min_amount, maxi(min_amount, max_amount))
	var bounds: Rect2 = _station_bounds()
	for i: int in pile_count:
		var share: int = total / pile_count + (1 if i < total % pile_count else 0)
		if share <= 0:
			continue
		var pile: ResourcePile = ResourcePile.spawn(Global.world_manager.pawn_layer, _roll_position(bounds))
		pile.add_amount(resource, share)

func describe() -> String:
	if resource == null:
		return ""
	return "salvage: ~%d %s adrift nearby" % [(min_amount + max_amount) / 2, resource.name]

## The bounds math moved to SpaceGeometry in WI-61, where comets need the same
## answer; this is the gather that feeds it. Kept here rather than in that file
## because it needs the SceneTree and Global, and SpaceGeometry is pure.
func _station_bounds() -> Rect2:
	var positions: Array[Vector2] = []
	for node: Node in Global.world_manager.get_tree().get_nodes_in_group(Groups.MODULE):
		var module: ModuleBase = node as ModuleBase
		if module == null:
			continue
		positions.append(Global.cell_to_world(module.module_cell, true))
	return SpaceGeometry.station_bounds(positions)

## Random point offset outward from a random edge point of the station's
## bounding box, so piles land in open space rather than inside modules.
func _roll_position(bounds: Rect2) -> Vector2:
	var direction := Vector2.from_angle(randf() * TAU)
	return SpaceGeometry.outward_point(bounds, direction,
			randf_range(spawn_distance.x, spawn_distance.y))
