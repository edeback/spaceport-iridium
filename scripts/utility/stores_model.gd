class_name StoresModel
extends RefCounted

## The rules behind the Stores panel (WI-56): which storages are listed, in what
## order, and how a haul priority is described.
##
## Storage priority **is** the routing language of the whole hauling system -
## construction imports sit at +99, deconstruction exports at −99, and a sink must
## out-priority its source ([StorageQuery]) - and until this panel the player met
## it as an unlabelled spinbox on one module at a time. Putting every bin's number
## on one screen only helps if the screen agrees with itself about what the number
## means, which is why the description and the ordering are here, pure and tested,
## rather than inline in a card.
##
## This model does **not** change any routing rule. It reads priorities and sorts
## by them; the hauling system is untouched (WI-56: *"this item shows the routing
## language; it does not change it"*).
##
## Pure: static, no nodes, no [Global]. The one type it names is
## [StorageComponent], and only to read fields off it.

## The panel's three sort orders.
enum Sort { PRIORITY, NAME, FILL }

## The design's legend line, and it is load-bearing: *"a range that abstract needs
## its legend on screen, not in a tooltip"*.
const LEGEND: String = "Priority decides where haulers deliver first · −100 last choice … +100 urgent"

## The range a player-set priority may take. The system's own reserved extremes
## (±99 for construction and deconstruction) sit inside it, so a player *can* out-
## bid a construction site - deliberately, because "my refinery matters more than
## that blueprint" is a legitimate thing to want and the panel that finally makes
## priority legible should not also be the thing that fences it off.
const PRIORITY_MIN: int = -100
const PRIORITY_MAX: int = 100

## Bands the number is described in. Boundaries are inclusive-low: a bin at
## exactly −100 is last in line for deliveries, one at −99 is merely nearly so.
##
## It used to be called REFUSE_AT and print "Refuses", which was a lie the moment
## WI-65 made refusal a *role* rather than a number: nothing the player can set on
## this stepper refuses a delivery, and [method StorageQuery.find_sink] skips the
## priority comparison entirely when the caller has no priority of its own (a pile
## or a carried-cargo sweep), so a bin at the floor accepts those regardless. The
## number ranks; the role refuses.
const LAST_CHOICE_AT: int = -100
const PUSH_BELOW: int = 0
const URGENT_ABOVE: int = 50

## One listed storage, flattened. Since WI-65 a module carries at most one of
## these (plus construction's), and a bin that used to be two rows - a refinery's
## input bay and output bay - is one row with **two meters**, because the two
## roles have separate capacity pools.
class Entry extends RefCounted:
	var component: StorageComponent = null
	## What the card is titled. The module's name, plus the component's own name
	## when the module carries more than one bin.
	var title: String = ""
	## Cell and capacity - the card's meta line.
	var cell: Vector2i = Vector2i.ZERO
	var priority: int = 0
	var stored: int = 0
	var capacity: int = 0
	## The intake pool (GENERAL + INPUT slots) and the output pool, separately.
	## `stored`/`capacity` above stay the combined totals, because "is this module
	## holding anything" and "how full is it overall" are still one question.
	var intake_stored: int = 0
	var intake_capacity: int = 0
	var output_stored: int = 0
	var output_capacity: int = 0
	## False when every slot is OUTPUT - a mining bay, a deconstruction site. Such a
	## bin has no priority of its own to set, because OUTPUT implies the floor
	## ([method priority_editable]).
	var has_intake: bool = true
	## False for a processor bay or a construction site: the card renders its
	## contents readable, its dump controls gone, and says why. Named for what it
	## gates - the bin's **priority stepper stays live either way**
	## ([method priority_editable]).
	var contents_configurable: bool = false
	## True while the owning module is still a blueprint.
	var under_construction: bool = false

	## 0..1. A bin with no capacity reads as full rather than as empty - there is
	## no room in it, which is what the meter is asking about.
	func fill() -> float:
		return _ratio(stored, capacity)

	## The IN meter: how full the intake pool is.
	func intake_fill() -> float:
		return _ratio(intake_stored, intake_capacity)

	## The OUT meter: how full the output pool is. A card only draws this when
	## [member output_capacity] is non-zero - most bins have no output side.
	func output_fill() -> float:
		return _ratio(output_stored, output_capacity)

	static func _ratio(part: int, whole: int) -> float:
		if whole <= 0:
			return 1.0
		return clampf(float(part) / float(whole), 0.0, 1.0)

	func is_empty() -> bool:
		return stored <= 0

# --- ordering -------------------------------------------------------------------

