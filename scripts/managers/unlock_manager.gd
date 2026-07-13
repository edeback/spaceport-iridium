class_name UnlockManager
extends Node

## Owns global (tech-tree) unlock state. Definitions are authored UnlockData
## resources; which of them are purchased is runtime state held here (and, later,
## saved/loaded from here) - never written back onto the shared resources.
##
## Global "module-type improvements" and local per-instance upgrades resolve to
## the same StatModifiers layer; this manager handles the global scope:
##   - broadcast: unlocking a StatModifierEffect applies it to already-built modules
##   - live query: a module applies all active global modifiers when it is built
##     (ModuleBase.ready_constructed -> apply_global_modifiers)

const UNLOCK_PATH: String = "res://data/unlocks/"
const LOCAL_UPGRADE_PATH: String = "res://data/local_upgrades/"

## Bump when the save format changes incompatibly.
const SAVE_VERSION: int = 1
const SAVE_PATH: String = "user://unlocks.save"

## When true, global unlocks auto-load from SAVE_PATH at startup and auto-save
## on every purchase. Off by default so unlocks don't silently persist before a
## central save system exists / you opt in. The Dictionary API and disk helpers
## work regardless of this flag.
@export var auto_persist: bool = false

## Runtime record of one active global, type-wide stat modifier.
class GlobalStatMod extends RefCounted:
	var tags: Array[String]
	var stat: StringName
	var op: StatModifiers.Op
	var value: float
	var source: StringName

	func matches(module_data: ModuleData) -> bool:
		if module_data == null:
			return false
		if tags.is_empty():
			return true
		for tag: String in tags:
			if module_data.tags.has(tag):
				return true
		return false

## All known unlock definitions, keyed by id.
var _unlocks: Dictionary[StringName, UnlockData] = {}
## Ids of unlocks that have been purchased.
var _unlocked_ids: Dictionary[StringName, bool] = {}
## Modules granted via GrantModuleEffect (unlocked despite unlocked_by_default).
var _granted_modules: Dictionary[ModuleData, bool] = {}
## Active global stat modifiers, keyed by source id.
var _global_modifiers: Dictionary[StringName, GlobalStatMod] = {}
## All known local upgrade definitions, keyed by id.
var _local_upgrades: Dictionary[StringName, LocalUpgradeData] = {}

func _ready() -> void:
	Global.unlock_manager = self
	_load_unlocks()
	_load_local_upgrades()
	if auto_persist:
		load_from_file()

# --- loading --------------------------------------------------------------

func _load_unlocks() -> void:
	for file_path: String in _tres_paths(UNLOCK_PATH):
		var res: Resource = ResourceLoader.load(file_path)
		if res is UnlockData:
			var unlock := res as UnlockData
			if unlock.id == &"":
				push_warning("UnlockData with empty id, skipping: " + file_path)
				continue
			_unlocks[unlock.id] = unlock
			if unlock.unlocked_by_default:
				force_unlock(unlock)

func _load_local_upgrades() -> void:
	for file_path: String in _tres_paths(LOCAL_UPGRADE_PATH):
		var res: Resource = ResourceLoader.load(file_path)
		if res is LocalUpgradeData:
			var upgrade := res as LocalUpgradeData
			if upgrade.id == &"":
				push_warning("LocalUpgradeData with empty id, skipping: " + file_path)
				continue
			_local_upgrades[upgrade.id] = upgrade

