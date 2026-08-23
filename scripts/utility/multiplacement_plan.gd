class_name MultiplacementPlan

## Which modules a click-drag actually builds, and in what order.
##
## A drag used to judge every cell on its own and quietly skip the ones the world
## refused. Drag a line of truss rightwards past the docking bay and the cells over
## the bay are refused while everything past them is built - an island floating
## beside the station, which the rest of the game works to prevent (a *removal*
## that would split the station is blocked outright by a cut-vertex test). On top
## of that, every module that multiplaces skipped the connection check entirely,
## because a module halfway down a drag genuinely is touching nothing yet: it is
## held up by the modules queued in front of it. Which is true right up until one
## of them isn't built.
##
## So the line is judged as a whole. A candidate is *anchored* when it touches
## built structure, and *linked* to the candidates in the drag it would connect
## to; a candidate builds only if it chains back to an anchor through other
## buildable candidates. The result is ordered so every module lands beside
## something already standing, which is what keeps a drag that stops early - the
## player runs out of credits partway - connected rather than scattered.
##
## Pure: no world lookups. The caller answers "is this cell clear" and "does this
## cell touch the station" per candidate; the geometry, the chaining and the order
## are here.

## One thing a placement leaves in the world: the module itself, plus - for a
## module that lives on a layer of its own - the structural backfill (truss) that
## lands under it (see [method ModuleBase.backfill_points]).
##
## This type exists because only a provision on the *connection layer* can hold
## the next module in a drag up, and for three of the four multiplaceable modules
## that is never the module itself. A dragged line of corridors is chained
## together by the truss under each corridor, not by the corridors.
class Provision:
	## Layer this lands on: ModuleData.interaction_layer for the module itself,
	## MODULE for a structural backfill.
	var layer: WorldManager.StructureLayer = WorldManager.StructureLayer.MODULE
	## Where it sits relative to the placing module's own origin cell.
	var offset: Vector2i = Vector2i.ZERO
	var size: Vector2i = Vector2i.ONE
	var connection_points: Array[Vector2i] = []
	var internal_points: Array[Vector2i] = []

	func _init(p_layer: WorldManager.StructureLayer = WorldManager.StructureLayer.MODULE,
			p_offset: Vector2i = Vector2i.ZERO, p_size: Vector2i = Vector2i.ONE,
			p_connection_points: Array[Vector2i] = [],
			p_internal_points: Array[Vector2i] = []) -> void:
		layer = p_layer
		offset = p_offset
		size = p_size
		connection_points = p_connection_points
		internal_points = p_internal_points

## The one module type a drag places: the footprint its connection test is read
## against, and everything that test could find once a copy of it is standing.
class Placement:
	var size: Vector2i = Vector2i.ONE
	var connection_points: Array[Vector2i] = []
	var internal_points: Array[Vector2i] = []
	## The layer the connection test reads - ModuleData.connection_layer, which is
	## deliberately not always the layer the module itself occupies.
	var connection_layer: WorldManager.StructureLayer = WorldManager.StructureLayer.MODULE
	var provisions: Array[Provision] = []

# --- drag geometry ------------------------------------------------------------

## The cells a drag from `start` to `end` covers, ordered outward from `start`
## row by row. `mode` flattens the drag onto its one axis for a module that only
## multiplaces along it, so a corridor drag never grows a second row.
static func drag_cells(start: Vector2i, end: Vector2i, mode: WorldManager.Multiplacement) -> Array[Vector2i]:
	var step := Vector2i(1 if end.x >= start.x else -1, 1 if end.y >= start.y else -1)
	var extent := Vector2i(absi(end.x - start.x), absi(end.y - start.y))
	match mode:
		WorldManager.Multiplacement.NONE:
			extent = Vector2i.ZERO
		WorldManager.Multiplacement.HORIZONTAL:
			extent.y = 0
		WorldManager.Multiplacement.VERTICAL:
			extent.x = 0
	var cells: Array[Vector2i] = []
	for y: int in extent.y + 1:
		for x: int in extent.x + 1:
			cells.append(start + Vector2i(x * step.x, y * step.y))
	return cells

## Origin-to-origin offsets `d` such that a second copy of `placement` sitting at
## `origin + d` would satisfy the connection test of one at `origin`.
##
## Mirrors [method PreviewModule.has_world_connection] and
## [method StructureComponent.can_connect_to] for a module that does not exist
## yet: one of our connection points has to land inside something the other copy
## provides on our connection layer, and one of our internal points has to be a
## cell that thing will connect back through.
static func link_offsets(placement: Placement) -> Array[Vector2i]:
	var offsets: Array[Vector2i] = []
	for provision: Provision in placement.provisions:
		if provision.layer != placement.connection_layer:
			continue
		for point: Vector2i in placement.connection_points:
			for x: int in provision.size.x:
				for y: int in provision.size.y:
					# The offset that puts this cell of the provision under our
					# connection point.
					var offset: Vector2i = point - provision.offset - Vector2i(x, y)
					# Vector2i.ZERO is the module's own provision, not a neighbour.
					if offset == Vector2i.ZERO or offsets.has(offset):
						continue
					if _connects_back(placement, provision, offset):
						offsets.append(offset)
	return offsets

## Does the provision a copy at `offset` supplies accept one of our internal
## points as a connection cell? The other half of the mutual test above.
static func _connects_back(placement: Placement, provision: Provision, offset: Vector2i) -> bool:
	for internal: Vector2i in placement.internal_points:
		var local: Vector2i = internal - offset - provision.offset
		if provision.connection_points.has(local) or provision.internal_points.has(local):
			return true
	return false

# --- the plan -----------------------------------------------------------------

## Build order for a drag: indices into `cells`, each landing beside something
## that is already there - built structure for the anchored ones, an earlier
## entry in this list for the rest. Candidates the world refused (`blocked`), and
## candidates that chain back to nothing, are simply absent.
##
## Breadth-first from the anchors rather than along the drag, because the anchor
## is not always at the near end: drag *towards* the station and the last cell is
## the only one touching it. Building in this order means any prefix of the list
## is a connected station, so a placement that fails partway - no credits left -
## truncates the chain instead of stranding what came after it.
static func resolve(cells: Array[Vector2i], blocked: Array[bool], anchored: Array[bool],
		links: Array[Vector2i]) -> PackedInt32Array:
	var order := PackedInt32Array()
	if blocked.size() != cells.size() or anchored.size() != cells.size():
		push_error("MultiplacementPlan.resolve: one verdict per candidate, please")
		return order
	var origin_to_index: Dictionary[Vector2i, int] = {}
	for index: int in cells.size():
		if not blocked[index]:
			origin_to_index[cells[index]] = index
	var reached: Array[bool] = []
	reached.resize(cells.size())
	var queue: Array[int] = []
	for index: int in cells.size():
		if not blocked[index] and anchored[index]:
			reached[index] = true
			queue.append(index)
	var head: int = 0
	while head < queue.size():
		var index: int = queue[head]
		head += 1
		order.append(index)
		# `links` runs from a module to the neighbour holding it up, so walking
		# outwards from one that is already standing means negating them.
		for offset: Vector2i in links:
			var neighbour: int = origin_to_index.get(cells[index] - offset, -1)
			if neighbour >= 0 and not reached[neighbour]:
				reached[neighbour] = true
				queue.append(neighbour)
	return order
