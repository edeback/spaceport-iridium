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
const LEGEND: String = "Priority decides where haulers deliver first · −100 refuse … +100 urgent"

## The range a player-set priority may take. The system's own reserved extremes
## (±99 for construction and deconstruction) sit inside it, so a player *can* out-
## bid a construction site - deliberately, because "my refinery matters more than
## that blueprint" is a legitimate thing to want and the panel that finally makes
## priority legible should not also be the thing that fences it off.
const PRIORITY_MIN: int = -100
const PRIORITY_MAX: int = 100

## Bands the number is described in. Boundaries are inclusive-low: a bin at
## exactly −100 refuses, one at −99 is merely last in line.
const REFUSE_AT: int = -100
const PUSH_BELOW: int = 0
const URGENT_ABOVE: int = 50

## One listed storage, flattened. A module can carry several storage components (a
## processor has an input bin and an output bin), and each is its own row: they
## have their own priorities and their own contents, and merging them would hide
## exactly the "why is the refinery hoarding ore" case this panel exists to
## answer.
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
		if capacity <= 0:
			return 1.0
		return clampf(float(stored) / float(capacity), 0.0, 1.0)

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
	if priority <= REFUSE_AT:
		return "Refuses"
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
static func lists(component: StorageComponent) -> bool:
	if component == null or not is_instance_valid(component):
		return false
	var module: ModuleBase = component.owner_module
	if module == null or not is_instance_valid(module):
		return false
	if module.build_state == ModuleBase.BuildState.Preview:
		return false
	return not (component.construction_storage and module.is_complete())

## May the player edit **what this bin holds** - its accepted-resource list, the
## desired amount of each, and the dump controls?
##
## This is what `player_configurable` means and the only thing it means: a
## multipurpose bin (a Storage module, a Docking Bay) holds whatever the player
## says, while a Forge always takes iron and carbon and always emits steel, and
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
	if component == null or not is_instance_valid(component):
		return false
	return component.player_configurable

## May the player edit this bin's **haul priority**?
##
## Always, for any bin that still exists, and that is a rule rather than an
## oversight. Priority **is** the routing language of the whole hauling system -
## construction imports sit at +99, deconstruction exports at −99, and a sink must
## out-priority its source ([StorageQuery]) - so it is the player's main lever for
## deciding where stock goes. A refinery's input bay holding only ore is the
## module's business; whether that bay out-bids the smelter for the ore is the
## player's.
##
## It is a function rather than nothing at all so that the asymmetry with
## [method contents_editable] is stated once, in the model, instead of as a
## comment in each of the surfaces that would otherwise be tempted to "fix" it.
static func priority_editable(component: StorageComponent) -> bool:
	return component != null and is_instance_valid(component)

## Why a bin's **contents** are not editable, in words - the sentence a locked
## control has to carry beside it (WI-54: locked is a state, not an absence).
## Empty for a bin the player configures.
##
## Shared with the Stores card so the inspector, the card and the dump dialog say
## the same thing about the same bin. Both sentences are careful not to claim the
## *whole* bin is locked, because its priority is not.
static func locked_reason(component: StorageComponent) -> String:
	if contents_editable(component):
		return ""
	if component == null or not is_instance_valid(component):
		return "This bin is gone"
	var module: ModuleBase = component.owner_module
	if module != null and is_instance_valid(module) and not module.is_complete():
		return "Construction site — the build decides what it imports"
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
