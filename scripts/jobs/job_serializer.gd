class_name JobSerializer

## WI-21 job save/restore registry. Maps each saveable job's type id (the
## string its get_save_data() stamps under "type") to the subclass's static
## restore(data) -> JobBase factory. Serialization is the inverse: a job's own
## get_save_data() emits the dict, base JobBase returns {} for the jobs a system
## re-derives on load and shouldn't persist (board hauls, idle, store-inventory).
##
## Deliberately NOT registered (re-derived by their owning system on load, the
## same way the shared board re-derives itself):
## - Job_Eat / Job_Sleep / Job_Recreate ARE registered - a mid-sleep/recreate
##   session sits above the "look for needs" threshold, so the decay loop
##   wouldn't re-queue it; persisting lets the pawn finish the session. They
##   re-link to their need slot via PawnNeedsComponent.adopt_restored_need_job.
## - Job_LeaveStation is NOT registered: PawnNeedsComponent re-emits crew_resigned
##   on load, and CrewManager interrupt_with_job()s a fresh walkout - restoring
##   one would just be replaced.
## - Job_StoreInventory / Job_Idle* are NOT registered: start_job() re-creates
##   the store sweep from saved inventory, and idle is the fallback anyway.

static var _factories: Dictionary[StringName, Callable] = {}

static func _ensure_registry() -> void:
	if not _factories.is_empty():
		return
	_factories[&"get_resource"] = Job_GetResource.restore
	_factories[&"construct_module"] = Job_ConstructModule.restore
	_factories[&"collect_pile"] = Job_CollectPile.restore
	_factories[&"mine_asteroid"] = Job_MineAsteroid.restore
	_factories[&"work_processor"] = Job_WorkProcessor.restore
	_factories[&"move_to_location"] = Job_MoveToLocation.restore
	_factories[&"eat"] = Job_Eat.restore
	_factories[&"sleep"] = Job_Sleep.restore
	_factories[&"recreate"] = Job_Recreate.restore

## A job's save dict, or {} when it isn't saveable (base get_save_data()).
static func serialize(job: JobBase) -> Dictionary:
	if job == null:
		return {}
	return job.get_save_data()

## Rebuilds a job from its save dict, or null when the dict is empty, the type
## is unknown (old/hand-edited save), or the factory can't resolve the job's
## targets. Null propagates as "drop this job" all the way up to the pawn.
static func deserialize(data: Dictionary) -> JobBase:
	if data.is_empty():
		return null
	_ensure_registry()
	var type_id := StringName(data.get("type", ""))
	var factory: Callable = _factories.get(type_id, Callable())
	if not factory.is_valid():
		return null
	return factory.call(data) as JobBase
