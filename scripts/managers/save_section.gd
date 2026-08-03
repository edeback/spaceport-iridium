class_name SaveSection
extends RefCounted

## One top-level block in a save file (WI-47 M3).
##
## The save used to be a 17-entry dictionary literal in SaveManager.save_slot(),
## mirrored by a 17-call sequence in _apply_pending_load() whose ORDER carried
## the real design ("after resources", "before pawns", "after world AND market").
## A mod that adds a manager - a new threat system, a faction, a research track -
## had nowhere to put state, because the list of sections was code.
##
## Now each contributing system registers one of these in its own _ready(), the
## same way it registers itself into Global, and the order it declares is the
## order it is both written and restored in.

## Top-level key in the save's `sections` dictionary. Stable forever: it is what
## an existing save file says.
var id: StringName
## LOWER RESTORES FIRST. The ordering constraints are load-bearing and each
## registrant carries the reason it sits where it does.
var order: int
## Returns this section's state. Usually a manager's own get_save_data.
var collect: Callable
## Takes it back. Usually a manager's own load_save_data.
var apply: Callable
## What to hand `apply` when the save has no such section - `{}` for almost
## everything, `[]` for the two list-shaped sections. Needed because the target
## methods are typed, so "absent" cannot simply be null.
var empty: Variant

func _init(section_id: StringName, section_order: int, section_collect: Callable,
		section_apply: Callable, section_empty: Variant = {}) -> void:
	id = section_id
	order = section_order
	collect = section_collect
	apply = section_apply
	empty = section_empty

## False once the registering node has been freed - which happens to every
## vanilla manager on a scene reload, and is how stale registrations from the
## previous run get dropped rather than called into freed memory.
func is_live() -> bool:
	return collect.is_valid() and apply.is_valid()
