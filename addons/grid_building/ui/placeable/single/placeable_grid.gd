class_name PlaceableGrid
extends GridContainer

signal placeable_selected(placeable : Placeable)

@export var placeable_view_template : PackedScene

var views : Array[PlaceableView]

## Creates views for each placeable
func setup(p_placeables : Array[Placeable]):
	clear()
	
	for placeable in p_placeables:
		var view : PlaceableView = placeable_view_template.instantiate()
		view.placeable = placeable
		view.placeable_selected.connect(_on_view_placeable_selected)
		add_child(view)
		views.append(view)

func clear():
	for view in views:
		if view != null:
			view.queue_free()
		
	views.clear()

func _on_view_placeable_selected(p_placeable : Placeable):
	placeable_selected.emit(p_placeable)
