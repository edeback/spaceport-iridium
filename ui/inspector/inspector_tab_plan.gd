class_name InspectorTabPlan
extends RefCounted

## Which tabs the inspector shows, in what order, under what names (WI-51).
##
## Pure and static, because "which tabs" is a *rule* and the program doc's own
## risk list says a rule inside a panel is a rule nobody can test. The panel
## gathers the facts - which components a module carries, which components a pawn
## carries - and this decides what the strip looks like.
##
## Two jobs:
##
## **Module tabs.** `ModuleBase.components` is walked and every component that
## reports `has_ui()` contributes one page. Left to itself that produces tabs in
## whatever order the components happen to sit in the scene, labelled with the
## component UI's node name ("Construct_Destruct", "Process Stats"). The mockup's
## `OUTPUT / POWER / STORES / UPGRADES` is a naming and ordering guide rather
## than a mandate to merge components, so this sorts them into bands and shortens
## the labels - and leaves a component it has never heard of (a mod's, WI-47)
## with a legible capitalised name in a band of its own rather than dropping it.
##
## **The Status fold (WI-64).** Three of those pages answer the same question -
## "what condition is this module in?" - and each was costing a tab: Power from
## the generation or draw component, Air from the atmosphere component, and the
## synthetic Environment page. On a refinery that is three of eight tabs spent
## before the module has said what it makes. They now fold into **one Status
## tab** whose sections are stacked in a fixed order, which is why a tab carries
## a `sources` list rather than a single `source`: merging is a property of the
## plan, so a module that happens to carry only one of the three still lands on
## Status rather than on a differently-named tab per module. See
## [constant STATUS_MEMBERS].
##
## **Crew tabs.** The three pawn specialisations differ by *which components they
## carry*, which is exactly what the tab set should be derived from. Asking for
## the component rather than testing `is RobotPawnBase` means a modded pawn kind
## that carries a needs component gets a Needs tab for free.

# --- ordering bands ------------------------------------------------------------
#
# Lower sorts earlier. Gaps are deliberate: a band can be inserted between two
# existing ones without renumbering, which is the whole reason these are not
# 0,1,2,3.

## What the module makes - processing, mining, growing, selling.
const BAND_PRODUCTION: int = 10
## The module's live condition - power, air, temperature, the fields it sits in.
## One fixed slot rather than the band of whichever member happens to be present,
## so Status is in the same place on every module that has one (WI-64).
const BAND_STATUS: int = 15
## The systems that hang off the power budget without being it - weapons and
## shields. Generation and draw used to sort here too; they fold into Status now.
const BAND_POWER: int = 20
## What it holds - storage, conveyors, logistics.
const BAND_STORAGE: int = 30
## Who works it, and who visits it.
const BAND_CREW: int = 40
## The hull itself - construction progress while it is going up, upkeep once it
## stands, and whatever a mod puts here.
const BAND_STRUCTURE: int = 50
## Anything this table has never heard of. After the known bands so a mod's tab
## does not land between two vanilla ones and look like a reordering bug, before
## upgrades so upgrades stay last.
const BAND_UNKNOWN: int = 70
## Always last, because it is about the module's future rather than its present.
const BAND_UPGRADES: int = 90

