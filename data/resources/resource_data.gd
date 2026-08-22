@tool
class_name ResourceData
extends Resource

## Stable identifier for save files (matches the .tres file stem). Never
## rename once players have saves referencing it.
@export var id: StringName = &""
@export var name: String = ""
@export var icon: Texture2D

#@export var sub_resources: Dictionary[ResourceData, float]
#@export var base_resource: ResourceData

@export var default_cost: int = 10
@export var default_market_supply: int = 100

@export var has_global_store: bool = false
## Authored seed for global_total, only used if has_global_store is true. This is
## the *only* global-store field that belongs in the .tres: everything below is
## runtime state on an engine-wide shared resource, and Godot's resource cache
## keeps it alive across a scene swap (WI-38 A8 / B3). SaveManager._ready() resets
## the runtime fields from this seed on entry to the game scene.
@export var starting_global_total: int = 0

## Runtime credit/global balance. Deliberately NOT exported - see above.
var global_total: int = 0
## Derived cache of global_total + everything in registered_storage.
var cached_total: int = 0
var needs_recalc: bool = true

## Does this resource carry per-stack variance (ore richness, food quality,
## etc)? When false (the default, and correct for most resources), every
## stack of this resource has instance_data == null and storage behaves
## exactly like a single int count - no behavior change from before this
## system existed.
@export var has_variance: bool = false

## How close two variant stacks' ItemInstanceData.get_primary_value() need to
## be to merge into one stack, once has_variance is true. Higher = coarser
## buckets (fewer stacks, less precision retained); 0 = only exact matches
## merge. Ignored when has_variance is false.
@export_range(0.0, 1.0, 0.01) var merge_tolerance: float = 0.05

## Which ItemInstanceData subclass this resource's stacks carry (WI-47 M4).
## Required when has_variance is true; ignored otherwise.
##
## Held as a Script reference rather than a type-name string for the same reason
## JobData.driver is: a rename is caught when the resource loads, and - the reason
## it matters here - a mod's class_name is never registered in an exported build,
## so a name would be unresolvable from a mod anyway. The save's `"type"` tag is a
## readability aid and a mismatch check; THIS is what decides the class.
@export var instance_data_script: Script

## --- world participation (WI-47 audit sweep) ---------------------------------
## Both of these exist so a MOD's resource can opt into systems whose vanilla
## membership is an authored list on a manager node in main.tscn - a list no mod
## can reach. The manager unions its authored list with everything declaring
## itself here, so vanilla behaviour is unchanged and a mod only has to say so.

## Does this resource trade on the station market? Once true it is quotable,
## sellable, carried by generic traders, and eligible for export contracts - the
## last two read the market's list rather than keeping their own.
@export var tradable: bool = false

## Relative chance of this ore turning up in a spawned asteroid's mix. 0 (the
## default, and correct for anything that isn't mined) = never spawns.
## AsteroidManager's own ore_spawn_weights dictionary overrides this per ore.
@export var asteroid_spawn_weight: float = 0.0

## --- ledger presentation (WI-52) ---------------------------------------------

## Which column of the resource ledger this resource is listed under.
##
## PRESENTATION ONLY, exactly as ModuleData.ui_category is (WI-43): it buckets a
## list and nothing may branch on it. `tags`-vs-`ui_category` is the same rule -
## gameplay reads gameplay fields. Nothing may group the ledger on `tradable` or
## `has_variance` either, which correlate with these columns today by accident.
##
## BASIC was called RAW_ORE until carbon stopped being refined from an ore. The
## column has always meant "what a mining trip puts in the bay", which the ores
## no longer have to themselves - so it is named for the shelf, not its former
## occupants. The ordinals are unchanged, so no .tres re-authoring was needed.
enum Category { BASIC, REFINED, LIFE_SUPPORT, GOODS }

@export var ledger_category: Category = Category.GOODS

## Does this resource appear in player-facing resource lists (the ledger, and
## therefore the set of things that can be pinned into the vitals strip)?
##
## Opt-OUT rather than opt-in, so a modded resource reaches the ledger with no
## core edit (WI-47). The base game turns it off in exactly two places -
## `test_resource` (a fixture) and `stored_energy` (a battery accounting unit
## that is never stored, traded or hauled).
@export var show_in_ledger: bool = true

var registered_storage: Array[StorageComponent] = []

#@export var show_test: bool = false:
	#set(value):
		#show_test = value
		#notify_property_list_changed()
		#
