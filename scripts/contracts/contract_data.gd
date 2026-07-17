class_name ContractData
extends RefCounted

## One delivery contract (WI-14): "Deliver `amount` of `resource` by cycle
## `deadline_cycle` for `unit_price` each; `penalty` credits on failure."
## A runtime object, not a .tres - contracts are generated, not authored.
## The unit price is locked at offer time (that's the point of contracts);
## payout is all-or-nothing: full completion pays amount x unit_price, while
## goods shipped before a failure only earn ordinary market sell price at
## resolution.

enum State { OFFERED, ACCEPTED, FULFILLED, FAILED, EXPIRED }

var id: int = 0
var resource: ResourceData
var amount: int = 0
## Credits per unit, locked at offer time (market sell price x premium).
var unit_price: int = 0
var deadline_cycle: int = 0
var penalty: int = 0
## Issuing party name - pure flavor v1.
var issuer: String = ""
var state: State = State.OFFERED
## Units already picked up by a trader/courier.
var delivered: int = 0
var offered_cycle: int = 0
## The near-deadline alert fired (once per contract).
var deadline_warned: bool = false

func remaining() -> int:
	return maxi(amount - delivered, 0)

func total_payout() -> int:
	return amount * unit_price

func is_final_cycle(cycle: int) -> bool:
	return state == State.ACCEPTED and cycle == deadline_cycle

func state_name() -> String:
	match state:
		State.OFFERED: return "Offered"
		State.ACCEPTED: return "Active"
		State.FULFILLED: return "Fulfilled"
		State.FAILED: return "Failed"
		State.EXPIRED: return "Expired"
	return "?"

# --- persistence ----------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"id": id,
		"resource": String(resource.id) if resource != null else "",
		"amount": amount,
		"unit_price": unit_price,
		"deadline": deadline_cycle,
		"penalty": penalty,
		"issuer": issuer,
		"state": state,
		"delivered": delivered,
		"offered_cycle": offered_cycle,
		"warned": deadline_warned,
	}

static func from_dict(data: Dictionary) -> ContractData:
	var resource: ResourceData = Global.save_manager.get_resource_by_id(StringName(String(data.get("resource", ""))))
	if resource == null:
		return null
	var contract := ContractData.new()
	contract.id = int(data.get("id", 0))
	contract.resource = resource
	contract.amount = int(data.get("amount", 0))
	contract.unit_price = int(data.get("unit_price", 0))
	contract.deadline_cycle = int(data.get("deadline", 0))
	contract.penalty = int(data.get("penalty", 0))
	contract.issuer = String(data.get("issuer", ""))
	contract.state = int(data.get("state", State.OFFERED)) as State
	contract.delivered = int(data.get("delivered", 0))
	contract.offered_cycle = int(data.get("offered_cycle", 0))
	contract.deadline_warned = bool(data.get("warned", false))
	return contract
