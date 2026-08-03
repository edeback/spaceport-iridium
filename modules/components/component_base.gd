class_name ComponentBase
extends Node2D

@export var ui_info_panel_element: PackedScene

var component_enabled: bool = false:
	set(new_enabled):
		if component_enabled != new_enabled:
			component_enabled = new_enabled
			if component_enabled:
				_on_enabled()
			else:
				_on_disabled()
				
var owner_module: ModuleBase

signal new_error(component: ComponentBase, error_message: String)

var last_error: String = "":
	get:
		return last_error
	set(new_value):
		if last_error != new_value:
			last_error = new_value
			new_error.emit(self, new_value)

func _on_enabled() -> void:
	pass
	
func _on_disabled() -> void:
	pass

func get_parent_module() -> ModuleBase:
	if owner is ModuleBase:
		return owner as ModuleBase
	elif owner is ComponentBase:
		return (owner as ComponentBase).get_parent_module()
	return null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	owner_module = get_parent_module()
	if owner_module != null:
		owner_module.components.append(self)

func ready_preview() -> void:
	pass
	
func ready_blueprint() -> void:
	pass
	
func ready_constructed() -> void:
	pass

## The module has started coming apart. Override to stop participating in
## anything a standing module participates in - a teardown site is not a live
## part of the station. One-way: nothing takes a module back out of
## deconstruction, so there is no matching "resumed" hook.
func ready_deconstructing() -> void:
	pass

func has_ui() -> bool:
	return false

func get_ui() -> ModuleComponentUI:
	return null

## Override to hand a pawn that just delivered resources to (or otherwise
## interacted with) this component straight into followup work - see
## Action_QueueFollowup, which is what calls this. Return null if there's nothing
## to offer.
func offer_followup_job(_pawn: PawnBase) -> Job:
	return null

# --- persistence (WI-47 M2) -----------------------------------------------------
#
# A component owns its save block. ModuleBase used to name every component type by
# hand - fifteen get_component_by_type() lookups in get_save_data(), mirrored in
# load_save_data() - which meant a component the base class had never heard of was
# STRUCTURALLY incapable of persisting. A modded component wasn't awkward to save;
# it had no seam at all.
#
# Override get_save_data()/load_save_data() to persist. Leave save_key() and
# save_order() alone unless you have a reason - the defaults are chosen so a new
# component drops in without disturbing anything.

## Where ModuleBase's own local-upgrade block restores, on the same scale as
## save_order(). A component whose restore reads an upgrade-modified stat has to
## sort AFTER this - ShieldComponent is the one that does.
const UPGRADE_SAVE_ORDER: int = 200

## Restores after everything the base game does, so a mod component sees a module
## that is already whole. Deliberately not 0: at 0 a mod component would restore
## before construction and storage, which is the one place vanilla's ordering
## constraints could be broken from outside.
const DEFAULT_SAVE_ORDER: int = 1000

## Position in the restore chain - LOWER RUNS FIRST. The ordering is load-bearing
## and each vanilla override carries the reason it sits where it does.
##
## The same number orders the save walk, so a module's keys land in the file in
## restore order. Ties break on registration order, which is scene-tree order.
func save_order() -> int:
	return DEFAULT_SAVE_ORDER

## The key this component's block lands under in the module's save data. Every
## vanilla component pins this to the string it has always used, so pre-WI-47
## saves load untouched and no SAVE_VERSION bump is needed.
##
## MOD AUTHOR RULE: the default is the component's node path within the module.
## It is unique and stable across a save/load, but MOVING OR RENAMING the node in
## a later version of your mod orphans every block already written under the old
## path. Pin save_key() to a literal if you ever intend to rearrange the scene.
func save_key() -> StringName:
	if owner_module == null:
		return StringName(name)
	return StringName(String(owner_module.get_path_to(self)))

## True when one module can legitimately carry several of this component and each
## needs its own block; the blocks then nest under save_key(), keyed by node path.
## Only StorageComponent does this - a processor has an Input bin and an Output
## bin - and it is why the storage block has always been shaped differently.
func saves_per_instance() -> bool:
	return false

## This component's state, or {} for "nothing to save" - the default, and correct
## for everything whose state is derived or runtime-only (slot occupancy, cached
## adjacency, claims). Empty blocks are never written.
func get_save_data() -> Dictionary:
	return {}

## Restore what get_save_data() wrote. Only called when a block was written, and
## always after the module's ready pass, so normal setup has already run.
func load_save_data(_data: Dictionary) -> void:
	pass
