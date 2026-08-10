class_name ResourceManager
extends Node

## Keeps every resource's station-wide total current, and (WI-52) its rate of
## change. The totals themselves live on the shared [ResourceData] `.tres`; this
## manager owns the tick that refreshes them and the history that turns them into
## a per-cycle rate.

## The resources the slow tick recalculates. Authored, because the recalc order
## and membership are a balance concern; [method tracked_resources] is what UI
## should read, since it also picks up anything a mod shipped.
@export var storable_resources: Array[ResourceData] = []

# Because so many use it directly
@export var credit_resource: ResourceData

## Rate history (WI-52). Owned by this NODE, deliberately not stashed on the
## shared [ResourceData]: a `.tres` survives a scene swap in Godot's resource
## cache, so a tracker living there would hand a new game the previous run's
## samples - which is exactly the bug WI-38's A8 was. A fresh scene means a fresh
## manager means an empty tracker, and one window of `—` on the ledger is the
## correct, honest cost of that.
var rates: ResourceRateTracker = ResourceRateTracker.new()

## Every resource this build knows about, discovered rather than authored, so a
## modded resource reaches the ledger with no core edit (WI-47). Built once in
## _ready and cached - the roots cannot change after the scene is up.
var _all_resources: Array[ResourceData] = []
## The player-facing subset of the above. Cached rather than filtered per call
## because the vitals strip asks twice a second and a fresh Array each time is
## garbage for no reason.
var _ledger_resources: Array[ResourceData] = []

func _ready() -> void:
	Global.resource_manager = self
	_discover_resources()
	Global.time_manager.slow_tick.connect(_on_slow_tick)

## Unions the authored list with a scan of every registered content root. The
## authored list stays first so its order is preserved; anything a mod added is
## appended. Mirrors SaveManager._build_lookups, which scans the same root for
## the same reason.
func _discover_resources() -> void:
	_all_resources = storable_resources.duplicate()
	for path: String in ContentPaths.scan(ContentPaths.RESOURCES):
		var resource: ResourceData = ResourceLoader.load(path) as ResourceData
		if resource != null and resource.id != &"" and not _all_resources.has(resource):
			_all_resources.append(resource)
	_ledger_resources = []
	for resource: ResourceData in _all_resources:
		if LedgerModel.in_ledger(resource):
			_ledger_resources.append(resource)

## Everything the recalc walks and the rate tracker samples - the authored list
## plus whatever the content scan turned up. Shared; do not mutate.
func tracked_resources() -> Array[ResourceData]:
	return _all_resources

## The resources a player-facing list may show, in discovery order. Shared; do
## not mutate. The ledger groups and sorts a copy - see [LedgerModel.group].
func ledger_resources() -> Array[ResourceData]:
	return _ledger_resources

## Units per cycle, or [constant ResourceRateTracker.NO_RATE] before there is
## enough history. One accessor so no panel reaches into the tracker's ids.
func rate_per_cycle(resource: ResourceData) -> float:
	if resource == null:
		return ResourceRateTracker.NO_RATE
	return rates.rate_per_cycle(resource.id)

## Recalculate, then sample. In that order: the sample must see this tick's total,
## not the previous one's, or every rate lags the display by a tick.
##
## `sample()` decimates internally (it keeps roughly four samples a sim-hour), so
## calling it on every 4 Hz tick is cheap and the cadence is the tracker's
## business rather than a counter kept here.
func _on_slow_tick(_interval: float) -> void:
	var sim_hours: float = Global.time_manager.total_sim_seconds / TimeManager.SECONDS_PER_HOUR
	for resource: ResourceData in _all_resources:
		resource._recalc_resource()
		rates.sample(resource.id, sim_hours, resource.cached_total)
