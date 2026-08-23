class_name PreviewModule
extends Node2D

@onready var sprite: Sprite2D = $Sprite2D
@export var default_texture: Texture2D

const SHADER_PARAM_PLACEABLE = "PLACEABLE"

const CELL_CLEAR_COLOR: Color = Color(0.25, 1.0, 0.35, 0.22)
const CELL_BLOCKED_COLOR: Color = Color(1.0, 0.12, 0.12, 0.4)

## Static per-scene metadata the preview needs, read off one instantiation of a
## module scene (WI-42). Every field is authored in the .tscn and never varies
## at runtime — nothing in the codebase assigns ModuleData.scene, and unlocks
## flip unlocked_by_default rather than swapping scenes — so an entry can't go
## stale once built.
class ModulePreviewData extends RefCounted:
	var module_size: Vector2i
	var connection_points: Array[Vector2i]
	var internal_points: Array[Vector2i]
	var must_be_clear_points: Array[Vector2i]
	## ModuleBase.offset node position, not the sprite's.
	var module_offset: Vector2
	var texture: Texture2D
	var sprite_offset: Vector2
	var region_enabled: bool
	var region_rect: Rect2
	var sprite_transform: Transform2D
	var flip_h: bool
	var flip_v: bool

	static func from_scene(scene: PackedScene) -> ModulePreviewData:
		var data := ModulePreviewData.new()
		var temp_module: ModuleBase = scene.instantiate() as ModuleBase
		var structure: StructureComponent = temp_module.get_structure_component()
		var temp_sprite: Sprite2D = temp_module.get_sprite()
		# Every buildable module is expected to carry all three; the pre-cache
		# code read them unguarded, so this only makes the assumption loud.
		assert(structure != null, "Module scene has no StructureComponent: " + scene.resource_path)
		assert(temp_module.offset != null, "Module scene has no offset node wired: " + scene.resource_path)
		assert(temp_sprite != null, "Module scene has no sprite wired: " + scene.resource_path)
		data.module_size = temp_module.size
		data.connection_points = structure.connection_points
		data.internal_points = structure.internal_points
		data.must_be_clear_points = structure.must_be_clear_points
		data.module_offset = temp_module.offset.position
		data.texture = temp_sprite.texture
		data.sprite_offset = temp_sprite.offset
		data.region_enabled = temp_sprite.region_enabled
		data.region_rect = temp_sprite.region_rect
		data.sprite_transform = temp_sprite.transform
		data.flip_h = temp_sprite.flip_h
		data.flip_v = temp_sprite.flip_v
		temp_module.queue_free()
		return data

## Lazily populated preview metadata, keyed by PackedScene rather than by
## ModuleData: a flippable module's flipped_scene has genuinely different
## geometry, and keying on the scene distinguishes the two for free. Owned by
## the node (not a static) so it dies with the scene instead of holding every
## previewed PackedScene alive across a Quit-to-Menu boundary. Multiplacement
## duplicates share this dictionary by reference, which is exactly what we want.
var _preview_cache: Dictionary[PackedScene, ModulePreviewData] = {}

## Per-cell validity from the last update_placeable(): local footprint cell
## (including must_be_clear points) -> clear. Drawn by _cell_overlay, which
## sits after the sprite in tree order so the tint renders on top of it.
var _cell_states: Dictionary[Vector2i, bool] = {}
var _cell_overlay: Node2D

var module_size: Vector2i
var connection_points: Array[Vector2i]
var internal_points: Array[Vector2i]
var must_be_clear_points: Array[Vector2i]
var module_layer: WorldManager.StructureLayer
var module_connection_layer: WorldManager.StructureLayer
var last_cell: Vector2i
var offset: Vector2 = Vector2(0, 0)

var module_data: ModuleData:
	get:
		return module_data
	set(new_value):
		if module_data != new_value:
			module_data = new_value
			if module_data == null:
				sprite.texture = default_texture
				sprite.visible = false
			else:
				update_from_module_data()

var flipped: bool:
	set(new_value):
		if flipped != new_value:
			flipped = new_value
			update_from_module_data()

