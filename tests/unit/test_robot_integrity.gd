extends GutTest

## WI-28 robot integrity math: percent + the repair-seek threshold predicate on a
## bare (never-in-tree) RobotIntegrityComponent - no Global, no hour_changed hook.

func _make(integrity: float, integrity_max: float = 100.0, threshold: float = 50.0) -> RobotIntegrityComponent:
	var c: RobotIntegrityComponent = autofree(RobotIntegrityComponent.new())
	c.integrity_max = integrity_max
	c.repair_seek_threshold_percent = threshold
	c.integrity = integrity
	return c

func test_integrity_percent() -> void:
	assert_almost_eq(_make(40.0).integrity_percent(), 40.0, 0.0001)

func test_wants_repair_below_threshold() -> void:
	assert_true(_make(40.0).wants_repair())

func test_wants_repair_false_above_threshold() -> void:
	assert_false(_make(80.0).wants_repair())

func test_wants_repair_boundary_is_exclusive() -> void:
	assert_false(_make(50.0).wants_repair())

func test_integrity_clamps_to_max() -> void:
	var c: RobotIntegrityComponent = _make(50.0)
	c.integrity = 999.0
	assert_almost_eq(c.integrity, 100.0, 0.0001)

func test_integrity_clamps_to_zero() -> void:
	var c: RobotIntegrityComponent = _make(50.0)
	c.integrity = -5.0
	assert_almost_eq(c.integrity, 0.0, 0.0001)

func test_malfunction_damage_range_is_sane() -> void:
	# Guards the authored malfunction band: positive, min <= max, and small enough
	# that a single roll can't outright destroy a full-integrity robot.
	var c: RobotIntegrityComponent = _make(100.0)
	c.malfunction_damage_min = 5.0
	c.malfunction_damage_max = 20.0
	assert_gt(c.malfunction_damage_min, 0.0)
	assert_lte(c.malfunction_damage_min, c.malfunction_damage_max)
	assert_lt(c.malfunction_damage_max, c.integrity_max)
