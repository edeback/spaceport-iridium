extends BaseDialogueTestScene


func _ready() -> void:
	var balloon = load("res://ui/dialogue/balloon.tscn").instantiate()
	get_tree().current_scene.add_child(balloon)
	balloon.start(resource, key if not key.is_empty() else resource.first_cue)
