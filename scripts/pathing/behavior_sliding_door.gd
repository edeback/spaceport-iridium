class_name Behavior_SlidingDoor
extends PathBehavior

## A single door that opens for whoever crosses it and shuts itself behind them.
## No module in the base game uses it today; it is kept working because a mod's
## module can.
##
## The door is a [DoorMotion] ticked by the owning [PathComponent] (WI-75 §3),
## where it used to be the sprite's playback plus an `animation_finished` lambda
## that awaited `sim_seconds` - and resumed on a freed sprite if the module went
## during the hold.

class SlidingDoorState:
	var door_sprite: AnimatedSprite2D = null
	var motion: DoorMotion = null

@export var door_node_path: NodePath
## How long the door stands open before shutting itself - and the head start a
## pawn entering gives it before walking on.
@export var open_seconds: float = 0.4

const DOOR_ANIMATION: StringName = &"open"

func create_state(pc: PathComponent) -> RefCounted:
	var state := SlidingDoorState.new()
	state.door_sprite = pc.get_node(door_node_path) as AnimatedSprite2D
	var frames: SpriteFrames = state.door_sprite.sprite_frames if state.door_sprite != null else null
	state.motion = DoorMotion.make(DoorMotion.animation_seconds(frames, DOOR_ANIMATION), open_seconds)
	if state.door_sprite != null:
		state.door_sprite.stop()
	_draw(state)
	return state

## Entering starts the door opening and gives it `open_seconds` before walking on,
## which is what the old await did; the pawn reaches the doorway as it finishes.
func on_enter(_pawn: PawnBase, _door_index: int, _meta: StringName, _module: ModuleBase,
		_next_node: Node2D, state: RefCounted) -> PathHookResult:
	var door_state: SlidingDoorState = state as SlidingDoorState
	if door_state == null:
		return PathHookResult.proceed()
	door_state.motion.request(true)
	_draw(door_state)
	return PathHookResult.wait(open_seconds)

## Crossing waits for the door to be fully open.
func on_traverse(_pawn: PawnBase, _edge: PathComponent.PathTraversalEdgeData, _module: ModuleBase,
		state: RefCounted) -> PathHookResult:
	var door_state: SlidingDoorState = state as SlidingDoorState
	if door_state == null:
		return PathHookResult.proceed()
	var open_in: float = door_state.motion.request(true)
	_draw(door_state)
	return PathHookResult.wait(open_in)

func tick_state(state: RefCounted, delta: float) -> bool:
	var door_state: SlidingDoorState = state as SlidingDoorState
	if door_state == null or not door_state.motion.needs_tick():
		return false
	door_state.motion.tick(delta)
	_draw(door_state)
	return door_state.motion.needs_tick()

func save_state(state: RefCounted) -> Dictionary:
	var door_state: SlidingDoorState = state as SlidingDoorState
	return door_state.motion.to_dict() if door_state != null else {}

func load_state(state: RefCounted, data: Dictionary) -> void:
	var door_state: SlidingDoorState = state as SlidingDoorState
	if door_state == null:
		return
	door_state.motion.load_dict(data)
	_draw(door_state)

static func _draw(door_state: SlidingDoorState) -> void:
	var sprite_variant: Variant = door_state.door_sprite
	if not is_instance_valid(sprite_variant):
		return
	var door_sprite: AnimatedSprite2D = sprite_variant as AnimatedSprite2D
	if door_sprite.sprite_frames == null or not door_sprite.sprite_frames.has_animation(DOOR_ANIMATION):
		return
	door_sprite.animation = DOOR_ANIMATION
	door_sprite.frame = DoorMotion.frame_for(door_state.motion.openness,
		door_sprite.sprite_frames.get_frame_count(DOOR_ANIMATION))
