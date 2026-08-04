class_name Minimap
extends Control

## Symbolic overview of the whole world in the upper-right (WI-34): modules as
## filled cells, asteroids as dots, tracked ships as triangles, and the current
## camera view as an outlined rect. Click/drag jumps the camera. This is a
## _draw()-based Control (no SubViewport by design - we want silhouettes, not a
## render), screen-fixed on the HUD CanvasLayer, and fully real-time (no sim
## scaling anywhere here - ships freezing while paused is correct).

## Square world-fit draw area, in screen pixels.
const MAP_SIZE: float = 220.0
## Collapsible header strip height.
const HEADER_H: float = 22.0
## Inner padding between the panel edge and the fitted world content.
const CONTENT_PAD: float = 6.0
## Gap from the parent's top-right corner.
const MARGIN: float = 8.0
## Smallest world span the fit will zoom to, so a young station reads as a small
## cluster rather than a few giant pixels. ~14 cells across.
const MIN_WORLD_SPAN: float = 900.0
## World-space breathing room added around the content bounds (2 cells each side).
const WORLD_PAD: float = 128.0
## Fraction of its own span the fitted box is padded by whenever it does resize.
## Buys roughly a quarter of the current view of drift before the next resize.
const BOUNDS_SLACK: float = 0.12
## How much larger than necessary the fitted box has to get before it shrinks
## back. Asteroids drift and raiders orbit constantly, so a box that tracked the
## content exactly would rescale the map several times a second; growth stays
## immediate, only shrinking waits for a change this big. Must stay above
## 1 + 2 * BOUNDS_SLACK so a resize can't trigger its own opposite.
const BOUNDS_SHRINK_RATIO: float = 1.6

## tag -> fill color for built modules. Unlisted tags fall back to HULL_COLOR.
## Exported so the palette can be retuned without touching code (balance/visuals
## live in data, per project convention).
@export var tag_colors: Dictionary[String, Color] = {
	"Power": Color("f5c542"),
	"Industrial": Color("d9803a"),
	"Crew": Color("54b95e"),
	"Defense": Color("6c8ecf"),
	"Storage": Color("8f96a3"),
	"Commerce": Color("c065c0"),
	"Life Support": Color("46b3a0"),
	"Logistics": Color("b0a13c"),
	"Transport": Color("7a86c9"),
	"Transportation": Color("7a86c9"),
	"Dock": Color("9aa0a6"),
	"Core": Color("7d828a"),
}

@export var hull_color: Color = Color("6f747c")
## Truss / structural placeholder - the dimmest hull shade.
@export var structure_color: Color = Color(0.32, 0.34, 0.37)
@export var blueprint_color: Color = Color(0.42, 0.72, 1.0, 0.9)
@export var damage_color: Color = Color(1.0, 0.24, 0.18)
@export var asteroid_color: Color = Color(0.55, 0.5, 0.42)
@export var asteroid_designated_color: Color = Color(1.0, 0.85, 0.45)
@export var friendly_ship_color: Color = Color(0.45, 0.85, 0.95)
@export var pirate_ship_color: Color = Color(1.0, 0.4, 0.35)
@export var viewport_rect_color: Color = Color(1.0, 1.0, 1.0, 0.85)
@export var panel_bg_color: Color = Color(0.05, 0.07, 0.09, 0.7)
@export var map_bg_color: Color = Color(0.03, 0.05, 0.07, 0.55)

## Layers drawn back-to-front so MODULE cells sit on top of the dimmer
## corridor/turbolift cells they share a cell with.
const DRAW_LAYERS: Array[WorldManager.StructureLayer] = [
	WorldManager.StructureLayer.CORRIDOR,
	WorldManager.StructureLayer.TURBOLIFT,
	WorldManager.StructureLayer.MODULE,
]

var _transform: MinimapTransform = MinimapTransform.new()
## World AABB the fit currently uses; recomputed only when content changes
## (module add/remove, slow_tick), never on a plain camera move. This is the
## settled box, not the raw content AABB - see MinimapTransform.settle_bounds.
## Starts zero-sized so the first recompute adopts the content as-is.
var _content_bounds: Rect2 = Rect2()
var _collapsed: bool = false
var _header: Button

## Camera state we watched on the last frame, to redraw the viewport rect only
## when the camera actually moved or zoomed.
var _last_cam_pos: Vector2 = Vector2.INF
var _last_cam_zoom: Vector2 = Vector2.ZERO

