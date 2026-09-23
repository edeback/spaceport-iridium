extends GutTest

## WI-47 M10: pawn kinds as scanned data, plus the shared WeightedPick the kind
## and ship rolls both go through. Pure - no manager, no scene, no Global.

func before_each() -> void:
	PawnData.clear_for_test()

func after_each() -> void:
	# Puts the shipped content back in every cache at once (WI-74 §2).
	ContentPaths.invalidate()

func _kind(id: String, role: PawnData.Role, weight: float = 1.0, price_mult: float = 1.0) -> PawnData:
	var kind := PawnData.new()
	kind.id = StringName(id)
	kind.display_name = id.capitalize()
	kind.role = role
	kind.weight = weight
	kind.hire_price_mult = price_mult
	kind.scene = PackedScene.new()
	PawnData.register_for_test(kind)
	return kind

func _ids(kinds: Array[PawnData]) -> Array[StringName]:
	var out: Array[StringName] = []
	for kind: PawnData in kinds:
		out.append(kind.id)
	return out

# --- roles ----------------------------------------------------------------------

func test_a_role_only_sees_its_own_kinds() -> void:
	_kind("crew", PawnData.Role.CREW)
	_kind("visitor", PawnData.Role.VISITOR)
	assert_eq(_ids(PawnData.for_role(PawnData.Role.CREW)), [&"crew"] as Array[StringName])
	assert_eq(_ids(PawnData.for_role(PawnData.Role.VISITOR)), [&"visitor"] as Array[StringName])

func test_a_mod_can_add_a_second_kind_to_a_role() -> void:
	# The point of M10: CrewManager held one scene, so "crew" was one thing.
	_kind("crew", PawnData.Role.CREW)
	_kind("coolmod.synthetic", PawnData.Role.CREW)
	assert_eq(PawnData.for_role(PawnData.Role.CREW).size(), 2)

func test_a_zero_weight_kind_is_never_rolled() -> void:
	# Weight 0 is how a kind exists only to be summoned by a mod's own code.
	_kind("crew", PawnData.Role.CREW)
	_kind("coolmod.unique", PawnData.Role.CREW, 0.0)
	assert_eq(_ids(PawnData.for_role(PawnData.Role.CREW)), [&"crew"] as Array[StringName])

func test_a_kind_with_no_scene_is_never_rolled() -> void:
	var broken: PawnData = _kind("broken", PawnData.Role.CREW)
	broken.scene = null
	assert_eq(PawnData.for_role(PawnData.Role.CREW).size(), 0)

func test_role_pools_are_deterministic_in_id_order() -> void:
	_kind("zulu", PawnData.Role.CREW)
	_kind("alpha", PawnData.Role.CREW)
	assert_eq(_ids(PawnData.for_role(PawnData.Role.CREW)), [&"alpha", &"zulu"] as Array[StringName])

func test_an_unknown_id_resolves_to_null() -> void:
	# What a hire queued before its mod was uninstalled looks like on arrival.
	_kind("crew", PawnData.Role.CREW)
	assert_null(PawnData.by_id(&"absentmod.synthetic"))

func test_pick_respects_weights() -> void:
	var pool: Array[PawnData] = [
		_kind("common", PawnData.Role.CREW, 3.0),
		_kind("rare", PawnData.Role.CREW, 1.0),
	]
	pool.sort_custom(func(a: PawnData, b: PawnData) -> bool: return String(a.id) < String(b.id))
	# sorted: common, rare -> common covers [0, 0.75)
	assert_eq(PawnData.pick(pool, 0.1).id, &"common")
	assert_eq(PawnData.pick(pool, 0.9).id, &"rare")

func test_pick_from_an_empty_pool_is_null() -> void:
	assert_null(PawnData.pick([] as Array[PawnData], 0.5))

# --- the shipped data -----------------------------------------------------------

func test_the_base_game_declares_a_crew_and_a_visitor_kind() -> void:
	PawnData.clear_for_test()
	assert_gt(PawnData.for_role(PawnData.Role.CREW).size(), 0, "something has to be hireable")
	assert_gt(PawnData.for_role(PawnData.Role.VISITOR).size(), 0, "something has to visit")

func test_every_vanilla_kind_declares_a_scene() -> void:
	PawnData.clear_for_test()
	for kind: PawnData in PawnData.all():
		assert_not_null(kind.scene, "%s declares no scene" % kind.id)

# --- WeightedPick (shared with ShipData) ----------------------------------------

func test_weighted_pick_is_empty_safe() -> void:
	assert_eq(WeightedPick.index_for(PackedFloat32Array(), 0.5), -1)

func test_weighted_pick_rejects_an_all_zero_pool() -> void:
	assert_eq(WeightedPick.index_for(PackedFloat32Array([0.0, 0.0]), 0.5), -1)

func test_weighted_pick_treats_negative_weight_as_zero() -> void:
	assert_eq(WeightedPick.index_for(PackedFloat32Array([-5.0, 1.0]), 0.0), 1)

func test_weighted_pick_boundaries_always_land_on_an_entry() -> void:
	# randf() can return exactly 0.0, and float accumulation can push a roll of
	# 1.0 past the last bucket; neither may yield -1.
	var weights := PackedFloat32Array([1.0, 1.0, 1.0])
	assert_eq(WeightedPick.index_for(weights, 0.0), 0)
	assert_between(WeightedPick.index_for(weights, 1.0), 0, 2)

func test_weighted_pick_bucket_edges() -> void:
	# 3:1 -> index 0 covers [0, 0.75), index 1 covers [0.75, 1).
	var weights := PackedFloat32Array([3.0, 1.0])
	assert_eq(WeightedPick.index_for(weights, 0.74), 0)
	assert_eq(WeightedPick.index_for(weights, 0.75), 1)
