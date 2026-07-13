class_name SustenanceComponent
extends ComponentBase

@export var storage_bay: StorageComponent
@export var sustenance_max: int = 500
@export var sustenance_available: int = 0
@export var sustenance_per_food: int = 100
@export var sustenance_resource: ResourceData

var override_ui: bool = false

signal sustenance_stored_changed(new_amount: int)

func _ready() -> void:
	super()

func ready_preview() -> void:
	override_ui = false
	set_process(false)

func ready_blueprint() -> void:
	override_ui = false
	set_process(false)

func ready_constructed() -> void:
	override_ui = true
	add_to_group("sustenance_component")
	set_process(true)

func _process(delta: float) -> void:
	if Global.time_manager.scale(delta) <= 0.0:
		return
	if sustenance_available <= sustenance_max - sustenance_per_food:
		if storage_bay.withdraw(sustenance_resource, 1):
			sustenance_available += sustenance_per_food
			sustenance_stored_changed.emit(sustenance_available)
	

## Returns amount actually consumed
func consume_sustenance(amount: int) -> int:
	var amount_to_consume := maxi(mini(amount, sustenance_available), 0)
	sustenance_available -= amount_to_consume
	sustenance_stored_changed.emit(sustenance_available)
	return amount_to_consume

func has_ui() -> bool:
	return override_ui

func get_ui() -> ModuleComponentUI:
	var ui: UISustenanceComponent = ui_info_panel_element.instantiate() as UISustenanceComponent
	ui.set_sustenance_component(self)
	return ui