#@export_storage var test_val: String = ""
#
#func _get_property_list() -> Array[Dictionary]:
	#var properties: Array[Dictionary] = []
	#if show_test:
		#properties.append({
			#"name": "test_val",
			#"type": TYPE_STRING,
			#"usage": PROPERTY_USAGE_DEFAULT,
			#"hint": PROPERTY_HINT_NONE,
			#"hint_string": ""
		#})
	#return properties

signal total_changed(new_total: int)

# Returns new global total
func change_global_total(amount: int) -> int:
	global_total += amount
	_recalc_resource(true)
	return global_total

func get_total(force_recalc: bool = false) -> int:
	_recalc_resource(force_recalc)
	return cached_total

## Station-wide amount-weighted average of the variance value (ore richness, food
## quality) across every registered storage, or -1.0 when nothing carries any -
## the same "no info" sentinel [method ResourceStackContainer.average_instance_value]
## uses, so a caller can tell it apart from a legitimate 0.0.
##
## The station-wide counterpart of the per-bin figure the storage tab already
## shows (WI-52; the ledger prints it as "142 · 72% AVG"). Weighted by each bin's
## total rather than by its variant-carrying units: for a `has_variance` resource
## every stack carries instance data in practice, and the distinction would cost
## a second accessor on StorageData for a meta line.
func average_instance_value() -> float:
	if not has_variance:
		return -1.0
	var units: int = 0
	var weighted: float = 0.0
	for component: StorageComponent in registered_storage:
		var data: StorageData = component.storage_data.get(self)
		if data == null or data.stored <= 0:
			continue
		var average: float = data.average_instance_value()
		if average < 0.0:
			continue
		weighted += average * float(data.stored)
		units += data.stored
	if units <= 0:
		return -1.0
	return weighted / float(units)

## Station-wide stock nobody has already claimed a withdrawal against - the
## Trade panel's `AVAIL` column (WI-55).
##
## The distinction from [method get_total] is the whole reason the column exists:
## HELD is stock, AVAIL is what is not reserved, and **selling into a reservation
## is the mistake the table exists to prevent**. A hauler that has claimed 40 ore
## for a construction site has not moved it yet, so the old order sheet - which
## showed only the total - would happily let the player commit that same ore to a
## trader.
##
## Deliberately re-derived on every call rather than cached like `cached_total`:
## reservations move on every claim and release, none of which go through
## `needs_recalc`, and a stale AVAIL is worse than no AVAIL. The panel that reads
## it refreshes on `slow_tick`, not per frame.
func available_unreserved() -> int:
	# A global store has no physical location and therefore nothing to reserve
	# against, so all of it is available. Only credits carry one today, and
	# credits are not tradable - this is here so the accessor is honest for any
	# resource rather than only for the ones the trade table lists.
	var total: int = global_total if has_global_store else 0
	for component: StorageComponent in registered_storage:
		total += component.available_to_withdraw(self)
	return total

func register_component(component: StorageComponent) -> void:
	if not registered_storage.has(component):
		registered_storage.append(component)
		needs_recalc = true

func unregister_component(component: StorageComponent) -> void:
	registered_storage.erase(component)
	needs_recalc = true
		
func _recalc_resource(force_recalc: bool = false) -> void:
	if needs_recalc or force_recalc:
		needs_recalc = false
		var total: int = global_total
		for storage_component: StorageComponent in registered_storage:
			total += storage_component.total_stored_by_resource(self)
		cached_total = total
		total_changed.emit(total)

## Spends `amount` wherever it can be found: the global store if there is one,
## otherwise across registered storages until the debt is covered.
##
## Recalculates and emits before returning, the same way change_global_total
## does (WI-52, bug C13). It used to only set needs_recalc, so ResourceManager's
## next slow tick was what moved the display - meaning hiring crew, paying off a
## raid, buying a module and purchasing an upgrade all left the credit readout
## stale for up to a quarter of a sim-second. It self-healed, so it read as UI
## lag rather than as a bug; with credits a first-class vital chip that lag would
## sit on the most-watched number on screen, so the two paths are now symmetric.
func force_withdraw(amount: int) -> void:
	if has_global_store:
		global_total -= amount
	else:
		var remaining_amount: int = amount
		for component in registered_storage:
			remaining_amount -= component.withdraw_up_to(self, remaining_amount)
			if remaining_amount <= 0:
				break
	_recalc_resource(true)
