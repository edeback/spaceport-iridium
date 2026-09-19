extends GutTest

## R5, shortened (WI-69 §4): a working station runs a sim-day at 4x with the
## invariants checked every sim-hour.
##
## The first audit ran this for 120 sim-hours on the real quicksave and found the
## station clean; this keeps it running on every change. A mining bay feeds ore
## to a manned ore processor and a storeroom, which is enough to exercise
## hauling, reservations on both ends, OUTPUT and INPUT slots and a robot
## workforce at once.

const HOURS: int = 24

var fx: StationFixture

func before_each() -> void:
	fx = StationFixture.new(self)
	await fx.boot()

func after_each() -> void:
	await fx.finish()

func test_a_working_station_stays_clean_for_a_sim_day() -> void:
	fx.build_production_line()
	var steel_at_start: int = fx.world_total(&"steel")
	var clean_hours: int = 0
	for hour: int in HOURS:
		if not await fx.tick(TimeManager.SECONDS_PER_HOUR):
			break
		if fx.check_invariants("sim-hour %d" % (hour + 1)):
			clean_hours += 1
		else:
			break # one failing hour says it; the next 23 would repeat it
	assert_eq(clean_hours, HOURS, "every sim-hour ended with the invariants holding")
	# Nothing on this station consumes or produces steel, so any change is stock
	# that vanished or appeared - the "no silent resource loss" rule.
	assert_eq(fx.world_total(&"steel"), steel_at_start, "steel is conserved")
	assert_gt(mined_so_far(fx), 0, "the drones mined something, so the soak measured a working station")

## Every ore on the station, carried or stored.
static func mined_so_far(station: StationFixture) -> int:
	var total: int = 0
	for ore: StringName in [&"iron_ore", &"gold_ore", &"silicon_ore", &"iridium_ore", &"ice", &"carbon"]:
		total += station.world_total(ore)
	return total
