class_name JobDataRegistry
extends RefCounted

## id -> JobData, discovered by scanning `data/jobs/` (WI-44).
##
## This is the replacement for JobSerializer._ensure_registry(), the
## hand-maintained StringName -> Callable table that every new saveable job type
## had to be added to by hand (and that silently dropped any job whose author
## forgot). A job type is now known to the save system because its `.tres` exists.
##
## Static and lazily built, like JobSerializer was, so it works from anywhere
## without a manager node - including from Job.from_dict() during a load, which
## runs before most managers have finished restoring.

static var _by_id: Dictionary[StringName, JobData] = {}
## The [member ContentPaths.generation] this cache last scanned at, -1 for never.
## A stale one rescans on the next read (WI-74 §2).
static var _scanned_generation: int = -1

static func _ensure_scanned() -> void:
	if _scanned_generation == ContentPaths.generation:
		return
	_scanned_generation = ContentPaths.generation
	_by_id.clear()
	for file_path: String in ContentPaths.scan(ContentPaths.JOBS):
		var res: Resource = ResourceLoader.load(file_path)
		if res is JobData:
			var job_data := res as JobData
			if not ContentPaths.accept_id(job_data.id, file_path, "JobData"):
				continue
			if _by_id.has(job_data.id):
				push_warning("Duplicate JobData id '%s', keeping the first: %s" % [job_data.id, file_path])
				continue
			_by_id[job_data.id] = job_data

## The definition for `id`, or null when nothing declares it - which is how an
## old or hand-edited save drops a job type that no longer exists.
static func get_data(id: StringName) -> JobData:
	_ensure_scanned()
	return _by_id.get(id, null)

static func has(id: StringName) -> bool:
	_ensure_scanned()
	return _by_id.has(id)

static func all() -> Array[JobData]:
	_ensure_scanned()
	var out: Array[JobData] = []
	out.assign(_by_id.values())
	return out

## Test seam: registers a definition without touching the filesystem, and marks
## the registry scanned so a later lookup doesn't pull the real directory in.
static func register_for_test(job_data: JobData) -> void:
	_scanned_generation = ContentPaths.generation
	if job_data != null and job_data.id != &"":
		_by_id[job_data.id] = job_data

static func clear_for_test() -> void:
	_by_id.clear()
	_scanned_generation = -1
