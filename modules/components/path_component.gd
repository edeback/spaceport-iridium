@tool
class_name PathComponent
extends ComponentBase

var astar: AStar2D = AStar2D.new()

class PathTraversalEdgeData:
	var start_pos: Vector2
	var end_pos: Vector2
	var start_index: int
	var end_index: int
	var edge_meta: StringName = ""
	var use_exact_position: bool = false
	
@export var door_not_connected_image: Texture2D

@export var show_debug: bool = false:
	set(new_show):
		show_debug = new_show
		queue_redraw()

@export var connection_points: Array[Vector2i]:
	set(new_points):
		connection_points = new_points
		queue_redraw()
		
@export var self_connection_only: bool = false

## Per-"terrain" movement speed multiplier (WI-11): pawns traverse this
## module's interior sub-path at this fraction of their normal speed (stairs
## 0.5x, hallway 1.0x). Pathfinding edge costs mirror it (make_connections)
## so route choice agrees with actual travel time.
@export var traversal_speed_mult: float = 1.0

func get_traversal_speed_mult() -> float:
	var mult: float = traversal_speed_mult
	if owner_module != null:
		mult = owner_module.get_effective_stat(Stats.TRAVERSAL_SPEED_MULT, traversal_speed_mult)
	return maxf(mult, 0.05)

@export var path_points: Array[Vector2i] = []:
	set(new_points):
		path_points = new_points
		queue_redraw()
## Where X and Y are the indexes of the points in path_points and the string is metadata
@export var path_edges: Dictionary[Vector2i, StringName] = {}:
	set(new_edges):
		path_edges = new_edges
		queue_redraw()

## Custom behaviors for when pawns start pathing along a specific edge
@export var edge_behaviors: Dictionary[Vector2i, PathBehavior] = {}

## Authored interior anchors (WI-16): bunks, workstations, queue spots.
## Generated STAND/QUEUE anchors (hallway subdivision) live in
## _generated_anchors and never need authoring.
@export var anchors: Array[AnchorDef] = []

## Which of the path points (by index) are actually doors, and what layer do they connect to?
@export var door_connections: Dictionary[int, WorldManager.StructureLayer] = {}
## Door metadata
@export var door_data: Dictionary[int, StringName] = {}
## Custom behaviors for when pawns path through doors
@export var door_behaviors: Dictionary[int, PathBehavior] = {}

var _behavior_states: Dictionary[PathBehavior, RefCounted] = {}

## Do we error if no door is connected?
@export var door_required: bool = false

## Do we prevent movement if not powered?
@export var power_required: bool = false
@export var power_consumption_component: PowerConsumptionComponent
		
var module_connections: Dictionary[Node2D, int] = {}
var space_connections: Array[Node2D] = []

var door_sprites: Dictionary[int, Sprite2D] = {}

signal door_connected(cell: Vector2i, from_layer: WorldManager.StructureLayer)
signal door_disconnected(cell: Vector2i, from_layer: WorldManager.StructureLayer)

## Is this part of a turbolift shaft, and if so, which?
#var current_shaft: ElevatorShaft = null

func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	for index in path_points.size():
		astar.add_point(index, path_points[index])
	for edge in path_edges:
		astar.connect_points(edge.x, edge.y)
	if power_required and power_consumption_component != null:
		power_consumption_component.powered_changed.connect(_on_power_changed)
	if door_required:
		for index in door_connections:
			var new_sprite: Sprite2D = Sprite2D.new()
			new_sprite.texture = door_not_connected_image
			new_sprite.position = Global.cell_to_world(Global.world_to_cell(path_points[index]), true)
			new_sprite.visible = true
			door_sprites[index] = new_sprite
			add_child(new_sprite)
	for behavior: PathBehavior in door_behaviors.values():
		_ensure_behavior_state(behavior)
	for behavior: PathBehavior in edge_behaviors.values():
		_ensure_behavior_state(behavior)
	# Idle until a hook starts something (wake_behaviors), so the hundreds of
	# modules with nothing to swing cost nothing a frame.
	set_process(false)

func _ensure_behavior_state(behavior: PathBehavior) -> void:
	if Engine.is_editor_hint():
		# Can't operate on these in editor mode
		return
	if behavior and not _behavior_states.has(behavior):
		_behavior_states[behavior] = behavior.create_state(self)

