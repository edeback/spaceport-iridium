class_name ContentPaths
extends RefCounted

## The registry of directories that content is discovered in (WI-47 M1).
##
## Before this, each of the 13 scan sites held its own `const String =
## "res://data/<kind>/"`, so a mod's `.tres` was unreachable no matter where its
## pack was mounted. Now a *kind* of content (&"modules", &"jobs", ...) names one
## directory, and every registered root contributes one directory per kind.
##
## The base game registers `res://data/` here, which makes vanilla literally
## "mod zero": the multi-root walk is the only code path there is, so it can
## never rot from being the untested branch. A root is a directory *containing*
## the per-kind directories - `res://data/` for vanilla, `res://mods/<id>/data/`
## for a mod - which is why kinds are directory names rather than free paths.
##
## Pure and static: no Global, no SignalBus, no nodes. ModManager registers mod
## roots after mounting their packs; everything else only reads.

const BASE_ROOT: String = "res://data/"

const MODULES: StringName = &"modules"
const RESOURCES: StringName = &"resources"
const UNLOCKS: StringName = &"unlocks"
const LOCAL_UPGRADES: StringName = &"local_upgrades"
const TIERS: StringName = &"tiers"
const JOBS: StringName = &"jobs"
const EVENTS: StringName = &"events"
const DISEASES: StringName = &"diseases"
const SKILLS: StringName = &"skills"
const TRAITS: StringName = &"traits"
const SHOPS: StringName = &"shops"
const DIFFICULTY: StringName = &"difficulty"
const BUILD_CATEGORIES: StringName = &"build_categories"
const RECIPES: StringName = &"recipes"
const SHIPS: StringName = &"ships"
const PAWNS: StringName = &"pawns"
## Kinds of mineable body - the asteroid belt, comets (WI-61).
const SPACE_BODIES: StringName = &"space_bodies"
## Who a conversation can be with (WI-62). A `.dialogue` file names a speaker by
## id at the head of a line; anything else prints verbatim with no portrait.
const SPEAKERS: StringName = &"speakers"
## The powers the station has a standing with (WI-62).
const FACTIONS: StringName = &"factions"
## Sets of faces a speaker can be drawn from (WI-62). Scanned as a kind - rather
## than only reached through the speakers that reference one - so a sweep can
## assert every pool actually matched something.
const PORTRAITS: StringName = &"portraits"
## What SAI teaches, and when (WI-63). One [TutorialHintData] per trigger; the
## conversation itself is a `.dialogue` file the hint points at.
const TUTORIAL: StringName = &"tutorial"

## Every kind there is. A scan for anything else is a typo, and a typo here would
## otherwise surface as "this mod added no content", which is invisible - so an
## unknown kind pushes an error instead of quietly returning nothing.
const KINDS: Array[StringName] = [
	MODULES, RESOURCES, UNLOCKS, LOCAL_UPGRADES, TIERS, JOBS,
	EVENTS, DISEASES, SKILLS, TRAITS, SHOPS, DIFFICULTY,
	BUILD_CATEGORIES, RECIPES, SHIPS, PAWNS, SPACE_BODIES,
	SPEAKERS, FACTIONS, PORTRAITS, TUTORIAL,
]

## Roots in load order, base game first. Static so the menus can scan content
## before any manager node exists, and so it survives the scene swap into
## main.tscn the same way SkillData's registry does.
static var _roots: Array[String] = [BASE_ROOT]
## root -> owning mod id. The base root maps to &"", the reserved namespace.
static var _mod_id_by_root: Dictionary[String, StringName] = {BASE_ROOT: &""}

# --- roots --------------------------------------------------------------------

## Adds a mod's content root, after its pack has been mounted. Idempotent: a
## re-registered root keeps its original position, because load order decides
## which content a later stage's patches apply over.
static func register_mod_root(root: String, mod_id: StringName) -> void:
	var normalized: String = _normalize(root)
	if _roots.has(normalized):
		return
	_roots.append(normalized)
	_mod_id_by_root[normalized] = mod_id

## Drops every mod root, leaving the base game. For tests and for a reload of the
## mod list; note that the packs themselves cannot be unmounted, so this only
## makes their content undiscoverable, it does not unload it.
static func clear_mod_roots() -> void:
	_roots = [BASE_ROOT]
	_mod_id_by_root = {BASE_ROOT: &""}

static func roots() -> Array[String]:
	return _roots.duplicate()

## Every directory that could hold `kind` content, base game first.
static func roots_for(kind: StringName) -> Array[String]:
	if not KINDS.has(kind):
		push_error("ContentPaths: unknown content kind '%s'" % kind)
		return [] as Array[String]
	var out: Array[String] = []
	for root: String in _roots:
		out.append(root + String(kind) + "/")
	return out

## Every `.tres` of `kind`, across every root, base game first. This is what the
## scan sites call - one line each, in place of the const they used to hold.
static func scan(kind: StringName) -> Array[String]:
	var out: Array[String] = []
	for dir: String in roots_for(kind):
		# A root that simply doesn't carry this kind costs nothing: ResourceScanner
		# returns empty for a directory that isn't there.
		out.append_array(ResourceScanner.scan_paths(dir))
	return out

# --- ownership and namespacing -------------------------------------------------

## Which mod owns `path`, or &"" for base-game content. Longest match wins so a
## mod root nested under another root can't be mistaken for its parent.
static func mod_id_for_path(path: String) -> StringName:
	var best_root: String = ""
	for root: String in _roots:
		if path.begins_with(root) and root.length() > best_root.length():
			best_root = root
	return _mod_id_by_root.get(best_root, &"")

## The id-validity gate every scan site runs before registering a definition.
## Returns false (with a warning naming the file) when the id can't be used.
##
## Mod content must be namespaced `modid.thing`: two mods that both call their ore
## &"crystal" would otherwise collide silently, and which one won would depend on
## mod load order. Base-game ids stay unprefixed - that IS the reserved namespace -
## so a vanilla id containing a dot is suspicious enough to warn about, but not
## worth refusing, since refusing would delete shipped content.
static func accept_id(id: StringName, path: String, what: String) -> bool:
	if id == &"":
		push_warning("%s with empty id, skipping: %s" % [what, path])
		return false
	var owner_id: StringName = mod_id_for_path(path)
	if owner_id == &"":
		if String(id).contains("."):
			push_warning("%s '%s' is base-game content but looks namespaced (%s)" % [what, id, path])
		return true
	var required: String = String(owner_id) + "."
	if not String(id).begins_with(required):
		push_warning("%s '%s' from mod '%s' must be named '%s<something>', skipping: %s"
				% [what, id, owner_id, required, path])
		return false
	return true

static func _normalize(root: String) -> String:
	return root if root.ends_with("/") else root + "/"
