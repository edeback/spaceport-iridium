class_name ProcessorComponentUI
extends ModuleComponentUI

@export var processor_recipe_label: Label
@export var continuous_label: Label
@export var processor_progress_bar: ProgressBar

const PROCESSOR_RECIPE_FORMAT: String = "%s: %s processed into %s in %.1f seconds"

func _get_resources_string(resources_used: Dictionary[ResourceData, int]) -> String:
	var resources_string: String = ""
	for resource: ResourceData in resources_used:
		if resources_string != "":
			resources_string += ", "
		resources_string += "%d %s" % [resources_used[resource], resource.name]
	return resources_string

func set_processor_component(component: ProcessorComponent) -> void:
	var input_string: String = _get_resources_string(component.recipe.inputs)
	var output_string: String = _get_resources_string(component.recipe.outputs)
	var recipe_string: String = PROCESSOR_RECIPE_FORMAT % [component.recipe.name, input_string, output_string, component.get_process_time()]
	processor_recipe_label.text = recipe_string
	continuous_label.visible = false
	processor_progress_bar.indeterminate = false
	processor_progress_bar.value = component.current_process_time / component.get_process_time()
	component.processor_progress_changed.connect(on_process_progress_changed)

func on_process_progress_changed(new_progress: float) -> void:
	processor_progress_bar.value = new_progress

func on_powered_changed(new_powered: bool) -> void:
	pass
