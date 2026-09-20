class_name JobManager
extends Node

## The shared job board: one priority-sorted queue per JobData.Category.
## Queues are sorted ascending by effective priority (high priority at the
## back, where find_job scans from). Selection across categories is a merge
## by effective priority, so categories act as an index/filter, not a
## ranking - a high-priority MISC job still beats a low-priority HAUL job.

var _board: Dictionary[JobData.Category, Array] = {}
var _all_categories: Array[JobData.Category] = []

## The queues exist from construction rather than from _ready, so the board can
## be driven without a scene tree - which is how test_job_manager.gd pins F32.
func _init() -> void:
	for category: int in JobData.Category.values():
		_board[category] = []
		_all_categories.append(category)

func _ready() -> void:
	Global.job_manager = self
	# Aging: bump every waiting job's age, then re-sort. Ages grow uniformly
	# but bonuses cap out, so relative effective order genuinely changes over
	# time; queues are small (tens of jobs), so a 4 Hz sim-time sort is
	# nothing - and it also repairs ordering after external priority changes
	# (StorageComponent.update_priority mutates posted jobs' priorities).
	Global.time_manager.slow_tick.connect(_on_slow_tick)

## Hands the slot back (WI-71 §7). Godot 4.7 reports a freed object as `== null`,
## so the guards around the game already take their null branch after a Quit to
## Menu - but `is_instance_valid(Global.job_manager)` and the debugger both lie until
## the slot is actually cleared. `== self` because a second scene can register
## before this one leaves.
func _exit_tree() -> void:
	if Global.job_manager == self:
		Global.job_manager = null


func _on_slow_tick(interval: float) -> void:
	for category: JobData.Category in _board:
		var queue: Array = _board[category]
		if queue.is_empty():
			continue
		for job: Job in queue:
			job.age += interval
		queue.sort_custom(_sort_effective_ascending)

func add_job(job: Job) -> void:
	var queue: Array = _board[job.get_category()]
	queue.insert(queue.bsearch_custom(job, _sort_effective_ascending), job)

func remove_job(job: Job) -> void:
	_board[job.get_category()].erase(job)

## Best claimable job for this pawn across allowed_categories (empty = all).
## Walks each queue from its high-priority end, always considering the
## highest effective priority remaining in any queue; invalid jobs found
## along the way are cancelled and removed.
func find_job(pawn: PawnBase, allowed_categories: Array[JobData.Category] = []) -> Job:
	var categories: Array[JobData.Category] = allowed_categories if not allowed_categories.is_empty() else _all_categories
	var queues: Array[Array] = []
	var cursors: Array[int] = []
	for category: JobData.Category in categories:
		var queue: Array = _board[category]
		if not queue.is_empty():
			queues.append(queue)
			cursors.append(queue.size() - 1)
	while true:
		var best_index: int = -1
		var best_priority: float = 0.0
		for index: int in queues.size():
			if cursors[index] < 0:
				continue
			var candidate: Job = queues[index][cursors[index]]
			# Per-pawn key (WI-23): folds in the workspace affinity bonus so an
			# assignee prefers their own workspace's job. The queues stay sorted by
			# the pawn-agnostic effective_priority(); the affinity bump is modest
			# and within-band, so scanning cursor-tops by this key still surfaces
			# the right job in every case the assignment mechanic cares about.
			var effective: float = candidate.effective_priority_for(pawn)
			if best_index == -1 or effective > best_priority:
				best_index = index
				best_priority = effective
		if best_index == -1:
			return null
		var job_to_do: Job = queues[best_index][cursors[best_index]]
		# Check that the job is still possible. Cancel (not just end) so the
		# requester releases its reservations / import-export slots.
		#
		# Off the board FIRST, then cancel (F32, WI-70 §7). The cancel emits
		# job_end synchronously, and an owner that re-posts from its handler
		# inserts into this very queue - which shifted the job under the cursor,
		# so the remove_at that followed took a valid job off the board and left
		# the dead one on it. At worst the insert now makes this scan skip one
		# job, which the next scan sees.
		if !job_to_do.is_valid():
			queues[best_index].remove_at(cursors[best_index])
			cursors[best_index] -= 1
			job_to_do.cancel(true)
			continue
		if job_to_do.can_do_job(pawn):
			queues[best_index].remove_at(cursors[best_index])
			return job_to_do
		cursors[best_index] -= 1
	return null

func re_sort_jobs() -> void:
	for category: JobData.Category in _board:
		_board[category].sort_custom(_sort_effective_ascending)

## WI-35 logistics overlay: the waiting HAUL jobs still on the board. Claimed
## jobs aren't here - they've been pulled off the board into their pawn's
## current_job - so the flow layer unions this with a sweep over pawns. Returns a
## fresh array; safe to iterate.
func get_waiting_haul_jobs() -> Array[Job]:
	var out: Array[Job] = []
	for job: Job in _board.get(JobData.Category.HAUL, []):
		out.append(job)
	return out

## Every job waiting on the board, highest effective priority first (WI-44 board
## inspector). Read-only: a fresh array, so the caller cannot reorder the real
## queues by sorting it.
##
## CLAIMED jobs are deliberately absent - find_job() removes a job from the board
## when a pawn takes it, so "what is the station doing" needs the union of this
## and a sweep over pawns. The inspector does that union; get_waiting_haul_jobs()
## has always done the same dance for the logistics overlay.
func get_board_snapshot() -> Array[Job]:
	var out: Array[Job] = []
	for category: JobData.Category in _board:
		out.append_array(_board[category])
	out.sort_custom(_sort_effective_descending)
	return out

func _sort_effective_descending(a: Job, b: Job) -> bool:
	return a.effective_priority() > b.effective_priority()

## Total jobs waiting on the board (debug/UI).
func board_size() -> int:
	var total: int = 0
	for category: JobData.Category in _board:
		total += _board[category].size()
	return total

func _sort_effective_ascending(a: Job, b: Job) -> bool:
	return a.effective_priority() < b.effective_priority()