## `component class name -> {label, band}`.
##
## Keyed on the **component's** script class rather than on the UI it produces,
## for two reasons. The tab strip has to be built before any page exists (pages
## are made lazily, one per tab the player actually opens), so a table keyed on
## the UI would force every component UI to be instantiated just to learn its
## name. And the UI node names are what the design is renaming - "Process Stats"
## becomes "Output" - so a table keyed on them would fall through to the fallback
## the moment the rename landed.
const MODULE_TABS: Dictionary[String, Dictionary] = {
	"ProcessorComponent": {"label": "Output", "band": BAND_PRODUCTION},
	"MiningComponent": {"label": "Mining", "band": BAND_PRODUCTION},
	"SustenanceComponent": {"label": "Meals", "band": BAND_PRODUCTION},
	"ShopComponent": {"label": "Shop", "band": BAND_PRODUCTION},
	"TradeComponent": {"label": "Trade", "band": BAND_PRODUCTION},
	"WeaponComponent": {"label": "Weapon", "band": BAND_POWER},
	"ShieldComponent": {"label": "Shield", "band": BAND_POWER},
	"StorageComponent": {"label": "Stores", "band": BAND_STORAGE},
	"ConveyorComponent": {"label": "Belts", "band": BAND_STORAGE},
	"LogisticsBayComponent": {"label": "Drones", "band": BAND_STORAGE},
	"WorkspaceComponent": {"label": "Crew", "band": BAND_CREW},
	# CrewRecruitmentComponent used to sit here with a "Hire" tab. Hiring is the
	# Crew panel's own tab now ([HireTab]) and the component carries no UI at all,
	# so it contributes nothing to walk - an entry for it would be a table row
	# describing a tab that can no longer be produced.
	"ConstructionComponent": {"label": "Build", "band": BAND_STRUCTURE},
}

## Tabs the module set contributes itself rather than getting from a component.
const SYNTHETIC_ENVIRONMENT: String = "Environment"
const SYNTHETIC_UPGRADES: String = "Upgrades"
## What keeping a standing module costs - integrity, breakdown, the upkeep bill -
## and the page DECONSTRUCT / DEMOLISH hang under (2026-09-13). The inverted
## inspector has no footer on its identity strip, and the design is explicit that
## a destructive action never goes there.
const SYNTHETIC_UPKEEP: String = "Upkeep"
const TAB_UPKEEP: StringName = &"upkeep"

const SYNTHETIC_TABS: Dictionary[String, Dictionary] = {
	# Beside Build in the structure band: the two never coexist (one is a site
	# going up, the other a module standing), so they read as one slot.
	SYNTHETIC_UPKEEP: {"label": "Upkeep", "band": BAND_STRUCTURE},
	# Always last, because it is about the module's future rather than its present.
	SYNTHETIC_UPGRADES: {"label": "Upgrades", "band": BAND_UPGRADES},
}

# --- the Status fold -----------------------------------------------------------

## The one merged tab's label and id. Not in [constant SYNTHETIC_TABS]: it is not
## a page the module set builds from a single source, it is several sources
## stacked, and giving it an entry there would imply a `make_page` that maps it
## back to one component.
const SYNTHETIC_STATUS: String = "Status"
const TAB_STATUS: StringName = &"status"

## Every key that folds into Status, with the heading it takes inside the tab and
## where it sorts there.
##
## `order` is the *section* order, and it is deliberately not the band order: the
## sections are read top to bottom in one page, so what matters is that power
## comes before air comes before the surroundings on every module, not where the
## component sat in the scene. Two members sharing a heading ("Power" from a
## generator and from a draw) print it once - see [ModuleStatusTab].
##
## Weapons and shields are NOT here. They are things the module *does*, they each
## carry their own controls, and folding them in would make Status the tab that
## means everything and therefore nothing.
const STATUS_MEMBERS: Dictionary[String, Dictionary] = {
	"PowerGenerationComponent": {"heading": "Power", "order": 10},
	"PowerConsumptionComponent": {"heading": "Power", "order": 20},
	"AtmosphereComponent": {"heading": "Air", "order": 30},
	SYNTHETIC_ENVIRONMENT: {"heading": "Environment", "order": 40},
}

## True when `key` contributes a section to Status rather than a tab of its own.
static func folds_into_status(key: String) -> bool:
	return STATUS_MEMBERS.has(key)

