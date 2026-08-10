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
## What it costs or supplies to run - generation, draw, batteries, shields.
const BAND_POWER: int = 20
## What it holds - storage, conveyors, logistics.
const BAND_STORAGE: int = 30
## Who works it, and who visits it.
const BAND_CREW: int = 40
## The hull itself - atmosphere, construction progress.
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
	"PowerGenerationComponent": {"label": "Power", "band": BAND_POWER},
	"PowerConsumptionComponent": {"label": "Power", "band": BAND_POWER},
	"WeaponComponent": {"label": "Weapon", "band": BAND_POWER},
	"ShieldComponent": {"label": "Shield", "band": BAND_POWER},
	"StorageComponent": {"label": "Stores", "band": BAND_STORAGE},
	"ConveyorComponent": {"label": "Belts", "band": BAND_STORAGE},
	"LogisticsBayComponent": {"label": "Drones", "band": BAND_STORAGE},
	"WorkspaceComponent": {"label": "Crew", "band": BAND_CREW},
	"CrewRecruitmentComponent": {"label": "Hire", "band": BAND_CREW},
	"AtmosphereComponent": {"label": "Air", "band": BAND_STRUCTURE},
	"ConstructionComponent": {"label": "Build", "band": BAND_STRUCTURE},
}

## Tabs the module set contributes itself rather than getting from a component.
const SYNTHETIC_ENVIRONMENT: String = "Environment"
const SYNTHETIC_UPGRADES: String = "Upgrades"

const SYNTHETIC_TABS: Dictionary[String, Dictionary] = {
	SYNTHETIC_ENVIRONMENT: {"label": "Environment", "band": BAND_STRUCTURE},
	# Always last, because it is about the module's future rather than its present.
	SYNTHETIC_UPGRADES: {"label": "Upgrades", "band": BAND_UPGRADES},
}

# --- module tabs ---------------------------------------------------------------

## Turns `keys` - the class name of each thing that contributes a page, in the
## order the module's components were walked - into tab definitions in the shape
## [TabStrip.set_tabs] takes, plus the `band` they sorted on and the `source`
## index the caller maps back to the component.
##
## Duplicate labels are numbered rather than deduplicated. A module really can
## carry two storages - a deconstruction site grows a second one for its
## recovered materials - and silently showing one of them would lose a bin the
## player can edit.
static func module_tabs(keys: Array[String]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen: Dictionary[String, int] = {}
	for index: int in keys.size():
		var key: String = keys[index]
		var entry: Dictionary = MODULE_TABS.get(key, SYNTHETIC_TABS.get(key, {}))
		var label: String = String(entry.get("label", "")) if not entry.is_empty() \
			else fallback_label(key)
		var band: int = int(entry.get("band", BAND_UNKNOWN))
		var count: int = int(seen.get(label, 0)) + 1
		seen[label] = count
		if count > 1:
			label = "%s %d" % [label, count]
		out.append({
			"id": StringName(label.to_lower().replace(" ", "_")),
			"text": label,
			"band": band,
			# The walk index, so the sort below is stable within a band and the
			# caller can map a tab back to the component it came from.
			"source": index,
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["band"]) == int(b["band"]):
			return int(a["source"]) < int(b["source"])
		return int(a["band"]) < int(b["band"]))
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

## Drops the `band` and `source` bookkeeping, leaving what [TabStrip.set_tabs]
## reads. The extra keys are harmless to the strip - it only looks at `id`,
## `text` and `badge` - but stripping them keeps the strip's contract narrow.
static func to_strip_defs(tabs: Array[Dictionary]) -> Array:
	var out: Array = []
	for tab: Dictionary in tabs:
		out.append({"id": tab["id"], "text": tab["text"]})
	return out