## Sorts a copy of `entries`. Total and stable in the sense that matters: every
## comparison falls through to the title, so two bins with the same priority and
## the same fill never swap places between refreshes.
static func sort_entries(entries: Array, sort: Sort) -> Array:
	var out: Array = entries.duplicate()
	out.sort_custom(func(a: Variant, b: Variant) -> bool:
		return compares_before(a as Entry, b as Entry, sort))
	return out

## The comparator. PRIORITY is **descending** - the bins pulling stock hardest are
## the ones the player came here to find - while FILL is descending for the same
## reason (a full bin is the one about to stop accepting deliveries) and NAME is
## the only ascending one.
static func compares_before(a: Entry, b: Entry, sort: Sort) -> bool:
	if a == null or b == null:
		return b == null and a != null
	match sort:
		Sort.NAME:
			pass
		Sort.FILL:
			if not is_equal_approx(a.fill(), b.fill()):
				return a.fill() > b.fill()
		_:
			if a.priority != b.priority:
				return a.priority > b.priority
	return a.title.naturalnocasecmp_to(b.title) < 0

# --- describing a priority ---------------------------------------------------------

## What a haul priority *does*, in words. The number stays on screen - this is the
## caption under it, and it is the whole reason the panel is worth building.
##
## Deliberately **short**. These sit in a fixed column under the stepper and the
## first draft ("Urgent — pulls stock first") ellipsed to `URGENT — PULLS STO…` on
## every card, which is a caption that explains nothing. The long form of the
## explanation is [constant LEGEND], which has a whole line to itself.
static func priority_label(priority: int) -> String:
	if priority <= LAST_CHOICE_AT:
		return "Last choice"
	if priority < PUSH_BELOW:
		return "Pushes away"
	if priority == PUSH_BELOW:
		return "Neutral"
	if priority > URGENT_ABOVE:
		return "Urgent"
	return "Pulls in"

## Sign is carried by colour as well as by the number: *"cyan pulls stock in,
## amber pushes it away"*. [method UIPalette.sign_color] already encodes exactly
## that, so this is a delegation rather than a second table - a Stores card and a
## ledger rate must not disagree about which way amber points.
static func priority_color(priority: int) -> Color:
	return UIPalette.sign_color(float(priority))

# --- membership -----------------------------------------------------------------------

## Is this component one the panel lists?
##
## *"Any module with a [StorageComponent]"* - which deliberately includes processor
## bays and construction sites, because "why is the refinery hoarding ore" is a
## question this panel should answer even where it cannot be edited. A read-only
## card **says so**; it is not hidden (WI-54: locked is a state, not an absence).
##
## Three exclusions, all of them bins that are not storage at all:
##
## 1. a module that is still a **preview** - a ghost following the cursor;
## 2. a component that has left the tree;
## 3. a **construction bin on a finished module**. `construction_storage` bins
##    take delivery of a module's build materials; the moment the module is built,
##    `ready_constructed` drops the bin out of [constant Groups.RESOURCE_STORAGE],
##    stops its posting scan and hides its own UI. It is dead, permanently empty,
##    and there is one on every corridor and airlock - which put six inert `+100`
##    cards at the top of the first station's list and pushed the two bins that
##    actually held something below the fold. A construction bin on a *blueprint*
##    is still listed: that one is a live construction site.
##
## Every entry point walks a live set - `WorldManager.id_to_module`, a module's
## own component list, a group scan - so a component reaches these queries live
## or null (WI-71 §2c). A freed one would be rejected at the call.
static func lists(component: StorageComponent) -> bool:
	if component == null:
		return false
	var module: ModuleBase = component.owner_module
	if module == null:
		return false
	if module.build_state == ModuleBase.BuildState.Preview:
		return false
	return not (component.construction_storage and module.is_complete())

## May the player edit **what this bin holds** - its accepted-resource list, the
## desired amount of each, and the dump controls?
##
## This is what `player_configurable` means and the only thing it means: a
## multipurpose bin (a Storage module, a Docking Bay) holds whatever the player
## says, while a Foundry takes what its recipe needs and emits what it makes, and
## a construction site holds exactly what its build requires. Those contents are
## the *module's* decision, so the controls that change them are not offered.
##
## **One rule, one place (WI-58).** Three surfaces used to answer it three
## different ways for the same field. The Stores card disabled its stepper on
## `player_configurable`; the inspector's storage tab commented *"desired amounts
## are always configurable"*; and [method StorageOverlays.open_resource] asked
## nothing at all, so its chip dialog wrote `desired` and destroyed stock on any
## bin it was handed. Because [method lists] deliberately keeps live construction
## sites, that third answer reached **a blueprint's construction import bin** -
## where it let the player rewrite the build's requirements and vent its
## delivered materials.
##
## **Priority is deliberately not on this list** - see [method priority_editable].
static func contents_editable(component: StorageComponent) -> bool:
	if component == null:
		return false
	return component.player_configurable

