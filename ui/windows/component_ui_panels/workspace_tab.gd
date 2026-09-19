class_name WorkspaceTab
extends ModuleComponentUI

## Module-panel tab (WI-23) listing the station crew with an assign/unassign
## toggle per pawn, so the player picks who works this module. Code-generated
## like LocalUpgradesTab so the info panel can add it as an ordinary component UI
## (WorkspaceComponent.get_ui()). An empty assignment leaves the module's jobs
## open to everyone; a non-empty one restricts them to the listed crew.

## The roster grows the tab up to this, then scrolls. Driven from code for the
## same reason as [LocalUpgradesTab]: a ScrollContainer reports a minimum height
## of zero, and the inspector sizes itself to its content - so an unmeasured
## scroll renders the crew list at nothing while every row inside it is correct.
const MAX_CONTENT_HEIGHT: float = 280.0

var workspace: WorkspaceComponent
var _list: VBoxContainer
var _scroll: ScrollContainer
var _header: Label

func setup(component: WorkspaceComponent) -> void:
	workspace = component
	associated_module = component.owner_module
	name = "Crew"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, UIMetrics.COMPONENT_PAGE_PAD)
	add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	margin.add_child(outer)

	_header = Label.new()
	outer.add_child(_header)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(_scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", UIMetrics.ITEM_GAP)
	_scroll.add_child(_list)
	_list.minimum_size_changed.connect(_fit_height)

	if not workspace.assignment_changed.is_connected(refresh):
		workspace.assignment_changed.connect(refresh)
	# Roster changes (hires/resignations) change who's listable.
	SignalBus.crew_hired.connect(_on_roster_changed)
	SignalBus.crew_resigned.connect(_on_roster_changed)
	refresh()

func _on_roster_changed(_pawn: PawnBase) -> void:
	refresh()

## Synchronous and tree-agnostic - the tab set configures this page before it
## enters the tree.
func _fit_height() -> void:
	if _scroll == null or _list == null:
		return
	_scroll.custom_minimum_size.y = minf(_list.get_combined_minimum_size().y, MAX_CONTENT_HEIGHT)

func refresh() -> void:
	if not is_instance_valid(workspace):
		return
	for child: Node in _list.get_children():
		child.queue_free()

	var crew: Array[PawnBase] = Global.crew_manager.get_crew(false)
	if workspace.max_workers > 0:
		_header.text = "Assigned: %d / %d" % [workspace.get_assigned().size(), workspace.max_workers]
	else:
		_header.text = "Assigned: %d" % workspace.get_assigned().size()
	if workspace.is_open():
		_header.text += "  (open to all)"

	if crew.is_empty():
		var empty := Label.new()
		empty.text = "No crew to assign."
		_list.add_child(empty)
		_fit_height()
		return

	for pawn: PawnBase in crew:
		_list.add_child(_build_row(pawn))
	_fit_height()

func _build_row(pawn: PawnBase) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIMetrics.INLINE_GAP)

	var label := Label.new()
	label.text = pawn.pawn_name if pawn.pawn_name != "" else "Crew"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var is_assigned: bool = workspace.lists(pawn)
	var toggle := Button.new()
	toggle.toggle_mode = true
	toggle.button_pressed = is_assigned
	toggle.text = "Assigned" if is_assigned else "Assign"
	# Can't newly assign when the workspace is full (already-assigned crew keep
	# their toggle so they can be unassigned).
	toggle.disabled = not is_assigned and not workspace.can_assign_more()
	toggle.toggled.connect(_on_toggled.bind(pawn))
	row.add_child(toggle)

	return row

func _on_toggled(pressed: bool, pawn: PawnBase) -> void:
	if pressed:
		workspace.assign(pawn)
	else:
		workspace.unassign(pawn)
	# refresh() runs via assignment_changed to re-evaluate every row's disabled state.
