class_name ModRegistry
extends RefCounted

## Decides which mods load and in what order (WI-47 M1). Pure: it takes parsed
## manifests and returns an ordering plus a list of things to tell the player.
## Nothing here touches the filesystem or mounts anything - that's ModManager -
## so every rule below is unit-testable.
##
## The rules, in the order they are applied:
##   1. A manifest that failed to parse is dropped.
##   2. Two mods claiming one id drops BOTH. Keeping "the first" would make which
##      mod the player actually gets depend on directory order, which is the exact
##      silent-and-load-order-dependent failure this WI exists to remove.
##   3. A mod whose dependency isn't installed is dropped, transitively.
##   4. A mod built for another game version is KEPT, with a warning: it is
##      usually fine across a patch, and the player is better placed to judge.
##   5. The rest are ordered by `deps` + `load_after`, ties broken alphabetically
##      so the order is reproducible run to run.
##   6. A dependency cycle is reported and its members load alphabetically. Fail
##      soft: dropping a cycle would cascade into every mod that depends on it.

class Resolution extends RefCounted:
	## Mods to mount, in load order.
	var ordered: Array[ModManifest] = []
	## Why a mod is NOT loaded, in player-facing words.
	var problems: PackedStringArray = PackedStringArray()
	## Loaded anyway, but worth saying out loud.
	var warnings: PackedStringArray = PackedStringArray()

	func loaded_ids() -> Array[StringName]:
		var out: Array[StringName] = []
		for manifest: ModManifest in ordered:
			out.append(manifest.id)
		return out

static func resolve(manifests: Array[ModManifest], game_version: String = "") -> Resolution:
	var out := Resolution.new()
	var surviving: Dictionary[StringName, ModManifest] = _drop_unusable_and_collisions(manifests, out)
	_drop_missing_deps(surviving, out)
	_warn_version_drift(surviving, game_version, out)
	for id: StringName in _order(surviving, out):
		out.ordered.append(surviving[id])
	return out

# --- rules 1 & 2 ---------------------------------------------------------------

static func _drop_unusable_and_collisions(manifests: Array[ModManifest], out: Resolution) -> Dictionary[StringName, ModManifest]:
	var by_id: Dictionary[StringName, Array] = {}
	for manifest: ModManifest in manifests:
		if manifest == null:
			continue
		if not manifest.is_usable():
			out.problems.append("%s: %s" % [_where(manifest), manifest.error])
			continue
		if not by_id.has(manifest.id):
			by_id[manifest.id] = []
		var group: Array = by_id[manifest.id]
		group.append(manifest)

	var surviving: Dictionary[StringName, ModManifest] = {}
	for id: StringName in by_id:
		var group: Array = by_id[id]
		if group.size() > 1:
			var places: PackedStringArray = PackedStringArray()
			for manifest: ModManifest in group:
				places.append(_where(manifest))
			out.problems.append("two mods claim the id '%s' (%s) - neither was loaded, remove one"
					% [id, ", ".join(places)])
			continue
		surviving[id] = group[0]
	return surviving

# --- rule 3 --------------------------------------------------------------------

## Repeated to a fixed point so a mod depending on a dropped mod drops too, and
## so on down the chain - otherwise B would load against a missing A.
static func _drop_missing_deps(surviving: Dictionary[StringName, ModManifest], out: Resolution) -> void:
	var changed: bool = true
	while changed:
		changed = false
		for id: StringName in surviving.keys():
			var manifest: ModManifest = surviving[id]
			for dep: StringName in manifest.deps:
				if surviving.has(dep):
					continue
				out.problems.append("mod '%s' needs '%s', which isn't installed" % [id, dep])
				surviving.erase(id)
				changed = true
				break

# --- rule 4 --------------------------------------------------------------------

static func _warn_version_drift(surviving: Dictionary[StringName, ModManifest], game_version: String, out: Resolution) -> void:
	if game_version == "":
		return
	for id: StringName in surviving:
		var manifest: ModManifest = surviving[id]
		if manifest.game_version != "" and manifest.game_version != game_version:
			out.warnings.append("mod '%s' was built for game version %s (this is %s) - it may misbehave"
					% [id, manifest.game_version, game_version])

# --- rules 5 & 6 ---------------------------------------------------------------

static func _order(surviving: Dictionary[StringName, ModManifest], out: Resolution) -> Array[StringName]:
	var incoming: Dictionary[StringName, int] = {}
	var after: Dictionary[StringName, Array] = {}
	for id: StringName in surviving:
		incoming[id] = 0
		after[id] = []
	for id: StringName in surviving:
		var manifest: ModManifest = surviving[id]
		var predecessors: Array[StringName] = []
		predecessors.append_array(manifest.deps)
		predecessors.append_array(manifest.load_after)
		for before: StringName in predecessors:
			# load_after naming a mod that isn't installed is not an error - it is
			# the whole point of it being soft.
			if before == id or not surviving.has(before):
				continue
			var edges: Array = after[before]
			if edges.has(id):
				continue
			edges.append(id)
			incoming[id] = int(incoming[id]) + 1

	# Kahn's algorithm with the ready set kept sorted, so equally-eligible mods
	# always load in the same order rather than in dictionary order.
	var ready: Array[StringName] = []
	for id: StringName in surviving:
		if int(incoming[id]) == 0:
			ready.append(id)
	_sort_ids(ready)

	var ordered: Array[StringName] = []
	while not ready.is_empty():
		var id: StringName = ready.pop_front()
		ordered.append(id)
		for next_id: StringName in after[id]:
			incoming[next_id] = int(incoming[next_id]) - 1
			if int(incoming[next_id]) == 0:
				ready.append(next_id)
		_sort_ids(ready)

	if ordered.size() < surviving.size():
		var stuck: Array[StringName] = []
		var stuck_names: PackedStringArray = PackedStringArray()
		for id: StringName in surviving:
			if not ordered.has(id):
				stuck.append(id)
		_sort_ids(stuck)
		for id: StringName in stuck:
			stuck_names.append(String(id))
		out.problems.append("circular dependency between %s - loading them alphabetically instead"
				% ", ".join(stuck_names))
		ordered.append_array(stuck)
	return ordered

## Alphabetical by TEXT. Array[StringName].sort() compares the names' internal
## pointers, not their characters, so it produces an order that depends on which
## StringNames the engine happened to intern first - reproducible within a run and
## meaningless between runs. Load order has to be stable, so it goes through String.
static func _sort_ids(ids: Array[StringName]) -> void:
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))

static func _where(manifest: ModManifest) -> String:
	if manifest.folder != "":
		return manifest.folder
	return String(manifest.id) if manifest.id != &"" else "<unnamed mod>"
