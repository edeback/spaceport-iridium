extends PanelContainer

@export var credits_available_label: Label

func _ready() -> void:
	credits_available_label.text = str(Global.resource_manager.credits)
	Global.resource_manager.credits_changed.connect(_on_credits_changed)

func _on_credits_changed(new_credits: int) -> void:
	credits_available_label.text = str(new_credits)

func _on_credits_button_clicked() -> void:
	Global.resource_manager.credits += 1000
