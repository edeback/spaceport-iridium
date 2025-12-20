## GBDiagnostics — runtime/shared diagnostics helpers

## Provide small, safe, static helpers for generating diagnostic strings that can be
## reused by runtime code and tests.
##
## Notes:
## - Keep these functions side-effect free (no printing) so callers may log or assert
##   as they prefer.
class_name GBDiagnostics
extends RefCounted

## Check if verbose diagnostics mode is enabled via environment variable.
## [return] true if GB_VERBOSE_TESTS is set to "1", "true", or "TRUE".
static func _is_verbose() -> bool:

	var v := OS.get_environment("GB_VERBOSE_TESTS")
	return v == "1" or v == "true" or v == "TRUE"

## Format a debug message string, optionally including suite and file path if verbose mode is enabled.
## [param message] The core message to format.
## [param suite] Optional suite name to prefix in brackets.
## [param file_path] Optional file path to append in parentheses.
## [return] Formatted string, enhanced if verbose mode is on.
static func format_debug(message: String, suite: String = "", file_path: String = "") -> String:

	if _is_verbose():
		var parts: Array[String] = []
		if suite != "":
			parts.append("[" + suite + "]")
		parts.append(message)
		if file_path != "":
			parts.append("(" + file_path + ")")
		return " ".join(parts)
	return message

## Format an indicator object into a human-readable string for diagnostics.
## [param indicator] The indicator object to format (can be RuleCheckIndicator, Node, or generic Object).
## [return] Formatted string like "name@position (extra_info)" or "<null>" if null.
static func format_indicator(indicator: Object) -> String:
	if indicator == null:
		return "<null>"

	var display_name: String = ""
	# Prefer explicit type checks where possible for clarity and safety
	if indicator is RuleCheckIndicator:
		display_name = str(indicator.name)
	elif indicator is Node:
		display_name = str(indicator.name)
	else:
		display_name = str(indicator)

	var pos_str: String = ""
	if indicator is Node and indicator.has_method("get_global_position"):
		pos_str = str(indicator.get_global_position())
	elif indicator is Node and indicator.has_method("get_position"):
		pos_str = str(indicator.get_position())

	var extra: String = ""
	if indicator is RuleCheckIndicator:
		# include rule count for helpful context (explicitly typed to satisfy GDScript)
		var rules_arr: Array = []
		# RuleCheckIndicator exposes get_rules() so safe to call when typed
		rules_arr = indicator.get_rules()
		extra = "rules=%d" % rules_arr.size()

	return "%s@%s%s" % [display_name, pos_str, (" (%s)" % extra) if extra != "" else ""]

## Format a list of tile coordinates into a compact string.
## @param tile_list Array of tile coordinates (e.g., Vector2i).
## @return String like "[tile1, tile2, ...]" or "[]" if null.
static func format_tile_list(tile_list: Array) -> String:

	if tile_list == null:
		return "[]"
	var parts: Array = []
	for i in range(tile_list.size()):
		parts.append(str(tile_list[i]))
	return "[%s]" % ", ".join(parts)

## Format a list of indicators into a multi-line string with a prefix.
## [param prefix] String to prepend to the list.
## [param indicators] Array of indicator objects.
## [param _cls_name] Unused parameter (for future extension).
## [param _file_path] Unused parameter (for future extension).
## [return] Multi-line string with prefix and indented indicator details.
static func format_indicator_list(prefix: String, indicators: Array, _cls_name: String = "", _file_path: String = "") -> String:

	var lines: Array = []
	lines.append(prefix)
	if indicators == null or indicators.size() == 0:
		lines.append("  (none)")
	else:
		for ind in indicators:
			lines.append("  - %s" % format_indicator(ind))
	return "\n" + "\n".join(lines)

## Format a compact stack summary string from `get_stack()` output.
## [param stack] Array returned by `get_stack()` (array of Dictionary/Frame objects)
## [param max_entries] maximum number of stack entries to include (default 6)
## [return] a short string like: "[file1.gd:123:func1, file2.gd:45:func2, ...]".
## This is intentionally lightweight and side-effect free so callers can log it.
static func format_stack_summary(stack: Array, max_entries: int = 6) -> String:
	if stack == null:
		return "[]"
	var parts: Array[String] = []
	var n := min(max_entries, stack.size())
	for i in range(n):
		var entry = stack[i]
		# entry is typically a Dictionary with keys 'source', 'line', 'function'
		var src: String = "<unknown>"
		var line_num: int = 0
		var func_name: String = "<anon>"
		if typeof(entry) == TYPE_DICTIONARY:
			if entry.has("source") and entry["source"] != null:
				src = str(entry["source"])
			if entry.has("line"):
				line_num = int(entry["line"])
			if entry.has("function") and entry["function"] != null:
				func_name = str(entry["function"])
		else:
			# Fallback: stringify the entry
			src = str(entry)
		parts.append("%s:%s:%s" % [src.get_file() if typeof(src) == TYPE_OBJECT and src.get_file != null else src, str(line_num), func_name])
	# If stack has more entries than we showed, append ellipsis
	if stack.size() > n:
		parts.append("...")
	return "[" + ", ".join(parts) + "]"