var can_place: bool = true:
	get:
		return can_place
	set(new_value):
		if can_place != new_value:
			can_place = new_value
			_update_shader()

## The three verdicts behind can_place, kept apart rather than folded together on
## the spot because multiplacement re-decides the third one for a whole drag at
## once (see [MultiplacementPlan]) while reusing the other two exactly as they are.
var affordable: bool = true
var footprint_clear: bool = true
var world_connected: bool = true

func update_from_module_data() -> void:
	# The flipped setter reaches here too, and flip_module is bindable with no
	# module selected - nothing to preview in that case.
	if module_data == null:
		return
	var temp_scene: PackedScene =  module_data.scene
	if flipped and module_data.flippable:
		temp_scene = module_data.flipped_scene
	var preview_data: ModulePreviewData = _preview_data_for(temp_scene)
	module_size = preview_data.module_size
	# The point arrays are shared with every other preview of this scene; they
	# are only ever read, never mutated.
	connection_points = preview_data.connection_points
	internal_points = preview_data.internal_points
	must_be_clear_points = preview_data.must_be_clear_points
	module_layer = module_data.interaction_layer
	module_connection_layer = module_data.connection_layer
	sprite.texture = preview_data.texture
	sprite.offset = preview_data.sprite_offset
	sprite.region_enabled = preview_data.region_enabled
	sprite.region_rect = preview_data.region_rect
	sprite.transform = preview_data.sprite_transform
	sprite.centered = true
	sprite.visible = true
	sprite.flip_h = preview_data.flip_h
	sprite.flip_v = preview_data.flip_v
	offset = preview_data.module_offset
	%ErrorLabel.position.x = -offset.x
	%ErrorLabel.position.y = -offset.y - 32

## Cached geometry for one module scene, built on first sight. Multiplacement
## duplicates share the dictionary by reference, and the truss a corridor drag
## backfills is looked up through here too rather than instantiated per drag.
func _preview_data_for(scene: PackedScene) -> ModulePreviewData:
	var preview_data: ModulePreviewData = _preview_cache.get(scene)
	if preview_data == null:
		preview_data = ModulePreviewData.from_scene(scene)
		_preview_cache[scene] = preview_data
	return preview_data

func _update_shader() -> void:
	if (sprite && sprite.material != null):
		sprite.material.set_shader_parameter(SHADER_PARAM_PLACEABLE, can_place)


func update_placeable(module_cell: Vector2i) -> void:
	last_cell = module_cell
	# flip_module is bindable with nothing selected and revalidates on the spot,
	# which reaches here with no module to judge (and used to crash on the cost
	# check). The preview is hidden in that state, so there is nothing to light.
	if module_data == null:
		return
	if Global.world_manager.debug_build_anything:
		affordable = true
		footprint_clear = true
		world_connected = true
		_show_verdict(true, true)
		return
	# Order matters only for which reason gets named: cost, then footprint, then
	# the neighbour test.
	footprint_clear = not _update_cell_states(module_cell)
	affordable = module_data.can_afford()
	world_connected = has_world_connection(module_cell)
	_show_verdict(world_connected, true)

## Multiplacement's answer to the connection question, standing in for the live
## neighbour test: a module in the middle of a drag is held up by the ones queued
## in front of it, which do not exist yet. `show_reason` is spent on the first
## refusal in the drag only - the cut is what the player needs named, and thirty
## stacked labels down a corridor line name nothing.
func apply_drag_verdict(connected: bool, show_reason: bool) -> void:
	_show_verdict(connected, show_reason)

func _show_verdict(connected: bool, show_reason: bool) -> void:
	can_place = affordable and footprint_clear and connected
	%ErrorLabel.visible = not can_place and show_reason
	if not affordable:
		%ErrorLabel.text = "Can't afford!"
	elif not footprint_clear:
		%ErrorLabel.text = "Blocked!"
	elif not connected:
		%ErrorLabel.text = "Not connected to anything!"

