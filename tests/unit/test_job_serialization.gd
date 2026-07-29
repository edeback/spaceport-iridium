extends GutTest

## Unit tests for the save-side plumbing job persistence sits on: the
## `data/jobs/` definition registry and SaveManager's ref helpers.
##
## WI-44 deleted the per-class `get_save_data()`/`restore()` pairs and the
## hand-maintained `JobSerializer` type table this suite used to exercise; the
## encode/decode logic that replaced them (targets, action index, per-action
## state, the signature guard) is covered by `test_job_persistence.gd`. What is
## left here is the part that outlived the rewrite - plus one thing that only
## became testable BECAUSE of it: which job types persist is now readable off the
## `.tres` files, rather than inferred from whose author remembered to register a
## factory.
##
## Pure: the registry scans a directory and the ref helpers are static
## encode-only functions, so nothing here touches Global or a live scene.

# --- the definition registry --------------------------------------------------

func test_every_definition_resolves_by_its_own_id() -> void:
	var all: Array[JobData] = JobDataRegistry.all()
	assert_gt(all.size(), 0, "data/jobs/ is not empty")
	for data: JobData in all:
		assert_eq(JobDataRegistry.get_data(data.id), data,
			"'%s' resolves back to itself" % data.id)

func test_every_definition_has_a_driver() -> void:
	# A definition with no driver produces a job that fails on its first frame,
	# and the failure would surface far from the .tres that caused it.
	for data: JobData in JobDataRegistry.all():
		assert_not_null(data.driver, "'%s' names a driver script" % data.id)

func test_unknown_id_resolves_to_null() -> void:
	assert_null(JobDataRegistry.get_data(&"no_such_job"),
		"an unknown id is null, not a half-built definition")

# --- the saveable split -------------------------------------------------------
#
# The four types below are re-derived by their own systems on load, so persisting
# them would duplicate what the world already says. Before WI-44 this was a
# comment in job_serializer.gd listing what had been left out of the type table
# on purpose - indistinguishable, from the outside, from an author forgetting.

func test_re_derived_job_types_are_flagged_not_saveable() -> void:
	for id: StringName in [&"idle", &"idle_wander", &"store_inventory", &"leave_station"]:
		var data: JobData = JobDataRegistry.get_data(id)
		assert_not_null(data, "'%s' exists" % id)
		if data != null:
			assert_false(data.saveable, "'%s' is flagged not-saveable" % id)

func test_a_not_saveable_job_serializes_to_nothing() -> void:
	# The flag has teeth: to_dict() checks it, rather than it being documentation.
	var job: Job = Job.create(JobDataRegistry.get_data(&"idle"))
	assert_eq(job.to_dict(), {}, "an idle job drops on save")

func test_ordinary_job_types_do_persist() -> void:
	for id: StringName in [&"haul_resource", &"construct_module", &"sleep", &"mine_asteroid"]:
		var data: JobData = JobDataRegistry.get_data(id)
		assert_not_null(data, "'%s' exists" % id)
		if data != null:
			assert_true(data.saveable, "'%s' persists" % id)

# --- SaveManager ref-helper null guards ---------------------------------------

func test_component_ref_null_is_empty() -> void:
	assert_eq(SaveManager.component_ref(null), {}, "null component -> empty ref")

func test_asteroid_ref_null_is_empty() -> void:
	assert_eq(SaveManager.asteroid_ref(null), {}, "null asteroid -> empty ref")

func test_pile_ref_null_is_empty() -> void:
	assert_eq(SaveManager.pile_ref(null), {}, "null pile -> empty ref")

func test_resolve_empty_refs_return_null() -> void:
	assert_null(SaveManager.resolve_module_ref({}), "empty module ref -> null")
	assert_null(SaveManager.resolve_component_ref({}), "empty component ref -> null")
	assert_null(SaveManager.resolve_asteroid_ref({}), "empty asteroid ref -> null")
	assert_null(SaveManager.resolve_pile_ref({}), "empty pile ref -> null")
