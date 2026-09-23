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

# --- declared owners (WI-70 §3) ------------------------------------------------
#
# A restored job goes back to the owner its type declares. A type an owner
# remembers that declares nobody posts that owner a duplicate on every load -
# F26, and F2 before it - so every type is listed here and a new one has to be
# added on purpose.

const ORIGINS: Dictionary[StringName, JobData.Origin] = {
	&"eat": JobData.Origin.PAWN,
	&"sleep": JobData.Origin.PAWN,
	&"recreate": JobData.Origin.PAWN,
	&"shop": JobData.Origin.PAWN,
	&"recharge": JobData.Origin.PAWN,
	&"get_repaired": JobData.Origin.PAWN,
	&"get_treatment": JobData.Origin.PAWN,
	&"change_suit": JobData.Origin.PAWN,
	&"construct_module": JobData.Origin.TARGET_A,
	&"deconstruct_module": JobData.Origin.TARGET_A,
	&"work_processor": JobData.Origin.TARGET_A,
	&"doctor": JobData.Origin.TARGET_A,
	&"repair_module": JobData.Origin.TARGET_A,
	&"collect_pile": JobData.Origin.TARGET_A,
	# Set per post: a pull is its sink's (TARGET_B), a push its source's (TARGET_A).
	&"haul_resource": JobData.Origin.NONE,
	&"idle": JobData.Origin.NONE,
	&"idle_wander": JobData.Origin.NONE,
	&"wait": JobData.Origin.NONE,
	&"move_to_location": JobData.Origin.NONE,
	&"store_inventory": JobData.Origin.NONE,
	&"leave_station": JobData.Origin.NONE,
	&"mine_asteroid": JobData.Origin.NONE,
}

func test_every_job_type_declares_who_adopts_it() -> void:
	for data: JobData in JobDataRegistry.all():
		assert_true(ORIGINS.has(data.id),
			"'%s' is new: decide who adopts it after a load, and list it here" % data.id)
		if ORIGINS.has(data.id):
			assert_eq(data.origin, ORIGINS[data.id], "'%s' declares %s" % [data.id,
				JobData.Origin.keys()[ORIGINS[data.id]]])

func test_a_job_takes_its_origin_from_its_type() -> void:
	var job: Job = Job.create(JobDataRegistry.get_data(&"construct_module"))
	assert_eq(job.origin, JobData.Origin.TARGET_A)

func test_the_data_default_origin_is_not_written() -> void:
	var job: Job = Job.create(JobDataRegistry.get_data(&"construct_module"))
	assert_false(job.to_dict().has("origin"), "every type's default comes from its .tres")

func test_a_per_post_origin_round_trips() -> void:
	var haul_data: JobData = JobDataRegistry.get_data(&"haul_resource")
	var pull: Job = Job.create(haul_data).with_origin(JobData.Origin.TARGET_B)
	var encoded: Dictionary = pull.to_dict()
	assert_true(encoded.has("origin"), "an override is written")
	var restored: Job = Job.restore(encoded, haul_data, null, null)
	assert_not_null(restored)
	if restored != null:
		assert_eq(restored.origin, JobData.Origin.TARGET_B, "and read back")

func test_a_haul_from_before_origin_restores_as_nobodys() -> void:
	# An old save's haul has no "origin" key. It takes the data default and is
	# offered to nobody: one duplicate trip on its first load, which was every
	# type's behaviour before WI-70. SAVE_VERSION does not move for it.
	var haul_data: JobData = JobDataRegistry.get_data(&"haul_resource")
	var restored: Job = Job.restore({"def": "haul_resource", "index": -1}, haul_data, null, null)
	assert_not_null(restored)
	if restored != null:
		assert_eq(restored.origin, JobData.Origin.NONE)
		assert_false(restored.offer_to_owner(null), "and nobody is asked")

# --- SaveManager ref-helper null guards ---------------------------------------

func test_component_ref_null_is_empty() -> void:
	assert_eq(SaveRefs.component_ref(null), {}, "null component -> empty ref")

func test_asteroid_ref_null_is_empty() -> void:
	assert_eq(SaveRefs.asteroid_ref(null), {}, "null asteroid -> empty ref")

func test_pile_ref_null_is_empty() -> void:
	assert_eq(SaveRefs.pile_ref(null), {}, "null pile -> empty ref")

# --- freed references (WI-68 F23) -------------------------------------------------
#
# A typed parameter rejects a freed object at the call, before any check inside
# runs, so these used to raise a script error - which aborted whichever save
# section was being collected. A pile tagged with a removed module wrote the
# whole pile section empty. Now a freed reference costs its own entry and no more.

func _freed(node: Node) -> Node:
	node.free()
	return node

func test_module_ref_of_a_freed_module_is_empty() -> void:
	assert_eq(SaveRefs.module_ref(_freed(ModuleBase.new())), {}, "freed module -> empty ref, not an error")

func test_pawn_ref_of_a_freed_pawn_is_empty() -> void:
	assert_eq(SaveRefs.pawn_ref(_freed(PawnBase.new())), {})

func test_pile_ref_of_a_freed_pile_is_empty() -> void:
	assert_eq(SaveRefs.pile_ref(_freed(ResourcePile.new())), {})

func test_asteroid_ref_of_a_freed_asteroid_is_empty() -> void:
	assert_eq(SaveRefs.asteroid_ref(_freed(AsteroidBase.new())), {})

func test_component_ref_of_a_freed_component_is_empty() -> void:
	assert_eq(SaveRefs.component_ref(_freed(ComponentBase.new())), {})

func test_module_ref_of_the_wrong_kind_is_empty() -> void:
	var node: Node2D = autofree(Node2D.new())
	assert_eq(SaveRefs.module_ref(node), {}, "a live node that isn't a module refers to nothing")

# --- a pile lets go of a module that leaves (WI-68 F23) ------------------------------

func test_a_pile_forgets_a_module_that_leaves_the_tree() -> void:
	var module: ModuleBase = autofree(ModuleBase.new())
	var pile: ResourcePile = autofree(ResourcePile.new())
	pile.parent_module = module
	module.tree_exiting.emit()
	assert_null(pile.parent_module, "a removed module's pile is left floating, not pointing at a freed node")

func test_a_repointed_pile_ignores_its_old_module_leaving() -> void:
	var first: ModuleBase = autofree(ModuleBase.new())
	var second: ModuleBase = autofree(ModuleBase.new())
	var pile: ResourcePile = autofree(ResourcePile.new())
	pile.parent_module = first
	pile.parent_module = second
	first.tree_exiting.emit()
	assert_eq(pile.parent_module, second, "only the current module's exit clears it")

# --- only a crew gateway receives a recruit (WI-68 F22) -----------------------------

func test_nothing_is_a_gateway_that_cannot_receive_crew() -> void:
	assert_false(CrewManager._is_gateway(null), "no module")
	assert_false(CrewManager._is_gateway(_freed(ModuleBase.new())), "a freed bay (bound to a shuttle that outlived it)")
	assert_false(CrewManager._is_gateway(autofree(ModuleBase.new())), "a module with no recruitment component - the truss the bay became")

func test_resolve_empty_refs_return_null() -> void:
	assert_null(SaveRefs.resolve_module_ref({}), "empty module ref -> null")
	assert_null(SaveRefs.resolve_component_ref({}), "empty component ref -> null")
	assert_null(SaveRefs.resolve_asteroid_ref({}), "empty asteroid ref -> null")
	assert_null(SaveRefs.resolve_pile_ref({}), "empty pile ref -> null")
