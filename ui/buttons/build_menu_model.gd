class_name BuildMenuModel

## Pure, autoload-free logic behind the build menu (WI-43): how modules bucket into
## rail categories, the order those categories display in, the search filter, and the
## recently-built MRU list. Kept out of BuildMenu itself so every rule here can be
## GUT-tested by constructing ModuleData directly, never touching Global/SignalBus -
## same contract as StorageQuery and MinimapTransform.
##
## Grouping keys on the ModuleData.UICategory enum, NOT tags: tags stay reserved for
## gameplay (upgrade eligibility, global modifiers, the inspection checklist, event
## conditions, minimap color), so one module lands in exactly one rail bucket here.
## The enum's declaration order IS the canonical rail order (OTHER last), so ordering
## is just an ascending sort of the enum values.

## Human label per category. GDScript can't reflect a custom enum's member names at
## runtime, so the rail's text comes from here.
static func category_name(category: ModuleData.UICategory) -> String:
	match category:
		ModuleData.UICategory.CORE: return "Core"
		ModuleData.UICategory.POWER: return "Power"
		ModuleData.UICategory.LIFE_SUPPORT: return "Life Support"
		ModuleData.UICategory.INDUSTRY: return "Industry"
		ModuleData.UICategory.FOOD: return "Food"
		ModuleData.UICategory.MINING: return "Mining"
		ModuleData.UICategory.STORAGE: return "Storage"
		ModuleData.UICategory.CREW: return "Crew"
		ModuleData.UICategory.COMMERCE: return "Commerce"
		ModuleData.UICategory.DEFENSE: return "Defense"
		ModuleData.UICategory.LOGISTICS: return "Logistics"
		_: return "Other"

## Buckets non-hidden modules by ui_category into Dictionary[UICategory, Array[ModuleData]],
## each bucket sorted by display name. Hidden modules (test stubs, the auto-placed
## battery) drop out here exactly as they did under the old tag walk.
static func group_modules(modules: Array[ModuleData]) -> Dictionary:
	var groups: Dictionary = {}
	for module_data: ModuleData in modules:
		if module_data == null or module_data.hidden:
			continue
		var bucket: Array[ModuleData] = groups.get_or_add(module_data.ui_category, [] as Array[ModuleData])
		bucket.append(module_data)
	for category: int in groups:
		(groups[category] as Array[ModuleData]).sort_custom(_name_less)
	return groups

## Orders the categories present in canonical rail order. The enum values ARE that
## order (OTHER is the max, so it lands last), so this just de-dupes and sorts ascending.
static func category_order(categories: Array[int]) -> Array[int]:
	var ordered: Array[int] = []
	for category: int in categories:
		if not ordered.has(category):
			ordered.append(category)
	ordered.sort()
	return ordered

## Case-insensitive substring match on display name, sorted by name. A blank or
## whitespace-only query returns nothing (the flyout closes rather than dumping every
## module). Unlock filtering is the caller's job - this stays pure.
static func filter_by_name(modules: Array[ModuleData], query: String) -> Array[ModuleData]:
	var out: Array[ModuleData] = []
	var needle: String = query.strip_edges().to_lower()
	if needle.is_empty():
		return out
	for module_data: ModuleData in modules:
		if module_data == null or module_data.hidden:
			continue
		if module_data.name.to_lower().contains(needle):
			out.append(module_data)
	out.sort_custom(_name_less)
	return out

## MRU push for recently-built ids: moves id to the front, de-dupes, caps length.
## Keyed on stable ModuleData.id (not the object) so it survives resource reloads and
## is cheap to persist later if we ever choose to. Returns a fresh array - never
## mutates the input.
static func push_recent(recent: Array[StringName], id: StringName, cap: int) -> Array[StringName]:
	var out: Array[StringName] = recent.duplicate()
	out.erase(id) # drop the earlier occurrence so the re-build floats to front
	out.insert(0, id)
	if cap < 0:
		cap = 0
	if out.size() > cap:
		out.resize(cap)
	return out

static func _name_less(a: ModuleData, b: ModuleData) -> bool:
	return a.name.naturalnocasecmp_to(b.name) < 0
