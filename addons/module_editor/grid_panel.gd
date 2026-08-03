@tool
extends Control

@export var grid_container: GridContainer
@export var base_button: Button

var last_size: Vector2i = Vector2i(0, 0)
var grid_size: Vector2i = Vector2i(5, 5)

var button_dictionary: Dictionary[Vector2i, Button] = {}

var editor: EditorProperty
var object: Object

func init_from_editor(editor_in: EditorProperty) -> void:
	editor = editor_in
	object = editor.get_edited_object()
	refresh()
	pass

## The footprint the grid is drawn against. The edited object is either the
## ModuleBase itself or one of its components (StructureComponent owns the point
## arrays), and only the module knows its own size - components no longer mirror it.
## Walks parents rather than reading `owner_module`, which ComponentBase only fills
## in from _ready() and so is null in the editor.
func module_size() -> Vector2i:
	var node: Node = object as Node
	while node != null:
		if node is ModuleBase:
			return (node as ModuleBase).size
		node = node.get_parent()
	return Vector2i.ONE

func refresh() -> void:
	var size: Vector2i = module_size()
	if size != last_size:
		last_size = size
		set_up(size, object.get(editor.get_edited_property()))
	else:
		var enabled: Array[Vector2i] = object.get(editor.get_edited_property())
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
