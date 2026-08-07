extends GutTest

## Unit tests for RobotDesignation, the pure half of robot naming ("Mining Droid
## 2"). All static - the live half (which robots count as "used") is a group scan
## in RobotPawnBase and isn't touched here.

# --- next_index ---------------------------------------------------------------

func test_first_robot_is_one() -> void:
	assert_eq(RobotDesignation.next_index(PackedInt32Array([])), 1, "numbering starts at 1, not 0")

func test_counts_up_from_a_contiguous_run() -> void:
	# Two Mining Bays: the second bay's drones continue the station-wide run
	# instead of restarting at 1.
	assert_eq(RobotDesignation.next_index(PackedInt32Array([1, 2, 3])), 4, "continues past the highest")

func test_fills_the_lowest_gap() -> void:
	# A destroyed drone frees its number; the bay's replacement takes it back
	# rather than climbing forever.
	assert_eq(RobotDesignation.next_index(PackedInt32Array([1, 3])), 2, "reuses the freed number")
	assert_eq(RobotDesignation.next_index(PackedInt32Array([2, 3, 4])), 1, "including a gap at the start")

func test_ignores_unallocated_and_duplicate_entries() -> void:
	# 0 = unallocated (a robot mid-_ready); duplicates can't happen but must not
	# skip a number if they ever did.
	assert_eq(RobotDesignation.next_index(PackedInt32Array([0, 0, 1])), 2, "0 is not a number in use")
	assert_eq(RobotDesignation.next_index(PackedInt32Array([-4, 1, 2])), 3, "negatives ignored too")
	assert_eq(RobotDesignation.next_index(PackedInt32Array([1, 1, 2])), 3, "duplicates count once")

func test_order_does_not_matter() -> void:
	assert_eq(RobotDesignation.next_index(PackedInt32Array([5, 1, 4, 2])), 3, "unsorted input still finds the gap")

func test_allocating_in_sequence_never_collides() -> void:
	# The real usage pattern: allocate, keep, allocate again. Six drones across
	# two bays must come out 1..6 with no repeats.
	var used: PackedInt32Array = []
	for i: int in 6:
		var index: int = RobotDesignation.next_index(used)
		assert_false(used.has(index), "allocation %d handed out a number already in use" % i)
		used.append(index)
	assert_eq(Array(used), [1, 2, 3, 4, 5, 6], "six robots number 1 through 6")

# --- format_name --------------------------------------------------------------

func test_format_name_appends_the_number() -> void:
	assert_eq(RobotDesignation.format_name("Mining Droid", 2), "Mining Droid 2", "designation then number")
	assert_eq(RobotDesignation.format_name("Hauling Droid", 11), "Hauling Droid 11", "no padding")

func test_format_name_drops_a_missing_number() -> void:
	assert_eq(RobotDesignation.format_name("Mining Droid", 0), "Mining Droid", "unallocated reads as the bare kind")
	assert_eq(RobotDesignation.format_name("Mining Droid", -1), "Mining Droid", "never 'Mining Droid -1'")
