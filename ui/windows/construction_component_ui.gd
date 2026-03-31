class_name ConstructionComponentUI
extends ModuleComponentUI

@export var progress_container: HBoxContainer
@export var label: Label
@export var progress_bar: ProgressBar

@export var button_container: HBoxContainer
@export var deconstruct_button: Button
@export var demolish_button: Button

var construction_component: ConstructionComponent

func set_construction_component(component: ConstructionComponent) -> void:
	construction_component = component
	construction_component.state_changed.connect(construction_state_changed)
	construction_component.progress_changed.connect(_on_progress_changed)
	construction_state_changed(construction_component.current_state)

func construction_state_changed(new_state: ConstructionComponent.ConstructionState) -> void:
	match new_state:
		ConstructionComponent.ConstructionState.Paused:
			pass
		ConstructionComponent.ConstructionState.NotStarted:
			progress_container.visible = true
			progress_bar.value = construction_component.get_progress()
			label.text = "Constructing: "
			button_container.visible = false
		ConstructionComponent.ConstructionState.Constructing:
			progress_container.visible = true
			progress_bar.value = construction_component.get_progress()
			label.text = "Constructing: "
			button_container.visible = false
		ConstructionComponent.ConstructionState.Built:
			progress_container.visible = false
			button_container.visible = true
		ConstructionComponent.ConstructionState.Deconstructing:
			progress_container.visible = true
			label.text = "Deconstructing: "
			progress_bar.value = construction_component.get_progress()
			button_container.visible = false
		ConstructionComponent.ConstructionState.Deconstructed:
			progress_container.visible = false
			button_container.visible = false
			
func _on_progress_changed(new_progress: float) -> void:
	progress_bar.value = new_progress

func _on_deconstruct_button_pressed() -> void:
	construction_component.start_deconstruction()

func _on_demolish_button_pressed() -> void:
	Global.world_manager.remove_module(construction_component.owner_module)
	