func get_behavior_state(behavior: PathBehavior) -> RefCounted:
	return _behavior_states.get(behavior)

## Starts ticking this module's behavior states - called after a hook has asked a
## door to move (WI-75 §3). The doors used to run themselves off their sprites'
## `animation_finished`, which is why nothing had to tick them.
func wake_behaviors() -> void:
	if not Engine.is_editor_hint() and not _behavior_states.is_empty():
		set_process(true)

## Door swings and holds run in sim time, here, and stop when nothing is moving.
## Dies with the module, which is what the old auto-close lambda could not do: it
## resumed on a freed sprite when an airlock was destroyed during its hold.
func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return
	var sim_delta: float = Global.time_manager.scale(delta)
	if sim_delta <= 0.0:
		return
	var moving: bool = false
	for behavior: PathBehavior in _behavior_states:
		if behavior.tick_state(_behavior_states[behavior], sim_delta):
			moving = true
	if not moving:
		set_process(false)

# --- persistence (WI-75 §3) ------------------------------------------------------
#
# Behavior states - an airlock's doors, half open or held open with the auto-close
# half run down. Keyed by position in _behavior_states, which is built in the same
# order from the scene's own door and edge tables every time the module readies.

func save_key() -> StringName:
	return &"path"

## Depends on nothing else in the module: a door is a door whatever the module
## holds. Its own number only because vanilla never shares one.
func save_order() -> int:
	return 140

func get_save_data() -> Dictionary:
	var states: Dictionary = {}
	var index: int = 0
	for behavior: PathBehavior in _behavior_states:
		var block: Dictionary = behavior.save_state(_behavior_states[behavior])
		if not block.is_empty():
			states[str(index)] = block
		index += 1
	return {"behaviors": states} if not states.is_empty() else {}

func load_save_data(data: Dictionary) -> void:
	var states: Dictionary = data.get("behaviors", {})
	var index: int = 0
	for behavior: PathBehavior in _behavior_states:
		var key: String = str(index)
		if states.has(key):
			behavior.load_state(_behavior_states[behavior], states[key])
		index += 1
	wake_behaviors()
		
func ready_preview() -> void:
	pass
	
func ready_blueprint() -> void:
	pass
	
func ready_constructed() -> void:
	pass
		
func _on_power_changed(new_power: bool) -> void:
	if new_power:
		Global.path_manager.enable_module(owner_module)
	else:
		Global.path_manager.disable_module(owner_module)
	
func get_edge_behavior(edge: PathTraversalEdgeData) -> PathBehavior:
	# Have to check both a->b and b->a as this is (currently) symmetric (though could be directional later?)
	var key := Vector2i(edge.start_index, edge.end_index)
	if edge_behaviors.has(key):
		return edge_behaviors[key]
	return edge_behaviors.get(Vector2i(edge.end_index, edge.start_index))
	
func get_closest_path_point(local_vec: Vector2) -> Vector2i:
	var index: int = astar.get_closest_point(local_vec)
	if index >= 0:
		return path_points[index]
	return Vector2i.ZERO
	
func get_connection_index_from(other_module: Node2D) -> int:
	# First check direct connection
	var index: int = module_connections.get(other_module, -1)
	if index < 0:
		# Check implicit connections: shared network group, or both exterior
		# (the jump across open space - was the "space" group before WI-15).
		var owner_vertex: ModuleGraphVertex = Global.path_manager.get_vertex(owner_module)
		var other_vertex: ModuleGraphVertex = Global.path_manager.get_vertex(other_module)
		if owner_vertex and other_vertex:
			if owner_vertex.group and owner_vertex.group == other_vertex.group:
				index = owner_vertex.group_door
			elif owner_vertex.is_exterior and other_vertex.is_exterior:
				index = owner_vertex.exterior_door
	return index
	
func get_connection_point_from(prev_module: Node2D) -> Vector2i:
	var connection_index: int = get_connection_index_from(prev_module)
	if connection_index >= 0 and connection_index < path_points.size():
		return path_points[connection_index]
	return Vector2i.ZERO
	