func _ready() -> void:
	clip_contents = true
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -(MAP_SIZE + MARGIN)
	offset_right = -MARGIN
	offset_top = MARGIN
	offset_bottom = MARGIN + HEADER_H + MAP_SIZE
	_build_header()
	_recompute_bounds()
	# Content-change redraws: build/demolish and the slow tick (drifting asteroids,
	# moving ships). Camera moves are polled in _process instead - they don't
	# change the fit, only the viewport rect.
	SignalBus.module_added.connect(_on_content_changed)
	SignalBus.module_removed.connect(_on_content_changed)
	if Global.time_manager != null:
		Global.time_manager.slow_tick.connect(_on_slow_tick)

func _build_header() -> void:
	_header = Button.new()
	_header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_header.offset_bottom = HEADER_H
	_header.focus_mode = Control.FOCUS_NONE
	_header.pressed.connect(_toggle_collapsed)
	add_child(_header)
	_refresh_header_text()

func _refresh_header_text() -> void:
	_header.text = ("▸ Minimap" if _collapsed else "▾ Minimap")

func _toggle_collapsed() -> void:
	_collapsed = not _collapsed
	offset_bottom = MARGIN + HEADER_H + (0.0 if _collapsed else MAP_SIZE)
	_refresh_header_text()
	queue_redraw()

func _on_content_changed(_module: ModuleBase) -> void:
	_recompute_bounds()
	queue_redraw()

func _on_slow_tick(_interval: float) -> void:
	_recompute_bounds()
	queue_redraw()

## Poll the camera every real frame (UI is real-time): redraw only when it moved
## or zoomed, so a still camera costs nothing.
func _process(_delta: float) -> void:
	if _collapsed:
		return
	var cam: GameCamera = _get_camera()
	if cam == null:
		return
	if cam.global_position != _last_cam_pos or cam.zoom != _last_cam_zoom:
		_last_cam_pos = cam.global_position
		_last_cam_zoom = cam.zoom
		queue_redraw()

# --- bounds -------------------------------------------------------------------

## Recompute the world AABB spanning every occupied cell, every live asteroid and
## every tracked ship, padded - i.e. everything _draw() puts on the map, so
## nothing it draws can land outside it (raiders orbit well clear of the station
## and used to be clipped off the edge). Cheap enough to run on content changes /
## slow_tick. The result is run through the hysteresis before it becomes the
## fitted box, because asteroids and ships move every single tick.
func _recompute_bounds() -> void:
	var world: WorldManager = Global.world_manager
	if world == null:
		return
	var has_any: bool = false
	var min_p: Vector2 = Vector2.INF
	var max_p: Vector2 = -Vector2.INF
	for layer: WorldManager.StructureLayer in DRAW_LAYERS:
		for cell: Vector2i in world.layer_data[layer].cell_to_module:
			var tl: Vector2 = Vector2(cell * Global.CELL_SIZE)
			var br: Vector2 = Vector2((cell + Vector2i.ONE) * Global.CELL_SIZE)
			min_p = Vector2(minf(min_p.x, tl.x), minf(min_p.y, tl.y))
			max_p = Vector2(maxf(max_p.x, br.x), maxf(max_p.y, br.y))
			has_any = true
	if Global.asteroid_manager != null:
		for asteroid: AsteroidBase in Global.asteroid_manager.asteroids:
			if not is_instance_valid(asteroid):
				continue
			var p: Vector2 = asteroid.global_position
			min_p = Vector2(minf(min_p.x, p.x), minf(min_p.y, p.y))
			max_p = Vector2(maxf(max_p.x, p.x), maxf(max_p.y, p.y))
			has_any = true
	for node: Node in get_tree().get_nodes_in_group(Groups.MINIMAP_TRACKED):
		var ship: Node2D = node as Node2D
		if ship == null or not is_instance_valid(ship):
			continue
		var p: Vector2 = ship.global_position
		min_p = Vector2(minf(min_p.x, p.x), minf(min_p.y, p.y))
		max_p = Vector2(maxf(max_p.x, p.x), maxf(max_p.y, p.y))
		has_any = true
	var desired: Rect2 = Rect2(Vector2.ZERO, Vector2(MIN_WORLD_SPAN, MIN_WORLD_SPAN))
	if has_any:
		var pad: Vector2 = Vector2(WORLD_PAD, WORLD_PAD)
		desired = Rect2(min_p - pad, (max_p - min_p) + pad * 2.0)
	_content_bounds = MinimapTransform.settle_bounds(
		_content_bounds, desired, BOUNDS_SLACK, BOUNDS_SHRINK_RATIO)

# --- drawing ------------------------------------------------------------------

