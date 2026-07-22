extends GutTest

## Unit tests for the WI-38 A2 shield save block: ShieldComponent's capacitor
## charge and hysteresis state have to survive a save/load, or quick-saving mid-raid
## hands every bubble back at full charge (RaidManager restores the pirates
## faithfully, so the fight came back easier than it was left).
##
## The component is constructed bare - never added to a tree, no owner_module - so
## effective_capacity() falls through to the authored `capacity` and nothing here
## touches Global. ready_constructed() (which needs TimeManager) is deliberately not
## called; the fields it would seed are set directly instead.

var shield: ShieldComponent

func before_each() -> void:
	shield = autofree(ShieldComponent.new())
	shield.capacity = 200.0
	shield.reengage_fraction = 0.25

## Stand-in for ready_constructed()'s initial fill, minus the tree/TimeManager work.
func _seed(charge: float, online: bool) -> void:
	shield._charge = charge
	shield._online = online

func test_charge_and_online_round_trip() -> void:
	_seed(60.0, true)
	var data: Dictionary = shield.get_save_data()
	_seed(200.0, true) # simulate the fresh-generator re-seed a load starts from
	shield.load_save_data(data)
	assert_almost_eq(shield.charge(), 60.0, 0.001, "a drained capacitor restores drained")
	assert_true(shield.is_online(), "an online bubble restores online")

func test_offline_state_survives_the_round_trip() -> void:
	# Below reengage_fraction: re-deriving from charge alone would put this back
	# online. The saved hysteresis flag has to win.
	_seed(20.0, false)
	shield.load_save_data(shield.get_save_data())
	assert_false(shield.is_online(), "a knocked-out bubble stays out until it recharges")

func test_charge_clamps_to_capacity_on_load() -> void:
	# A save written while a +capacity upgrade was active, loaded after that upgrade
	# failed to resolve (load_upgrade_save_data warns and skips a renamed id).
	shield.load_save_data({"charge": 900.0, "online": true})
	assert_almost_eq(shield.charge(), 200.0, 0.001, "charge can't exceed the bank it loads into")
	assert_almost_eq(shield.charge_fraction(), 1.0, 0.001, "and the fraction stays in range")

func test_negative_charge_clamps_to_zero() -> void:
	shield.load_save_data({"charge": -50.0, "online": false})
	assert_almost_eq(shield.charge(), 0.0, 0.001, "a corrupt negative charge floors at empty")

func test_absent_keys_leave_the_pristine_seed_alone() -> void:
	# ModuleBase only calls load_save_data when the key exists, but an empty dict
	# (pre-WI-38 save shape) must still be a no-op rather than a wipe.
	_seed(150.0, true)
	shield.load_save_data({})
	assert_almost_eq(shield.charge(), 150.0, 0.001, "missing charge keeps what ready_constructed seeded")
	assert_true(shield.is_online(), "missing online derives from the surviving charge")
