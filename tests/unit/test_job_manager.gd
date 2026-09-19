extends GutTest

## JobManager's board scan (F32, WI-70 §7).
##
## find_job() cancels a job it finds invalid, and the cancel emits job_end
## synchronously. An owner that re-posts from its handler inserts into the very
## queue being scanned. When the cancel came before the remove_at, the insert
## shifted the queue under the cursor and the remove_at took the re-posted job off
## the board, leaving the dead one on it. After WI-70 every owner re-posts
## through a JobSlot handler, which made that path more likely than it was.
##
## Driven without a scene tree: the board is built in _init, and nothing here
## reaches Global.

class StubDriver:
	extends JobDriver

	var valid: bool = true

	func is_valid(_job: Job) -> bool:
		return valid

	func can_do(_job: Job, _pawn: PawnBase) -> bool:
		return valid

var manager: JobManager = null
var registry: ClaimRegistry = null

func before_each() -> void:
	manager = JobManager.new()
	registry = ClaimRegistry.new()

func after_each() -> void:
	manager.free()
	registry.free()

func _job(priority: int, valid: bool) -> Job:
	var data := JobData.new()
	data.id = &"test_job"
	data.category = JobData.Category.MISC
	var job := Job.create(data).with_priority(priority)
	job.registry = registry
	var driver := StubDriver.new()
	driver.valid = valid
	job.install_driver(driver)
	return job

func test_a_repost_from_a_cancelled_jobs_handler_stays_on_the_board() -> void:
	var waiting: Job = _job(1, true)
	var dead: Job = _job(5, false)
	var reposted: Job = _job(3, true)
	manager.add_job(waiting)
	manager.add_job(dead)
	# The dead job's owner re-posts when it ends, as a construction site or a pile
	# does - into the same queue, between the two jobs already there.
	var slot := JobSlot.new(func(_ended: Job, _completed: bool) -> void: manager.add_job(reposted))
	slot.post(dead)
	var handed_out: Job = manager.find_job(null)
	assert_eq(handed_out, waiting, "the scan still hands out the valid job")
	assert_true(dead.is_ended(), "the invalid job was cancelled")
	var board: Array[Job] = manager.get_board_snapshot()
	assert_false(board.has(dead), "and taken off the board")
	assert_true(board.has(reposted), "while the owner's re-post stays on it")
	assert_eq(manager.board_size(), 1, "and nothing else is left behind")

func test_an_invalid_job_alone_is_cleared_off_the_board() -> void:
	var dead: Job = _job(5, false)
	manager.add_job(dead)
	assert_null(manager.find_job(null), "nothing to hand out")
	assert_true(dead.is_failed(), "cancelled as failed, so its requester lets go")
	assert_eq(manager.board_size(), 0)