## The key a component contributes, given `chain` - its `class_name` and those of
## its base scripts, most-derived first.
##
## The first name either table recognises wins, so **a subclass inherits its
## base's tab**. `SolarPowerComponent extends PowerGenerationComponent` and does
## not override `get_ui()`, so a solar panel's power page is the power page - and
## keying on the exact class name put it under a tab of its own called "Solar
## Power", in the band reserved for things the plan has never heard of. It has
## been that way since WI-51 and only became loud when WI-64 folded Power into
## Status and left the panel with a Status tab that had no power in it.
##
## A chain nothing recognises keeps its most-derived name, which is what
## [method fallback_label] renders - so a mod's genuinely new component still
## gets its own legible tab, while a mod's `extends PowerGenerationComponent`
## lands in Status for free.
static func resolve_key(chain: Array[String]) -> String:
	for candidate: String in chain:
		if MODULE_TABS.has(candidate) or STATUS_MEMBERS.has(candidate):
			return candidate
	return chain[0] if not chain.is_empty() else ""

## The heading `key`'s section prints inside the Status tab, or "" for a key that
## does not belong to it.
static func status_heading(key: String) -> String:
	return String(STATUS_MEMBERS.get(key, {}).get("heading", ""))

# --- module tabs ---------------------------------------------------------------

