class_name LedgerModel
extends RefCounted

## The rules behind the vitals strip and the resource ledger (WI-52), extracted
## so they can be tested without a HUD.
##
## Three rules live here, and each of them is one a panel would otherwise
## re-derive: which resources appear in the ledger and in which column, what a
## saved pin list resolves to, and how a number and a rate are printed.
##
## Grouping is **presentation only**. `ledger_category` follows the precedent
## `ModuleData.ui_category` set in WI-43: it buckets a list and nothing else may
## branch on it. The inverse holds too - the ledger must never group on
## `tradable` or `has_variance`, which happen to correlate with these columns
## today and are gameplay fields that will stop correlating the moment somebody
## makes biowaste sellable.
##
## Pure: static, no nodes, no [Global]. GUT calls it directly.

# --- categories ---------------------------------------------------------------

## Column order, left to right, in the ledger flyout.
const CATEGORY_ORDER: Array[ResourceData.Category] = [
	ResourceData.Category.RAW_ORE,
	ResourceData.Category.REFINED,
	ResourceData.Category.LIFE_SUPPORT,
	ResourceData.Category.GOODS,
]

const CATEGORY_LABELS: Dictionary[ResourceData.Category, String] = {
	ResourceData.Category.RAW_ORE: "Raw Ore",
	ResourceData.Category.REFINED: "Refined",
	ResourceData.Category.LIFE_SUPPORT: "Life Support",
	ResourceData.Category.GOODS: "Goods",
}

static func category_label(category: ResourceData.Category) -> String:
	return CATEGORY_LABELS.get(category, "Goods")

## Whether a resource belongs in a player-facing list at all. Opt-*out*, so a
## modded resource reaches the ledger with no core edit (WI-47); the two the base
## game excludes (`test_resource`, `stored_energy`) say so in their own `.tres`.
static func in_ledger(resource: ResourceData) -> bool:
	return resource != null and resource.show_in_ledger and resource.id != &""

## Which column a resource is listed under, correcting an unset or unrecognised
## value to GOODS.
##
## A resource that fell out of the ledger because a mod shipped an enum value
## this build has never heard of would be *invisible*, and invisible is the one
## failure mode a list that claims to be complete cannot have.
static func category_of(resource: ResourceData) -> ResourceData.Category:
	if resource == null or not CATEGORY_ORDER.has(resource.ledger_category):
		return ResourceData.Category.GOODS
	return resource.ledger_category

## The ledger-visible members of `resources` in one column, sorted by display
## name.
##
## One column per call rather than a dictionary of all four, because GDScript has
## no nested typed collections and `Dictionary[Category, Array[ResourceData]]`
## does not parse. The ledger asks four times over eighteen resources, which is
## not a cost worth an untyped return for.
static func in_category(resources: Array[ResourceData],
		category: ResourceData.Category) -> Array[ResourceData]:
	var column: Array[ResourceData] = []
	for resource: ResourceData in resources:
		if in_ledger(resource) and category_of(resource) == category:
			column.append(resource)
	column.sort_custom(func(a: ResourceData, b: ResourceData) -> bool:
		return a.name.naturalnocasecmp_to(b.name) < 0)
	return column

# --- pins ---------------------------------------------------------------------

## Chips in the strip. The zone is flex, so more would fit at 2560 and not at
## 1920; capping it is the safer knob than a strip that overflows on one display
## and not another (WI-52 edge cases).
const PIN_CAP: int = 6

## Namespace for the three chips that are computed rather than stored, so a
## single ordered pin list can hold both kinds. A resource id can never collide
## with one: base-game ids are hand-authored and a mod's must begin with its own
## `modid.` prefix ([method ContentPaths.accept_id]).
const DERIVED_PREFIX: String = "derived:"

## Power production against capacity, from [PowerManager].
const DERIVED_ENERGY: StringName = &"derived:energy"
## Station-average O2 partial pressure, from [AtmosphereManager].
const DERIVED_OXYGEN: StringName = &"derived:oxygen"
## Heads against crew bunks, from [CrewManager].
const DERIVED_CREW: StringName = &"derived:crew"

