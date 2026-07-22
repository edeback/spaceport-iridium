@tool
class_name ModuleTurbolift
extends ModuleBase

var truss: ModuleData = preload("res://data/modules/core/truss_mdata.tres")

@export var collision_upper: CollisionShape2D
@export var collision_lower: CollisionShape2D
@export var door_sprite: AnimatedSprite2D

var shaft: TurboliftShaft
var open_requests: Array[RideRequest] = []

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
	# Door open/close is a gameplay-blocking wait: play it at sim speed (WI-20).
	Global.time_manager.sync_animation(door_sprite)
	door_sprite.animation_finished.connect(func() -> void:
		if door_sprite.frame != 0:
			await Global.time_manager.sim_seconds(2.0)
			set_door(true)
	)
	Global.turbolift_manager.add_turbolift_module(self)

func on_place() -> void:
	super()
	if Global.world_manager.get_module_by_cell(WorldManager.StructureLayer.MODULE, module_cell) == null:
		# add a truss segment below
		Global.world_manager.add_module(truss, module_cell)

func pre_delete() -> void:
	super()
	Global.turbolift_manager.remove_turbolift_module(self)

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

func get_save_data() -> Dictionary:
	var data: Dictionary = super()
	if not floor_enabled:
		data["floor_enabled"] = false
	return data

func load_save_data(data: Dictionary) -> void:
	super(data)
	floor_enabled = bool(data.get("floor_enabled", true))

## Walk the pawn to a claimed QUEUE spot in the corridor behind this floor
## (WI-16) - replaces the old position teleport. Falls back to a small random
## sidestep when there's no corridor or no free anchor: anchor scarcity must
## never block the ride.
func assign_waiting_slot(request: RideRequest) -> void:
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
	await pawn.walk_straight_to(dest)

func has_custom_pathing() -> bool:
	return true

func traverse(_pawn: PawnBase, _path_edge: PathComponent.PathTraversalEdgeData) -> void:
	pass

func path_enter(_pawn: PawnBase, _door: int, _meta: StringName, next_node: Node2D, cancel_signal: Signal) -> void:
	if next_node is ModuleTurbolift:
		pass
	pass
	
func path_exit(_pawn: PawnBase, _door: int, _meta: StringName, next_node: Node2D, cancel_signal: Signal) -> void:
	if next_node is ModuleTurbolift:
		# Awaits only through boarding (WI-20): on success the pawn comes back
		# Conveyed and the movement chain unwinds here; the cab drives the ride
		# and calls exit_conveyed at the drop-off floor, which repaths from there.
		var ride_request: RideRequest = await shaft.request_ride(_pawn, self, next_node, cancel_signal)
		if ride_request.cancelled:
			_pawn.movement_component.cancel()
	#if _meta == &"turbolift_door":
		#await set_door(false)
