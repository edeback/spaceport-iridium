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
## JobBase.get_followup_job(). Return null if there's nothing to offer.
func offer_followup_job(_pawn: PawnBase) -> JobBase:
	return null
