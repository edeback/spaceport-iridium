extends GutTest

## Unit tests for WI-52's per-cycle rate tracker (ResourceRateTracker).
## Constructed directly - no Global, no nodes, no TimeManager instance.

const ID: StringName = &"iron"
## Round numbers so the expected slopes are exact rather than "about right".
const HOURS_PER_CYCLE: float = 10.0

func _tracker(capacity: int = 96, window: float = 24.0, spacing: float = 0.25,
		minimum: int = 3) -> ResourceRateTracker:
	var tracker := ResourceRateTracker.new()
	tracker.capacity = capacity
	tracker.window_hours = window
	tracker.sample_spacing_hours = spacing
	tracker.min_samples = minimum
	tracker.hours_per_cycle = HOURS_PER_CYCLE
	return tracker

## `count` samples one hour apart, rising by `per_hour` each hour from `start`.
func _feed_linear(tracker: ResourceRateTracker, count: int, per_hour: float,
		start: float = 0.0, first_hour: float = 0.0) -> float:
	var hour: float = first_hour
	for i: int in count:
		tracker.sample(ID, hour, roundi(start + per_hour * float(i)))
		hour += 1.0
	return hour

# --- constant slope ----------------------------------------------------------

func test_constant_production_reads_back_exactly() -> void:
	var tracker := _tracker()
	_feed_linear(tracker, 12, 5.0)
	# +5/hour over a 10-hour cycle is +50/cycle.
	assert_almost_eq(tracker.rate_per_cycle(ID), 50.0, 0.0001, "constant slope scaled to a cycle")

func test_constant_consumption_is_negative() -> void:
	var tracker := _tracker()
	_feed_linear(tracker, 12, -2.0, 500.0)
	assert_almost_eq(tracker.rate_per_cycle(ID), -20.0, 0.0001, "draining reads negative")

func test_flat_stock_reads_zero_not_no_data() -> void:
	var tracker := _tracker()
	_feed_linear(tracker, 12, 0.0, 100.0)
	assert_true(ResourceRateTracker.has_rate(tracker.rate_per_cycle(ID)), "a flat line is data")
	assert_almost_eq(tracker.rate_per_cycle(ID), 0.0, 0.0001, "flat stock is 0.0/cycle")

# --- spikes ------------------------------------------------------------------

func test_a_single_spike_does_not_read_as_its_magnitude() -> void:
	# Eleven flat samples then one haul of +40. Last-minus-first would call this
	# +40 over the window; least squares must not.
	var tracker := _tracker()
	var hour: float = _feed_linear(tracker, 11, 0.0, 100.0)
	tracker.sample(ID, hour, 140)
	var rate: float = tracker.rate_per_cycle(ID)
	assert_true(rate > 0.0, "the deposit still registers as positive")
	assert_lt(rate, 40.0, "one deposit is not read as its full magnitude per cycle")

func test_spike_matters_less_the_longer_the_window_is() -> void:
	var short_window := _tracker(96, 6.0)
	var long_window := _tracker(96, 24.0)
	for tracker: ResourceRateTracker in [short_window, long_window]:
		var hour: float = _feed_linear(tracker, 23, 0.0, 100.0)
		tracker.sample(ID, hour, 140)
	assert_gt(short_window.rate_per_cycle(ID), long_window.rate_per_cycle(ID),
		"the same spike moves a short window more than a long one")

# --- insufficient data -------------------------------------------------------

func test_never_sampled_is_no_data() -> void:
	var tracker := _tracker()
	assert_false(ResourceRateTracker.has_rate(tracker.rate_per_cycle(&"nothing")),
		"an untracked id has no rate")

func test_fewer_than_min_samples_is_no_data_not_zero() -> void:
	var tracker := _tracker(96, 24.0, 0.25, 3)
	_feed_linear(tracker, 2, 5.0)
	var rate: float = tracker.rate_per_cycle(ID)
	assert_false(ResourceRateTracker.has_rate(rate), "two samples is not a rate")
	assert_ne(rate, 0.0, "and specifically is not a fabricated 0.0")

func test_min_samples_boundary() -> void:
	var tracker := _tracker(96, 24.0, 0.25, 3)
	_feed_linear(tracker, 3, 5.0)
	assert_true(ResourceRateTracker.has_rate(tracker.rate_per_cycle(ID)),
		"exactly min_samples is enough")

