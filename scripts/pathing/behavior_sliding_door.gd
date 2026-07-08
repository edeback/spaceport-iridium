class_name Behavior_SlidingDoor
extends PathBehavior

@export var door_node_path: NodePath
@export var open_seconds: float = 0.4
	
func create_state(pc: PathComponent) -> RefCounted:
	var door: AnimatedSprite2D = pc.get_node(door_node_path)
	door.animation_finished.connect(func() -> void:
		if door.frame != 0:
			await pc.get_tree().create_timer(open_seconds).timeout
			set_door(door, false)
	)
	return null
	
func on_enter(pawn: PawnBase, door_index: int, meta: StringName, module: ModuleBase, next_node: Node2D, state: RefCounted) -> void:
	var door: AnimatedSprite2D = module.get_node(door_node_path)
	door.play("open")
	await module.get_tree().create_timer(open_seconds).timeout

func set_door(door: AnimatedSprite2D, open: bool) -> void:
	if door.is_playing():
		if door.get_playing_speed() > 0 and open or door.get_playing_speed() < 0 and not open:
			# In progress
			#print(("Closing " if is_close else "Opening ") + airlock_name + " but it's already being opened")
			await door.animation_finished
			return
	if door.frame == 0 and not open:
		# Already closed
		#print("Closing " + airlock_name + " but it's already closed")
		return
	elif open and (door.frame == door.sprite_frames.get_frame_count(&"open") - 1):
		# Already open
		#print("Opening " + airlock_name + " but it's already open")
		return
	#print("Starting animation to " + ("close " if is_close else "open ") + airlock_name)
	door.play(&"open", 1 if open else -1, not open)
	await door.animation_finished
	

func on_traverse(pawn: PawnBase, edge: PathComponent.PathTraversalEdgeData, module: ModuleBase, state: RefCounted) -> void:
	var door: AnimatedSprite2D = module.get_path_component().get_node(door_node_path)
	await set_door(door, true)
