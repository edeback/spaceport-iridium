class_name NameGenerator
extends RefCounted

## Thin front for pawn naming (WI-22). Call sites only ever see random_name();
## the actual source (the vendored m12 generator today, faction-specific styles
## later) stays hidden here so it can be swapped without touching spawn code.
##
## m12 (addons/m12_name_generator) reads its whole plaintext source tree on
## construction, so it's built once and the pulled pools are cached statically
## for the session. If those sources aren't readable - an export that didn't
## bundle the .txt/.md files, say - the pools come back empty and we fall back
## to a small syllable table with the same output shape.

## First names (both genders, all bundled cultures) and surnames, flattened out
## of m12 once. Empty until _ensure_loaded() runs.
static var _first_names: Array[String] = []
static var _surnames: Array[String] = []
static var _loaded: bool = false

## Returns a "First Last" name. Never empty - fallback covers a missing source
## tree so spawn code never has to null-check.
static func random_name() -> String:
	_ensure_loaded()
	if _first_names.is_empty():
		return _fallback_name()
	var first: String = _first_names[randi() % _first_names.size()]
	if _surnames.is_empty():
		return first
	var last: String = _surnames[randi() % _surnames.size()]
	return "%s %s" % [first, last]

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var gen := m12NameGenerator.new()
	# "male"/"female"/"surname" are file-name tags shared across every culture
	# folder, so one query each pulls the whole international pool.
	_first_names.append_array(gen.generate_name_pool(["male"]))
	_first_names.append_array(gen.generate_name_pool(["female"]))
	_surnames.append_array(gen.generate_name_pool(["surname"]))

# --- fallback ----------------------------------------------------------------

const _FALLBACK_ONSETS: PackedStringArray = [
	"Br", "Cal", "Dor", "Fen", "Gar", "Hal", "Jor", "Kel", "Lor", "Mar",
	"Nor", "Pel", "Quin", "Ral", "Sar", "Tor", "Val", "Wyn", "Zar", "Ash",
]
const _FALLBACK_CODAS: PackedStringArray = [
	"a", "en", "is", "on", "ric", "ta", "us", "wyn", "ex", "or",
	"ia", "an", "eth", "im", "os", "yn",
]

## Two-syllable name from the tables above, used only when m12's sources are
## unreadable. Same "First Last" shape as random_name().
static func _fallback_name() -> String:
	return "%s %s" % [_syllable_word(), _syllable_word()]

static func _syllable_word() -> String:
	var onset: String = _FALLBACK_ONSETS[randi() % _FALLBACK_ONSETS.size()]
	var coda: String = _FALLBACK_CODAS[randi() % _FALLBACK_CODAS.size()]
	return onset + coda