func test_samples_older_than_the_window_do_not_count_toward_the_minimum() -> void:
	# Three samples, then a 100-hour gap, then two more. Only two are in a 24-hour
	# window, so there is no rate even though five samples are retained.
	var tracker := _tracker(96, 24.0, 0.25, 3)
	_feed_linear(tracker, 3, 5.0)
	tracker.sample(ID, 100.0, 500)
	tracker.sample(ID, 101.0, 505)
	assert_eq(tracker.sample_count(ID), 5, "all five are retained")
	assert_false(ResourceRateTracker.has_rate(tracker.rate_per_cycle(ID)),
		"but only two are in the window, which is below the minimum")

# --- pause -------------------------------------------------------------------

func test_a_paused_stretch_holds_the_rate() -> void:
	# A pause emits no slow_tick, so no samples accrue at all. The window is
	# anchored to the newest SAMPLE rather than to "now" - which is why the rate
	# holds at its real value instead of decaying toward zero the way a
	# wall-clock window would.
	var tracker := _tracker()
	_feed_linear(tracker, 12, 5.0)
	assert_almost_eq(tracker.rate_per_cycle(ID), 50.0, 0.0001, "the rate before the pause")
	for _tick: int in 100:
		assert_almost_eq(tracker.rate_per_cycle(ID), 50.0, 0.0001,
			"and it is still that after a long stretch with no samples")

func test_speed_does_not_change_the_rate() -> void:
	# 1x and 4x differ only in how much real time passes between ticks; the
	# sim-hour stamps are identical, and so the rates must be.
	var at_1x := _tracker()
	var at_4x := _tracker()
	_feed_linear(at_1x, 12, 5.0)
	_feed_linear(at_4x, 12, 5.0)
	assert_almost_eq(at_1x.rate_per_cycle(ID), at_4x.rate_per_cycle(ID), 0.0001,
		"identical sim-hour stamps give identical rates")

# --- decimation --------------------------------------------------------------

func test_samples_closer_than_the_spacing_are_dropped() -> void:
	var tracker := _tracker(96, 24.0, 0.25)
	assert_true(tracker.sample(ID, 0.0, 10), "the first sample always lands")
	assert_false(tracker.sample(ID, 0.1, 11), "0.1h after the last is inside the spacing")
	assert_true(tracker.sample(ID, 0.25, 12), "exactly the spacing lands")
	assert_eq(tracker.sample_count(ID), 2, "only the two accepted samples are held")

func test_a_non_advancing_stamp_is_refused() -> void:
	var tracker := _tracker()
	tracker.sample(ID, 5.0, 10)
	assert_false(tracker.sample(ID, 5.0, 99), "the same stamp twice is refused")
	assert_false(tracker.sample(ID, 1.0, 99), "a backwards stamp is refused")
	assert_eq(tracker.sample_count(ID), 1, "and neither is retained")

# --- ring buffer -------------------------------------------------------------

func test_the_buffer_never_grows_past_its_capacity() -> void:
	var tracker := _tracker(8)
	_feed_linear(tracker, 40, 1.0)
	assert_eq(tracker.sample_count(ID), 8, "count saturates at the capacity")

func test_the_buffer_overwrites_oldest_first() -> void:
	# Ten hours flat, then ten hours climbing, into an 8-slot buffer. If the wrap
	# kept the oldest samples the slope would come out flatter than +3/hour.
	var tracker := _tracker(8, 24.0)
	var hour: float = _feed_linear(tracker, 10, 0.0, 100.0)
	_feed_linear(tracker, 10, 3.0, 100.0, hour)
	assert_almost_eq(tracker.rate_per_cycle(ID), 30.0, 0.0001,
		"only the newest eight samples are in the fit")

func test_capacity_is_per_resource() -> void:
	var tracker := _tracker(8)
	_feed_linear(tracker, 40, 1.0)
	tracker.sample(&"steel", 0.0, 5)
	assert_eq(tracker.sample_count(ID), 8, "one resource's buffer saturates")
	assert_eq(tracker.sample_count(&"steel"), 1, "without touching another's")

func test_clear_drops_every_buffer() -> void:
	var tracker := _tracker()
	_feed_linear(tracker, 12, 5.0)
	tracker.clear()
	assert_eq(tracker.sample_count(ID), 0, "history is gone")
	assert_false(ResourceRateTracker.has_rate(tracker.rate_per_cycle(ID)),
		"and reads as no data again, not 0.0")

func test_tracked_ids_lists_what_has_been_sampled() -> void:
	var tracker := _tracker()
	tracker.sample(ID, 0.0, 1)
	tracker.sample(&"steel", 0.0, 1)
	var ids: Array[StringName] = tracker.tracked_ids()
	assert_eq(ids.size(), 2, "both resources are tracked")
	assert_true(ids.has(ID) and ids.has(&"steel"), "and both are named")