func get_path_through_module(start_module: Node2D, end_module: Node2D) -> Array[PathTraversalEdgeData]:
	var start_index: int = get_connection_index_from(start_module)
	var end_index: int = get_connection_index_from(end_module)
	return _get_path_within_module(start_index, end_index)
	
func get_path_exiting_module(start_global_position: Vector2, end_module: Node2D) -> Array[PathTraversalEdgeData]:
	var local_vec := start_global_position - owner_module.global_position
	var start_index: int = astar.get_closest_point(local_vec)
	var end_index: int = get_connection_index_from(end_module)
	return _get_path_within_module(start_index, end_index)

func _get_path_within_module(start_index: int, end_index: int) -> Array[PathTraversalEdgeData]:
	var path: Array[PathTraversalEdgeData] = []
	if start_index > -1 and end_index > -1 and start_index != end_index:
		var id_path: PackedInt64Array = astar.get_id_path(start_index, end_index)
		if id_path.size() > 0:
			# Add a starter point so we get here before we move through the module
			var edge_data: PathTraversalEdgeData = PathTraversalEdgeData.new()
			edge_data.start_index = -1
			edge_data.start_pos = Vector2.ZERO
			edge_data.end_index = start_index
			edge_data.end_pos = path_points[start_index]
			path.append(edge_data)
		for index in range(id_path.size() - 1):
			var edge_data: PathTraversalEdgeData = PathTraversalEdgeData.new()
			edge_data.start_index = id_path[index]
			edge_data.end_index = id_path[index + 1]
			edge_data.start_pos = path_points[id_path[index]]
			edge_data.end_pos = path_points[id_path[index + 1]]
			# Gotta check which way we put it in the path_edges dict
			if path_edges.has(Vector2i(id_path[index], id_path[index + 1])):
				edge_data.edge_meta = path_edges[Vector2i(id_path[index], id_path[index + 1])]
			elif path_edges.has(Vector2i(id_path[index + 1], id_path[index])):
				edge_data.edge_meta = path_edges[Vector2i(id_path[index + 1], id_path[index])]
			path.append(edge_data)
	return path

#region Anchors (WI-16)

## Target spacing for runtime-generated anchors along path edges.
const GENERATED_ANCHOR_SPACING: float = 20.0

## claimant instance id -> claimed anchor. Runtime-only (never saved): jobs
## aren't saved either, so on load claims rebuild as jobs repopulate. Keyed by
## instance id, not object ref, so a claim can never keep its claimant alive.
var _anchor_claims: Dictionary[int, AnchorDef] = {}
## Lazily generated anchors per type; micro graphs are static per scene, so
## this is never invalidated.
var _generated_anchors: Dictionary[AnchorDef.AnchorType, Array] = {}

## Local-space position an anchor resolves to.
func get_anchor_local_position(anchor: AnchorDef) -> Vector2:
	if anchor.path_index >= 0 and anchor.path_index < path_points.size():
		return Vector2(path_points[anchor.path_index]) + anchor.offset
	return anchor.offset

func get_anchor_global_position(anchor: AnchorDef) -> Vector2:
	return owner_module.global_position + get_anchor_local_position(anchor)

## Claim a free anchor of the given type for claimant. Returns null when none
## are free (callers must treat that as "target the module center as before" -
## never block movement on anchor scarcity). One claim per claimant per
## component; re-claiming releases the old claim first. Same discipline as
## storage reservations: release on EVERY job cancel path.
func claim_anchor(type: AnchorDef.AnchorType, claimant: Object) -> AnchorDef:
	if claimant == null:
		return null
	_anchor_claims.erase(claimant.get_instance_id())
	var anchor: AnchorDef = _find_free_anchor(type)
	if anchor == null:
		# Leak detector: claims must be released by their claimant's cancel
		# path. A claim whose claimant no longer exists is a bug - warn loudly,
		# then self-heal so anchors don't stay lost for the whole session.
		if _purge_dead_claims():
			anchor = _find_free_anchor(type)
	if anchor != null:
		_anchor_claims[claimant.get_instance_id()] = anchor
	return anchor

func release_anchor(claimant: Object) -> void:
	if claimant != null:
		_anchor_claims.erase(claimant.get_instance_id())

