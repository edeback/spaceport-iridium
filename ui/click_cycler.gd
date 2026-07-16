class_name ClickCycler
extends RefCounted

## Click arbiter for stacked cells (WI-10). Physics picking delivers the same
## click to every overlapping footprint (corridor + turbolift + module can all
## occupy one cell), so first dedupe per physics frame, then let repeated
## clicks on the same cell step through the stack instead of fighting over it.

var _last_cell: Vector2i = Vector2i.MAX
var _cycle_index: int = 0
var _last_click_frame: int = -1

## Returns the module whose info should open for this click, or null when this
## click was already arbitrated this frame (a lower stacked footprint firing
## for the same event). panel_open: whether an info panel is showing - cycling
## only advances an open selection; with the panel closed, a click re-opens on
## the module that was actually hit rather than silently advancing.
func handle_click(clicked: ModuleBase, cell: Vector2i, panel_open: bool) -> ModuleBase:
	var frame: int = Engine.get_physics_frames()
	if frame == _last_click_frame:
		return null
	_last_click_frame = frame
	var stack: Array[ModuleBase] = Global.world_manager.get_stack_at_cell(cell)
	if stack.is_empty():
		return clicked
	if panel_open and cell == _last_cell and stack.size() > 1:
		_cycle_index = (_cycle_index + 1) % stack.size()
	else:
		_last_cell = cell
		_cycle_index = maxi(stack.find(clicked), 0)
	return stack[_cycle_index]
