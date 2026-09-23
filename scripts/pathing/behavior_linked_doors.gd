class_name Behavior_LinkedDoors
extends PathBehavior

## An airlock's pair of doors: crossing one shuts every other first, then opens
## it, so the station is never open to vacuum.
##
## Each door is a [DoorMotion] ticked by the owning [PathComponent] (WI-75 §3).
## They used to be their sprites' playback, driven by `await animation_finished`
## and closed again by an `animation_finished` lambda awaiting `sim_seconds` -
## which resumed on a freed sprite if the airlock was destroyed during the hold,
## and could not be saved at all. The timing is the same: a door swings in its
## animation's length at sim speed, stands open for [member open_seconds], then
## shuts itself.

class LinkedDoorsState:
	var door_sprites: Dictionary[StringName, AnimatedSprite2D] = {}
	var motions: Dictionary[StringName, DoorMotion] = {}

@export var doors: Dictionary[StringName, NodePath]
## How long a door stands fully open before shutting itself.
@export var open_seconds: float = 0.4

const DOOR_ANIMATION: StringName = &"open"

func create_state(pc: PathComponent) -> RefCounted:
	var state := LinkedDoorsState.new()
	for door_name: StringName in doors:
		var door_sprite: AnimatedSprite2D = pc.get_node(doors[door_name]) as AnimatedSprite2D
		if door_sprite == null:
			continue
		# The sprite only draws the door now, so it never plays on its own.
		door_sprite.stop()
		state.door_sprites[door_name] = door_sprite
		state.motions[door_name] = DoorMotion.make(
			DoorMotion.animation_seconds(door_sprite.sprite_frames, DOOR_ANIMATION), open_seconds)
		_draw(door_sprite, state.motions[door_name])
	return state

## Every other door shuts, one after another, and then this one opens - the order
## the awaits used to run in. The pawn waits for all of it.
func on_traverse(_pawn: PawnBase, path_edge: PathComponent.PathTraversalEdgeData, _module: ModuleBase,
		state: RefCounted) -> PathHookResult:
	var doors_state: LinkedDoorsState = state as LinkedDoorsState
	if doors_state == null or not doors_state.motions.has(path_edge.edge_meta):
		return PathHookResult.proceed()
	var ready_in: float = 0.0
	for door_name: StringName in doors_state.motions:
		if door_name != path_edge.edge_meta:
			ready_in = doors_state.motions[door_name].request(false, ready_in)
	var open_in: float = doors_state.motions[path_edge.edge_meta].request(true, ready_in)
	_draw_all(doors_state)
	return PathHookResult.wait(open_in)

func tick_state(state: RefCounted, delta: float) -> bool:
	var doors_state: LinkedDoorsState = state as LinkedDoorsState
	if doors_state == null:
		return false
	var moving: bool = false
	for door_name: StringName in doors_state.motions:
		var motion: DoorMotion = doors_state.motions[door_name]
		if not motion.needs_tick():
			continue
		motion.tick(delta)
		_draw(doors_state.door_sprites.get(door_name), motion)
		moving = moving or motion.needs_tick()
	return moving

func save_state(state: RefCounted) -> Dictionary:
	var doors_state: LinkedDoorsState = state as LinkedDoorsState
	var out: Dictionary = {}
	if doors_state == null:
		return out
	for door_name: StringName in doors_state.motions:
		var block: Dictionary = doors_state.motions[door_name].to_dict()
		if not block.is_empty():
			out[String(door_name)] = block
	return out

func load_state(state: RefCounted, data: Dictionary) -> void:
	var doors_state: LinkedDoorsState = state as LinkedDoorsState
	if doors_state == null:
		return
	for key: String in data:
		var door_name := StringName(key)
		if doors_state.motions.has(door_name):
			doors_state.motions[door_name].load_dict(data[key])
	_draw_all(doors_state)

func _draw_all(doors_state: LinkedDoorsState) -> void:
	for door_name: StringName in doors_state.motions:
		_draw(doors_state.door_sprites.get(door_name), doors_state.motions[door_name])

## Takes the sprite as Variant (WI-71): it is read out of a stored dictionary, and
## a typed Object parameter would error at the call on a freed one.
static func _draw(sprite_variant: Variant, motion: DoorMotion) -> void:
	if not is_instance_valid(sprite_variant):
		return
	var door_sprite: AnimatedSprite2D = sprite_variant as AnimatedSprite2D
	if door_sprite == null or door_sprite.sprite_frames == null \
			or not door_sprite.sprite_frames.has_animation(DOOR_ANIMATION):
		return
	door_sprite.animation = DOOR_ANIMATION
	door_sprite.frame = DoorMotion.frame_for(motion.openness,
		door_sprite.sprite_frames.get_frame_count(DOOR_ANIMATION))