## Claims `anchor` itself for `claimant` if nobody holds it, and returns whether
## it did. A load re-takes the exact queue spot a saved turbolift ride was
## standing on (WI-75 §5), and a restored walk the exact bunk it was heading to,
## rather than whichever is first free.
func claim_specific_anchor(anchor: AnchorDef, claimant: Object) -> bool:
	if anchor == null or claimant == null:
		return false
	for id: int in _anchor_claims:
		if _anchor_claims[id] == anchor and id != claimant.get_instance_id():
			return false
	_anchor_claims[claimant.get_instance_id()] = anchor
	return true

## A save's name for one of this module's anchors: its index among the authored
## ones, or its type and index among the generated ones. {} for null.
func anchor_ref(anchor: AnchorDef) -> Dictionary:
	if anchor == null:
		return {}
	var authored: int = anchors.find(anchor)
	if authored >= 0:
		return {"authored": authored}
	var generated: Array[AnchorDef] = get_generated_anchors(anchor.type)
	var at: int = generated.find(anchor)
	if at >= 0:
		return {"type": int(anchor.type), "generated": at}
	return {}

func resolve_anchor_ref(ref: Dictionary) -> AnchorDef:
	if ref.has("authored"):
		var index: int = int(ref["authored"])
		return anchors[index] if index >= 0 and index < anchors.size() else null
	if ref.has("generated"):
		var generated: Array[AnchorDef] = get_generated_anchors(int(ref.get("type", 0)) as AnchorDef.AnchorType)
		var at: int = int(ref["generated"])
		return generated[at] if at >= 0 and at < generated.size() else null
	return null

## Per-type claim targets for WI-44 jobs, cached so repeat lookups are free.
## The pool wraps claim_anchor/release_anchor rather than replacing them - the
## non-job callers (turbolift queue spots, a pawn's idle stand anchor) use those
## directly, and both routes share one _anchor_claims map, so neither can hand out
## an anchor the other is standing on.
var _anchor_pools: Dictionary[int, AnchorPool] = {}

func anchor_pool(type: AnchorDef.AnchorType) -> AnchorPool:
	var key: int = int(type)
	if not _anchor_pools.has(key):
		_anchor_pools[key] = AnchorPool.make(self, type)
	return _anchor_pools[key]

func _find_free_anchor(type: AnchorDef.AnchorType) -> AnchorDef:
	var claimed: Array[AnchorDef] = []
	claimed.assign(_anchor_claims.values())
	for anchor: AnchorDef in anchors:
		if anchor.type == type and not claimed.has(anchor):
			return anchor
	# No authored anchors of this type: fall back to generated floor spots for
	# the "stand somewhere sensible" types. BUNK/WORKSTATION must be authored -
	# a generated point in the middle of a hallway is not a bed.
	if type == AnchorDef.AnchorType.STAND or type == AnchorDef.AnchorType.QUEUE:
		for anchor: AnchorDef in get_generated_anchors(type):
			if not claimed.has(anchor):
				return anchor
	return null

func _purge_dead_claims() -> bool:
	var purged: bool = false
	for id: int in _anchor_claims.keys():
		if instance_from_id(id) == null:
			push_warning("PathComponent on %s: purged anchor claim from a freed claimant - a job leaked its claim" % owner_module.name)
			_anchor_claims.erase(id)
			purged = true
	return purged

## Subdivide interior path edges into evenly spaced anchors (~20px apart, at
## least one per edge). Door-stub edges are skipped so generated spots never
## sit in a doorway. Cached forever - the micro graph is static per scene.
func get_generated_anchors(type: AnchorDef.AnchorType) -> Array[AnchorDef]:
	if _generated_anchors.has(type):
		var cached: Array[AnchorDef] = []
		cached.assign(_generated_anchors[type])
		return cached
	var result: Array[AnchorDef] = []
	for edge: Vector2i in path_edges:
		if door_connections.has(edge.x) or door_connections.has(edge.y):
			continue
		var a: Vector2 = Vector2(path_points[edge.x])
		var b: Vector2 = Vector2(path_points[edge.y])
		var count: int = maxi(1, roundi(a.distance_to(b) / GENERATED_ANCHOR_SPACING) - 1)
		for i: int in range(1, count + 1):
			var t: float = float(i) / float(count + 1)
			var point: Vector2 = a.lerp(b, t)
			var anchor: AnchorDef = AnchorDef.new()
			anchor.type = type
			anchor.path_index = edge.x if t <= 0.5 else edge.y
			anchor.offset = point - Vector2(path_points[anchor.path_index])
			result.append(anchor)
	_generated_anchors[type] = result
	return result