const DERIVED_IDS: Array[StringName] = [DERIVED_ENERGY, DERIVED_OXYGEN, DERIVED_CREW]

## The designed strip, in order (the mockup's Energy / Credits / Oxygen / Food /
## Steel / Crew). "Food" is **biomass**: it is what `algae_vats` and
## `hydroponics_bay` actually produce and what `SustenanceComponent` eats, so
## until a rations tier exists biomass is the food chain's output.
const DEFAULT_PINS: Array[StringName] = [
	DERIVED_ENERGY,
	&"credits",
	DERIVED_OXYGEN,
	&"biomass",
	&"steel",
	DERIVED_CREW,
]

static func is_derived(id: StringName) -> bool:
	return String(id).begins_with(DERIVED_PREFIX)

## What a saved pin list actually renders as, given the resource ids this build
## can resolve.
##
## Four corrections, in order: the list is capped at [constant PIN_CAP],
## duplicates are dropped, unknown ids are dropped (a mod was removed, a resource
## was renamed), and any shortfall *against what the save asked for* is refilled
## from [constant DEFAULT_PINS].
##
## The refill target is the saved list's own length, not the cap, and that
## distinction is the whole rule: a player who deliberately runs four chips gets
## four back, while a player who had six and lost one to a removed mod gets six.
## Refilling to the cap either way would make unpinning impossible; never
## refilling would turn "the resource you pinned is gone" into a hole in the
## strip. An empty (or absent) list is the one case with no expressed intent, so
## it means the designed six.
static func resolve_pins(saved: Array, known_resource_ids: Array[StringName]) -> Array[StringName]:
	var resolved: Array[StringName] = []
	for entry: Variant in saved:
		var id: StringName = StringName(str(entry))
		if id == &"" or resolved.has(id) or resolved.size() >= PIN_CAP:
			continue
		if not can_pin(id, known_resource_ids):
			push_warning("Vitals: dropping pinned '%s' - no such resource in this build" % id)
			continue
		resolved.append(id)
	var target: int = PIN_CAP if saved.is_empty() else mini(saved.size(), PIN_CAP)
	for id: StringName in DEFAULT_PINS:
		if resolved.size() >= target:
			break
		if not resolved.has(id) and can_pin(id, known_resource_ids):
			resolved.append(id)
	return resolved

## Whether `id` names something the strip can draw: one of the derived chips, or
## a resource this build knows about.
static func can_pin(id: StringName, known_resource_ids: Array[StringName]) -> bool:
	if is_derived(id):
		return DERIVED_IDS.has(id)
	return known_resource_ids.has(id)

# --- formatting ---------------------------------------------------------------

## A per-cycle rate as the ledger prints it. [constant ResourceRateTracker.NO_RATE]
## becomes an em dash, because "no measurement yet" and "not moving" are different
## claims and only one of them is honest for the first window after a load.
static func format_per_cycle(rate: float) -> String:
	if not ResourceRateTracker.has_rate(rate):
		return "—"
	# Rounded before the sign is chosen, so a rate that prints as 0.0 does not
	# also print a `+`. This is the deadband UIPalette.sign_color documents that
	# callers are responsible for.
	var rounded: float = snappedf(rate, 0.1)
	if is_zero_approx(rounded):
		return "0.0"
	return "%+.1f" % rounded

## The colour a formatted rate is drawn in - cyan rising, amber falling, meta grey
## for flat *and* for no data, so a dash never reads as a fall.
static func rate_color(rate: float) -> Color:
	if not ResourceRateTracker.has_rate(rate):
		return UIPalette.TEXT_META
	return UIPalette.sign_color(snappedf(rate, 0.1))

## A stored amount in a fixed-width-ish slot. Credits reach six figures and the
## strip's chips are a constant width, so past ten thousand the number switches to
## a compact form rather than being clipped or forcing the strip to reflow.
static func format_compact(value: int) -> String:
	var magnitude: int = absi(value)
	if magnitude < 10000:
		return str(value)
	if magnitude < 1000000:
		return "%.1fK" % (float(value) / 1000.0)
	return "%.1fM" % (float(value) / 1000000.0)
