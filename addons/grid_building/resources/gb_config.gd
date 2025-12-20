## Configuration resource containing all grid building plugin settings.
class_name GBConfig
extends GBResource

## All settings resources for grid building operations.
@export var settings: GBSettings

## Packed scene templates for system instantiation.
@export var templates: GBTemplates

## Input action definitions for systems and UI.
@export var actions: GBActions

func _init():
	_lazy_init_subresources()

## Lazy inits sub resources that have not been defined in the Godot inspector.
func _lazy_init_subresources():
	if settings == null:
		settings = GBSettings.new()
	if templates == null:
		templates = GBTemplates.new()
	if actions == null:
		actions = GBActions.new()

func get_editor_issues() -> Array[String]:
	var issues: Array[String] = []
	if settings == null:
		issues.append("GBConfig.settings is null")
	else:
		issues.append_array(settings.get_editor_issues())
	if templates == null:
		issues.append("GBConfig.templates is null")
	else:
		issues.append_array(templates.get_editor_issues())
	if actions == null:
		issues.append("GBConfig.actions is null")
	else:
		issues.append_array(actions.get_editor_issues())

	return issues

func get_runtime_issues() -> Array[String]:
	return get_editor_issues()