## Final-leg sub-path (WI-16): entry door -> anchor, instead of the exit door.
func get_path_to_anchor(start_module: Node2D, anchor: AnchorDef) -> Array[PathTraversalEdgeData]:
	return _path_to_anchor(get_connection_index_from(start_module), anchor)

## Same, but starting from an arbitrary position already inside this module.
func get_path_to_anchor_from_position(start_global_position: Vector2, anchor: AnchorDef) -> Array[PathTraversalEdgeData]:
	var local_vec: Vector2 = start_global_position - owner_module.global_position
	return _path_to_anchor(astar.get_closest_point(local_vec), anchor)

func _path_to_anchor(start_index: int, anchor: AnchorDef) -> Array[PathTraversalEdgeData]:
	var result: Array[PathTraversalEdgeData] = []
	if anchor == null or start_index < 0 or anchor.path_index < 0 or anchor.path_index >= path_points.size():
		return result
	result = _get_path_within_module(start_index, anchor.path_index)
	if result.is_empty() and start_index == anchor.path_index:
		# Entry point IS the anchor's graph point: synthesize the starter hop
		# (as _get_path_within_module does) so the offset tail has a base.
		var starter: PathTraversalEdgeData = PathTraversalEdgeData.new()
		starter.start_index = -1
		starter.start_pos = Vector2.ZERO
		starter.end_index = start_index
		starter.end_pos = Vector2(path_points[start_index])
		## Bunks and Workstations are specifically authored, don't use random offset
		starter.use_exact_position = (anchor.type == AnchorDef.AnchorType.WORKSTATION or anchor.type == AnchorDef.AnchorType.BUNK)
		result.append(starter)
	if not result.is_empty() and anchor.offset != Vector2.ZERO:
		# Straight-line tail off the micro graph; interiors are open boxes so
		# this is safe. end_index -1 marks it synthetic (no behavior lookups).
		var tail: PathTraversalEdgeData = PathTraversalEdgeData.new()
		tail.start_index = anchor.path_index
		tail.start_pos = Vector2(path_points[anchor.path_index])
		tail.end_index = -1
		tail.end_pos = tail.start_pos + anchor.offset
		## Bunks and Workstations are specifically authored, don't use random offset
		tail.use_exact_position = (anchor.type == AnchorDef.AnchorType.WORKSTATION or anchor.type == AnchorDef.AnchorType.BUNK)
		result.append(tail)
	return result

#endregion

## Do we maybe have any connection?
func _has_possible_connections() -> bool:
	for point in connection_points:
		if Global.world_manager.has_overlaps(owner_module.module_data.interaction_layer, owner_module.module_cell + point):
			return true
	return false
		
func _can_connect(other_module: ModuleBase) -> bool:
	return other_module != null and other_module != owner_module and other_module.is_complete() and (not self_connection_only or other_module.module_data == owner_module.module_data)
		
## Find the index of a connection between this and another module. -1 if not found
func _find_connection(other_module: ModuleBase) -> int:
	for index: int in connection_points.size():
		var module: ModuleBase = Global.world_manager.get_module_by_cell(owner_module.module_data.interaction_layer, owner_module.module_cell + connection_points[index])
		if module != null and module == other_module:
			return index
	return -1

## Returns a mapping of connected modules -> their connection point
func _find_connections() -> Dictionary[ModuleBase, int]:
	var connected_modules: Dictionary[ModuleBase, int] = {}
	for index: int in connection_points.size():
		var module: ModuleBase = Global.world_manager.get_module_by_cell(owner_module.module_data.interaction_layer, owner_module.module_cell + connection_points[index])
		if _can_connect(module):
			connected_modules[module] = index
	return connected_modules
	
