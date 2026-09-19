extends PanelContainer

## The pawn's "what are you doing" tab. Two lines: the job's headline report and
## the current action's subtask line, both composed by the job itself (WI-44) -
## `JobData.report_template` with the job's own targets substituted in, and
## `ActionBase.report()` for the step. Nothing here knows about job types.
##
## The headline goes through [PawnStatus] since WI-56, so this tab, the crew
## roster and the job board say the same thing about the same pawn. It used to
## print the literal word "Nothing" for a null job, which is a third spelling of
## "Idle" - and the roster is a column of forty of these where that shows.

var pawn: PawnBase = null
## The job we're currently listening to, so its subtask signal can be dropped when
## the pawn moves on. Without this the connection outlives the job: the tab keeps
## a dead job alive and re-connects on every change, which Godot reports as an
## already-connected error the first time a pawn re-runs the same job object.
var _watched: Job = null

@export var cancel_button: Button

func set_pawn(_pawn: PawnBase) -> void:
	pawn = _pawn
	if not pawn.job_changed.is_connected(job_changed):
		pawn.job_changed.connect(job_changed)
	job_changed()

func job_changed() -> void:
	_watch(pawn.current_job if pawn != null else null)
	var line: PawnStatus.Line = PawnStatus.of(pawn)
	var task: Label = %CurrentTask
	task.text = line.text
	task.add_theme_color_override("font_color", PawnStatus.tone_color(line.tone))
	if pawn != null and pawn.current_job != null:
		# The category stays: it is the one thing the status sentence deliberately
		# does not carry, and this tab is where a player would look for it.
		task.text = "%s  [%s]" % [line.text, pawn.current_job.get_category_name()]
		cancel_button.visible = pawn.current_job.player_cancelable()
	else:
		cancel_button.visible = false
	subtask_changed()

func subtask_changed() -> void:
	if pawn != null and pawn.current_job != null:
		(%CurrentSubTask as Label).text = pawn.current_job.subtask_report()
	else:
		(%CurrentSubTask as Label).text = ""
	(%SubTaskContainer as HBoxContainer).visible = not (%CurrentSubTask as Label).text.is_empty()

## Follows exactly one job's subtask signal at a time.
func _watch(job: Job) -> void:
	if job == _watched:
		return
	if _watched != null and is_instance_valid(_watched) \
			and _watched.subtask_changed.is_connected(subtask_changed):
		_watched.subtask_changed.disconnect(subtask_changed)
	_watched = job
	if _watched != null and not _watched.subtask_changed.is_connected(subtask_changed):
		_watched.subtask_changed.connect(subtask_changed)

func _exit_tree() -> void:
	_watch(null)

func _on_cancel_button_pressed() -> void:
	if is_instance_valid(pawn) and pawn.current_job != null and pawn.current_job.player_cancelable():
		pawn.current_job.cancel(true)