func _map_rect() -> Rect2:
	return Rect2(
		Vector2(CONTENT_PAD, HEADER_H + CONTENT_PAD),
		Vector2(size.x - CONTENT_PAD * 2.0, size.y - HEADER_H - CONTENT_PAD * 2.0))

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), panel_bg_color)
	if _collapsed:
		return
	var map_rect: Rect2 = _map_rect()
	draw_rect(map_rect, map_bg_color)
	_transform.configure(_content_bounds, map_rect, MIN_WORLD_SPAN)
	_draw_modules()
	_draw_asteroids()
	_draw_ships()
	_draw_viewport_rect()

func _draw_modules() -> void:
	var world: WorldManager = Global.world_manager
	if world == null:
		return
	for layer: WorldManager.StructureLayer in DRAW_LAYERS:
		var dim: bool = layer != WorldManager.StructureLayer.MODULE
		for cell: Vector2i in world.layer_data[layer].cell_to_module:
			var module: ModuleBase = world.layer_data[layer].cell_to_module[cell]
			if module == null:
				continue
			var tl: Vector2 = _transform.world_to_map(Vector2(cell * Global.CELL_SIZE))
			var br: Vector2 = _transform.world_to_map(Vector2((cell + Vector2i.ONE) * Global.CELL_SIZE))
			var rect: Rect2 = Rect2(tl, br - tl)
			if not module.is_complete():
				# Blueprints / construction sites read as an outline, not a solid.
				draw_rect(rect, blueprint_color, false, 1.0)
				continue
			var col: Color = _module_color(module, world)
			if dim:
				col = col.darkened(0.4)
			var frac: float = module.hp_fraction()
			if frac < 1.0:
				col = col.lerp(damage_color, (1.0 - frac) * 0.9)
			draw_rect(rect, col)

func _module_color(module: ModuleBase, world: WorldManager) -> Color:
	if module.module_data == null:
		return hull_color
	if module.module_data == world.replacement_module:
		return structure_color
	# A module may name its own colour (WI-47 audit sweep). Checked before the tag
	# table because that table is authored on this node and a mod can't extend it,
	# so a modded module's new tag would otherwise always fall through to grey.
	if module.module_data.minimap_color.a > 0.0:
		return module.module_data.minimap_color
	for tag: String in module.module_data.tags:
		if tag_colors.has(tag):
			return tag_colors[tag]
	return hull_color

func _draw_asteroids() -> void:
	if Global.asteroid_manager == null:
		return
	for asteroid: AsteroidBase in Global.asteroid_manager.asteroids:
		if not is_instance_valid(asteroid):
			continue
		var p: Vector2 = _transform.world_to_map(asteroid.global_position)
		draw_circle(p, 1.6, asteroid_designated_color if asteroid.designated else asteroid_color)

func _draw_ships() -> void:
	for node: Node in get_tree().get_nodes_in_group(Groups.MINIMAP_TRACKED):
		var ship: Node2D = node as Node2D
		if ship == null or not is_instance_valid(ship):
			continue
		var p: Vector2 = _transform.world_to_map(ship.global_position)
		var col: Color = pirate_ship_color if ship.is_in_group(Groups.PIRATE_SHIP) else friendly_ship_color
		_draw_triangle(p, 4.0, col)

func _draw_triangle(center: Vector2, radius: float, color: Color) -> void:
	var pts: PackedVector2Array = [
		center + Vector2(0.0, -radius),
		center + Vector2(radius * 0.9, radius * 0.8),
		center + Vector2(-radius * 0.9, radius * 0.8),
	]
	draw_colored_polygon(pts, color)

func _draw_viewport_rect() -> void:
	var cam: GameCamera = _get_camera()
	if cam == null:
		return
	var view_size: Vector2 = get_viewport_rect().size / cam.zoom
	var world_rect: Rect2 = Rect2(cam.global_position - view_size * 0.5, view_size)
	var tl: Vector2 = _transform.world_to_map(world_rect.position)
	var br: Vector2 = _transform.world_to_map(world_rect.end)
	draw_rect(Rect2(tl, br - tl), viewport_rect_color, false, 1.5)

# --- interaction --------------------------------------------------------------

## Left click / drag jumps the camera. accept_event() keeps the click from
## leaking through to the world (so it never places a module mid-build-preview
## or selects an object underneath).
func _gui_input(event: InputEvent) -> void:
	if _collapsed:
		return
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		if button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
			_jump_from_local(button.position)
			accept_event()
	elif event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event
		if motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_jump_from_local(motion.position)
			accept_event()

func _jump_from_local(local: Vector2) -> void:
	if not _map_rect().has_point(local):
		return
	var cam: GameCamera = _get_camera()
	if cam == null:
		return
	cam.jump_to(_transform.map_to_world(local))
	queue_redraw()

func _get_camera() -> GameCamera:
	return get_viewport().get_camera_2d() as GameCamera
