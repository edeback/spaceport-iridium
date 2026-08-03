class_name ProcessorComponentUI
extends ModuleComponentUI

@export var processor_recipe_label: Label
@export var continuous_label: Label
@export var processor_progress_bar: ProgressBar
@export var recipe_selector: OptionButton
@export var batch_richness_label: Label

const PROCESSOR_RECIPE_FORMAT: String = "%s: %s processed into %s in %.1f seconds"

var processor_component: ProcessorComponent

func _get_resources_string(resources_used: Dictionary[ResourceData, int]) -> String:
	var resources_string: String = ""
	for resource: ResourceData in resources_used:
		if resources_string != "":
			resources_string += ", "
		resources_string += "%d %s" % [resources_used[resource], resource.name]
	return resources_string

func set_processor_component(component: ProcessorComponent) -> void:
	processor_component = component
	continuous_label.visible = false
	processor_progress_bar.indeterminate = false
	processor_progress_bar.value = component.current_process_time / component.get_process_time()
	component.processor_progress_changed.connect(on_process_progress_changed)
	component.batch_richness_changed.connect(_on_batch_richness_changed)
	component.recipe_changed.connect(_on_recipe_changed)
	_refresh_recipe_text()
	_on_batch_richness_changed(component.current_batch_richness)
	if component.can_select_recipes():
		for recipe: RecipeData in component.get_available_recipes():
			recipe_selector.add_item(recipe.name)
		recipe_selector.select(component.get_available_recipes().find(component.recipe))
		recipe_selector.item_selected.connect(_on_recipe_selected)
	else:
		recipe_selector.visible = false

func _refresh_recipe_text() -> void:
	var recipe: RecipeData = processor_component.recipe
	var input_string: String = _get_resources_string(recipe.inputs)
	var output_string: String = _get_resources_string(recipe.outputs)
	var recipe_string: String = PROCESSOR_RECIPE_FORMAT % [recipe.name, input_string, output_string, processor_component.get_process_time()]
	if processor_component.pending_recipe != null:
		recipe_string += "\nSwitching to %s after this batch" % processor_component.pending_recipe.name
	processor_recipe_label.text = recipe_string

func _on_recipe_selected(index: int) -> void:
	processor_component.select_recipe(processor_component.get_available_recipes()[index])
	# Mid-batch the switch is queued, not applied - reflect that immediately;
	# recipe_changed fires later when it actually lands.
	_refresh_recipe_text()

func _on_recipe_changed(new_recipe: RecipeData) -> void:
	_refresh_recipe_text()
	var index: int = processor_component.get_available_recipes().find(new_recipe)
	if index >= 0 and recipe_selector.selected != index:
		recipe_selector.select(index)

func _on_batch_richness_changed(new_richness: float) -> void:
	if new_richness < 0.0:
		batch_richness_label.visible = false
	else:
		batch_richness_label.visible = true
		batch_richness_label.text = "Batch richness: %d%%" % roundi(new_richness * 100.0)

func on_process_progress_changed(new_progress: float) -> void:
	processor_progress_bar.value = new_progress

func on_powered_changed(new_powered: bool) -> void:
	pass
