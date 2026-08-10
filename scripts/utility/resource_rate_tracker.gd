class_name ResourceRateTracker
extends RefCounted

## Per-resource rate of change, in units per cycle (WI-52).
##
## Nothing in the game tracked one before this. [ResourceManager] walked its
## resource list on `slow_tick` and recalculated each total, and a total has no
## derivative - so the ledger had no rate column to fill and the vitals strip had
## no way to tell a falling vital from a low one. This is that missing piece: a
## fixed-capacity ring buffer of `(sim_hours, total)` samples per resource, and a
## least-squares slope over the most recent [member window_hours] of them.
##
## Five rules, each of which is a way this goes wrong if ignored:
##
##   - **Sim time, not wall time.** Samples are stamped with [TimeManager] hours,
##     so the same production reads the same at 1x and at 4x. A paused game emits
##     no `slow_tick` at all, so no samples accrue and the rate *holds its last
##     value* rather than decaying toward zero - the window is anchored to the
##     newest sample, not to "now", which is what makes that true for free.
##   - **Least squares, not last-minus-first.** One haul depositing 40 ore must
##     not read as `+40/cyc`. The slope over a window is the honest answer and it
##     is also cheap.
##   - **Decimated at the source.** `slow_tick` is 4 Hz sim-time, so a cycle is
##     960 ticks; retaining all of them would be a 960-entry buffer per resource
##     for no extra fidelity. [method sample] drops anything closer than
##     [member sample_spacing_hours] to the previous sample, so the caller stays
##     dumb (it just calls on every tick) and the decimation stays testable.
##   - **Too few samples is [constant NO_RATE], not `0.0`.** A newly tracked
##     resource has no rate, and `0.0` claims something false. This matters most
##     on load, where every buffer starts empty and a fabricated zero on a station
##     that is actually mining is a worse lie than a dash.
##   - **Never saved.** Derived state is re-derived (standing project rule) and
##     this re-derives within one window. The tracker is owned by the manager
##     *node* rather than stashed on the shared [ResourceData], because a `.tres`
##     survives a scene swap in Godot's resource cache and a new game would
##     otherwise inherit the previous run's samples - which is exactly WI-38's A8.
##
## Pure: no nodes, no [Global], no [SignalBus]. GUT constructs it directly.

## What [method rate_per_cycle] returns when there is not enough history to have
## an opinion. Deliberately not `0.0` - see the class docs. Test it with
## [method has_rate] rather than comparing against this value.
const NO_RATE: float = INF

## Samples retained per resource. One cycle's worth at the default spacing.
##
## Read when a resource's buffer is first allocated, so it must be set before the
## first [method sample] for that resource; [method clear] is the seam that makes
## a change take effect afterwards.
var capacity: int = 96

## How far back the slope looks, in sim-hours, measured from the newest sample.
## One cycle is the starting point: long enough that a single delivery does not
## dominate, short enough that a mine going offline shows up while the player
## still cares.
var window_hours: float = float(TimeManager.HOURS_PER_CYCLE)

## Minimum sim-hours between two retained samples. See "decimated at the source".
var sample_spacing_hours: float = 0.25

## Fewer in-window samples than this and the resource has no rate. Three is the
## floor a slope is meaningful at; two is a line through two points, which is
## last-minus-first wearing a hat.
var min_samples: int = 3

## Sim-hours per cycle, for scaling the slope. A field rather than a direct read
## of [constant TimeManager.HOURS_PER_CYCLE] so the class stays pure and a test
## can use round numbers.
var hours_per_cycle: float = float(TimeManager.HOURS_PER_CYCLE)

var _buffers: Dictionary[StringName, Buffer] = {}

## True when `rate` is a real measurement rather than [constant NO_RATE]. Callers
## format the dash from this; see [method LedgerModel.format_per_cycle].
static func has_rate(rate: float) -> bool:
	return is_finite(rate)

## Records `total` for `id` at `sim_hours`. Returns whether the sample was kept -
## false means it arrived too soon after the last one (the common case; see
## "decimated at the source") or that the clock did not move forward.
##
## A non-advancing stamp is rejected rather than replacing the previous sample:
## within one scene `TimeManager.total_sim_seconds` only ever grows, and a tracker
## does not outlive its scene, so a repeated or backwards stamp means a caller is
## sampling something other than sim time and silently rewriting history would
## hide that.
func sample(id: StringName, sim_hours: float, total: int) -> bool:
	var buffer: Buffer = _buffers.get(id)
	if buffer == null:
		buffer = Buffer.new(capacity)
		_buffers[id] = buffer
	elif sim_hours - buffer.newest_hours() < sample_spacing_hours:
		return false
	buffer.push(sim_hours, float(total))
	return true

