## Drag for a single drag operation between a start and end position
class_name DragPathData

var start_position: Vector2
var current_position: Vector2
var time_held: float = 0.0
var drag_distance: float = 0.0
var last_tile: Vector2i
var target_tile: Vector2i
var next_tile: Vector2i
var last_attempted_tile: Vector2i = Vector2i(999999, 999999)

## Number of build requests made during this drag session.
## Incremented each time DragManager calls BuildingSystem.try_build().
## Useful for monitoring drag-build behavior and verifying request throttling.
var build_requests: int = 0

var positioner: Node2D
var targeting_state: GridTargetingState

var is_dragging: bool = true


func _init(p_positioner: Node2D, p_targeting_state: GridTargetingState):
	positioner = p_positioner
	targeting_state = p_targeting_state
	start_position = positioner.global_position
	last_tile = get_tile_at_node_2d(targeting_state.target_map, start_position)
	# Initialize target_tile to current position so DragManager can detect changes
	target_tile = last_tile


## Updates the drag data with current frame delta time.
## Recalculates distance, time held, and target tile position for this drag operation.[br][br]
## [code]delta[/code]: [i]float[/i] - Time elapsed since last frame in seconds
func update(delta: float) -> void:
	current_position = positioner.global_position
	drag_distance = start_position.distance_to(current_position)
	time_held += delta

	# Use next_tile if set, otherwise calculate from current position
	if next_tile != Vector2i.ZERO:
		target_tile = next_tile
	else:
		target_tile = get_tile_at_node_2d(targeting_state.target_map, current_position)


## Converts global position to tile coordinates on the specified map.
## Helper function for converting world positions to tilemap coordinates.[br][br]
## [code]p_map[/code]: [i]TileMapLayer[/i] - The tilemap layer to convert coordinates for[br]
## [code]p_global_position[/code]: [i]Vector2[/i] - Global position to convert to tile coordinates
func get_tile_at_node_2d(p_map: TileMapLayer, p_global_position: Vector2) -> Vector2i:
	return p_map.local_to_map(p_map.to_local(p_global_position))


func stop():
	is_dragging = false