## May the player edit this bin's **haul priority**?
##
## For any bin that still exists **and takes deliveries**. Priority **is** the
## routing language of the whole hauling system - construction imports sit at +99
## and a sink must out-priority its source ([StorageQuery]) - so it is the
## player's main lever for deciding where stock goes. A refinery's input bay
## holding only ore is the module's business; whether that bay out-bids the
## smelter for the ore is the player's.
##
## The one exception is a bin whose every slot is OUTPUT - a mining bay, a
## deconstruction site. OUTPUT *implies* the floor (WI-65), so a stepper there
## would be a control that does nothing, and a control that does nothing is worse
## than an absent one. Before WI-65 that case could not arise, because the export
## side of a module was a separate component with its own settable number.
##
## It is a function rather than nothing at all so that the asymmetry with
## [method contents_editable] is stated once, in the model, instead of as a
## comment in each of the surfaces that would otherwise be tempted to "fix" it.
static func priority_editable(component: StorageComponent) -> bool:
	return component != null and component.has_intake_slots()

## The number a bin actually routes at, for any surface that shows or sorts by one.
##
## A bin with an intake side routes at its own `priority`. An export-only bin - a
## mining bay - has no number of its own: OUTPUT ships at the floor (WI-65) and its
## `priority` field is a leftover nothing routes on. The logistics overlay printed
## that field, which put a +1 on a mining bay that actually ships at -100.
static func routing_priority(component: StorageComponent) -> int:
	return component.priority if priority_editable(component) else PRIORITY_MIN

## Why a bin's **priority** is not editable, in words - the sentence that takes
## the stepper's place (WI-54: a blocked control names its blocker). Empty for a
## bin whose priority the player sets, which is nearly all of them.
static func priority_locked_reason(component: StorageComponent) -> String:
	if priority_editable(component):
		return ""
	if component == null:
		return "This bin is gone"
	return "This module only exports goods and does not have its own priority"

## Why a bin's **contents** are not editable, in words - the sentence a locked
## control has to carry beside it (WI-54: locked is a state, not an absence).
## Empty for a bin the player configures.
##
## Shared with the Stores card so the inspector, the card and the dump dialog say
## the same thing about the same bin. Both sentences are careful not to claim the
## *whole* bin is locked, because its priority is not.
##
## Empty on an export-only bin, where the priority *is* locked: its
## [method priority_locked_reason] already says the module decides everything
## about it, and the sentence below would print "its priority is still yours"
## directly under "does not have its own priority".
static func locked_reason(component: StorageComponent) -> String:
	if contents_editable(component):
		return ""
	if component == null:
		return "This bin is gone"
	if not priority_locked_reason(component).is_empty():
		return ""
	var module: ModuleBase = component.owner_module
	if module != null and not module.is_complete():
		return "Construction site — the build decides what it imports"
	# The docking bay is driven end to end by the order sheet (WI-65): sell orders
	# create its staging slots and size them, purchases create its arrival slots. It
	# used to be player_configurable as WELL, which meant two authorities on one bin
	# and the sheet silently winning every recalculation.
	if module != null and module.get_component_by_type(TradeComponent) != null:
		return "Set by the trade sheet — its priority is still yours"
	return "Contents set by the module — its priority is still yours"

## How many of `entries` are actually holding something - the subtitle's
## `n MODULES HOLDING STOCK`.
##
## Counts distinct **modules**, not bins: a refinery with a full input bay and an
## empty output bay is one module holding stock, and the subtitle says "modules".
static func modules_holding_stock(entries: Array) -> int:
	var seen: Dictionary[Object, bool] = {}
	for item: Variant in entries:
		var entry: Entry = item as Entry
		if entry == null or entry.is_empty() or entry.component == null:
			continue
		if entry.component.owner_module != null:
			seen[entry.component.owner_module] = true
	return seen.size()

## The subtitle line. Both numbers, because *"a store you've set to +80 and that
## is empty is exactly the interesting case"* - so the panel lists more bins than
## it says are holding stock and has to account for the difference.
static func subtitle_text(entries: Array) -> String:
	return "%d holding stock · %d bins" % [modules_holding_stock(entries), entries.size()]
