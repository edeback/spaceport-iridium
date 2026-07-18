extends GutTest

## Trivial smoke test: proves the GUT vendor drop runs headless and the
## suite harness is wired up. Real coverage lives in the sibling test_*.gd files.

func test_gut_runs() -> void:
	assert_eq(2 + 2, 4, "arithmetic still works")

func test_true_is_true() -> void:
	assert_true(true)
