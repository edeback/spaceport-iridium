class_name ClaimSpec
extends RefCounted

## One reservation held by a Job (WI-44): "this job has 12 units of withdraw
## reserved against that storage", "this job holds a slot in that sleep pod".
##
## Doubles as a REQUEST (what JobDriver.required_claims() returns, so a restored
## job can re-acquire what it was holding) and as the RECORD the ClaimRegistry
## keeps. `payload` is only filled in on the record side.
##
## Kind lives here rather than on ClaimRegistry so that the dependency runs one
## way - the registry knows about specs, specs know nothing about the registry.
## Mutual class_name references parse, but a one-way edge is cheaper to reason
## about and keeps ClaimSpec usable in pure tests with no registry at all.

enum Kind {
	SLOT,               ## a capacity-limited occupancy: bunk, charger pad, shop counter, medical bed
	ANCHOR,             ## a specific authored anchor on a PathComponent (payload = the AnchorDef)
	STORAGE_WITHDRAW,   ## `amount` units reserved to be taken out of a storage
	STORAGE_DEPOSIT,    ## `amount` units of space reserved to be put into a storage
	PILE,               ## `amount` units reserved on a ResourcePile
	WORK,               ## exclusive "I am the worker at this component"
}

var target: Object = null
var kind: Kind = Kind.SLOT
var amount: int = 1
## Whatever the target's take_claim() handed back - the claimed AnchorDef for
## ANCHOR, usually null for everything else. Opaque to the registry; passed back
## verbatim on release so the target can undo exactly what it did.
var payload: Variant = null

static func make(claim_target: Object, claim_kind: Kind, claim_amount: int = 1) -> ClaimSpec:
	var spec := ClaimSpec.new()
	spec.target = claim_target
	spec.kind = claim_kind
	spec.amount = maxi(claim_amount, 0)
	return spec

func is_alive() -> bool:
	return target != null and is_instance_valid(target)

## Same reservation, ignoring payload - what release(job, target, kind) matches on.
func matches(other_target: Object, other_kind: Kind) -> bool:
	return target == other_target and kind == other_kind

func describe() -> String:
	return "%s x%d on %s" % [String(Kind.keys()[kind]), amount, str(target)]
