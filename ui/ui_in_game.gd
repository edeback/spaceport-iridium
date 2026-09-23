class_name UIInGame
extends Control

@onready var selector: Node2D = $Selector
@onready var preview_module: PreviewModule = $Selector/PreviewModule

var debug_path_position: PackedVector2Array:
	set(new_path):
		debug_path_position = new_path
		queue_redraw()
		
## No Turbolift mode any more (WI-68 F7): it was never entered, and its one branch
## called a TurboliftManager method that does not exist - which only the
## typed-warning census could see.
enum InputMode {None, Module, Structure, Multiplace}

signal input_mode_changed(new_mode: InputMode)

var cur_input_mode: InputMode = InputMode.None
var cur_module: ModuleData = null

var multiplace_start: Vector2i
var preview_multimodules: Array[PreviewModule] = []
## Indices into preview_multimodules that the drag actually builds, in the order
## they have to be built (see [MultiplacementPlan]). Recomputed whenever the drag
## changes shape, so it is never read stale.
var multiplace_order: PackedInt32Array = PackedInt32Array()

var last_hovered_cell: Vector2i

## Selection brackets (WI-10). Two instances, but no longer because two info
## panels can be open at once - under one inspector (WI-51) exactly one thing is
## selected, so only one set is ever live. They stay separate because they are
## driven from different places: module brackets off [ModuleBase.selected], pawn
## brackets off the inspector via [method set_selected_pawn]. A single shared
## instance would have to know which of the two raised it.
var module_brackets: SelectionBrackets
var pawn_brackets: SelectionBrackets

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.ui_in_game = self
	module_brackets = SelectionBrackets.new()
	add_child(module_brackets)
	pawn_brackets = SelectionBrackets.new()
	pawn_brackets.padding = 0
	add_child(pawn_brackets)
	SignalBus.module_selected.connect(_on_module_selected)
	# The multi-select path preview is PathManager's to compute and ours to draw
	# (WI-74 §3, F33): we listen, it never reaches for us. Managers ready first.
	if Global.path_manager != null:
		Global.path_manager.debug_path_changed.connect(queue_redraw)

## Hands the slot back (WI-71 §7). Godot 4.7 reports a freed object as `== null`,
## so the guards around the game already take their null branch after a Quit to
## Menu - but `is_instance_valid(Global.ui_in_game)` and the debugger both lie until
## the slot is actually cleared. `== self` because a second scene can register
## before this one leaves.
func _exit_tree() -> void:
	if Global.ui_in_game == self:
		Global.ui_in_game = null

## ModuleBase.selected emits on every change, select and deselect alike.
func _on_module_selected(module: ModuleBase) -> void:
	if module.selected:
		module_brackets.show_around(module, Rect2(Vector2.ZERO, Vector2(module.size * Global.CELL_SIZE)))
	else:
		module_brackets.clear_if_target(module)

## Points the pawn brackets at `pawn`, or clears them for null - which is what
## selecting a module, an asteroid, a pile or nothing at all passes.
##
## The one caller reads the inspector's subject the moment it changes, and the
## inspector clears itself the frame its subject dies - live or null (WI-71 §2c).
func set_selected_pawn(pawn: PawnBase) -> void:
	if pawn == null:
		pawn_brackets.clear()
		return
	pawn_brackets.show_around(pawn, _pawn_bracket_rect(pawn))

## The pawn's sprite footprint in its own local space, so the brackets frame the
## art rather than a nominal cell. Falls back to a sensible box for a pawn whose
## sprite frames have not loaded.
func _pawn_bracket_rect(pawn: PawnBase) -> Rect2:
	if pawn.animated_sprite != null and pawn.animated_sprite.sprite_frames != null:
		var frame_texture: Texture2D = pawn.animated_sprite.sprite_frames.get_frame_texture(
			pawn.animated_sprite.animation, pawn.animated_sprite.frame)
		if frame_texture != null:
			var sprite_size: Vector2 = frame_texture.get_size() * pawn.animated_sprite.scale
			return Rect2(Vector2(-sprite_size.x / 2.0, -sprite_size.y), sprite_size)
	return Rect2(Vector2(-16, -24), Vector2(32, 48))

func change_input_mode(mode: InputMode, module: ModuleData = null) -> void:
	#Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	# Changing mode with the mouse still held cancels the drag. Nothing else can:
	# the drag previews are children of this node, and finalize is only reached on
	# button release in Multiplace mode - so right-clicking (or Esc, or picking
	# another module) mid-drag used to leave the whole ghost line on screen until
	# some later drag happened to reuse the array.
	drop_multiplacement_previews()
	cur_input_mode = mode
	cur_module = module
	preview_module.module_data = module
	input_mode_changed.emit(mode)
	preview_module.visible = module != null
	# The master preview was last judged wherever the drag started, so revalidate
	# rather than waiting for the cursor to cross into a new cell.
	if module != null:
		update_module_placement(true)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.is_action_pressed("build"):
			if cur_module != null and preview_module != null and preview_module.can_place:
				if cur_module.multiplacement != WorldManager.Multiplacement.NONE:
					preview_module.visible = false
					cur_input_mode = InputMode.Multiplace
					# The cell the preview was judged on, not the raw one under the
					# cursor: the two only agree for a module whose offset centres it.
					multiplace_start = preview_module.last_cell
				else:
					Global.world_manager.purchase_and_add_module(cur_module, preview_module.last_cell, preview_module.flipped)
					update_module_placement(true)
				get_viewport().set_input_as_handled()
		if event.is_action_pressed("remove"):
				if cur_input_mode != InputMode.None:
					change_input_mode(InputMode.None)
					get_viewport().set_input_as_handled()
	if event is InputEventKey:
		if event.is_action_pressed("flip_module"):
			preview_module.flipped = not preview_module.flipped
			# The flipped variant has its own structure points - revalidate now
			# rather than waiting for the mouse to move to a new cell.
			update_module_placement(true)
		if event.is_action_pressed("show_details"):
			get_tree().call_group(Groups.MODULE, "show_label")
		if event.is_action_released("show_details"):
			get_tree().call_group(Groups.MODULE, "hide_label")
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	match cur_input_mode:
		InputMode.None:
			pass
		InputMode.Module:
			update_module_placement()
		InputMode.Structure:
			update_structure_placement()
		InputMode.Multiplace:
			update_multiplacement()
			if Input.is_action_just_released("build"):
				finalize_multiplacement()
				
			
