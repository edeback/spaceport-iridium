class_name Action_Pay
extends ActionBase

## Settle up at the register (WI-44). Instant.
##
## The vendor is duck-typed through two methods: `roll_visit_price()` for the
## bill and `complete_sale(pawn, amount)` for the consequences of a completed
## sale. Keeping the second one on the component is what lets this action stay
## generic - the shop books its own income and applies its own visit mood, and a
## future paid service needs no change here.
##
## Going broke is not a failure: the charge is clamped to the wallet, so a
## customer that dipped below the rolled price still gets served for what they
## have. That is the shopping job's rule, kept.

@export var slot: JobTarget.Slot = JobTarget.Slot.A

func _init(vendor_slot: JobTarget.Slot = JobTarget.Slot.A) -> void:
	slot = vendor_slot
	complete_mode = CompleteMode.INSTANT

func on_start(job: Job) -> Status:
	var vendor: ComponentBase = _vendor(job)
	if vendor == null or job.pawn == null:
		return Status.FAILED
	var price: int = 0
	if vendor.has_method(&"roll_visit_price"):
		price = int(vendor.call(&"roll_visit_price"))
	var charge: int = mini(price, job.pawn.personal_credits)
	if charge > 0:
		job.pawn.spend_credits(charge)
		if vendor.has_method(&"complete_sale"):
			vendor.call(&"complete_sale", job.pawn, charge)
	# The receipt. Saved with the job, which is what makes on_resume idempotent.
	job.count = charge
	return Status.DONE

## Already paid. the shopping job documented the opposite behaviour as an accepted v1
## edge - it did not persist its paid flag, so a visit saved mid-session and
## reloaded charged the customer a second time. The bill lives in job.count now,
## so the resume is free.
func on_resume(job: Job) -> Status:
	return Status.DONE if job.count > 0 else on_start(job)

func report(_job: Job) -> String:
	return "Paying"

func _vendor(job: Job) -> ComponentBase:
	var slot_target: JobTarget = job.target(slot)
	if slot_target == null or not slot_target.is_alive():
		return null
	return slot_target.component()
