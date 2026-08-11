class_name JobsScreen
extends VBoxContainer

## The station job board (WI-44): what work is queued, who is doing what, and -
## the part that earns the panel - WHY a given pawn will not take a given job.
##
## Before this, "why is nobody hauling?" had no answer short of writing a probe
## script. The board is a priority-sorted queue whose entries are rejected by
## per-driver `can_do()` rules; the rejection reason existed only as a boolean
## returned deep inside a scan. `JobDriver.explain_block()` turns that into a
## sentence, and this panel is where it surfaces. **That explanation is the whole
## value of this view** and survives every reframing intact.
##
## Two lists, because the board only holds UNCLAIMED work: `find_job()` removes a
## job when a pawn takes it, so "in progress" has to come from sweeping pawns.
##
## It does NOT pause the sim. It refreshes on `slow_tick` while open (the same
## cadence JobManager ages the board on) rather than per frame, because
## `explain_block()` runs driver validity checks and pathfinding queries that
## have no business happening 60 times a second.
##
## ## How it has moved
##
## **WI-49** converted it from a code-built full-rect window that invented its own
## frame to one that mounts a [ConsolePanel]. **WI-50** made it the CREW mode's
## panel outright. **WI-56** takes the frame away again: this is now the *second
## view* of the Crew panel - the roster is who, the board is what - reached by
## `SHOW ALL JOBS` and returned from by a back control in the header. A
## drill-down rather than a peer, so it is a swap rather than a tab.
##
## It is therefore a plain body now: [CrewPanel] owns the frame, calls
## [method refresh] when it swaps this in, and takes the board's shape from
## [signal subtitle_changed].

## Rows past this are summarised as a count. A backed-up board can hold hundreds;
## the player needs the shape of the queue, not every entry.
const MAX_ROWS: int = 40

## The board's shape ("4 IN PROGRESS · 12 WAITING"), for whatever frame is
## hosting this view. Emitted rather than written, because the body no longer
## owns a header to write it into.
signal subtitle_changed(text: String)

var _content: VBoxContainer
var _pawn_picker: OptionButton
## Crew in picker order, so the selected index maps back to a pawn. Rebuilt on
## every refresh - pawns are hired and leave.
var _picker_pawns: Array[PawnBase] = []
## Who "blocked because" is being answered for. Null = don't ask.
var _selected: PawnBase = null

func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", UIMetrics.SECTION_GAP)
	_build_body()
	if Global.time_manager != null:
		Global.time_manager.slow_tick.connect(_on_slow_tick)

func _on_slow_tick(_interval: float) -> void:
	if is_visible_in_tree():
		refresh()

# --- shell --------------------------------------------------------------------

func _build_body() -> void:
	var picker_row := HBoxContainer.new()
	picker_row.add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	add_child(picker_row)
	var picker_label := Label.new()
	picker_label.theme_type_variation = UIType.READOUT_LABEL
	picker_label.text = "EXPLAIN FOR"
	picker_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	picker_row.add_child(picker_label)
	_pawn_picker = OptionButton.new()
	_pawn_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pawn_picker.item_selected.connect(_on_pawn_selected)
	picker_row.add_child(_pawn_picker)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", UIMetrics.SECTION_GAP)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content)

func _on_pawn_selected(index: int) -> void:
	# Index 0 is the "nobody" entry, so the pawn list is offset by one.
	_selected = _picker_pawns[index - 1] if index > 0 and index <= _picker_pawns.size() else null
	refresh()

# --- refresh ------------------------------------------------------------------

func refresh() -> void:
	if _content == null or Global.job_manager == null:
		return
	_rebuild_picker()
	for child: Node in _content.get_children():
		child.queue_free()
	var working: Array[PawnBase] = _working_pawns()
	var waiting: Array[Job] = Global.job_manager.get_board_snapshot()
	subtitle_changed.emit("%d in progress · %d waiting" % [working.size(), waiting.size()])
	_build_working(working)
	_build_waiting(waiting)

func _rebuild_picker() -> void:
	var previous: PawnBase = _selected
	_picker_pawns.clear()
	for node: Node in get_tree().get_nodes_in_group(Groups.PAWN):
		var pawn: PawnBase = node as PawnBase
		if pawn != null and not pawn.is_visitor:
			_picker_pawns.append(pawn)
	_pawn_picker.clear()
	_pawn_picker.add_item("nobody")
	var restore_index: int = 0
	for i: int in _picker_pawns.size():
		_pawn_picker.add_item(_pawn_name(_picker_pawns[i]))
		if _picker_pawns[i] == previous:
			restore_index = i + 1
	_pawn_picker.select(restore_index)
	# A pawn that left the station takes its selection with it.
	_selected = previous if restore_index > 0 else null

