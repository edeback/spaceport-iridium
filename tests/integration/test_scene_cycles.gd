extends GutTest

## R6 (WI-69 §4, from the first audit): booting and tearing down the game does not
## leak. WI-68 F3 found each teardown leaking both module graphs; after the fix a
## New Game <-> menu cycle kept about 6 objects.
##
## Measured as loose objects (neither Node nor Resource) after each teardown. The
## first cycle warms caches that live for the process - the content registries,
## the preview cache, GDScript's own - so growth is judged from the second
## teardown on.

const CYCLES: int = 5
## Objects a boot/teardown cycle may keep, on average, after warm-up. Set from
## the first measurement under this fixture (see the WI-69 status block), with
## headroom; the regression it guards against was ~35 per cycle on this station
## and ~320 per load on the real quicksave.
const MAX_GROWTH_PER_CYCLE: float = 5.0

var fx: StationFixture

func before_each() -> void:
	fx = StationFixture.new(self)

func after_each() -> void:
	await fx.finish()

func test_boot_and_teardown_do_not_leak() -> void:
	var counts: Array[int] = []
	for cycle: int in CYCLES:
		assert_true(await fx.boot(), "boot %d" % (cycle + 1))
		assert_true(await fx.tick(TimeManager.SECONDS_PER_HOUR), "an hour of play on boot %d" % (cycle + 1))
		await fx.teardown()
		counts.append(StationFixture.loose_objects())
	var growth: float = float(counts[CYCLES - 1] - counts[0]) / float(CYCLES - 1)
	gut.p("loose objects after each teardown: %s (%.1f per cycle after warm-up)" % [counts, growth])
	assert_lt(growth, MAX_GROWTH_PER_CYCLE, "per-cycle growth after warm-up: %s" % [counts])