## Connect to the other module if we can, return if successful
func try_connect(other_module: ModuleBase) -> bool:
	var connected_index: int = _find_connection(other_module)
	if connected_index != -1:
		module_connections[other_module] = connected_index
		return true
	return false

func make_connections() -> void:
	var connected_modules: Dictionary[ModuleBase, int] = _find_connections()
	for module in connected_modules:
		if module.get_path_component().try_connect(owner_module):
			module_connections[module] = connected_modules[module]
			# Edge cost = travel time, not raw distance: half the span crossed
			# at each module's speed. Keeps slow terrain (stairs) honestly more
			# expensive than the same distance of corridor.
			var distance: float = owner_module.global_position.distance_to(module.global_position)
			var cost: float = distance * 0.5 / get_traversal_speed_mult() + distance * 0.5 / module.get_path_component().get_traversal_speed_mult()
			Global.path_manager.add_connection(owner_module, module, cost)
	connect_doors()
		
	
func manual_connection(other_module: Node2D, connection_index: int) -> void:
	module_connections[other_module] = connection_index
	Global.path_manager.add_connection(owner_module, other_module, 1)
	
func get_door_data_to(other_module: ModuleBase) -> StringName:
	var index: int = get_connection_index_from(other_module)
	if index >= 0:
		return door_data.get(index, "")
	return ""
	
func has_door_to(cell_to_check: Vector2i, target_layer: WorldManager.StructureLayer) -> bool:
	for index: int in door_connections:
		if door_connections[index] == target_layer:
			var door_cell: Vector2i = Global.world_to_cell(path_points[index])
			if door_cell + owner_module.module_cell == cell_to_check:
				return true
	return false
	
func try_connect_door(other_module: ModuleBase, cell_to_check: Vector2i) -> bool:
	if not owner_module.is_complete():
		return false
	for index: int in door_connections:
		if other_module.module_data.interaction_layer == door_connections[index]:
			var door_cell: Vector2i = Global.world_to_cell(path_points[index])
			if door_cell + owner_module.module_cell == cell_to_check:
				if door_required:
					door_sprites[index].visible = false
				module_connections[other_module] = index
				door_connected.emit(door_cell, other_module.module_data.interaction_layer)
				check_doors()
				return true
	check_doors()
	return false
			
func connect_doors() -> void:
	for index: int in door_connections:
		if door_connections[index] == WorldManager.StructureLayer.SPACE:
			# Special case for direct to space!
			var space_node := Node2D.new()
			owner_module.add_child(space_node)
			space_node.global_position = Vector2(path_points[index]) + owner_module.global_position
			Global.path_manager.add_vertex(space_node, false, "", true)
			Global.path_manager.add_connection(owner_module, space_node, 30)
			module_connections[space_node] = index
			space_connections.append(space_node)
			continue
		var door_cell: Vector2i = Global.world_to_cell(path_points[index])
		var module: ModuleBase = Global.world_manager.get_module_by_cell(door_connections[index], owner_module.module_cell + door_cell)
		if module == null and door_required and door_connections[index] == WorldManager.StructureLayer.CORRIDOR:
			module = Global.world_manager.add_module(Global.world_manager.hallway_module, owner_module.module_cell + door_cell)
		if module!= null and module != owner_module and module.get_path_component() and module.get_path_component().try_connect_door(owner_module, owner_module.module_cell + door_cell):
			if door_required:
				door_sprites[index].visible = false
			module_connections[module] = index
			door_connected.emit(door_cell, module.module_data.interaction_layer)
			var data: StringName = door_data.get(index, "")
			if data.is_empty():
				data = module.get_path_component().get_door_data_to(owner_module)
			Global.path_manager.add_connection(owner_module, module, 1, data)
	check_doors()

## The space node this module's SPACE door `door_index` made in connect_doors, or
## null. A path through open space runs through these, so a saved path names one
## as its module and door (WI-75).
func space_node_for_door(door_index: int) -> Node2D:
	for node: Node2D in space_connections:
		if is_instance_valid(node) and int(module_connections.get(node, -1)) == door_index:
			return node
	return null

## The door index behind one of this module's space nodes, or -1.
func door_of_space_node(node: Node2D) -> int:
	if not space_connections.has(node):
		return -1
	return int(module_connections.get(node, -1))