## Turns `keys` - the class name of each thing that contributes a page, in the
## order the module's components were walked - into tab definitions in the shape
## [TabStrip.set_tabs] takes, plus the `band` they sorted on and the `sources`
## indices the caller maps back to the components.
##
## `sources` is a list on **every** tab, not only on Status. A caller that had to
## ask which kind of tab it was holding before it knew how to read the field
## would be the merge leaking back out of here; `source` is kept beside it as the
## first index, because it is also the within-band sort tiebreak.
##
## Duplicate labels are numbered rather than deduplicated. A module really can
## carry two storages - a deconstruction site grows a second one for its
## recovered materials - and silently showing one of them would lose a bin the
## player can edit.
static func module_tabs(keys: Array[String]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen: Dictionary[String, int] = {}
	var status: Array[int] = status_sections(keys)
	if not status.is_empty():
		# Claims the label before the walk, so a mod component that renders as
		# "Status" is numbered against it rather than colliding with it - two tabs
		# sharing one id is two tabs the strip cannot tell apart.
		seen[SYNTHETIC_STATUS] = 1
		out.append({
			"id": TAB_STATUS,
			"text": SYNTHETIC_STATUS,
			"band": BAND_STATUS,
			"source": status[0],
			"sources": status,
		})
	for index: int in keys.size():
		var key: String = keys[index]
		if folds_into_status(key):
			continue
		var entry: Dictionary = MODULE_TABS.get(key, SYNTHETIC_TABS.get(key, {}))
		var label: String = String(entry.get("label", "")) if not entry.is_empty() \
			else fallback_label(key)
		var band: int = int(entry.get("band", BAND_UNKNOWN))
		var count: int = int(seen.get(label, 0)) + 1
		seen[label] = count
		if count > 1:
			label = "%s %d" % [label, count]
		var sources: Array[int] = [index]
		out.append({
			"id": StringName(label.to_lower().replace(" ", "_")),
			"text": label,
			"band": band,
			# The walk index, so the sort below is stable within a band and the
			# caller can map a tab back to the component it came from.
			"source": index,
			"sources": sources,
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["band"]) == int(b["band"]):
			return int(a["source"]) < int(b["source"])
		return int(a["band"]) < int(b["band"]))
	return out

## The walk indices that fold into Status, in the order their sections stack.
## Empty when the module carries none of them, which is what leaves such a module
## with no Status tab at all rather than an empty one.
##
## Sorted by [constant STATUS_MEMBERS]'s `order`, ties broken by the walk index -
## so the page reads Power, then Air, then Environment on every module regardless
## of where those components sat in the scene, and two members sharing an order
## keep the module author's ordering.
static func status_sections(keys: Array[String]) -> Array[int]:
	var out: Array[int] = []
	for index: int in keys.size():
		if folds_into_status(keys[index]):
			out.append(index)
	out.sort_custom(func(a: int, b: int) -> bool:
		var rank_a: int = int(STATUS_MEMBERS[keys[a]]["order"])
		var rank_b: int = int(STATUS_MEMBERS[keys[b]]["order"])
		if rank_a == rank_b:
			return a < b
		return rank_a < rank_b)
	return out

## A component this table has never seen - a mod's (WI-47). The trailing
## "Component" is noise on every tab in the strip, so it goes; what is left is
## capitalised into something legible rather than being dropped or rendered as a
## bare class name.
static func fallback_label(key: String) -> String:
	if key.is_empty():
		return "Info"
	var trimmed: String = key
	if trimmed.length() > "Component".length() and trimmed.ends_with("Component"):
		trimmed = trimmed.substr(0, trimmed.length() - "Component".length())
	return trimmed.replace("_", " ").capitalize()

# --- crew tabs -----------------------------------------------------------------

const TAB_NEEDS: StringName = &"needs"
const TAB_VITALS: StringName = &"vitals"
const TAB_JOB: StringName = &"job"
const TAB_SKILLS: StringName = &"skills"
const TAB_KIT: StringName = &"kit"
const TAB_SCHEDULE: StringName = &"schedule"
const TAB_SOCIAL: StringName = &"social"

## The crew tab set, derived from which components the pawn carries.
##
## `flags` keys, all optional and all defaulting to false: `needs`, `vitals`,
## `inventory`, `skills`, `schedule`, `social`. The Job tab has no flag - every
## pawn has a job, including the idle-wander one, so a pawn with no Job tab would
## be a pawn you cannot ask what it is doing.
##
## `vitals` is the robot counterpart of `needs` (energy and integrity in place of
## sleep and hunger) and the two are mutually exclusive: a pawn with both would
## be reporting the same thing twice under two names.
static func crew_tabs(flags: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if bool(flags.get("needs", false)):
		out.append({"id": TAB_NEEDS, "text": "Needs"})
	elif bool(flags.get("vitals", false)):
		out.append({"id": TAB_VITALS, "text": "Vitals"})
	out.append({"id": TAB_JOB, "text": "Job"})
	if bool(flags.get("skills", false)):
		out.append({"id": TAB_SKILLS, "text": "Skills"})
	if bool(flags.get("inventory", false)):
		out.append({"id": TAB_KIT, "text": "Kit"})
	if bool(flags.get("schedule", false)):
		out.append({"id": TAB_SCHEDULE, "text": "Schedule"})
	if bool(flags.get("social", false)):
		out.append({"id": TAB_SOCIAL, "text": "Social"})
	return out

# --- which tab is open (2026-09-13) ----------------------------------------------
#
# The inverted inspector's tabs are a **toggle, not a selector**: nothing open is
# its resting state, and it is the one a player who only wants to know what they
# clicked never has to leave. So "no tab" is a real answer here, spelled `&""`,
# and it is remembered like any other.

## The tab to open when a subject is mounted, given the one its kind was last left
## on (`preferred`) and the tabs this subject actually has.
##
## A remembered tab this subject lacks opens **nothing** rather than the first tab:
## clicking from a refinery with Output open onto a truss that has no Output must
## not pop some other page open. The caller keeps the memory, so the next refinery
## still opens on Output.
static func tab_to_open(preferred: StringName, available: Array[StringName]) -> StringName:
	if preferred == &"" or not available.has(preferred):
		return &""
	return preferred

## What is open after the player presses `clicked` while `open` is: pressing the
## open tab closes the box back to the resting strip, pressing any other opens it.
static func tab_after_click(open: StringName, clicked: StringName) -> StringName:
	return &"" if clicked == open else clicked

## Drops the `band` and `source` bookkeeping, leaving what [TabStrip.set_tabs]
## reads. The extra keys are harmless to the strip - it only looks at `id`,
## `text` and `badge` - but stripping them keeps the strip's contract narrow.
static func to_strip_defs(tabs: Array[Dictionary]) -> Array:
	var out: Array = []
	for tab: Dictionary in tabs:
		out.append({"id": tab["id"], "text": tab["text"]})
	return out
