class_name Behavior_SlidingDoor
extends PathBehavior

@export var door_node_path: NodePath
@export var open_seconds: float = 0.4
	
func create_state(pc: PathComponent) -> RefCounted:
	var door: AnimatedSprite2D = pc.get_node(door_node_path)
	# Doors are a gameplay-blocking wait: play at sim speed, freeze on pause
	# (WI-20). The open_seconds hold below is already sim_seconds.
	Global.time_manager.sync_animation(door)
	door.animation_finished.connect(func() -> void:
		if door.frame != 0:
			await Global.time_manager.sim_seconds(open_seconds)
			set_door(door, false)
	)
	return null

func on_enter(pawn: PawnBase, door_index: int, meta: StringName, module: ModuleBase, next_node: Node2D, state: RefCounted) -> void:
	var door: AnimatedSprite2D = module.get_node(door_node_path)
	door.play("open")
	await Global.time_manager.sim_seconds(open_seconds)

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
