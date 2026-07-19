class_name AsteroidBase
extends ObjectBase

@export var sprite: Sprite2D
@export var resource_weighted_values: Dictionary[ResourceData, float] = {}
@export var max_resources: int = 10
var cur_resources: int
var resource_total_weights: float = 0

## Stable save id (WI-21), assigned by AsteroidManager at spawn. -1 = never
## registered (a bare instance not owned by the manager). Jobs that target this
## rock persist it as SaveManager.asteroid_ref({"id": asteroid_id}).
var asteroid_id: int = -1

var speed_pixels_per_sec: float = 15
var direction: Vector2
var rotation_speed_deg_per_sec: float = 30

## Per-asteroid richness band, assigned at spawn (richer asteroids are rarer -
## see AsteroidManager.spawn_asteroid). Every stack mined off this asteroid
## samples its richness inside this range.
var richness_range: Vector2 = Vector2(0.3, 0.7)

## Player-flagged for priority mining: Job_MineAsteroid targets designated
## asteroids before ore-priority or random picks. Persisted with the asteroid
## (WI-21) so a designation survives save/load like the rest of the field.
var designated: bool = false:
	set(new_designated):
		if designated != new_designated:
			designated = new_designated
			_update_designation_visual()

const DESIGNATED_TINT := Color(1.3, 1.15, 0.7)

signal despawning
signal asteroid_clicked(asteroid: AsteroidBase)
signal contents_changed

func _ready() -> void:
	add_to_group("asteroid")
	cur_resources = max_resources
	for weight: float in resource_weighted_values.values():
		resource_total_weights += weight
	$ClickArea.input_event.connect(_on_click_area_input_event)

func _on_click_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event.is_action_pressed("build"):
		get_viewport().set_input_as_handled()
		asteroid_clicked.emit(self)
		Global.ui_main.asteroid_clicked(self)

func _update_designation_visual() -> void:
	sprite.modulate = DESIGNATED_TINT if designated else Color.WHITE

func _exit_tree() -> void:
	despawning.emit()
	Global.path_manager.remove_vertex(self)

func _process(delta: float) -> void:
	var sim_delta: float = Global.time_manager.scale(delta)
	if sim_delta <= 0.0:
		return
	position += speed_pixels_per_sec * sim_delta * direction
	sprite.rotation_degrees += sim_delta * rotation_speed_deg_per_sec

func mine_resource() -> ResourceData:
	if resource_total_weights == 0 or cur_resources <= 0:
		return null
	var weight_to_hit: float = randf() * resource_total_weights
	var cur_weight: float = 0
	for resource: ResourceData in resource_weighted_values:
		cur_weight += resource_weighted_values[resource]
		if weight_to_hit <= cur_weight:
			cur_resources -= 1
			contents_changed.emit()
			return resource
	return null

## Richness for one freshly mined stack.
func sample_richness() -> float:
	return randf_range(richness_range.x, richness_range.y)

func average_richness() -> float:
	return (richness_range.x + richness_range.y) / 2.0

## Surface-level quality readout for UI, e.g. "Rich (72%)".
func get_richness_descriptor() -> String:
	var avg: float = average_richness()
	var band: String
	if avg < 0.35:
		band = "Poor"
	elif avg < 0.55:
		band = "Average"
	elif avg < 0.75:
		band = "Rich"
	else:
		band = "Bonanza"
	return "%s (%d%%)" % [band, roundi(avg * 100.0)]

func has_ore(resource: ResourceData) -> bool:
	return cur_resources > 0 and resource_weighted_values.get(resource, 0.0) > 0.0

func is_empty() -> bool:
	return cur_resources <= 0

# --- persistence (WI-21) ------------------------------------------------------

## Full serializable state. AsteroidManager aggregates these into the world
## save so mining jobs still have their rock on load and the asteroid field
## (contents, richness, positions) round-trips identically. resource_total_weights
## is derived in _ready() from the ore mix, so it isn't stored.
func get_save_data() -> Dictionary:
	var ore_mix: Dictionary = {}
	for resource: ResourceData in resource_weighted_values:
		if resource == null or resource.id == &"":
			continue
		ore_mix[String(resource.id)] = resource_weighted_values[resource]
	return {
		"id": asteroid_id,
		"position": [position.x, position.y],
		"direction": [direction.x, direction.y],
		"speed": speed_pixels_per_sec,
		"rotation": sprite.rotation_degrees if sprite != null else 0.0,
		"max_resources": max_resources,
		"cur_resources": cur_resources,
		"richness_range": [richness_range.x, richness_range.y],
		"ore_mix": ore_mix,
		"designated": designated,
	}
