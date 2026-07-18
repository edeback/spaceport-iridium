extends GutTest

## Unit tests for ContractData resolution rules (scripts/contracts/
## contract_data.gd) - the pure per-contract math the ContractManager drives
## deadlines and payouts off. from_dict is not covered here: it resolves the
## resource through Global.save_manager, which these detached tests avoid.

var resource: ResourceData

func before_each() -> void:
	resource = ResourceData.new()
	resource.id = &"ore"
	resource.name = "Ore"

func _contract(amount: int, unit_price: int) -> ContractData:
	var contract := ContractData.new()
	contract.resource = resource
	contract.amount = amount
	contract.unit_price = unit_price
	return contract

# --- payout & remaining -------------------------------------------------------

func test_total_payout_is_amount_times_unit_price() -> void:
	assert_eq(_contract(10, 25).total_payout(), 250)

func test_remaining_decreases_with_delivery() -> void:
	var contract := _contract(10, 5)
	assert_eq(contract.remaining(), 10, "nothing delivered yet")
	contract.delivered = 4
	assert_eq(contract.remaining(), 6)

func test_remaining_never_goes_negative() -> void:
	var contract := _contract(10, 5)
	contract.delivered = 15 # over-delivered somehow
	assert_eq(contract.remaining(), 0, "clamped at zero, not negative")

# --- final-cycle rule ---------------------------------------------------------

func test_is_final_cycle_only_when_accepted_and_at_deadline() -> void:
	var contract := _contract(10, 5)
	contract.deadline_cycle = 7
	contract.state = ContractData.State.ACCEPTED
	assert_true(contract.is_final_cycle(7), "accepted contract on its deadline cycle")
	assert_false(contract.is_final_cycle(6), "not yet the deadline")
	assert_false(contract.is_final_cycle(8), "already past the deadline")

func test_is_final_cycle_false_for_unaccepted_contract() -> void:
	var contract := _contract(10, 5)
	contract.deadline_cycle = 7
	contract.state = ContractData.State.OFFERED
	assert_false(contract.is_final_cycle(7), "an offered (not accepted) contract is never 'final cycle'")

# --- state naming & serialization shape --------------------------------------

func test_state_name_maps_each_state() -> void:
	var contract := _contract(1, 1)
	contract.state = ContractData.State.OFFERED
	assert_eq(contract.state_name(), "Offered")
	contract.state = ContractData.State.ACCEPTED
	assert_eq(contract.state_name(), "Active")
	contract.state = ContractData.State.FULFILLED
	assert_eq(contract.state_name(), "Fulfilled")
	contract.state = ContractData.State.FAILED
	assert_eq(contract.state_name(), "Failed")
	contract.state = ContractData.State.EXPIRED
	assert_eq(contract.state_name(), "Expired")

func test_to_dict_captures_the_contract_fields() -> void:
	var contract := _contract(10, 25)
	contract.id = 3
	contract.deadline_cycle = 6
	contract.delivered = 2
	contract.state = ContractData.State.ACCEPTED
	var data: Dictionary = contract.to_dict()
	assert_eq(data["id"], 3)
	assert_eq(data["resource"], "ore", "serialized by resource id")
	assert_eq(data["amount"], 10)
	assert_eq(data["unit_price"], 25)
	assert_eq(data["deadline"], 6)
	assert_eq(data["delivered"], 2)
	assert_eq(int(data["state"]), int(ContractData.State.ACCEPTED))
