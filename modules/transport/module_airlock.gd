@tool
class_name AirlockModule
extends ModuleBase

@export var airlock: Dictionary[StringName, AnimatedSprite2D]

var airlock_resetting: bool = false
signal airlock_reset

func _ready() -> void:
	super()
	for airlock_name: StringName in airlock:
		var door_sprite: AnimatedSprite2D = airlock[airlock_name]
		door_sprite.animation_finished.connect(func() -> void:
			if door_sprite.frame != 0:
				await get_tree().create_timer(2).timeout
				set_airlock(airlock_name, true)
		)

func has_custom_pathing() -> bool:
	return true
	
func set_airlock(airlock_name: StringName, is_close: bool) -> void:
	var anim_sprite: AnimatedSprite2D = airlock[airlock_name]
	if anim_sprite.is_playing():
		if anim_sprite.get_playing_speed() > 0 and not is_close or anim_sprite.get_playing_speed() < 0 and is_close:
			# In progress
			print(("Closing " if is_close else "Opening ") + airlock_name + " but it's already being opened")
			await anim_sprite.animation_finished
			return
	if anim_sprite.frame == 0 and is_close:
		# Already closed
		print("Closing " + airlock_name + " but it's already closed")
		return
	elif not is_close and (anim_sprite.frame == anim_sprite.sprite_frames.get_frame_count(&"open") - 1):
		# Already open
		print("Opening " + airlock_name + " but it's already open")
		return
	print("Starting animation to " + ("close " if is_close else "open ") + airlock_name)
	anim_sprite.play(&"open", -1 if is_close else 1, is_close)
	await anim_sprite.animation_finished
	
func wait_for_airlocks(outer_closed: bool, inner_closed: bool) -> void:
	set_airlock(&"outer_airlock", outer_closed) 
	set_airlock(&"inner_airlock", inner_closed) 
	var inner_sprite: AnimatedSprite2D = airlock[&"inner_airlock"]
	if inner_sprite.is_playing():
		await inner_sprite.animation_finished
	var outer_sprite: AnimatedSprite2D = airlock[&"outer_airlock"]
	if outer_sprite.is_playing():
		await outer_sprite.animation_finished

func traverse(path_edge: PathComponent.PathTraversalEdgeData) -> void:
	if path_edge.edge_meta == "inner_airlock":
		await set_airlock(&"outer_airlock", true)
		await set_airlock(&"inner_airlock", false)
	elif path_edge.edge_meta == "outer_airlock":
		await set_airlock(&"inner_airlock", true)
		await set_airlock(&"outer_airlock", false)
	pass
	# Ensure all closed
	# Travel 0-1
	# Wait at 1 if queue
	# Open inner
	# Travel 1-2
	# Close inner
	# Open outer
	# Travel 2-3
	# Let pawn continue
	# Close outer as pawn leaves
