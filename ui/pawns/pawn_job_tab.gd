extends PanelContainer

var pawn: PawnBase = null

func set_pawn(_pawn: PawnBase) -> void:
	pawn = _pawn
	pawn.job_changed.connect(job_changed)
	job_changed()

func job_changed() -> void:
	if pawn and pawn.current_job:
		%CurrentTask.text = pawn.current_job.get_job_description()
		pawn.current_job.subtask_changed.connect(subtask_changed)
		subtask_changed()
	else:
		%CurrentTask.text = "Nothing"

func subtask_changed() -> void:
	if pawn and pawn.current_job:
		%CurrentSubTask.text = pawn.current_job.get_subtask_description()
	else:
		%CurrentSubTask.text = ""
	%SubTaskContainer.visible = not %CurrentSubTask.text.is_empty()


func _on_cancel_button_pressed() -> void:
	if is_instance_valid(pawn) and pawn.current_job:
		pawn.current_job.cancel(true)
