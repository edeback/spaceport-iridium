class_name Behavior_LinkedDoors
extends PathBehavior

class LinkedDoorsState:
	var door_sprites: Dictionary[StringName, AnimatedSprite2D] = {}

@export var doors: Dictionary[StringName, NodePath]
@export var open_seconds: float = 0.4

func create_state(pc: PathComponent) -> RefCounted:
	var state := LinkedDoorsState.new()
	for door_name in doors:
		var door_sprite: AnimatedSprite2D = pc.get_node(doors[door_name])
		state.door_sprites[door_name] = door_sprite
		# Automatically close the door after the timeout
		door_sprite.animation_finished.connect(func() -> void:
			if door_sprite.frame != 0:
				await pc.get_tree().create_timer(open_seconds).timeout
				_set_door(state, door_name, false)
		)
	return state

func _set_door(state: LinkedDoorsState, door_name: StringName, open: bool) -> void:
	var door_sprite_node := state.door_sprites[door_name]
	if door_sprite_node.is_playing():
		if door_sprite_node.get_playing_speed() > 0 and open or door_sprite_node.get_playing_speed() < 0 and not open:
			# In progress
			await door_sprite_node.animation_finished
			return
	if door_sprite_node.frame == 0 and not open:
		# Already closed
		return
	elif open and (door_sprite_node.frame == door_sprite_node.sprite_frames.get_frame_count(&"open") - 1):
		# Already open
		return
	# Start animation
	door_sprite_node.play(&"open", 1 if open else -1, not open)
	await door_sprite_node.animation_finished

func on_traverse(_pawn: PawnBase, path_edge: PathComponent.PathTraversalEdgeData, _module: ModuleBase, state: RefCounted) -> void:
	# Ensure other doors are closed
	for door_name in state.door_sprites:
		if door_name != path_edge.edge_meta:
			await _set_door(state, door_name, false)
	# Open this door
	await _set_door(state, path_edge.edge_meta, true)
