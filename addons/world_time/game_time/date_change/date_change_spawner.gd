class_name DateChangeSpawner
extends DateChangeRandomizer
## Creates an instance of one of the options as a child of this node
## on date change

@export var options_weights : Dictionary[PackedScene, float]

func act(p_new : GameDate):
	var selection = get_random_selection(options_weights)
	spawn(selection)
	
func spawn(p_scene : PackedScene):
	var instance = p_scene.instantiate()
	add_child(instance)
