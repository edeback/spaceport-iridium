@tool
class_name ModuleTeleporter
extends ModuleBase

@export var teleporter_path_index: int = 0
@export var lightning_sprite: AnimatedSprite2D

const LIGHTNING_ANIMATION: StringName = &"teleport"

## Sim-seconds left of the lightning flash a crossing plays, and which way it runs
## (WI-75 §4). `traverse` used to await the sprite's `animation_finished` twice
## with the pawn's movement suspended inside it; now the flash is this countdown,
## the pawn waits the same length as a state of its own, and a save carries both.
##
## The flash runs in sim time now, like the doors. It used to play at wall-clock
## speed - a 4x crossing took as long as a 1x one, and a paused game finished it -
## which was the one gameplay-blocking wait that did not follow the sim.
var _flash_left: float = 0.0
var _flash_backward: bool = false

func _ready() -> void:
	add_to_group(Groups.TELEPORTERS)
	Global.path_manager.graph.set_group_multiple("teleporters", 0.1)
	super()
	set_process(false)

func make_connections() -> void:
	super()
	Global.path_manager.change_vertex_group(self, "teleporters", teleporter_path_index)
	#var teleporter_node := Node2D.new()
	#add_child(teleporter_node)
	#get_path_component().path_points.get(teleporter_path_index)
	#teleporter_node.global_position = Vector2(get_path_component().path_points.get(teleporter_path_index)) + global_position
	#Global.path_manager.add_vertex(teleporter_node, false, "teleport")
	#Global.path_manager.add_connection(self, teleporter_node, 30)
	#get_path_component().manual_connection(teleporter_node, teleporter_path_index)

func has_custom_pathing() -> bool:
	return true

## Stepping onto the pad flashes forwards; arriving through it flashes the same
## animation backwards. Either way the pawn stands in it for the whole flash.
func traverse(_pawn: PawnBase, path_edge: PathComponent.PathTraversalEdgeData) -> PathHookResult:
	if path_edge.edge_meta != &"run_teleporter":
		return PathHookResult.proceed()
	var flash_seconds: float = _flash_seconds()
	if flash_seconds <= 0.0:
		return PathHookResult.proceed()
	_flash_left = flash_seconds
	_flash_backward = path_edge.start_index == teleporter_path_index
	_draw_flash()
	set_process(true)
	return PathHookResult.wait(flash_seconds)

func path_enter(pawn: PawnBase, door: int, meta: StringName, _next_node: Node2D) -> PathHookResult:
	if meta == &"teleporters" and door >= 0:
		pawn.global_position = global_position + Vector2(get_path_component().path_points[door])
	return PathHookResult.proceed()

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _flash_left <= 0.0:
		set_process(false)
		return
	var sim_delta: float = Global.time_manager.scale(delta)
	if sim_delta <= 0.0:
		return
	_flash_left = maxf(_flash_left - sim_delta, 0.0)
	_draw_flash()
	if _flash_left <= 0.0:
		set_process(false)

func _flash_seconds() -> float:
	if lightning_sprite == null:
		return 0.0
	return DoorMotion.animation_seconds(lightning_sprite.sprite_frames, LIGHTNING_ANIMATION)

## The flash drawn from the countdown rather than played, so it keeps sim time and
## a load puts it back on the right frame.
func _draw_flash() -> void:
	if lightning_sprite == null or lightning_sprite.sprite_frames == null:
		return
	if _flash_left <= 0.0:
		lightning_sprite.visible = false
		return
	var total: float = _flash_seconds()
	var count: int = lightning_sprite.sprite_frames.get_frame_count(LIGHTNING_ANIMATION)
	var frame_index: int = DoorMotion.frame_for(1.0 - _flash_left / total if total > 0.0 else 1.0, count)
	lightning_sprite.stop()
	lightning_sprite.animation = LIGHTNING_ANIMATION
	lightning_sprite.frame = count - 1 - frame_index if _flash_backward else frame_index
	lightning_sprite.visible = true

func get_save_data() -> Dictionary:
	var data: Dictionary = super()
	if _flash_left > 0.0:
		data["flash"] = {"left": _flash_left, "backward": _flash_backward}
	return data

func load_save_data(data: Dictionary) -> void:
	super(data)
	var flash: Dictionary = data.get("flash", {})
	_flash_left = maxf(float(flash.get("left", 0.0)), 0.0)
	_flash_backward = bool(flash.get("backward", false))
	_draw_flash()
	set_process(_flash_left > 0.0)

#func enter_module_from(pawn: PawnBase, _prev_module: ModuleBase = null) -> void:
	#super(pawn, _prev_module)
	#if _prev_module is ModuleTeleporter:
		#var new_position: Vector2 = global_position + Vector2(get_path_component().get_connection_point_from(_prev_module))
		#pawn.global_position = new_position