## Format a Node or Object for logging.
## [param obj] The object to format.
## [return] Formatted string like "name(class)" or "<null>" etc.
static func format_node_label(obj: Object) -> String:
	if typeof(obj) == TYPE_OBJECT and is_instance_valid(obj) and obj is Node:
		var n: Node = obj as Node
		return "%s(%s)" % [n.name, n.get_class()]
	if obj == null:
		return "<null>"
	if typeof(obj) == TYPE_OBJECT and not is_instance_valid(obj):
		return "<freed>"
	return str(obj)

## Build a visibility context string similar to GridPositioner2D._visibility_context
## [param node] The GridPositioner2D (or any CanvasItem/Node) providing context
## [param visual] The visual CanvasItem associated with the node (may be null)
## [param vp] Active Viewport (optional)
## [param cam] Active Camera2D (optional)
static func format_visibility_context(node: Node, visual: CanvasItem, vp: Viewport, cam: Camera2D) -> String:
	var hidden_ancestor := "<none>"
	var p: Node = node
	while p != null:
		if p is CanvasLayer:
			if not (p as CanvasLayer).visible:
				hidden_ancestor = "%s(%s:layer_hidden)" % [p.name, p.get_class()]
				break
		elif p is CanvasItem:
			if not (p as CanvasItem).visible:
				hidden_ancestor = "%s(%s)" % [p.name, p.get_class()]
				break
		p = p.get_parent()

	var self_ci: CanvasItem = node as CanvasItem
	var self_alpha := "n/a"
	var self_z := "n/a"
	var self_vis_in_tree := "n/a"
	if self_ci:
		self_alpha = "%.2f" % self_ci.self_modulate.a
		self_z = str(self_ci.z_index)
		self_vis_in_tree = str(self_ci.is_visible_in_tree())

	var visual_alpha := "n/a"
	var visual_z := "n/a"
	var visual_vis_in_tree := "n/a"
	var visual_info := "<none>"
	if visual != null:
		visual_alpha = "%.2f" % visual.self_modulate.a
		visual_z = str(visual.z_index)
		visual_vis_in_tree = str(visual.is_visible_in_tree())
		visual_info = "%s(%s)" % [visual.name, visual.get_class()]

	var cam_cur := cam != null and cam.is_current()
	var node_pos := Vector2.ZERO
	if self_ci:
		node_pos = self_ci.global_position

	return "anc_hidden=%s self_a=%s self_z=%s self_tree=%s visual_a=%s visual_z=%s visual_tree=%s visual=%s cam_current=%s pos=%s" \
		% [hidden_ancestor, self_alpha, self_z, self_vis_in_tree, visual_alpha, visual_z, visual_vis_in_tree, visual_info, str(cam_cur), str(node_pos)]


## Describe collision layers of a CollisionObject2D.
## [param obj] The object to check (should be CollisionObject2D).
## [return] Array of active collision layer indices (1-32).
static func describe_collision_layers(obj: Object) -> Array[int]:
	if obj is CollisionObject2D:
		var co: CollisionObject2D = obj as CollisionObject2D
		var bits: Array[int] = []
		for i in range(1, 33):
			var ok: bool = co.get_collision_layer_value(i)
			if ok:
				bits.append(i)
		return bits
	return []


## Format current collisions of a ShapeCast2D for diagnostics.
## [param shape_cast] The ShapeCast2D to inspect.
## [return] Formatted string like "colliding count=X -> collider1, collider2, ...".
static func format_shape_cast_collisions(shape_cast: ShapeCast2D) -> String:
	var count: int = shape_cast.get_collision_count()
	var colliders_info: Array[String] = []
	for i in range(count):
		var c: Object = shape_cast.get_collider(i)
		if c is Node:
			var n: Node = c as Node
			colliders_info.append("%s(%s) layers=%s" % [n.name, n.get_class(), describe_collision_layers(n)])
		else:
			colliders_info.append(str(c))
	return "colliding count=%s -> %s" % [count, ", ".join(colliders_info)]

## Format a CanvasItem's render-related state (modulate, self_modulate, z_index, position, scale, texture info).
## [param ci] CanvasItem (Sprite2D, AnimatedSprite2D, etc.) or null.
## [return] String with key properties for diagnosing visibility without relying solely on .visible.
static func format_canvas_item_state(ci: CanvasItem) -> String:
	if ci == null:
		return "<none>"
	var cls_name = ci.get_class()
	var base = "%s(%s) vis=%s tree=%s a=%.2f z=%s pos=%s scale=%s" % [ci.name, cls_name, str(ci.visible), str(ci.is_visible_in_tree()), ci.self_modulate.a, str(ci.z_index), str(ci.global_position), str(ci.scale)]
	if ci is Sprite2D:
		var sp: Sprite2D = ci as Sprite2D
		var tx: Texture2D = sp.texture
		if tx:
			base += " tex=%s size=%s" % [tx.resource_name, str(tx.get_size())]
	if ci is AnimatedSprite2D:
		var aspr: AnimatedSprite2D = ci as AnimatedSprite2D
		base += " anim=%s frame=%s" % [aspr.animation, str(aspr.frame)]
	return base

