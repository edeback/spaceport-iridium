class_name ModuleButtonTooltip
extends MarginContainer

@export var cost_ui_scene: PackedScene

func set_module_data(module_data: ModuleData) -> void:
	%ModuleName.text = module_data.name
	%ModuleIcon.texture = module_data.icon
	%ModuleDescription.text = module_data.description
	for child in %CostContainer.get_children():
		%CostContainer.remove_child(child)
	for resource: ResourceData in module_data.resource_costs:
		var cost_ui: ModuleResourceCostUI = cost_ui_scene.instantiate() as ModuleResourceCostUI
		cost_ui.set_resource(resource, module_data.resource_costs[resource])
		%CostContainer.add_child(cost_ui)
		
	
	
