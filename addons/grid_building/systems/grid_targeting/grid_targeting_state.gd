## State for targeting objects within the Grid Building System.
class_name GridTargetingState
extends GBResource

#region Signals
## Emitted when the readiness status of the state has changed - usually after successful validation.
signal ready_changed(value : bool)

## Emitted when the target node for the state is changed.
##
## NOTE: Typically target is set by a TargetingShapeCast2D or similar casting node from the runtime scene
signal target_changed(new : Node2D, old : Node2D)

## Emitted when the node responsible for positioning grid building placement objects and indicators is changed on the BuildingState.
signal positioner_changed(positioner : Node2D)

## Emitted when the targeted map node is changed.
## This represents the main target TileMapLayer node on the state.
signal target_map_changed(target_map : TileMapLayer)

## Emitted when the list of known maps is changed.[br][br]
## This is a list of maps that can be accessed without the need
## for any collision check calls.
signal maps_changed(maps : Array[TileMapLayer])

#region Properties
## References the user root that serves as the origin for this targeting state
var _owner_context : GBOwnerContext

func _init(p_owner_context : GBOwnerContext):
	_owner_context = p_owner_context

## Returns true if the targeting state has all runtime requirements met for operation
func is_ready() -> bool:
	return get_runtime_issues().is_empty()
		
## The placed node currently being targeted
var target : Node2D :
	set(value):
		if target == value:
			return

		# Keep reference to old before we mutate
		var old : Node2D = target
		# Disconnect signal from old target (if any) before switching
		_disconnect_target_signal()
		target = value
		
		# Auto-clear collision exclusions when target changes, with smart detection:
		# 1. During manual targeting: NEVER clear (preserve exclusions for move/build operations)
		# 2. Same-context update: Don't clear if new target is part of excluded object tree
		#    (e.g., TargetingShapeCast2D detecting Body instead of Original during manipulation)
		# 3. Different context: DO clear (switching from manipulation to build, or preview change)
		var should_clear := not is_manual_targeting_active and not _is_same_context_update(value)
		if should_clear:
			clear_collision_exclusions()

		# Connect to new target's lifecycle so we can clear when it exits
		if is_instance_valid(target):
			# Avoid duplicate connections if setter is invoked redundantly
			if not target.tree_exiting.is_connected(_on_target_tree_exiting):
				target.tree_exiting.connect(_on_target_tree_exiting)
			_target_signal_connected = true

		if not is_instance_valid(old):
			old = null # Ensure freed references are not emitted

		target_changed.emit(target, old)

## Parent node for positioning grid building objects onto the game world.
var positioner : Node2D :
	set(value):
		if positioner == value:
			return
		
		positioner = value
		positioner_changed.emit(positioner)
		_revalidate_on_change()

## The TileMapLayer or TileMap node to be used
## when determining grid distances in your game world
## [br][br]
## You could think of this as the main map node usually where characters stand on
var target_map : TileMapLayer :
	set(value):
		if target_map == value:
			return
		
		target_map = value
		target_map_changed.emit(target_map)
		_revalidate_on_change()

## All maps to be known by the targeting state for testing against without casting for collisions. [br][br]
## You can exclude any purely cosmetic maps that shouldn't have gameplay impacts.
var maps : Array[TileMapLayer]:
	set(value):
		maps = value
		maps_changed.emit(maps)
		_revalidate_on_change()

## Tile size property that delegates to the target map's tile set
var tile_size: Vector2i :
	get:
		return get_tile_size()
	set(value):
		set_tile_size(value)

## Nodes that should be excluded from collision detection during indicator validation.
## This is primarily used during manipulation move operations to exclude the original
## object being moved, so indicators only detect collisions with OTHER objects.
## 
## **IMPORTANT**: This list is automatically cleared when:
## - The target changes (manipulation ends and switches to a different target)
## - Manually calling clear_collision_exclusions()
## 
## **Usage**: Set this at the start of manipulation move operations and it will
## auto-clear when manipulation ends.
var collision_exclusions: Array[Node] = []

## Flag indicating whether manual targeting mode is currently active.
## When true, automatic targeting systems (like TargetingShapeCast2D) will not
## overwrite the manually-set target, and collision_exclusions will persist across
## target updates. Used during BUILD mode (preview) and MOVE mode (manipulation copy).
## Set via set_manual_target() and cleared via clear_manual_target().
var is_manual_targeting_active: bool = false

## Clears the collision exclusion list.
## This is called automatically when the target changes (and manipulation is not active),
## but can also be called manually when ending manipulation operations.
func clear_collision_exclusions() -> void:
	collision_exclusions.clear()

## Sets a manual target and prevents automatic targeting updates.
## This prevents automatic targeting systems (like TargetingShapeCast2D) from
## overwriting the manually-set target. Used during:
## - BUILD mode: Locks preview as target
## - MOVE mode: Locks manipulation copy as target
## 
## If p_target is null, clears manual targeting mode (equivalent to clear_manual_target()).
## Otherwise, enables manual targeting and assigns the target.
## 
## [param p_target] The node to manually target, or null to clear manual targeting
func set_manual_target(p_target: Node2D) -> void:
	if p_target == null:
		is_manual_targeting_active = false
	else:
		is_manual_targeting_active = true
	target = p_target

