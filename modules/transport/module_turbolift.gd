@tool
class_name ModuleTurbolift
extends ModuleBase

var truss: ModuleData = preload("res://data/modules/core/truss_mdata.tres")

@export var collision_upper: CollisionShape2D
@export var collision_lower: CollisionShape2D
@export var door_sprite: AnimatedSprite2D

func _ready() -> void:
	add_to_group("turbolifts")
	super()
	SignalBus.module_added.connect(set_sprite)
	SignalBus.module_removed.connect(set_sprite)
	get_path_component().door_connected.connect(door_connected)
	get_path_component().door_disconnected.connect(door_disconnected)
	set_sprite(null)
	door_sprite.animation_finished.connect(func() -> void:
		if door_sprite.frame != 0:
			await get_tree().create_timer(2).timeout
			set_door(true)
	)

func on_place() -> void:
	super()
	if Global.world_manager.get_module_by_cell(WorldManager.StructureLayer.MODULE, module_cell) == null:
		# add a truss segment below
		Global.world_manager.add_module(truss, module_cell)

func on_select(new_selected: bool) -> void:
	super(new_selected)
	#if new_selected:
		#Global.ui_in_game.change_input_mode(UIInGame.InputMode.Turbolift)
	#else:
		#Global.ui_in_game.change_input_mode(UIInGame.InputMode.None)
	
func door_connected(_cell: Vector2i, _from_layer: WorldManager.StructureLayer) -> void:
	door_sprite.visible = true
	
func door_disconnected(_cell: Vector2i, _from_layer: WorldManager.StructureLayer) -> void:
	door_sprite.visible = false
	
func set_sprite(_module: ModuleBase) -> void:
	if _module == null or _module is ModuleTurbolift or _module is CorridorModule:
		#if Global.world_manager.get_module_by_cell(WorldManager.StructureLayer.CORRIDOR, module_cell) == null:
			## No corridor behind, this is just a shaft
			#sprite.region_rect.position.x = Global.CELL_SIZE.x * 2
			#collision_upper.disabled = false
		#else:
		var image_select: int = 0
		if Global.world_manager.get_module_by_cell(WorldManager.StructureLayer.TURBOLIFT, module_cell + Vector2i(0, -1)) is ModuleTurbolift:
			# There is a turbolift above this
			collision_upper.disabled = false
			image_select += 1
		else:
			collision_upper.disabled = false
		if Global.world_manager.get_module_by_cell(WorldManager.StructureLayer.TURBOLIFT, module_cell + Vector2i(0, 1)) is ModuleTurbolift:
			# There is a turbolift below
			sprite.region_rect.position.x = 0
			collision_lower.disabled = false
			image_select += 2
		else:
			collision_lower.disabled = true
		sprite.region_rect.position.x = Global.CELL_SIZE.x * image_select
			
		queue_redraw()

func set_door(is_close: bool) -> void:
	var anim_sprite: AnimatedSprite2D = door_sprite
	if anim_sprite.is_playing():
		if anim_sprite.get_playing_speed() > 0 and not is_close or anim_sprite.get_playing_speed() < 0 and is_close:
			# In progress
			print(("Closing " if is_close else "Opening ") + "turbolift but it's already being opened")
			await anim_sprite.animation_finished
			return
	if anim_sprite.frame == 0 and is_close:
		# Already closed
		print("Closing " + "turbolift but it's already closed")
		return
	elif not is_close and (anim_sprite.frame == anim_sprite.sprite_frames.get_frame_count(&"open") - 1):
		# Already open
		print("Opening " + "turbolift but it's already open")
		return
	print("Starting animation to " + ("close " if is_close else "open ") + "turbolift")
	anim_sprite.play(&"open", -1 if is_close else 1, is_close)
	await anim_sprite.animation_finished

func has_custom_pathing() -> bool:
	return true

func traverse(_pawn: PawnBase, _path_edge: PathComponent.PathTraversalEdgeData) -> void:
	if _path_edge.edge_meta == &"board_turbolift":
		if _path_edge.start_index == 3:
			# 3 -> 2 enters lift
			_pawn.traverse_turbolift(true)
		else:
			# must be exiting lift
			_pawn.traverse_turbolift(false)

func path_enter(_pawn: PawnBase, _door: int, _meta: StringName) -> void:
	if _meta == &"turbolift_door":
		await set_door(false)
	
func path_exit(_pawn: PawnBase, _door: int, _meta: StringName, next_node: Node2D = null) -> void:
	if _meta == &"turbolift_door":
		await set_door(false)
