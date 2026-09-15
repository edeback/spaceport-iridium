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
##
## Bucket order is [method sort_bucket]'s: buildable first, locked after, name
## within each. Hidden is the only thing that removes a module from a *bucket*;
## which of a bucket's modules the menu actually lists, and whether its category
## reaches the rail at all, is [method is_listed] / [method category_shown]'s -
## both change as the tech tree opens, and the buckets never do.
static func group_modules(modules: Array[ModuleData]) -> Dictionary:
	var groups: Dictionary = {}
	for module_data: ModuleData in modules:
		if module_data == null or module_data.hidden:
			continue
		var bucket: Array[ModuleData] = groups.get_or_add(module_data.category_id, [] as Array[ModuleData])
		bucket.append(module_data)
	for category_id: StringName in groups:
		var bucket: Array[ModuleData] = groups[category_id]
		groups[category_id] = sort_bucket(bucket)
	return groups

## Orders one category's modules for the flyout: everything currently buildable
## first, everything gated behind an unlock after it, alphabetical within each
## half. Never drops an entry: *which* locked modules are listed is decided
## before this, by [method is_listed], and the ones that survive render dimmed
## with their gating tech.
##
## `is_locked` is injected rather than read off the module so this stays pure:
## `ModuleData.is_unlocked()` goes through `Global.unlock_manager`, and a rule
## that needs an autoload is a rule that cannot be tested. The view passes the
## live predicate; the suite passes a stub.
##
## Returns a fresh array - never mutates the input.
static func sort_bucket(modules: Array[ModuleData], is_locked: Callable = Callable()) -> Array[ModuleData]:
	var out: Array[ModuleData] = modules.duplicate()
	var locked := func(module_data: ModuleData) -> bool:
		if is_locked.is_valid():
			return bool(is_locked.call(module_data))
		return false
	out.sort_custom(func(a: ModuleData, b: ModuleData) -> bool:
		var a_locked: bool = locked.call(a)
		var b_locked: bool = locked.call(b)
		if a_locked != b_locked:
			return b_locked # an unlocked module sorts ahead of a locked one
		return _name_less(a, b))
	return out

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

# --- locked entries (WI-54) ----------------------------------------------------

## What a locked row prints when nothing in the tree grants it. A module with
## `unlocked_by_default = false` and no [GrantModuleEffect] pointing at it is
## unreachable by design (a mod's leftover, a node someone deleted) - saying so
## is better than an empty line that reads like a missing label.
const NO_GATE_LABEL: String = "Unavailable"

## The unlock that grants `module`, found by walking each node's effects for the
## [GrantModuleEffect] that names it. Null when nothing grants it.
##
## The walk is the deliberate choice over a `required_unlock` back-reference on
## [ModuleData]: the grant already lives on the unlock, and a back-reference
## would be a second source of truth about the same edge - one that a mod adding
## its own tech tree over vanilla modules could not keep in step. The tree is a
## few dozen nodes with a handful of effects each, and the answer is only asked
## for a row that is actually being drawn.
##
## Takes the unlock list rather than reaching for [UnlockManager] so it stays
## pure and testable.
static func gating_unlock(module: ModuleData, unlocks: Array[UnlockData]) -> UnlockData:
	if module == null:
		return null
	for unlock: UnlockData in unlocks:
		if _grants(unlock, module):
			return unlock
	return null

## Whether `unlock` carries a [GrantModuleEffect] naming `module`. The one place
## the grant edge is read, so the gate label and the listing rule below can never
## disagree about which node unlocks what.
static func _grants(unlock: UnlockData, module: ModuleData) -> bool:
	if unlock == null or module == null:
		return false
	for effect: UnlockEffect in unlock.effects:
		var grant: GrantModuleEffect = effect as GrantModuleEffect
		if grant != null and grant.module == module:
			return true
	return false

