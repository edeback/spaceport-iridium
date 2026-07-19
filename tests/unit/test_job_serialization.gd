extends GutTest

## Unit tests for WI-21 job serialization - the pure-logic surface that doesn't
## need a live world: JobBase's saveable/not-saveable split, JobSerializer's
## registry + null/unknown-type handling, each saveable job's get_save_data()
## shape (with node targets left null, so SaveManager's ref helpers return {}),
## and the null-guard paths of the SaveManager ref helpers themselves.
##
## Full round-trips through resolve_*_ref (which need Global/managers and a live
## scene) are covered by the in-game verification steps in the WI, not here -
## these construct jobs directly and never touch Global/SignalBus.

func _ore(id: StringName = &"test_ore") -> ResourceData:
	var resource := ResourceData.new()
	resource.id = id
	return resource

# --- JobBase saveable/not-saveable split -------------------------------------

func test_base_job_is_not_saveable() -> void:
	assert_eq(JobBase.new().get_save_data(), {}, "base JobBase serializes to {} (drop on save)")

func test_store_inventory_is_not_saveable() -> void:
	# Re-created from saved inventory by start_job(), so it must not persist.
	assert_eq(Job_StoreInventory.new().get_save_data(), {}, "Job_StoreInventory is not saveable")

# --- JobSerializer registry / guards -----------------------------------------

func test_serialize_null_job_returns_empty() -> void:
	assert_eq(JobSerializer.serialize(null), {}, "null job serializes to {}")

func test_deserialize_empty_returns_null() -> void:
	assert_null(JobSerializer.deserialize({}), "empty dict deserializes to null")

func test_deserialize_unknown_type_returns_null() -> void:
	assert_null(JobSerializer.deserialize({"type": "not_a_real_job"}), "unknown type -> null (old/edited save)")

func test_deserialize_missing_type_returns_null() -> void:
	assert_null(JobSerializer.deserialize({"amount": 3}), "no type key -> null")

# --- get_resource ------------------------------------------------------------

func test_get_resource_save_shape() -> void:
	var job := Job_GetResource.new()
	job.resource_data = _ore()
	job.amount = 5
	var data: Dictionary = job.get_save_data()
	assert_eq(data.get("type"), "get_resource", "type stamped")
	assert_eq(data.get("resource"), "test_ore", "resource id stamped")
	assert_eq(data.get("amount"), 5, "amount stamped")
	# Storages left null -> component_ref returns {}, still round-trippable.
	assert_eq(data.get("export"), {}, "null export storage -> empty ref")
	assert_eq(data.get("deposit"), {}, "null deposit storage -> empty ref")

func test_get_resource_without_resource_is_not_saveable() -> void:
	assert_eq(Job_GetResource.new().get_save_data(), {}, "no resource_data -> not saveable")

func test_get_resource_with_unsaveable_resource_id() -> void:
	var job := Job_GetResource.new()
	job.resource_data = _ore(&"") # blank id can't be resolved on load
	assert_eq(job.get_save_data(), {}, "blank resource id -> not saveable")

# --- construct_module --------------------------------------------------------

func test_construct_module_without_target_is_not_saveable() -> void:
	assert_eq(Job_ConstructModule.new().get_save_data(), {}, "no module -> not saveable")

# --- collect_pile ------------------------------------------------------------

func test_collect_pile_without_target_is_not_saveable() -> void:
	assert_eq(Job_CollectPile.new().get_save_data(), {}, "no pile -> not saveable")

# --- mine_asteroid -----------------------------------------------------------

func test_mine_asteroid_without_component_is_not_saveable() -> void:
	assert_eq(Job_MineAsteroid.new().get_save_data(), {}, "no mining component -> not saveable")

# --- move_to_location --------------------------------------------------------

func test_move_to_location_without_target_is_not_saveable() -> void:
	assert_eq(Job_MoveToLocation.new().get_save_data(), {}, "no destination -> not saveable")

# --- needs jobs (target-less: re-found on load) ------------------------------

func test_eat_round_trips_through_registry() -> void:
	assert_eq(Job_Eat.new().get_save_data(), {"type": "eat"}, "eat saves just its type")
	assert_true(JobSerializer.deserialize({"type": "eat"}) is Job_Eat, "eat restores to a Job_Eat")

func test_sleep_round_trips_through_registry() -> void:
	assert_eq(Job_Sleep.new().get_save_data(), {"type": "sleep"}, "sleep saves just its type")
	assert_true(JobSerializer.deserialize({"type": "sleep"}) is Job_Sleep, "sleep restores to a Job_Sleep")

func test_recreate_round_trips_through_registry() -> void:
	assert_eq(Job_Recreate.new().get_save_data(), {"type": "recreate"}, "recreate saves just its type")
	assert_true(JobSerializer.deserialize({"type": "recreate"}) is Job_Recreate, "recreate restores to a Job_Recreate")

# --- SaveManager ref-helper null guards --------------------------------------

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
