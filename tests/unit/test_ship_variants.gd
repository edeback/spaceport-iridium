extends GutTest

## WI-47 M7: raider variants as scanned data, and the eligible/weighted-pick rules
## RaidManager rolls a wave from. Pure - no manager, no scene, no Global. The
## registry is static and shared by every suite in a run, so each test rebuilds it.

func before_each() -> void:
	ShipData.clear_for_test()

func after_each() -> void:
	# Puts the shipped content back in every cache at once (WI-74 §2).
	ContentPaths.invalidate()

func _ship(id: String, weight: float = 1.0, min_strength: float = 0.0) -> ShipData:
	var ship := ShipData.new()
	ship.id = StringName(id)
	ship.display_name = id.capitalize()
	ship.weight = weight
	ship.min_strength = min_strength
	# eligible() requires a scene; the content of it is irrelevant to selection.
	ship.scene = PackedScene.new()
	ShipData.register_for_test(ship)
	return ship

func _ids(ships: Array[ShipData]) -> Array[StringName]:
	var out: Array[StringName] = []
	for ship: ShipData in ships:
		out.append(ship.id)
	return out

# --- eligibility ----------------------------------------------------------------

func test_a_variant_below_its_min_strength_never_appears() -> void:
	# Heavier raiders show up as the station grows, rather than ambushing a
	# starting base.
	_ship("raider")
	_ship("dreadnought", 1.0, 500.0)
	assert_eq(_ids(ShipData.eligible(10.0)), [&"raider"] as Array[StringName])

func test_it_appears_once_the_station_is_worth_it() -> void:
	_ship("raider")
	_ship("dreadnought", 1.0, 500.0)
	assert_eq(ShipData.eligible(500.0).size(), 2, "exactly at the threshold counts")

func test_a_zero_weight_variant_is_never_eligible() -> void:
	_ship("raider")
	_ship("parade_float", 0.0)
	assert_eq(_ids(ShipData.eligible(1000.0)), [&"raider"] as Array[StringName])

func test_a_variant_with_no_scene_is_never_eligible() -> void:
	# A mod whose scene failed to load must not produce an unspawnable pick.
	var broken: ShipData = _ship("broken")
	broken.scene = null
	assert_eq(ShipData.eligible(1000.0).size(), 0)

func test_eligibility_is_deterministic_in_id_order() -> void:
	# The pool feeds a weighted roll; the same seed must give the same wave
	# whatever order the directory scanned in.
	_ship("zulu")
	_ship("alpha")
	assert_eq(_ids(ShipData.eligible(0.0)), [&"alpha", &"zulu"] as Array[StringName])

# --- weighted pick --------------------------------------------------------------

func test_pick_from_an_empty_pool_is_null() -> void:
	assert_null(ShipData.pick([] as Array[ShipData], 0.5))

func test_pick_with_all_weights_zero_is_null() -> void:
	var pool: Array[ShipData] = [_ship("a", 0.0), _ship("b", 0.0)]
	assert_null(ShipData.pick(pool, 0.5))

func test_pick_respects_the_weights() -> void:
	# a:3, b:1 -> a covers [0, 0.75), b covers [0.75, 1).
	var pool: Array[ShipData] = [_ship("a", 3.0), _ship("b", 1.0)]
	assert_eq(ShipData.pick(pool, 0.0).id, &"a")
	assert_eq(ShipData.pick(pool, 0.74).id, &"a")
	assert_eq(ShipData.pick(pool, 0.75).id, &"b")
	assert_eq(ShipData.pick(pool, 0.99).id, &"b")

func test_pick_is_total_at_both_ends() -> void:
	# randf() can return exactly 0.0, and floating point can put a roll of 1.0
	# past the last bucket - neither may yield null.
	var pool: Array[ShipData] = [_ship("a"), _ship("b")]
	assert_not_null(ShipData.pick(pool, 0.0))
	assert_not_null(ShipData.pick(pool, 1.0))

func test_a_single_variant_always_wins() -> void:
	var pool: Array[ShipData] = [_ship("only")]
	for roll: float in [0.0, 0.3, 0.99]:
		assert_eq(ShipData.pick(pool, roll).id, &"only")

# --- the shipped data -----------------------------------------------------------

func test_the_base_game_declares_a_raider_available_from_the_start() -> void:
	ShipData.clear_for_test()
	var pool: Array[ShipData] = ShipData.eligible(0.0)
	assert_gt(pool.size(), 0, "a brand-new station must still be raidable")
	for ship: ShipData in pool:
		assert_not_null(ship.scene, "%s declares no scene" % ship.id)
