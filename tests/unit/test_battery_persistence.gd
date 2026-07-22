extends GutTest

## Unit tests for the WI-39 battery save block: BatteryComponent's charge bank has
## to survive a save/load. Without it every battery reloads empty, so a station
## deliberately built to run its night cycle off stored power comes back with no
## reserve - the same unsaved-stateful-field bug as the shield capacitor (WI-38 A2).
##
## The component is constructed bare - never added to a tree, no owner_module - so
## nothing here touches Global. The charge/discharge arithmetic is exercised too:
## it's pure (delta in, float out) and the restore is only worth anything if the
## bank keeps discharging from the level it came back at.

var battery: BatteryComponent

func before_each() -> void:
	battery = autofree(BatteryComponent.new())
	battery.max_power_stored = 1000.0
	battery.max_power_throughput = 100.0
	battery.charge_efficiency = 1.0
	battery.can_discharge = true

# --- save/load round trip -----------------------------------------------------

func test_partial_charge_round_trips() -> void:
	battery.total_power_stored = 400.0
	var data: Dictionary = battery.get_save_data()
	battery.total_power_stored = 0.0 # a freshly placed battery starts empty
	battery.load_save_data(data)
	assert_almost_eq(battery.total_power_stored, 400.0, 0.001, "a 40% bank comes back at 40%, not empty and not full")

func test_empty_and_full_round_trip() -> void:
	battery.total_power_stored = 0.0
	battery.load_save_data(battery.get_save_data())
	assert_almost_eq(battery.total_power_stored, 0.0, 0.001, "empty stays empty")
	battery.total_power_stored = 1000.0
	battery.load_save_data(battery.get_save_data())
	assert_almost_eq(battery.total_power_stored, 1000.0, 0.001, "full stays full")

func test_charge_clamps_to_capacity_on_load() -> void:
	# A hand-edited save, or a .tres whose max_power_stored was reduced after the
	# save was written. Restoring an over-full bank would hand out free power.
	battery.load_save_data({"stored": 5000.0})
	assert_almost_eq(battery.total_power_stored, 1000.0, 0.001, "charge can't exceed the bank it loads into")

func test_negative_charge_clamps_to_zero() -> void:
	battery.load_save_data({"stored": -50.0})
	assert_almost_eq(battery.total_power_stored, 0.0, 0.001, "a corrupt negative charge floors at empty")

func test_absent_key_leaves_the_pristine_value_alone() -> void:
	# ModuleBase only calls load_save_data when the key exists, but an empty dict
	# (a pre-WI-39 save's shape) must be a no-op rather than a wipe.
	battery.total_power_stored = 250.0
	battery.load_save_data({})
	assert_almost_eq(battery.total_power_stored, 250.0, 0.001, "missing key keeps whatever the component already had")

# --- the point of restoring it ------------------------------------------------

func test_restored_bank_discharges_from_the_restored_level() -> void:
	battery.load_save_data({"stored": 400.0})
	# One sim-second of full-throughput draw off the restored bank.
	var generated: float = battery.generate_power(1.0, 100.0)
	assert_almost_eq(generated, 100.0, 0.001, "throughput-limited draw is served in full")
	assert_almost_eq(battery.total_power_stored, 300.0, 0.001, "and comes out of the restored 400, not a reset 0")

func test_discharge_is_limited_by_what_was_restored() -> void:
	battery.load_save_data({"stored": 30.0})
	var generated: float = battery.generate_power(1.0, 100.0)
	assert_almost_eq(generated, 30.0, 0.001, "a nearly-flat restored bank only gives what it has")
	assert_almost_eq(battery.total_power_stored, 0.0, 0.001, "and empties doing it")

func test_recharge_tops_up_from_the_restored_level() -> void:
	battery.load_save_data({"stored": 950.0})
	var stored: float = battery.store_power(1.0, 100.0)
	assert_almost_eq(stored, 50.0, 0.001, "charging stops at the cap, not at the throughput")
	assert_almost_eq(battery.total_power_stored, 1000.0, 0.001, "leaving the bank exactly full")
