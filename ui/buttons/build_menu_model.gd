class_name BuildMenuModel

## Pure, autoload-free logic behind the build menu (WI-43): how modules bucket into
## rail categories, the order those categories display in, the search filter, and the
## recently-built MRU list. Kept out of BuildMenu itself so every rule here can be
## GUT-tested by constructing ModuleData directly, never touching Global/SignalBus -
## same contract as StorageQuery and MinimapTransform.
##
## Grouping keys on ModuleData.category_id, NOT tags: tags stay reserved for gameplay
## (upgrade eligibility, global modifiers, the inspection checklist, event conditions,
## minimap color), so one module lands in exactly one rail bucket here. Rail order
## comes from each BuildCategoryData's sort_order (WI-47 M5 replaced the enum, whose
## declaration order used to serve as the ordering).

## Rail label for a category id, falling back to the id itself when nothing declares
## it - a module whose category came from an uninstalled mod still renders.
static func category_name(category_id: StringName) -> String:
	return BuildCategoryData.display_name_of(category_id)

## Buckets non-hidden modules by category_id into Dictionary[StringName, Array[ModuleData]],
## each bucket sorted by display name. Hidden modules (test stubs, the auto-placed
## battery) drop out here exactly as they did under the old tag walk.
static func group_modules(modules: Array[ModuleData]) -> Dictionary:
	var groups: Dictionary = {}
	for module_data: ModuleData in modules:
		if module_data == null or module_data.hidden:
			continue
		var bucket: Array[ModuleData] = groups.get_or_add(module_data.category_id, [] as Array[ModuleData])
		bucket.append(module_data)
	for category_id: StringName in groups:
		(groups[category_id] as Array[ModuleData]).sort_custom(_name_less)
	return groups

## Orders the categories present in rail order: by the declared sort_order, then by
## id so the result is reproducible. A category nothing declares sorts last (at
## UNKNOWN_SORT_ORDER) rather than silently first.
static func category_order(category_ids: Array[StringName]) -> Array[StringName]:
	var ordered: Array[StringName] = []
	for category_id: StringName in category_ids:
		if not ordered.has(category_id):
			ordered.append(category_id)
	ordered.sort_custom(func(a: StringName, b: StringName) -> bool:
		var order_a: int = BuildCategoryData.sort_order_of(a)
		var order_b: int = BuildCategoryData.sort_order_of(b)
		if order_a != order_b:
			return order_a < order_b
		return String(a) < String(b))
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
