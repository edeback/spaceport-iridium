class_name OverlayFlowLayer
extends Node2D

## WI-35 logistics overlay's drawing layer: the one overlay mode that needs more
## than a shader tint. Parented into the world-following SPACE canvas (above the
## module layer) by the OverlayController, so its _draw() runs in world space on
## top of the station. It draws, only while the logistics mode is active:
##   - a small priority number on every active storage module (the routing value
##     players set jobs by), and
##   - flow arrows for current hauls (claimed jobs on pawns + any fully-specified
##     waiting job) and for configured conveyor lanes (WI-27).
##
## Everything is recomputed per redraw and retained nowhere: an endpoint freed
## between frames just isn't drawn (guarded by is_instance_valid), so there are
## never stale arrows. The controller triggers redraws on slow_tick / builds.

@export var haul_color: Color = Color(0.45, 0.85, 1.0, 0.8)
@export var conveyor_color: Color = Color(1.0, 0.8, 0.35, 0.85)
@export var label_color: Color = Color(0.95, 0.97, 1.0)
@export var label_shadow: Color = Color(0.0, 0.0, 0.0, 0.85)
@export var arrow_width: float = 2.5
@export var arrow_head: float = 12.0
@export var label_font_size: int = 14

func _draw() -> void:
	if Global.world_manager == null:
		return
	_draw_haul_arrows()
	_draw_conveyor_arrows()
	_draw_priority_labels()

# --- arrows -------------------------------------------------------------------

## Claimed hauls live on each pawn's current_job; fully-specified waiting jobs
## (both endpoints known) live on the board. Either way we only draw a job whose
## source and destination modules are both still alive.
func _draw_haul_arrows() -> void:
	for node: Node in get_tree().get_nodes_in_group("pawn"):
		var pawn: PawnBase = node as PawnBase
		if pawn == null:
			continue
		_try_draw_haul(pawn.current_job as Job_GetResource)
	if Global.job_manager != null:
		for job: Job_GetResource in Global.job_manager.get_waiting_haul_jobs():
			_try_draw_haul(job)

func _try_draw_haul(job: Job_GetResource) -> void:
	if job == null or job.is_ended():
		return
	var from_module: ModuleBase = _storage_module(job.export_storage)
	var to_module: ModuleBase = _storage_module(job.deposit_storage)
	if from_module == null or to_module == null or from_module == to_module:
		return
	_draw_arrow(_center(from_module), _center(to_module), haul_color)

func _draw_conveyor_arrows() -> void:
	for module: ModuleBase in Global.world_manager.id_to_module.values():
		if not is_instance_valid(module):
			continue
		var conveyor: ConveyorComponent = module.get_component_by_type(ConveyorComponent) as ConveyorComponent
		if conveyor == null:
			continue
		for lane: ConveyorLane in conveyor.lanes:
			var from_module: ModuleBase = _endpoint_module(lane.source)
			var to_module: ModuleBase = _endpoint_module(lane.destination)
			if from_module == null or to_module == null or from_module == to_module:
				continue
			_draw_arrow(_center(from_module), _center(to_module), conveyor_color)

## An arrow from -> to in this layer's local space (== world space here).
func _draw_arrow(from_world: Vector2, to_world: Vector2, color: Color) -> void:
	var from: Vector2 = to_local(from_world)
	var to: Vector2 = to_local(to_world)
	if from.distance_to(to) < arrow_head:
		return
	draw_line(from, to, color, arrow_width, true)
	var dir: Vector2 = (to - from).normalized()
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var base: Vector2 = to - dir * arrow_head
	var head: PackedVector2Array = [to, base + perp * arrow_head * 0.5, base - perp * arrow_head * 0.5]
	draw_colored_polygon(head, color)

# --- priority labels ----------------------------------------------------------

## The routing number on each active storage module. "resource_storage" holds
## every live storage component (construction sites while blueprint, regular
## bins once built), so the group is the cheap authoritative set.
func _draw_priority_labels() -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var seen: Dictionary[ModuleBase, int] = {}
	for node: Node in get_tree().get_nodes_in_group("resource_storage"):
		var storage: StorageComponent = node as StorageComponent
		if storage == null or not is_instance_valid(storage.owner_module):
			continue
		var module: ModuleBase = storage.owner_module
		# One label per module: keep the largest-magnitude priority if a module
		# somehow hosts several storages, matching the tint's "most salient" rule.
		if seen.has(module) and absi(seen[module]) >= absi(storage.priority):
			continue
		seen[module] = storage.priority
	for module: ModuleBase in seen:
		_draw_label(font, _center(module), str(seen[module]))

func _draw_label(font: Font, world_center: Vector2, text: String) -> void:
	var size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, label_font_size)
	var pos: Vector2 = to_local(world_center) - size * 0.5 + Vector2(0.0, size.y * 0.5)
	draw_string(font, pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, label_font_size, label_shadow)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, label_font_size, label_color)

# --- helpers ------------------------------------------------------------------

func _storage_module(storage: StorageComponent) -> ModuleBase:
	if storage == null or not is_instance_valid(storage) or not is_instance_valid(storage.owner_module):
		return null
	return storage.owner_module

func _endpoint_module(endpoint: ComponentBase) -> ModuleBase:
	if endpoint == null or not is_instance_valid(endpoint) or not is_instance_valid(endpoint.owner_module):
		return null
	return endpoint.owner_module

func _center(module: ModuleBase) -> Vector2:
	return module.get_global_center()