## Where the cursor is; [method lay_out_multiplacement] is what that means.
func update_multiplacement() -> void:
	var hovered_cell: Vector2i = Global.world_to_cell(get_global_mouse_position() - preview_module.offset + Vector2(Global.CELL_SIZE) / 2)
	if last_hovered_cell == hovered_cell and preview_multimodules.size() > 0:
		return
	last_hovered_cell = hovered_cell
	lay_out_multiplacement(hovered_cell)

## Lay the drag out, judge it as a whole, and light each preview by the answer.
## Per-cell judgement is only half of it: a cell the world refuses cuts the line,
## and everything past the cut has nothing holding it up - which is how a drag
## across the docking bay's approach lane used to leave an island floating beside
## the station. [MultiplacementPlan] resolves the chain; the previews report it.
##
## Takes the cell rather than reading the cursor, which is also the only way to
## exercise a drag headlessly.
func lay_out_multiplacement(hovered_cell: Vector2i) -> void:
	var cells: Array[Vector2i] = MultiplacementPlan.drag_cells(multiplace_start, hovered_cell, cur_module.multiplacement)
	while preview_multimodules.size() < cells.size():
		preview_multimodules.append(preview_module.duplicate())
		add_child(preview_multimodules.back())
	while preview_multimodules.size() > cells.size():
		var spare: PreviewModule = preview_multimodules.pop_back()
		if spare != null:
			remove_child(spare)
			spare.queue_free()
	var blocked: Array[bool] = []
	var anchored: Array[bool] = []
	blocked.resize(cells.size())
	anchored.resize(cells.size())
	for index: int in cells.size():
		var previewmod: PreviewModule = preview_multimodules[index]
		previewmod.visible = true
		previewmod.position = Global.cell_to_world(cells[index]) + preview_module.offset
		previewmod.module_data = preview_module.module_data
		previewmod.update_placeable(cells[index])
		blocked[index] = not (previewmod.affordable and previewmod.footprint_clear)
		anchored[index] = previewmod.world_connected
	# One drag places one module type, so the links between candidates are the
	# same everywhere down the line and are worked out once.
	multiplace_order = MultiplacementPlan.resolve(cells, blocked, anchored,
		MultiplacementPlan.link_offsets(preview_module.multiplacement_placement()))
	var buildable: Dictionary[int, bool] = {}
	for index: int in multiplace_order:
		buildable[index] = true
	var reason_shown: bool = false
	for index: int in cells.size():
		var previewmod: PreviewModule = preview_multimodules[index]
		previewmod.apply_drag_verdict(buildable.has(index), not reason_shown)
		reason_shown = reason_shown or not previewmod.can_place

## Build what the drag resolved to, in the order it resolved.
func finalize_multiplacement() -> void:
	for index: int in multiplace_order:
		var mod: PreviewModule = preview_multimodules[index]
		if mod == null or not mod.can_place:
			continue
		# Re-ask the connection question against the world the last placement just
		# changed. The plan guarantees this module lands beside another one in the
		# drag, so if that one failed - the credits ran out partway down the line -
		# this one has nothing to hold onto and has to fail with it.
		if not Global.world_manager.debug_build_anything and not mod.has_world_connection(mod.last_cell):
			continue
		Global.world_manager.purchase_and_add_module(cur_module, mod.last_cell)
	drop_multiplacement_previews()
	cur_input_mode = InputMode.Module
	update_module_placement(true)
	preview_module.visible = true

## Take the drag off the screen without building any of it.
func drop_multiplacement_previews() -> void:
	for mod: PreviewModule in preview_multimodules:
		if mod != null:
			mod.queue_free()
	multiplace_order = PackedInt32Array()
	preview_multimodules.clear()

func update_module_placement(force: bool = false) -> void:
	if preview_module != null:
		var hovered_cell: Vector2i = Global.world_to_cell(get_global_mouse_position() - preview_module.offset + Vector2(Global.CELL_SIZE) / 2)
		if hovered_cell != last_hovered_cell or force:
			preview_module.update_placeable(hovered_cell)
		# Always grid-snap, even when invalid: the per-cell blocked overlay is
		# only meaningful if the preview sits on the cells being judged.
		selector.position = Global.cell_to_world(hovered_cell) + preview_module.offset
		last_hovered_cell = hovered_cell

func update_structure_placement() -> void:
	pass

func _draw() -> void:	 		
	var last_point: Variant = null
	var debug_path_cell: PackedVector2Array = Global.path_manager.debug_path if Global.path_manager != null else PackedVector2Array()
	for next_point in debug_path_cell:
		if last_point == null:
			last_point = next_point
			continue
		draw_line(last_point * Vector2(Global.CELL_SIZE) + Vector2(32, 32), next_point * Vector2(Global.CELL_SIZE)+ Vector2(32, 32), Color.LAWN_GREEN, 2.5, true) 
		last_point = next_point
	last_point = null
	for next_point in debug_path_position:
		if last_point == null:
			last_point = next_point
			continue
		draw_line(last_point, next_point, Color.AQUA, 1, true) 
		last_point = next_point