## Clears manual targeting mode and resumes automatic targeting.
## Call this when BUILD or MOVE mode ends to allow TargetingShapeCast2D to
## automatically update the target again.
## Note: Does NOT clear the target node itself - only disables the manual targeting flag.
func clear_manual_target() -> void:
	is_manual_targeting_active = false

#endregion

#region Methods
## Sets the target map and maps array for this targeting state
func set_map_objects(p_target_map: TileMapLayer, p_maps: Array[TileMapLayer]) -> void:
	target_map = p_target_map
	maps = p_maps

## Get the shape of the currently targeted TileMapLayer's tileset tiles
func get_target_map_tile_shape() -> TileSet.TileShape:
	var tile_set := get_target_map_tile_set()
	assert(tile_set != null, "There must be an active tile set to get the tile shape. Is the target_map assigned?")
	return get_target_map_tile_set().tile_shape

## Gets the tileset of the currently targeted TileMapLayer
func get_target_map_tile_set() -> TileSet:
	if target_map == null:
		return null
	if target_map.tile_set == null:
		return null
	return target_map.tile_set

## Gets the tile size from the target map's tile set
func get_tile_size() -> Vector2i:
	var tile_set := get_target_map_tile_set()
	if tile_set == null:
		return Vector2i(16, 16)  # Default fallback
	return tile_set.tile_size

## Sets the tile size on the target map's tile set
func set_tile_size(size: Vector2i) -> void:
	var tile_set := get_target_map_tile_set()
	if tile_set != null:
		tile_set.tile_size = size
	else:
		push_error("GridTargetingState: Cannot set tile_size - no target_map or tile_set available")

## Ensures that the targeting state is ready for runtime operation
## and logs any issues found
func validate_runtime(logger: GBLogger = null) -> bool:
	var issues := get_runtime_issues()
	if logger != null and not issues.is_empty():
		logger.log_issues(issues)
	return issues.is_empty()

func get_owner() -> Node:
	return _owner_context.get_owner() if _owner_context else null
		
func get_owner_root() -> Node:
	return _owner_context.get_owner_root() if _owner_context else null

## Returns the origin node associated with this targeting state.
## [return] The origin node provided by the owner context or null when unavailable.
func get_origin() -> Node:
	if _owner_context == null:
		return null
	return _owner_context.get_origin()

## Internal: Re-validate when critical properties change so 'ready' flips to true at the right time.
func _revalidate_on_change() -> void:
	var was_ready = is_ready()
	var current_ready = is_ready()
	if was_ready != current_ready:
		ready_changed.emit(current_ready)
	

## Returns an array of issues found during editor validation
func get_editor_issues() -> Array[String]:
	var issues: Array[String] = []
	
	if _owner_context == null:
		issues.append("GridTargetingState owner context is not set")
	
	return issues

## Should be called AFTER necessary properties on the state have been set
## Checks the minimum setup dependencies for the state.
func get_runtime_issues() -> Array[String]:
	var issues : Array[String] = []
	issues.append_array(get_editor_issues())
	
	# Check target_map first - it's usually set before positioner during initialization
	if target_map == null:
		issues.append("Property [target_map] is NULL")
	
	# Only check positioner if target_map is already set, indicating we're past initial setup
	# This avoids warnings during dependency injection timing when target_map is set but positioner isn't yet
	if target_map != null and positioner == null:
		issues.append("Property [positioner] is NULL") 
	
	if maps.is_empty():
		issues.append("[maps] is empty.")
	return issues

#endregion

#region Internal target lifecycle management
var _target_signal_connected : bool = false

## Disconnects the tree_exiting signal from the current target (if connected)
func _disconnect_target_signal() -> void:
	if not _target_signal_connected:
		return
	if is_instance_valid(target) and target.tree_exiting.is_connected(_on_target_tree_exiting):
		target.tree_exiting.disconnect(_on_target_tree_exiting)
	_target_signal_connected = false

## Called when the current target is about to exit the scene tree
func _on_target_tree_exiting() -> void:
	# Clear target only if it is still the active one
	if target != null:
		# Setting to null invokes setter which will handle disconnect (idempotent)
		target = null

## Checks if the new target is part of the same object tree as any exclusion
## Returns true if new_target is a child/descendant of an excluded node
## This helps detect when TargetingShapeCast2D detects a different node of the same logical object
func _is_same_context_update(new_target: Node2D) -> bool:
	if new_target == null or collision_exclusions.is_empty():
		return false
	
	# Check if new_target is a descendant of any exclusion
	for exclusion in collision_exclusions:
		if not is_instance_valid(exclusion):
			continue
		
		# Walk up from new_target to see if we reach the exclusion
		var current: Node = new_target
		while current != null:
			if current == exclusion:
				return true  # new_target is part of excluded object tree
			current = current.get_parent()
	
	return false

#endregion
