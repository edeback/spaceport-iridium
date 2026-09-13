class_name PendingHires
extends RefCounted

## Hires that have been paid for and have no pawn yet (WI-07) - the bookkeeping
## [CrewManager] runs its arrival timers, its housing gate and its lose condition
## over. Pure: holds plain JSON-safe dictionaries and touches no Global.
##
## A hire has two phases after it is paid for: the arrival delay counting down,
## then the shuttle flying in to dock. **It stays in this list through both** and
## leaves only when [method settle] is called as its pawn is delivered (or its fee
## refunded). Removing it when the delay ran out - which is what the manager used
## to do - opened a window of a few sim-seconds with no pawn and no pending hire,
## and the lose check fires on slow_tick, so a player whose only crew was on that
## shuttle lost the run while it was on final approach. The same window hid the
## hire from the bunk gate (a second hire could over-book the pods) and from the
## save, which dropped a paid hire outright.
##
## Entry keys: "remaining" (sim-hours of delay left), "bay" (a module ref, resolved
## at arrival so a deconstructed bay can refund), "candidate"
## ([method HireCandidate.to_dict]) and "launched" (its shuttle is in flight).

var _entries: Array[Dictionary] = []

## Queues a paid hire to arrive after `delay_hours` sim-hours.
func add(bay_ref: Dictionary, candidate: Dictionary, delay_hours: float) -> Dictionary:
	var hire: Dictionary = {
		"remaining": delay_hours,
		"bay": bay_ref,
		"candidate": candidate,
		"launched": false,
	}
	_entries.append(hire)
	return hire

## Every hire not yet delivered, shuttles in flight included.
func count() -> int:
	return _entries.size()

func is_empty() -> bool:
	return _entries.is_empty()

## Counts every waiting hire down by `hours` and returns the ones whose delay has
## just run out, marking each launched. They are NOT removed: a launched hire is
## still owed a pawn. A hire is returned once - later calls skip it.
func advance(hours: float) -> Array[Dictionary]:
	var due: Array[Dictionary] = []
	for hire: Dictionary in _entries:
		if bool(hire.get("launched", false)):
			continue
		hire["remaining"] = float(hire.get("remaining", 0.0)) - hours
		if float(hire["remaining"]) <= 0.0:
			hire["launched"] = true
			due.append(hire)
	return due

## The hire is now a pawn (or a refund). Matched by identity, not by value - two
## hires are dictionaries that could compare equal. Returns false for a hire this
## list no longer holds, which is how a shuttle launched before a load, docking
## afterwards, is told not to deliver a second copy of a crew member the load has
## already relaunched.
func settle(hire: Dictionary) -> bool:
	for index: int in _entries.size():
		if is_same(_entries[index], hire):
			_entries.remove_at(index)
			return true
	return false

## `launched` is not saved: the shuttle it describes is a scene node that is not
## saved either. A hire saved mid-flight therefore reloads with its delay spent and
## launches again on the next [method advance] - the flight restarts rather than
## the paid hire vanishing.
func to_save() -> Array:
	var out: Array = []
	for hire: Dictionary in _entries:
		out.append({
			"remaining": float(hire.get("remaining", 0.0)),
			"bay": (hire.get("bay", {}) as Dictionary).duplicate(true),
			"candidate": (hire.get("candidate", {}) as Dictionary).duplicate(true),
		})
	return out

func load_save(data: Array) -> void:
	_entries.clear()
	for entry: Variant in data:
		if not entry is Dictionary:
			continue
		var hire: Dictionary = entry
		var bay_ref: Dictionary = hire.get("bay", {})
		var candidate: Dictionary = hire.get("candidate", {})
		add(bay_ref, candidate, float(hire.get("remaining", 0.0)))
