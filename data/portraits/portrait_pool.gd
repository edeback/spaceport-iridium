class_name PortraitPool
extends Resource

## A set of faces a speaker can be drawn from (WI-62 §4).
##
## The contents are **scanned, not enumerated**: a pool names a directory and an
## optional filename prefix, and [ResourceScanner] lists what is actually there.
## Two reasons, and the second is the one that bites:
##
## 1. A mod drops portraits in its own directory and gets a pool with no core
##    edit, which is WI-47's bar.
## 2. The vanilla art has a hole in it. `thirstsector_portraits/` runs
##    `portrait12`…`portrait18`, then `portrait20`…`portrait49` - there is no
##    `portrait19`. Any code that builds a path from a numeric range asks for a
##    missing file one time in thirty-seven. A directory listing cannot.
##
## The listing is sorted and cached: sorted so a seeded roll is reproducible
## (directory order is not a guarantee), cached because a pool is asked for a face
## once per speaker per conversation and re-walking a directory for that is waste.

@export var id: StringName = &""
## Human-readable, for the cheat dump and for an editor tooltip. Never shown to
## the player - a pool is not a faction.
@export var description: String = ""
## Directory to list. Not recursive-safe by accident: [ResourceScanner] *is*
## recursive, so a directory with sub-folders contributes all of them.
@export_dir var directory: String = ""
## Optional filename prefix filter, applied to the file's base name. This is what
## separates eight pools sharing one directory.
@export var prefix: String = ""
## An explicit exclusion list, for a prefix that is a prefix of another one.
## `portrait` matches `portrait_pirate01` as well as `portrait12`, so the civilian
## pool excludes every faction prefix by name.
@export var excluded_prefixes: PackedStringArray = []
## File extension to list. Exposed rather than hardcoded so a pool of `.svg`
## portraits works without a code change.
@export var extension: String = "png"

## Sorted res:// paths, or an empty array before the first [method paths] call.
var _paths: PackedStringArray = []
var _scanned: bool = false

## Every face in the pool, sorted. Shared; do not mutate.
func paths() -> PackedStringArray:
	if not _scanned:
		_scan()
	return _paths

func size() -> int:
	return paths().size()

func is_empty() -> bool:
	return paths().is_empty()

## The path of the face at `index`, wrapped into range. Wrapping rather than
## clamping so a caller with a large arbitrary number (a hash, a seeded roll)
## lands on a face rather than always on the last one.
##
## Separate from [method texture_at] because the path is what [SpeakerCast] holds
## and what a test can assert on without an imported texture.
func path_at(index: int) -> String:
	var list: PackedStringArray = paths()
	if list.is_empty():
		return ""
	return list[posmod(index, list.size())]

func texture_at(index: int) -> Texture2D:
	var path: String = path_at(index)
	if path.is_empty():
		return null
	return ResourceLoader.load(path) as Texture2D

## Drops the cache. Only the mod loader and the tests need this; a pool's
## directory cannot change during a run.
func rescan() -> void:
	_scanned = false
	_paths = PackedStringArray()

func _scan() -> void:
	_scanned = true
	_paths = PackedStringArray()
	if directory.is_empty():
		push_warning("PortraitPool '%s' names no directory" % id)
		return
	var found: Array[String] = ResourceScanner.scan_paths(directory, extension)
	for path: String in found:
		if _accepts(path.get_file()):
			_paths.append(path)
	_paths.sort()
	if _paths.is_empty():
		# A speaker falls back to no portrait rather than a broken rect, but an
		# empty pool is almost always a typo'd prefix and should be said out loud.
		push_warning("PortraitPool '%s' matched nothing in %s" % [id, directory])

func _accepts(file_name: String) -> bool:
	if not prefix.is_empty() and not file_name.begins_with(prefix):
		return false
	for excluded: String in excluded_prefixes:
		if not excluded.is_empty() and file_name.begins_with(excluded):
			return false
	return true
