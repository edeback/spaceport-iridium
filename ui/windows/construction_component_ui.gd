class_name ConstructionComponentUI
extends ModuleComponentUI

## Build / teardown progress for a module that is not finished yet.
##
## WI-51 took the DECONSTRUCT and DEMOLISH buttons out of here and put them in
## the inspector's footer, where the design wants a module's destructive actions:
## outline-only, in one place, on every module rather than only on the ones whose
## construction component happens to have a UI. What is left is the progress
## readout, which is the only thing this tab was ever for while a module was
## actually building - and [ConstructionComponent.has_ui] now retires the tab
## once the module is Built, so the strip never carries an empty page.

@export var progress_container: Control
@export var label: Label
@export var progress_bar: ProgressBar

var construction_component: ConstructionComponent

func set_construction_component(component: ConstructionComponent) -> void:
	construction_component = component
	construction_component.state_changed.connect(construction_state_changed)
	construction_component.progress_changed.connect(_on_progress_changed)
	construction_state_changed(construction_component.current_state)

func construction_state_changed(new_state: ConstructionComponent.ConstructionState) -> void:
	match new_state:
		ConstructionComponent.ConstructionState.NotStarted, \
		ConstructionComponent.ConstructionState.Paused, \
		ConstructionComponent.ConstructionState.Constructing:
			progress_container.visible = true
			progress_bar.value = construction_component.get_progress()
			label.text = "CONSTRUCTING"
		ConstructionComponent.ConstructionState.Deconstructing:
			progress_container.visible = true
			progress_bar.value = construction_component.get_progress()
			label.text = "DECONSTRUCTING"
		_:
			# Built, and the export-bin drain after Deconstructed: nothing is
			# progressing, so the readout says nothing rather than showing a bar
			# stuck at either end.
			progress_container.visible = false

func _on_progress_changed(new_progress: float) -> void:
	progress_bar.value = new_progress