## Recompute per-cell validity for the footprint at module_cell. Returns true
## if any cell is blocked (the whole-placement answer the caller needs).
func _update_cell_states(module_cell: Vector2i) -> bool:
	_cell_states.clear()
	var any_blocked: bool = false
	for x: int in module_size.x:
		for y: int in module_size.y:
			var local_cell := Vector2i(x, y)
			var clear: bool = not Global.world_manager.is_blocked(module_layer, module_cell + local_cell)
			_cell_states[local_cell] = clear
			any_blocked = any_blocked or not clear
	# must_be_clear cells fail on ANY overlap, not just building-blockers.
	for point: Vector2i in must_be_clear_points:
		var clear: bool = not Global.world_manager.has_overlaps(module_layer, module_cell + point)
		_cell_states[point] = _cell_states.get(point, true) and clear
		any_blocked = any_blocked or not clear
	if _cell_overlay != null:
		_cell_overlay.queue_redraw()
	return any_blocked

func _draw_cell_overlay() -> void:
	if module_data == null or not visible:
		return
	for local_cell: Vector2i in _cell_states:
		var rect := Rect2(Vector2(local_cell * Global.CELL_SIZE) - offset, Vector2(Global.CELL_SIZE))
		_cell_overlay.draw_rect(rect, CELL_CLEAR_COLOR if _cell_states[local_cell] else CELL_BLOCKED_COLOR)

## Would a module of this type at `module_cell` be touching built structure right
## now? Public because multiplacement asks it twice: once per candidate while the
## drag is on screen, and again between placements, when the modules it built a
## moment ago are the answer.
func has_world_connection(module_cell: Vector2i) -> bool:
	# Explicit connection points
	for point in connection_points:
		var test_module: ModuleBase = Global.world_manager.get_module_by_cell(module_connection_layer, module_cell + point)
		if test_module != null:
			var struct_component: StructureComponent = test_module.get_structure_component()
			if struct_component != null:
				for internal_point in internal_points:
					if struct_component.can_connect_to(module_cell + internal_point):
						return true
	return false

## This module's drag geometry: its own footprint, plus everything a placed copy
## leaves in the world for the next module in the line to connect to. That second
## part is not always the module itself - a corridor lands on the CORRIDOR layer
## but connects through the MODULE layer, so a dragged corridor line is chained
## together by the truss each corridor backfills under itself.
func multiplacement_placement() -> MultiplacementPlan.Placement:
	var placement := MultiplacementPlan.Placement.new()
	placement.size = module_size
	placement.connection_points = connection_points
	placement.internal_points = internal_points
	placement.connection_layer = module_connection_layer
	placement.provisions.append(MultiplacementPlan.Provision.new(
		module_layer, Vector2i.ZERO, module_size, connection_points, internal_points))
	var backfill: ModuleData = Global.world_manager.replacement_module
	if backfill == null or backfill.scene == null:
		return placement
	var backfill_data: ModulePreviewData = _preview_data_for(backfill.scene)
	for point: Vector2i in ModuleBase.backfill_points(module_layer, internal_points):
		placement.provisions.append(MultiplacementPlan.Provision.new(
			backfill.interaction_layer, point, backfill_data.module_size,
			backfill_data.connection_points, backfill_data.internal_points))
	return placement

func _ready() -> void:
	sprite.texture = default_texture
	if (sprite && sprite.material != null):
		sprite.material = sprite.material.duplicate()
	# The scene authors PLACEABLE = false while can_place defaults to true, and
	# the setter only pushes the parameter when the value *changes* - so without
	# this a preview that is placeable from its first frame draws refused-red.
	# Multiplacement duplicates ready here too, which is where it showed: a copy
	# whose verdict matches the one it was duplicated with never fires the setter.
	_update_shader()
	# Overlay node added last so per-cell tints draw over the sprite; a plain
	# Node2D can't override _draw, so hook its draw signal instead. Multiplace
	# duplicates this whole node (overlay child and remapped connection
	# included), so reuse a cloned overlay rather than stacking a second one.
	_cell_overlay = get_node_or_null("CellOverlay")
	if _cell_overlay == null:
		_cell_overlay = Node2D.new()
		_cell_overlay.name = "CellOverlay"
		add_child(_cell_overlay)
		_cell_overlay.draw.connect(_draw_cell_overlay)