func _tres_paths(path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		var full := path.path_join(file_name)
		if dir.current_is_dir():
			out += _tres_paths(full)
		elif file_name.get_extension() == "tres":
			out.append(full)
		file_name = dir.get_next()
	dir.list_dir_end()
	return out

# --- queries --------------------------------------------------------------

func get_all_unlocks() -> Array[UnlockData]:
	var out: Array[UnlockData] = []
	out.assign(_unlocks.values())
	return out

## Local upgrades applicable to this module's type and currently unlocked
## globally. Still includes maxed-out / unaffordable ones - the module itself
## (can_apply_local_upgrade) decides purchasability from its per-instance tiers.
func get_local_upgrade_catalog(module: ModuleBase) -> Array[LocalUpgradeData]:
	var out: Array[LocalUpgradeData] = []
	if module == null:
		return out
	for upgrade: LocalUpgradeData in _local_upgrades.values():
		if upgrade.matches_module(module.module_data) and upgrade.is_globally_unlocked():
			out.append(upgrade)
	return out

func is_unlocked(unlock: UnlockData) -> bool:
	return unlock != null and _unlocked_ids.has(unlock.id)

func is_module_granted(module: ModuleData) -> bool:
	return _granted_modules.has(module)

func get_unlock_by_id(id: StringName) -> UnlockData:
	return _unlocks.get(id)

func get_local_upgrade_by_id(id: StringName) -> LocalUpgradeData:
	return _local_upgrades.get(id)

## True if every (non-null) prerequisite of this unlock is already owned.
func prerequisites_met(unlock: UnlockData) -> bool:
	if unlock == null:
		return false
	for prereq: UnlockData in unlock.prerequisites:
		# Null entries are placeholders in authored data - ignore them.
		if prereq != null and not is_unlocked(prereq):
			return false
	return true

## Purchasable = not already owned, all prerequisites owned, and affordable.
func can_unlock(unlock: UnlockData) -> bool:
	if unlock == null or is_unlocked(unlock):
		return false
	return prerequisites_met(unlock) and unlock.can_afford()

# --- mutation -------------------------------------------------------------

func try_unlock(unlock: UnlockData) -> bool:
	if not can_unlock(unlock):
		return false
	unlock.withdraw_cost()
	_unlocked_ids[unlock.id] = true
	for effect: UnlockEffect in unlock.effects:
		if effect != null:
			effect.apply(self, unlock)
	SignalBus.global_unlock_changed.emit(unlock)
	if auto_persist:
		save_to_file()
	return true
	
## Set unlocked without going through cost or prereq checks (starting nodes, or
## a future load-from-save path).
func force_unlock(unlock: UnlockData) -> void:
	if unlock == null or is_unlocked(unlock):
		return
	_unlocked_ids[unlock.id] = true
	for effect: UnlockEffect in unlock.effects:
		if effect != null:
			effect.apply(self, unlock)
	SignalBus.global_unlock_changed.emit(unlock)

## Called by GrantModuleEffect. Marks a module buildable and notifies its UI.
func grant_module(module: ModuleData) -> void:
	if module == null or _granted_modules.has(module):
		return
	_granted_modules[module] = true
	# The build-menu button group listens to this to reveal the button.
	module.module_lock_changed.emit(true)

## Called by StatModifierEffect. Registers a global modifier and broadcasts it to
## every already-constructed module that matches.
func register_global_modifier(tags: Array[String], stat: StringName, op: StatModifiers.Op, value: float, source: StringName) -> void:
	if _global_modifiers.has(source):
		return
	var mod := GlobalStatMod.new()
	mod.tags = tags.duplicate()
	mod.stat = stat
	mod.op = op
	mod.value = value
	mod.source = source
	_global_modifiers[source] = mod
	for module: ModuleBase in _constructed_modules():
		if mod.matches(module.module_data):
			module.stat_modifiers.add_modifier(mod.stat, mod.op, mod.value, mod.source)

func unregister_global_modifier(source: StringName) -> void:
	if not _global_modifiers.erase(source):
		return
	for module: ModuleBase in _constructed_modules():
		module.stat_modifiers.remove_source(source)

## Live query on build: apply every active global modifier this module qualifies
## for. Call once, when the module becomes constructed.
func apply_global_modifiers(module: ModuleBase) -> void:
	if module == null:
		return
	for mod: GlobalStatMod in _global_modifiers.values():
		if mod.matches(module.module_data):
			module.stat_modifiers.add_modifier(mod.stat, mod.op, mod.value, mod.source)

func _constructed_modules() -> Array[ModuleBase]:
	var out: Array[ModuleBase] = []
	for node: Node in get_tree().get_nodes_in_group("module"):
		if node is ModuleBase and (node as ModuleBase).is_complete():
			out.append(node)
	return out

# --- persistence ----------------------------------------------------------
# Only the set of unlocked ids is stored; granted modules and global stat
# modifiers are derived by re-running each unlock's effects on load. A central
# save system can call get_save_data()/load_save_data() and fold the result into
# its own file; the *_file helpers are a self-contained convenience.

func get_save_data() -> Dictionary:
	var ids: Array[String] = []
	for id: StringName in _unlocked_ids:
		ids.append(String(id))
	return {"version": SAVE_VERSION, "unlocked": ids}

func load_save_data(data: Dictionary) -> void:
	_clear_unlock_state()
	for id_str: String in data.get("unlocked", []):
		var unlock := get_unlock_by_id(StringName(id_str))
		if unlock != null:
			# force_unlock re-marks it owned and re-runs effects, regenerating
			# granted modules and global modifiers.
			force_unlock(unlock)
		else:
			push_warning("Unknown unlock id in save, skipping: " + id_str)

## Reset all owned/derived global-unlock state. Intended for a fresh load; if
## called mid-game it also strips applied global modifiers from live modules and
## re-hides granted module buttons.
func _clear_unlock_state() -> void:
	for source: StringName in _global_modifiers.keys():
		for module: ModuleBase in _constructed_modules():
			module.stat_modifiers.remove_source(source)
	_global_modifiers.clear()
	for module_data: ModuleData in _granted_modules.keys():
		module_data.module_lock_changed.emit(false)
	_granted_modules.clear()
	_unlocked_ids.clear()

func save_to_file(path: String = SAVE_PATH) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not open unlock save for writing: " + path)
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(get_save_data()))
	file.close()
	return OK

## Returns true if a save was found and applied.
func load_from_file(path: String = SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Could not open unlock save for reading: " + path)
		return false
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_warning("Unlock save file is malformed: " + path)
		return false
	load_save_data(parsed)
	return true