func has_door_connected() -> bool:
	var connected_indices: Array[int] = module_connections.values()
	for index: int in door_connections:
		if connected_indices.has(index):
			return true
	return false

func check_doors() -> void:
	if door_required and not has_door_connected():
		last_error = "Door not connected!"
	else:
		last_error = ""
			
func remove_connections() -> void:
	for node in module_connections:
		if node is ModuleBase:
			var module := node as ModuleBase
			module.get_path_component().disconnect_from(owner_module)
			if door_connections.has(module_connections[module]):
				if door_required:
					door_sprites[module_connections[module]].visible = true
				door_disconnected.emit(Global.world_to_cell(path_points[module_connections[module]]), module.module_data.interaction_layer)
			# Signal is typed (ModuleBase, ModuleBase); plain Node2D space nodes
			# get their edges removed via remove_vertex in the loop below instead.
			SignalBus.module_path_connection_removed.emit(owner_module, module)
	module_connections.clear()
	for node in space_connections:
		Global.path_manager.remove_vertex(node)
	check_doors()
	
func disconnect_from(other_module: ModuleBase) -> void:
	if door_connections.has(module_connections[other_module]):
		if door_required:
			door_sprites[module_connections[other_module]].visible = true
		door_disconnected.emit(Global.world_to_cell(path_points[module_connections[other_module]]), other_module.module_data.interaction_layer)
	module_connections.erase(other_module)
	check_doors()

var _disconnected_label: Label = null

## Blinking "no path" marker (WI-10): shown while this module's path vertex is
## cut off from the station's main subgraph (driven by PathManager). The blink
## is UI feedback, so it runs on wall-clock (tween), per the TimeManager rules.
func set_disconnected_indicator(active: bool) -> void:
	if not active:
		last_error = ""
		if _disconnected_label != null:
			_disconnected_label.queue_free()
			_disconnected_label = null
		return
	last_error = "No path to station!"
	if _disconnected_label != null:
		return
	_disconnected_label = Label.new()
	_disconnected_label.text = "!"
	_disconnected_label.add_theme_font_size_override("font_size", 36)
	_disconnected_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.15))
	_disconnected_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_disconnected_label.add_theme_constant_override("outline_size", 8)
	_disconnected_label.position = Vector2(owner_module.size.x * Global.CELL_SIZE.x / 2.0 - 8.0, 0)
	_disconnected_label.z_index = 10
	owner_module.add_child(_disconnected_label)
	# Bound to the label, so the loop dies with it on queue_free above.
	var blink: Tween = _disconnected_label.create_tween().set_loops()
	blink.tween_property(_disconnected_label, "modulate:a", 0.15, 0.45)
	blink.tween_property(_disconnected_label, "modulate:a", 1.0, 0.45)

func _draw() -> void:
	if show_debug && Engine.is_editor_hint():
		for index in connection_points.size():
			var point: Vector2i = connection_points[index]
			var center: Vector2 = Vector2(point * Vector2i(64, 64)) +  Vector2(32, 32)
			draw_circle(center, 12, Color.GREEN)
			draw_string(ThemeDB.fallback_font, center + Vector2(-4, 5), str(index), HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color.BLACK)
		for index in path_points.size():
			var point: Vector2i = path_points[index]
			draw_circle(point, 2, Color.GREEN)
			draw_string(ThemeDB.fallback_font, point + Vector2i(-1, 2), str(index), HORIZONTAL_ALIGNMENT_CENTER, -1, 4, Color.BLACK)
		for edge: Vector2i in path_edges:
			draw_line(path_points[edge.x], path_points[edge.y], Color.RED, 1)
		for anchor: AnchorDef in anchors:
			var point: Vector2i = anchor.offset
			if path_points.get(anchor.path_index):
				point += path_points[anchor.path_index]
			draw_circle(point, 2, Color.LIGHT_BLUE)
			draw_string(ThemeDB.fallback_font, point + Vector2i(-1, 1), AnchorDef.AnchorType.keys()[anchor.type], HORIZONTAL_ALIGNMENT_CENTER, -1, 3, Color.BLACK)
