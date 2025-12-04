class_name ModuleButtonTooltip
extends MarginContainer

func set_module_data(module_data: ModuleData) -> void:
	%ModuleName.text = module_data.name
	%ModulePrice.text = "%d credits" % module_data.cost
	%ModuleIcon.texture = module_data.icon
	%ModuleDescription.text = module_data.description
	
