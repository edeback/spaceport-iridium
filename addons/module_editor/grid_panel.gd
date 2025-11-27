@tool
extends Control

@export var grid_container: GridContainer
@export var base_button: Button

var last_size: Vector2i = Vector2i(0, 0)
var grid_size: Vector2i = Vector2i(5, 5)

var button_dictionary: Dictionary[Vector2i, Button] = {}

var editor: EditorProperty
var module: ModuleBase

func init_from_editor(editor_in: EditorProperty) -> void:
	editor = editor_in
	module = editor.get_edited_object() as ModuleBase
	refresh()
	pass

func refresh() -> void:
	if module.size != last_size:
		last_size = module.size
		set_up(module.size, module.get(editor.get_edited_property()))
	else:
		var enabled: Array[Vector2i] = module.get(editor.get_edited_property())
		for pos in button_dictionary:
			button_dictionary[pos].set_pressed_no_signal(enabled.has(pos))

func set_up(size_in: Vector2i, enabled: Array[Vector2i]) -> void:
	for current_button in grid_container.get_children():
		current_button.queue_free()
	button_dictionary.clear()
	grid_size = Vector2i(maxi(size_in.x, 1), maxi(size_in.y, 1))
	grid_container.columns = grid_size.x + 2
	for y in range(grid_size.y + 2):
		for x in range(grid_size.x + 2):
			var new_button = base_button.duplicate()
			new_button.visible = true
			var pos: Vector2i = Vector2i(x - 1, y - 1)
			if enabled.has(pos):
				new_button.set_pressed_no_signal(true)
			new_button.text = "%d, %d" % [pos.x, pos.y]
			new_button.pressed.connect(_pressed_changed)
			button_dictionary[pos] = new_button
			grid_container.add_child(new_button)
	
			
func _pressed_changed() -> void:
	editor.emit_changed(editor.get_edited_property(), get_pressed())
	pass

func get_pressed() -> Array[Vector2i]:
	var pressed: Array[Vector2i] = []
	for position: Vector2i in button_dictionary:
		if button_dictionary[position].button_pressed:
			pressed.append(position)
	return pressed