## Everyone with a live job, robots included - *"robots hauling show up in the job
## board view but not the roster"*, because the board is about the work and the
## roster is about the staff.
func _working_pawns() -> Array[PawnBase]:
	var out: Array[PawnBase] = []
	for node: Node in get_tree().get_nodes_in_group(Groups.PAWN):
		var pawn: PawnBase = node as PawnBase
		if pawn != null and pawn.current_job != null and not pawn.current_job.is_ended():
			out.append(pawn)
	return out

# --- sections -----------------------------------------------------------------

## The in-progress list. The sentence comes from [PawnStatus] rather than from
## `job.report()` directly (WI-56), so the board and the roster in front of it
## describe the same pawn the same way - which they did not before: a drone
## recharging read as "Recharging at Bay" here and "Recharging" there.
func _build_working(working: Array[PawnBase]) -> void:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	section.add_child(SectionLabel.create("In progress"))
	if working.is_empty():
		section.add_child(_muted("Nobody is working"))
	for pawn: PawnBase in working:
		var job: Job = pawn.current_job
		var line: PawnStatus.Line = PawnStatus.of(pawn)
		# Real work keeps the live treatment this section has always had, and a pawn
		# in trouble escalates past it - but an **idle** pawn goes inert. Five cyan
		# rows under `IN PROGRESS` all reading "Idle — no work available" is a
		# screenshot-only defect and exactly the shape WI-54 and WI-55 both hit:
		# every check about the data passed while the colour said the opposite.
		var kind: UIPalette.Row = UIPalette.Row.LIVE
		if line.tone == PawnStatus.Tone.ALERT:
			kind = UIPalette.Row.AMBER
		elif line.tone == PawnStatus.Tone.IDLE:
			kind = UIPalette.Row.INERT
		var row: ListRow = _row(
			"%s — %s" % [_pawn_name(pawn), line.text],
			job.subtask_report(),
			job.get_category_name(),
			kind)
		section.add_child(row)
	_content.add_child(section)

func _build_waiting(waiting: Array[Job]) -> void:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	section.add_child(SectionLabel.create("Waiting on the board"))
	if waiting.is_empty():
		section.add_child(_muted("The board is empty"))
	var shown: int = mini(waiting.size(), MAX_ROWS)
	for i: int in shown:
		var job: Job = waiting[i]
		section.add_child(_row(job.report(), _detail_for(job),
			"%s p%d" % [job.get_category_name(), job.priority], UIPalette.Row.INERT))
	if waiting.size() > shown:
		section.add_child(_muted("... and %d more" % (waiting.size() - shown)))
	_content.add_child(section)

## The second line under a waiting job: how long it has sat there, its workspace
## gate, and - when a pawn is selected - whether that pawn could take it, and if
## not, why. This is the only place explain_block() is ever called, and only for
## the rows actually on screen.
func _detail_for(job: Job) -> String:
	var parts: Array[String] = []
	if job.age > 0.0:
		parts.append("waiting %s" % _age_text(job.age))
	if job.workspace != null and is_instance_valid(job.workspace) and not job.workspace.is_open():
		parts.append("assigned workspace")
	if _selected != null and is_instance_valid(_selected):
		if job.can_do_job(_selected):
			parts.append("%s can take this" % _pawn_name(_selected))
		else:
			var reason: String = job.explain_block(_selected)
			parts.append(reason if not reason.is_empty() else "%s cannot take this" % _pawn_name(_selected))
	return " - ".join(parts)

## Board age is in sim-seconds; hours are what the player thinks in.
func _age_text(seconds: float) -> String:
	var hours: float = seconds / TimeManager.SECONDS_PER_HOUR
	if hours < 1.0:
		return "under an hour"
	return "%.0fh" % hours

# --- widgets ------------------------------------------------------------------

func _pawn_name(pawn: PawnBase) -> String:
	return pawn.pawn_name if not pawn.pawn_name.is_empty() else "Crew"

func _row(name_text: String, meta_text: String, action_text: String,
		kind: UIPalette.Row) -> ListRow:
	var row: ListRow = ListRow.create()
	row.configure(name_text, meta_text, action_text, kind)
	# Rows here are reports, not controls - there is nothing to open yet, so the
	# button never takes focus and never looks clickable on hover.
	row.disabled = true
	return row

func _muted(text: String) -> Label:
	var label := Label.new()
	label.theme_type_variation = UIType.META_LINE
	label.text = text.to_upper()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
