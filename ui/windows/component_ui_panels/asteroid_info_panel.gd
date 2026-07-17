class_name AsteroidInfoPanel
extends PanelContainer

@export var richness_label: Label
@export var remaining_label: Label
@export var contents_container: VBoxContainer
@export var designate_button: CheckButton

var asteroid: AsteroidBase = null

func set_asteroid(new_asteroid: AsteroidBase) -> void:
	if asteroid != null:
		asteroid.contents_changed.disconnect(_refresh)
		asteroid.despawning.disconnect(_on_exit_button_pressed)
	asteroid = new_asteroid
	asteroid.contents_changed.connect(_refresh)
	asteroid.despawning.connect(_on_exit_button_pressed)
	designate_button.button_pressed = asteroid.designated
	designate_button.toggled.connect(_on_designate_toggled)
	_refresh()
	set_position(asteroid.get_global_transform_with_canvas().get_origin())

func _refresh() -> void:
	richness_label.text = "Richness: %s" % asteroid.get_richness_descriptor()
	remaining_label.text = "Remaining chunks: %d / %d" % [asteroid.cur_resources, asteroid.max_resources]
	for child: Node in contents_container.get_children():
		child.queue_free()
	# Ore weights are relative shares of what mining yields, not exact counts -
	# present them as approximate percentages.
	var total: float = asteroid.resource_total_weights
	if total <= 0.0:
		return
	for resource: ResourceData in asteroid.resource_weighted_values:
		var line := Label.new()
		line.text = "%s: ~%d%%" % [resource.name, roundi(asteroid.resource_weighted_values[resource] / total * 100.0)]
		contents_container.add_child(line)

func _on_designate_toggled(pressed: bool) -> void:
	if asteroid != null:
		asteroid.designated = pressed

func _process(_delta: float) -> void:
	# Asteroids drift constantly - follow one on screen, and close ourselves
	# once it's been freed (mined out or drifted past the despawn radius).
	if is_instance_valid(asteroid):
		set_position(asteroid.get_global_transform_with_canvas().get_origin())
	else:
		asteroid = null
		_on_exit_button_pressed()

func _on_exit_button_pressed() -> void:
	queue_free()
