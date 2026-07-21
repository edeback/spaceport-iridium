class_name UISustenanceComponent
extends ModuleComponentUI

@export var meals_available_label: Label
@export var meals_max_label: Label
## Optional (WI-29): shows the sustenance pool's average food quality. Guarded so
## an older scene without the label still works.
@export var quality_label: Label

var sustenance_component: SustenanceComponent

func set_sustenance_component(component: SustenanceComponent) -> void:
	name = component.name
	sustenance_component = component
	sustenance_component.sustenance_stored_changed.connect(_on_sustenance_changed)
	_on_sustenance_changed(sustenance_component.sustenance_available)
	meals_max_label.text = str(sustenance_component.sustenance_max / 100)

func _on_sustenance_changed(new_sustenance: int) -> void:
	meals_available_label.text = "%.2f" % (new_sustenance / 100.0)
	if quality_label != null:
		# Pool quality is undefined with an empty pool; show a neutral dash.
		quality_label.text = "%d%%" % roundi(sustenance_component.pool_quality * 100.0) if new_sustenance > 0 else "-"
	
