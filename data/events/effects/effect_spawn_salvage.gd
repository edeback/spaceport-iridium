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

func _station_bounds() -> Rect2:
	var bounds := Rect2()
	var first: bool = true
	for node: Node in Global.world_manager.get_tree().get_nodes_in_group(Groups.MODULE):
		var module: ModuleBase = node as ModuleBase
		if module == null:
			continue
		var world_pos: Vector2 = Global.cell_to_world(module.module_cell, true)
		if first:
			bounds = Rect2(world_pos, Vector2.ZERO)
			first = false
		else:
			bounds = bounds.expand(world_pos)
	return bounds

## Random point offset outward from a random edge point of the station's
## bounding box, so piles land in open space rather than inside modules.
func _roll_position(bounds: Rect2) -> Vector2:
	var angle: float = randf() * TAU
	var direction := Vector2.from_angle(angle)
	var center: Vector2 = bounds.get_center()
	# Push out past the box along the rolled direction, then add the band.
	var half_extent: float = absf(direction.x) * bounds.size.x * 0.5 + absf(direction.y) * bounds.size.y * 0.5
	var distance: float = half_extent + randf_range(spawn_distance.x, spawn_distance.y)
	return center + direction * distance