## The `NEEDS: DRILLING II` line on a locked row. Falls back to the unlock's id
## when it carries no display name, and to [constant NO_GATE_LABEL] when nothing
## grants the module at all.
static func gating_label(module: ModuleData, unlocks: Array[UnlockData]) -> String:
	var unlock: UnlockData = gating_unlock(module, unlocks)
	if unlock == null:
		return NO_GATE_LABEL
	var label: String = unlock.name if unlock.name != "" else String(unlock.id)
	if label == "":
		return NO_GATE_LABEL
	return "Needs: %s" % label

# --- what the menu lists (2026-09-15) -------------------------------------------
# WI-54 rendered every locked module and never hid a category. That left the rail
# advertising things the player could not act on: Defense and Logistics opened
# on nothing buildable, and a tier-1 station's Power flyout offered a fusion
# reactor it could not even research for two promotions. The menu now lists what
# the player can build *or can do something about* - a locked module stays,
# dimmed, while research alone can reach it; one that also needs a promotion, or
# that nothing grants, does not.

## Whether `unlock` can be bought without the station being promoted - now, or
## once research the station can also reach is owned. An owned node is reachable
## whatever its `min_tier`: a cheat or an old save can own one above the station's
## tier, and an owned node gates nothing. Null prerequisites are authoring
## placeholders and are ignored, as [method UnlockManager.prerequisites_met]
## ignores them.
##
## `is_owned` is injected for [method sort_bucket]'s reason: ownership lives on
## [UnlockManager], and a rule that reads an autoload cannot be tested.
static func unlock_reachable(unlock: UnlockData, tier: int, is_owned: Callable = Callable()) -> bool:
	var memo: Dictionary[UnlockData, bool] = {}
	return _reachable(unlock, tier, is_owned, memo)

## `memo` keeps the walk linear and finite. A diamond of prerequisites resolves
## each node once; and a node is recorded unreachable *before* its prerequisites
## are walked, so a prerequisite cycle - an authoring error nothing could ever buy
## into - ends as unreachable rather than recursing forever. Any node that meets an
## in-progress entry depends on its own ancestor, so the early `false` is the
## right answer and not merely a stop.
static func _reachable(unlock: UnlockData, tier: int, is_owned: Callable,
		memo: Dictionary[UnlockData, bool]) -> bool:
	if unlock == null:
		return false
	if memo.has(unlock):
		return memo[unlock]
	if is_owned.is_valid() and bool(is_owned.call(unlock)):
		memo[unlock] = true
		return true
	memo[unlock] = false
	if not unlock.available_at_tier(tier):
		return false
	for prereq: UnlockData in unlock.prerequisites:
		if prereq != null and not _reachable(prereq, tier, is_owned, memo):
			return false
	memo[unlock] = true
	return true

## Whether any node that grants `module` is [method unlock_reachable]. *Any*,
## not [method gating_unlock]'s first: a module two trees both grant is within
## reach if either of them is.
static func module_reachable(module: ModuleData, unlocks: Array[UnlockData], tier: int,
		is_owned: Callable = Callable()) -> bool:
	if module == null:
		return false
	# One memo across every granter: entries are final once a walk returns, so a
	# prerequisite two granters share is resolved once.
	var memo: Dictionary[UnlockData, bool] = {}
	for unlock: UnlockData in unlocks:
		if _grants(unlock, module) and _reachable(unlock, tier, is_owned, memo):
			return true
	return false

## Whether the build menu lists `module` at all. A buildable module always is,
## whatever the tier - it can be placed, so it has to be pickable. A locked one is
## listed only while research the station can reach grants it; one that needs a
## promotion first, or that nothing grants, is left off, because nothing the
## player can do today changes it.
##
## `locked` is the caller's answer rather than read off the module, for
## [method sort_bucket]'s reason.
static func is_listed(module: ModuleData, locked: bool, unlocks: Array[UnlockData], tier: int,
		is_owned: Callable = Callable()) -> bool:
	if module == null or module.hidden:
		return false
	if not locked:
		return true
	return module_reachable(module, unlocks, tier, is_owned)

