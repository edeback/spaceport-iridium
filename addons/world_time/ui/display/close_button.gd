extends Button

@export var target : Control

func _ready() -> void:
	pressed.connect(_on_press)
	
func _on_press():
	target.hide()
