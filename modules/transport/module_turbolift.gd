@tool
class_name ModuleTurbolift
extends ModuleBase

@export var collision_upper: CollisionShape2D
@export var collision_lower: CollisionShape2D
@export var door_sprite: AnimatedSprite2D
## How long this floor's door stands open after a cab stops, before shutting
## itself. It was a literal in the door's auto-close lambda.
@export var door_hold_seconds: float = 2.0

var shaft: TurboliftShaft
## The floor's door, as state (WI-75 §3): a cab asks it open and waits the answer
## out, and it shuts itself after door_hold_seconds. It used to be the sprite's
## playback, awaited by the cab and closed by an animation_finished lambda.
var _door: DoorMotion = null

const DOOR_ANIMATION: StringName = &"open"

## Skip-floor toggle (WI-11): a disabled floor stays a physical shaft cell
## (cabs ride through it) but pawns can't board or alight there.
var floor_enabled: bool = true:
	set = set_floor_enabled

const DISABLED_DIM := Color(0.45, 0.45, 0.45)

func set_floor_enabled(new_enabled: bool) -> void:
	if floor_enabled == new_enabled:
		return
	floor_enabled = new_enabled
	# no_group_stop marks the graph dirty and fires the module_group_changed
	# repath hook, so pawns mid-route re-plan (stairs, or honest failure).
	Global.path_manager.set_no_group_stop(self, not new_enabled)
	door_sprite.modulate = Color.WHITE if new_enabled else DISABLED_DIM
	sprite.self_modulate = Color.WHITE if new_enabled else DISABLED_DIM
	if shaft != null:
		shaft.on_floor_toggled(self)

func _ready() -> void:
	add_to_group(Groups.TURBOLIFTS)
	super()
	SignalBus.module_added.connect(set_sprite)
	SignalBus.module_removed.connect(set_sprite)
	get_path_component().door_connected.connect(door_connected)
	get_path_component().door_disconnected.connect(door_disconnected)
	set_sprite(null)
	# The door is state now, ticked in sim time below; the sprite only draws it.
	door_sprite.stop()
	_door = DoorMotion.make(DoorMotion.animation_seconds(door_sprite.sprite_frames, DOOR_ANIMATION),
		door_hold_seconds)
	_draw_door()
	set_process(false)
	Global.turbolift_manager.add_turbolift_module(self)

func pre_delete() -> void:
	super()
	Global.turbolift_manager.remove_turbolift_module(self)

func on_select(new_selected: bool) -> void:
	super(new_selected)
	
func door_connected(_cell: Vector2i, _from_layer: WorldManager.StructureLayer) -> void:
	door_sprite.visible = true
	
func door_disconnected(_cell: Vector2i, _from_layer: WorldManager.StructureLayer) -> void:
	door_sprite.visible = false
	
func set_sprite(_module: ModuleBase) -> void:
	if _module == null or _module is ModuleTurbolift or _module is CorridorModule:
		var image_select: int = 0
		if Global.world_manager.get_module_by_cell(WorldManager.StructureLayer.TURBOLIFT, module_cell + Vector2i(0, -1)) is ModuleTurbolift:
			# There is a turbolift above this
			collision_upper.disabled = false
			image_select += 1
		else:
			collision_upper.disabled = true
		if Global.world_manager.get_module_by_cell(WorldManager.StructureLayer.TURBOLIFT, module_cell + Vector2i(0, 1)) is ModuleTurbolift:
			# There is a turbolift below
			sprite.region_rect.position.x = 0
			collision_lower.disabled = false
			image_select += 2
		else:
			collision_lower.disabled = true
		sprite.region_rect.position.x = Global.CELL_SIZE.x * image_select
			
		queue_redraw()

## Opens this floor's door for a cab that has just stopped, and returns the
## sim-seconds until it is fully open - what the cab waits before anyone gets on
## or off. 0 if it is open already (the hold from the last stop keeps running).
func open_door() -> float:
	var seconds: float = _door.request(true)
	_draw_door()
	set_process(_door.needs_tick())
	return seconds

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _door == null or not _door.needs_tick():
		set_process(false)
		return
	var sim_delta: float = Global.time_manager.scale(delta)
	if sim_delta <= 0.0:
		return
	_door.tick(sim_delta)
	_draw_door()
	if not _door.needs_tick():
		set_process(false)

func _draw_door() -> void:
	if door_sprite == null or door_sprite.sprite_frames == null \
			or not door_sprite.sprite_frames.has_animation(DOOR_ANIMATION):
		return
	door_sprite.animation = DOOR_ANIMATION
	door_sprite.frame = DoorMotion.frame_for(_door.openness,
		door_sprite.sprite_frames.get_frame_count(DOOR_ANIMATION))

func get_save_data() -> Dictionary:
	var data: Dictionary = super()
	if not floor_enabled:
		data["floor_enabled"] = false
	# A door part way through a stop - opening, or held open with its auto-close
	# half run down - carries on from there after a load (WI-75).
	var door: Dictionary = _door.to_dict() if _door != null else {}
	if not door.is_empty():
		data["door"] = door
	return data

func load_save_data(data: Dictionary) -> void:
	super(data)
	floor_enabled = bool(data.get("floor_enabled", true))
	if _door != null:
		_door.load_dict(data.get("door", {}))
		_draw_door()
		set_process(_door.needs_tick())

## Claims a QUEUE spot for the ride in the corridor behind this floor (WI-16)
## and returns where it is, for the pawn to walk to - the walk itself is the
## pawn's ManualWalk state now, not an await in here (WI-75 §6). Falls back to a
## small random sidestep when there's no corridor or no free anchor: anchor
## scarcity must never block the ride.
func assign_waiting_slot(request: RideRequest) -> Vector2:
	var pawn: PawnBase = request.pawn
	var dest: Vector2 = pawn.global_position + Vector2(randi_range(-10, 10), randi_range(0, 5))
	var corridor: ModuleBase = Global.world_manager.get_module_by_cell(WorldManager.StructureLayer.CORRIDOR, module_cell)
	if corridor != null:
		pawn.reparent(corridor)
		var pc: PathComponent = corridor.get_path_component()
		if pc != null:
			request.queue_anchor = pc.claim_anchor(AnchorDef.AnchorType.QUEUE, request)
			if request.queue_anchor != null:
				request.queue_path = pc
				dest = pc.get_anchor_global_position(request.queue_anchor)
	return dest

func has_custom_pathing() -> bool:
	return true

func traverse(_pawn: PawnBase, _path_edge: PathComponent.PathTraversalEdgeData) -> PathHookResult:
	return PathHookResult.proceed()

func path_enter(_pawn: PawnBase, _door: int, _meta: StringName, _next_node: Node2D) -> PathHookResult:
	return PathHookResult.proceed()

## Leaving this floor for another of the shaft's is a ride (WI-75 §5). The shaft
## takes the pawn - a queue walk, a wait, a walk into the cab, the ride - and the
## path is finished with until the cab drops it and exit_conveyed re-paths from
## that floor. A ride that cannot start (a floor switched off) fails the move, and
## the pawn re-plans.
func path_exit(pawn: PawnBase, _door: int, _meta: StringName, next_node: Node2D) -> PathHookResult:
	var next_floor: ModuleTurbolift = next_node as ModuleTurbolift
	if next_floor == null or shaft == null:
		return PathHookResult.proceed()
	var request: RideRequest = shaft.request_ride(pawn, self, next_floor)
	if request.phase == RideRequest.Phase.CANCELLED:
		return PathHookResult.fail()
	return PathHookResult.taken_over()
