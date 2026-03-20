class_name SustenanceComponent
extends ComponentBase

var sustenance_available: float = 100

func _ready() -> void:
	super()

func ready_preview() -> void:
	pass
	
func ready_blueprint() -> void:
	pass
	
func ready_constructed() -> void:
	add_to_group("sustenance_component")

func consume_sustenance(amount: float) -> bool:
	if amount <= sustenance_available:
		sustenance_available -= amount
		return true
	return false