## Compute world bounds rectangle for the active camera & viewport.
## [param cam] Active Camera2D (may be null)
## [param vp] Viewport owning the camera (may be null)
## [return] Dictionary with keys: has(bool), center(Vector2), world_min(Vector2), world_max(Vector2), zoom(Vector2)
static func camera_world_bounds(cam: Camera2D, vp: Viewport) -> Dictionary:
	if cam == null or vp == null:
		return {"has": false}
	var vp_rect := vp.get_visible_rect()
	var half := vp_rect.size * 0.5 * cam.zoom
	# Prefer global_position when camera is not current or not in tree to keep behavior stable in tests
	var cam_center: Vector2
	if cam.is_inside_tree() and cam.is_current() and cam.has_method("get_screen_center_position"):
		cam_center = cam.get_screen_center_position()
	else:
		cam_center = cam.global_position
	return {
		"has": true,
		"center": cam_center,
		"world_min": cam_center - half,
		"world_max": cam_center + half,
		"zoom": cam.zoom
	}

## Determine if a world position is inside provided camera world bounds
## [param bounds] Result from camera_world_bounds
## [param pos] World position to test
## [return] true if inside or bounds invalid (fail open for safety)
static func is_inside_camera_bounds(bounds: Dictionary, pos: Vector2) -> bool:
	if not bounds.has("has") or not bounds["has"]:
		return true
	var minv: Vector2 = bounds["world_min"]
	var maxv: Vector2 = bounds["world_max"]
	return pos.x >= minv.x and pos.x <= maxv.x and pos.y >= minv.y and pos.y <= maxv.y

## Convenience negative predicate for offscreen detection
static func is_offscreen(bounds: Dictionary, pos: Vector2) -> bool:
	return not is_inside_camera_bounds(bounds, pos)

## Format screen & mouse diagnostic state (formerly in GridPositioner2D)
## [param cam] Active camera
## [param vp] Active viewport
## [param positioner_pos] World position of positioner
## [param has_mouse] Whether we have cached mouse world position
## [param mouse_world] Last cached mouse world (ignored if has_mouse false)
## [param map] Tile map / target map providing coordinate -> tile projection (expects get_tile_from_global_position via GBPositioning2DUtils)
## [return] Formatted string matching prior screen_state log output
static func format_screen_state(cam: Camera2D, vp: Viewport, positioner_pos: Vector2, has_mouse: bool, mouse_world: Vector2, map: Object) -> String:
	if cam == null or vp == null:
		return "screen_state: <no camera> pos=%s" % str(positioner_pos)
	var bounds := camera_world_bounds(cam, vp)
	var inside := is_inside_camera_bounds(bounds, positioner_pos)
	var pos_tile := Vector2i.ZERO
	var mouse_tile := Vector2i.ZERO
	if map != null:
		pos_tile = _safe_get_tile_from_global_position(positioner_pos, map)
		if has_mouse:
			mouse_tile = _safe_get_tile_from_global_position(mouse_world, map)
	var delta_tiles := Vector2i(mouse_tile.x - pos_tile.x, mouse_tile.y - pos_tile.y)
	return "screen_state cam_center=%s zoom=%s world_min=%s world_max=%s pos=%s inside=%s pos_tile=%s mouse_world=%s mouse_tile=%s delta_tiles=%s has_mouse=%s" % [
		str(bounds.get("center", Vector2.ZERO)),
		str(bounds.get("zoom", Vector2.ONE)),
		str(bounds.get("world_min", Vector2.ZERO)),
		str(bounds.get("world_max", Vector2.ZERO)),
		str(positioner_pos),
		str(inside),
		str(pos_tile),
		str(mouse_world if has_mouse else Vector2.INF),
		str(mouse_tile),
		str(delta_tiles),
		str(has_mouse)
	]

## Safe wrapper for getting tile position from global position.
## Handles both TileMapLayer and test objects with duck-typed interface.
## [param global_position] The world position to convert.
## [param map] The map object (TileMapLayer or duck-typed equivalent).
## [return] The tile coordinate as Vector2i, or Vector2i.ZERO if conversion fails.
static func _safe_get_tile_from_global_position(global_position: Vector2, map: Object) -> Vector2i:
	if map == null:
		return Vector2i.ZERO
	
	# Handle TileMapLayer (standard case)
	if map is TileMapLayer:
		return GBPositioning2DUtils.get_tile_from_global_position(global_position, map)
	
	# Handle duck-typed objects (like test FakeMap)
	# These should have local_to_map(Vector2) -> Vector2i method
	if map.has_method("local_to_map"):
		var map_position: Vector2
		if map.has_method("to_local"):
			map_position = map.to_local(global_position)
		else:
			# For simple test objects without transform, use direct position
			map_position = global_position - map.global_position
		return map.local_to_map(map_position)
	
	# Fallback: return zero tile for unsupported map types
	return Vector2i.ZERO
