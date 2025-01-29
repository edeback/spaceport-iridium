extends Control

@export var module_button: PackedScene

@onready var button_container: VBoxContainer = $Modules/MarginContainer/ButtonContainer

var module_datas: Array[ModuleData]
var preview_model : ModuleBase

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	load_moduledatas()
	create_module_buttons()

func load_moduledatas() -> void:
	var current_buttons = button_container.get_children()
	for node in current_buttons:
		button_container.remove_child(node)
	module_datas.clear()
	for file_name in DirAccess.get_files_at("res://data/modules/"):
		if file_name.get_extension() == "tres":
			module_datas.append(ResourceLoader.load("res://data/modules/" + file_name, "ModuleData"))

func create_module_buttons() -> void:
	for module_data in module_datas:
		var new_button = module_button.instantiate() as ModuleButton
		new_button.set_moduledata(module_data)
		button_container.add_child(new_button)
		
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
