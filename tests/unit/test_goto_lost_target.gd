extends GutTest

## Action_GotoTarget's handling of a destination that gets freed while the pawn
## is still walking to it.
##
## This exists because asteroids now break up the moment they are mined dry, so
## "the thing I was flying to stopped existing" went from a rarity to a routine
## event for every mining drone. The rule the walk applies is JobTarget's own
## fail_on_lost flag: a target the job declared survivable ends the walk as DONE
## and lets the driver pick the next one, while a target the job depends on still
## fails (Job._targets_alive() is what actually ends those, but on_start has to
## agree or a restored job would resume into a walk to nothing).

var _action: Action_GotoTarget = null

func before_each() -> void:
	_action = Action_GotoTarget.new(JobTarget.Slot.A)

func _job(target: JobTarget) -> Job:
	var data := JobData.new()
	data.id = &"test_goto"
	var job := Job.create(data)
	if target != null:
		job.set_target(JobTarget.Slot.A, target)
	return job

## A JobTarget pointing at an asteroid that has already been freed.
func _dead_asteroid_target(survivable: bool) -> JobTarget:
	var asteroid := AsteroidBase.new()
	var target: JobTarget = JobTarget.of_asteroid(asteroid)
	target.fail_on_lost = not survivable
	asteroid.free()
	return target

func _live_asteroid_target() -> JobTarget:
	var asteroid := AsteroidBase.new()
	var target: JobTarget = JobTarget.of_asteroid(autofree(asteroid))
	target.fail_on_lost = false
	return target

func test_walk_to_a_live_target_keeps_going() -> void:
	var job: Job = _job(_live_asteroid_target())
	assert_eq(_action.tick(job, 0.1), ActionBase.Status.ONGOING,
		"the rock is still there - keep flying")

func test_lost_survivable_target_finishes_the_walk() -> void:
	var job: Job = _job(_dead_asteroid_target(true))
	assert_eq(_action.tick(job, 0.1), ActionBase.Status.DONE,
		"another drone mined it out from under us - the walk is over, not failed")

func test_lost_required_target_is_left_to_the_job_to_fail() -> void:
	# A hard target is Job._targets_alive()'s business; the walk must not quietly
	# report success and let the next action run at the wrong place.
	var job: Job = _job(_dead_asteroid_target(false))
	assert_eq(_action.tick(job, 0.1), ActionBase.Status.ONGOING,
		"losing a required destination is not this action's call")

func test_unset_slot_never_reads_as_lost() -> void:
	var job: Job = _job(null)
	assert_eq(_action.tick(job, 0.1), ActionBase.Status.ONGOING,
		"an empty slot is not a freed target")

func test_entering_on_a_lost_survivable_target_skips_the_walk() -> void:
	var job: Job = _job(_dead_asteroid_target(true))
	assert_eq(_action.on_start(job), ActionBase.Status.DONE,
		"nothing left to walk to, and the job said it could outlive this")

func test_entering_on_a_lost_required_target_fails() -> void:
	var job: Job = _job(_dead_asteroid_target(false))
	assert_eq(_action.on_start(job), ActionBase.Status.FAILED,
		"the job depends on this destination")

func test_entering_with_no_target_at_all_fails() -> void:
	var job: Job = _job(null)
	assert_eq(_action.on_start(job), ActionBase.Status.FAILED,
		"a walk with no destination is a broken job, not a skipped step")
