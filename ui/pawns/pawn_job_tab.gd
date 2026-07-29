extends PanelContainer

var pawn: PawnBase = null

@export var cancel_button: Button

func set_pawn(_pawn: PawnBase) -> void:
	pawn = _pawn
	pawn.job_changed.connect(job_changed)
	job_changed()

func job_changed() -> void:
	if pawn and pawn.current_job:
		%CurrentTask.text = "%s  [%s]" % [pawn.current_job.report(), pawn.current_job.get_category_name()]
		pawn.current_job.subtask_changed.connect(subtask_changed)
		subtask_changed()
		cancel_button.visible = pawn.current_job.player_cancelable()
	else:
		%CurrentTask.text = "Nothing"
		subtask_changed()

func subtask_changed() -> void:
	if pawn and pawn.current_job:
		%CurrentSubTask.text = pawn.current_job.subtask_report()
	else:
		%CurrentSubTask.text = ""
	%SubTaskContainer.visible = not %CurrentSubTask.text.is_empty()


func _on_cancel_button_pressed() -> void:
	if is_instance_valid(pawn) and pawn.current_job and pawn.current_job.player_cancelable():
		pawn.current_job.cancel(true)
