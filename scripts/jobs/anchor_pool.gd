class_name AnchorPool
extends RefCounted

## The claim target for one anchor TYPE on one PathComponent (WI-44) - bunks in a
## sleeping pod, workstations in a processor bay.
##
## Same shape as SlotPool and StorageData: the claimable object is the thing that
## owns the constraint. The wrinkle is that PathComponent keys its anchor claims
## by CLAIMANT instance id, one anchor per claimant, so the pool itself cannot be
## the claimant - two jobs claiming the same type would erase each other
## (claim_anchor() drops the claimant's previous claim on entry). Each claim
## therefore mints its own throwaway Claim holder to act as the claimant, and
## hands it back as the ClaimSpec payload so release can undo exactly that one.
##
## This needs no change to PathComponent at all, and its leak detector still
## works: a Claim stays alive precisely as long as the ClaimSpec holding it, so a
## job that ends releases it and a job that leaks trips _purge_dead_claims().

## One claimed anchor. Doubles as the opaque claimant handle PathComponent keys on.
class Claim:
	extends RefCounted

	## The anchor that was handed out, or null - see take_claim() on why null is
	## still a successful claim.
	var anchor: AnchorDef = null

var path: PathComponent = null
var type: AnchorDef.AnchorType = AnchorDef.AnchorType.STAND

static func make(path_component: PathComponent, anchor_type: AnchorDef.AnchorType) -> AnchorPool:
	var pool := AnchorPool.new()
	pool.path = path_component
	pool.type = anchor_type
	return pool

func can_take_claim(kind: int, _amount: int) -> bool:
	return kind == ClaimSpec.Kind.ANCHOR and path != null and is_instance_valid(path)

## Note that a null anchor is NOT a failure. PathComponent's contract is that
## "no free anchor of this type" means "target the module centre as before" -
## movement must never be blocked on anchor scarcity - so the claim succeeds with
## an empty holder and the goto action falls back to the module.
func take_claim(kind: int, amount: int) -> Variant:
	if not can_take_claim(kind, amount):
		return null
	var holder := Claim.new()
	holder.anchor = path.claim_anchor(type, holder)
	return holder

func release_claim(_kind: int, _amount: int, payload: Variant) -> void:
	var holder: Claim = payload as Claim
	if holder != null and path != null and is_instance_valid(path):
		path.release_anchor(holder)