## Units per cycle for `id`, or [constant NO_RATE] when there is not enough
## history. Positive is accumulating, negative is draining.
func rate_per_cycle(id: StringName) -> float:
	var buffer: Buffer = _buffers.get(id)
	if buffer == null:
		return NO_RATE
	var per_hour: float = buffer.slope_per_hour(window_hours, min_samples)
	if not has_rate(per_hour):
		return NO_RATE
	return per_hour * hours_per_cycle

## Retained samples for `id` - the assertion the ring-buffer tests are written
## against, and what a `dump_rates()` cheat prints so a dash can be told apart
## from a genuinely flat line.
func sample_count(id: StringName) -> int:
	var buffer: Buffer = _buffers.get(id)
	return buffer.count if buffer != null else 0

## Every id that has been sampled at least once.
func tracked_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in _buffers:
		ids.append(id)
	return ids

## Drops all history. Not needed on the normal load path (a scene reload builds a
## fresh manager and therefore a fresh tracker), but a changed [member capacity]
## only reaches existing resources through here, and a test wants the seam.
func clear() -> void:
	_buffers.clear()

## One resource's ring buffer. An inner class rather than two parallel
## dictionaries so the write index and the wrap arithmetic cannot drift apart.
class Buffer extends RefCounted:
	## Sim-hour stamps and totals, oldest-first once [member count] reaches the
	## capacity. `PackedFloat64Array` rather than `Array[float]`: the buffer is
	## allocated once and never grows, which is the property that matters.
	var hours: PackedFloat64Array = PackedFloat64Array()
	var totals: PackedFloat64Array = PackedFloat64Array()
	## Samples held, saturating at the capacity.
	var count: int = 0
	## Next write slot; wraps, which is what makes the overwrite oldest-first.
	var head: int = 0

	func _init(buffer_capacity: int) -> void:
		hours.resize(buffer_capacity)
		totals.resize(buffer_capacity)

	func capacity() -> int:
		return hours.size()

	func push(sim_hours: float, total: float) -> void:
		hours[head] = sim_hours
		totals[head] = total
		head = (head + 1) % capacity()
		count = mini(count + 1, capacity())

	## Sim-hours of the most recent sample, or -INF when empty - so a first sample
	## always clears the spacing gate without a separate empty check.
	func newest_hours() -> float:
		if count == 0:
			return -INF
		return hours[_slot(count - 1)]

	## Ordinal `index` counted oldest-first, mapped through the wrap.
	func _slot(index: int) -> int:
		return (head - count + index + capacity() * 2) % capacity()

	## Least-squares slope in units per sim-hour over the samples within `window`
	## hours of the newest one, or [constant ResourceRateTracker.NO_RATE].
	##
	## x is taken relative to the first in-window sample. `sim_hours` grows without
	## bound over a long run, and a regression on raw stamps in the thousands loses
	## most of its precision to the subtraction in `n*Sxx - Sx^2`.
	func slope_per_hour(window: float, minimum: int) -> float:
		if count < minimum:
			return ResourceRateTracker.NO_RATE
		var cutoff: float = newest_hours() - window
		var first: int = 0
		while first < count and hours[_slot(first)] < cutoff:
			first += 1
		var n: int = count - first
		if n < minimum:
			return ResourceRateTracker.NO_RATE
		var origin: float = hours[_slot(first)]
		var sum_x: float = 0.0
		var sum_y: float = 0.0
		var sum_xx: float = 0.0
		var sum_xy: float = 0.0
		for i: int in range(first, count):
			var slot: int = _slot(i)
			var x: float = hours[slot] - origin
			var y: float = totals[slot]
			sum_x += x
			sum_y += y
			sum_xx += x * x
			sum_xy += x * y
		var denominator: float = float(n) * sum_xx - sum_x * sum_x
		# Every retained sample landing on one instant is impossible through
		# `sample()` (it enforces spacing), but a caller feeding the buffer
		# directly must not get a division by zero disguised as a rate.
		if is_zero_approx(denominator):
			return ResourceRateTracker.NO_RATE
		return (float(n) * sum_xy - sum_x * sum_y) / denominator
