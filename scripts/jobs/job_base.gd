class_name JobBase
extends Resource

@export var name: String = ""
@export var description: String = ""
var priority: int = 0

enum JobState { Starting, Moving, Working, Finished, Failed }

signal subtask_changed

signal job_end

func get_job_description() -> String:
	return ""

func get_subtask_description() -> String:
	return ""

func is_valid() -> bool:
	return true

func can_do_job(_pawn: PawnBase) -> bool:
	return true

func start_job(_pawn: PawnBase) -> void:
	pass

func process_job(_delta: float) -> void:
	# Override by subclasses
	pass
	
func is_failed() -> bool:
	# Override by subclasses
	return false
	
func is_finished() -> bool:
	# Override by subclasses
	return false

func cancel(_as_failed: bool) -> void:
	# Override by subclasses
	pass
	
func end_job() -> void:
	job_end.emit()

## Override to compute a followup job for pawn. Call this yourself (see
## Job_GetResource.deposit_resource()) at the exact moment you know you've
## succeeded, and push the result onto the pawn's queue immediately - don't
## wait for end_job()/is_finished() to be noticed on a later _process()
## tick. Node processing order between you and whatever you're offering a
## followup on behalf of isn't guaranteed, so resolving eagerly and
## synchronously inside your own success path is what keeps the handoff
## race-free. Return null (the default) if there's nothing to chain into.
func get_followup_job(_pawn: PawnBase) -> JobBase:
	return null
