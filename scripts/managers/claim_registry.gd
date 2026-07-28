class_name ClaimRegistry
extends Node

## The one place that remembers who reserved what (WI-44). A Managers/ node like
## every other manager; registers itself into Global.claim_registry in _ready().
##
## WHAT THIS IS NOT: RimWorld's ReservationManager, which is the single source of
## truth for every reservation on the map. Copying that shape here would mean
## StorageData asking a global singleton how much of itself is reserved - and
## StorageData is a pure class with a GUT suite that constructs it directly and
## never touches Global. So the split is:
##
##   - the OWNER stays authoritative for capacity and amounts. StorageData keeps
##     reserved_withdraw/reserved_deposit and its assertions; SleepComponent keeps
##     counting its own occupants; PathComponent keeps its anchor map.
##   - the REGISTRY owns the claim RECORDS and the release path. It calls through
##     to the owner to take and give back, and it guarantees that every claim a
##     job made is released when that job ends, whatever ended it.
##
## That second half is the actual win. Before WI-44, "release on EVERY
## termination path" was a discipline repeated in fourteen _on_end() bodies and
## guarded by a latch every job author had to know about. Now Job.end() calls
## release_all() once and the invariant is structural.
##
## CLAIMABLE CONTRACT (duck-typed - GDScript has no interfaces, and the targets
## don't share a base: ComponentBase, ResourcePile, StorageData). A claimable
## implements all three:
##
##   can_take_claim(kind: int, amount: int) -> bool
##   take_claim(kind: int, amount: int) -> Variant    # null = refused; else payload
##   release_claim(kind: int, amount: int, payload: Variant) -> void
##
## take_claim returning a payload (rather than a bool) is what lets ANCHOR claims
## use the same path as everything else: the payload is the AnchorDef that got
## picked, handed back verbatim on release.

## job -> Array[ClaimSpec]. Keyed by the Job object itself; a job that never
## claims anything never appears here.
var _by_job: Dictionary[Job, Array] = {}

func _ready() -> void:
	Global.claim_registry = self

# --- claiming -----------------------------------------------------------------

## Whether `target` would accept this claim right now. Pure query - no side
## effects, safe from can_do()/is_valid() scans.
func can_claim(target: Object, kind: ClaimSpec.Kind, amount: int = 1) -> bool:
	if not _is_claimable(target):
		return false
	return bool(target.call(&"can_take_claim", int(kind), amount))

## Takes the claim and records it against `job`. Returns the record, or null if
## the target refused (someone else got there first, no space, no free slot).
##
## Re-claiming the same (target, kind) a job already holds returns the existing
## record untouched rather than double-reserving - restore paths and retrying
## actions both rely on that being safe.
func claim(job: Job, target: Object, kind: ClaimSpec.Kind, amount: int = 1) -> ClaimSpec:
	if job == null or not _is_claimable(target):
		return null
	var existing: ClaimSpec = find_claim(job, target, kind)
	if existing != null:
		return existing
	var payload: Variant = target.call(&"take_claim", int(kind), amount)
	if payload == null:
		return null
	var spec := ClaimSpec.make(target, kind, amount)
	# `true` is the "succeeded, nothing to hand back" answer; anything else is a
	# real payload the target wants to see again on release.
	spec.payload = null if typeof(payload) == TYPE_BOOL else payload
	if not _by_job.has(job):
		_by_job[job] = [] as Array[ClaimSpec]
	var claims: Array = _by_job[job]
	claims.append(spec)
	return spec

# --- releasing ----------------------------------------------------------------

## Gives one claim back. No-op when the job doesn't hold it.
func release(job: Job, target: Object, kind: ClaimSpec.Kind) -> void:
	if job == null or not _by_job.has(job):
		return
	var claims: Array = _by_job[job]
	for index: int in range(claims.size() - 1, -1, -1):
		var spec: ClaimSpec = claims[index]
		if spec.matches(target, kind):
			_give_back(spec)
			claims.remove_at(index)
	if claims.is_empty():
		_by_job.erase(job)

## Drops a claim record WITHOUT giving anything back, because the job has now
## SPENT it: the reserved units are physically on the pawn, or the reserved space
## is physically full.
##
## This is the counterpart the pre-WI-44 code expressed by having
## complete_withdraw_job() erase the job from withdraw_jobs, making the later
## cancel_withdraw_job() a no-op. Miss it and the reservation is credited back a
## second time on job end, which quietly inflates available stock.
func consume(job: Job, target: Object, kind: ClaimSpec.Kind) -> void:
	if job == null or not _by_job.has(job):
		return
	var claims: Array = _by_job[job]
	for index: int in range(claims.size() - 1, -1, -1):
		if (claims[index] as ClaimSpec).matches(target, kind):
			claims.remove_at(index)
	if claims.is_empty():
		_by_job.erase(job)

## Gives back everything `job` holds. Job.end() calls this unconditionally, which
## is what makes the "reservations reconcile to zero" invariant structural rather
## than a per-job discipline.
func release_all(job: Job) -> void:
	if job == null or not _by_job.has(job):
		return
	var claims: Array = _by_job[job]
	# Erase FIRST: _give_back reaches into components whose release paths can, in
	# principle, end another job and re-enter here. Working off a detached array
	# means re-entry can't see a half-released job.
	_by_job.erase(job)
	for spec: ClaimSpec in claims:
		_give_back(spec)

func _give_back(spec: ClaimSpec) -> void:
	# A target that was destroyed while claimed takes its accounting with it -
	# there is nothing to give back to.
	if not spec.is_alive() or not _is_claimable(spec.target):
		return
	spec.target.call(&"release_claim", int(spec.kind), spec.amount, spec.payload)

# --- queries ------------------------------------------------------------------

func find_claim(job: Job, target: Object, kind: ClaimSpec.Kind) -> ClaimSpec:
	if job == null or not _by_job.has(job):
		return null
	for spec: ClaimSpec in _by_job[job]:
		if spec.matches(target, kind):
			return spec
	return null

func holds_claim(job: Job, target: Object, kind: ClaimSpec.Kind) -> bool:
	return find_claim(job, target, kind) != null

## This job's claims. Returns a copy - callers (the board inspector, the
## post-end assertion) must not be able to mutate the ledger by iterating it.
func claims_of(job: Job) -> Array[ClaimSpec]:
	var out: Array[ClaimSpec] = []
	if job != null and _by_job.has(job):
		out.assign(_by_job[job])
	return out

## Total units of `kind` claimed against `target` across all jobs. The owner's
## own counter is authoritative for gameplay; this is for the inspector and for
## leak assertions, so a scan is the right cost.
func claimed_amount(target: Object, kind: ClaimSpec.Kind) -> int:
	var total: int = 0
	for job: Job in _by_job:
		for spec: ClaimSpec in _by_job[job]:
			if spec.matches(target, kind):
				total += spec.amount
	return total

## Number of jobs currently holding at least one claim (debug / probe output).
func claiming_job_count() -> int:
	return _by_job.size()

func _is_claimable(target: Object) -> bool:
	return target != null and is_instance_valid(target) \
		and target.has_method(&"can_take_claim") \
		and target.has_method(&"take_claim") \
		and target.has_method(&"release_claim")