## The entries of `modules` that `keep` accepts, order preserved. Returns a fresh
## array - never mutates the input.
static func listed_only(modules: Array[ModuleData], keep: Callable) -> Array[ModuleData]:
	var out: Array[ModuleData] = []
	for module_data: ModuleData in modules:
		if module_data != null and bool(keep.call(module_data)):
			out.append(module_data)
	return out

## Whether a category reaches the rail: only while it holds something the player
## can build right now. A category of nothing but locked entries - Defense and
## Logistics on a new station - is R&D's to advertise, not the build menu's, and
## it joins the rail the moment its first module is granted.
##
## Deliberately not "holds something listed": a category of researchable-but-
## locked modules is exactly the distraction this rule exists to remove.
static func category_shown(bucket: Array[ModuleData], is_locked: Callable = Callable()) -> bool:
	for module_data: ModuleData in bucket:
		if module_data == null or module_data.hidden:
			continue
		if not (is_locked.is_valid() and bool(is_locked.call(module_data))):
			return true
	return false

# --- row text (WI-54) -----------------------------------------------------------

## The separator between the parts of a meta line, everywhere in the design.
const META_SEPARATOR: String = " · "

## A module's footprint as the design writes it: `2×2`.
static func format_footprint(footprint: Vector2i) -> String:
	return "%d×%d" % [maxi(footprint.x, 1), maxi(footprint.y, 1)]

## A module's build cost as one meta line: `12 STEEL · 4 SILICON`.
##
## Ordered by descending amount then by name, so the expensive part of a cost
## reads first and the same module always prints the same string - a dictionary's
## iteration order must never decide what the player sees. A free module returns
## an empty string rather than "0", which the caller hides.
static func format_cost(costs: Dictionary[ResourceData, int]) -> String:
	var entries: Array[ResourceData] = []
	for resource: ResourceData in costs:
		if resource != null and costs[resource] > 0:
			entries.append(resource)
	entries.sort_custom(func(a: ResourceData, b: ResourceData) -> bool:
		if costs[a] != costs[b]:
			return costs[a] > costs[b]
		return a.name.naturalnocasecmp_to(b.name) < 0)
	var parts: Array[String] = []
	for resource: ResourceData in entries:
		parts.append("%d %s" % [costs[resource], resource.name.to_upper()])
	return META_SEPARATOR.join(parts)

## The selected module's rate/draw line, from the numbers its scene declares
## ([ModuleFacts]). Signed parts read `+120 ENERGY` / `−14 ENERGY`; unsigned ones
## are capacities, not flows.
##
## Ordering is fixed rather than "whatever the module has", so the same fact
## always sits in the same place across two modules the player is comparing.
## Returns an empty array for a module that declares none of them - a corridor
## has nothing to say here, and an empty line is better than a fabricated zero.
static func format_facts(power_draw: float, power_output: float,
		storage_capacity: int, crew_slots: int) -> Array[String]:
	var parts: Array[String] = []
	if power_output > 0.0:
		parts.append("+%s ENERGY" % _trim_number(power_output))
	if power_draw > 0.0:
		# U+2212 MINUS, not a hyphen: it is the same width as the plus above it,
		# so two stacked facts line up.
		parts.append("−%s ENERGY" % _trim_number(power_draw))
	if storage_capacity > 0:
		parts.append("%d STORAGE" % storage_capacity)
	if crew_slots > 0:
		parts.append("%d CREW" % crew_slots)
	return parts

## True for a fact the design prints in amber - the ones that cost the player
## something. Kept beside the formatter so "which half of the line is amber" is
## one rule rather than a `begins_with` test copied into every panel that grows a
## facts line (invariant 5: amber is a budget).
static func fact_is_a_cost(part: String) -> bool:
	return part.begins_with("−")

## Drops a trailing `.0` so whole numbers read as whole numbers, and keeps one
## decimal otherwise. Power values are authored as floats but are almost always
## integral.
static func _trim_number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return "%d" % int(roundf(value))
	return "%.1f" % value
