class_name AsteroidBase
extends ObjectBase

## A mineable body drifting in space. Despite the name, this covers **every**
## kind: the belt's asteroids and WI-61's comets are both instances of this
## class, differing only by scene, by the [SpaceBodyProfile] that spawned them,
## and by the fields below.
##
## The name stays "asteroid" deliberately. Renaming to something neutral would
## churn Groups.ASTEROID, JobTarget.Kind.ASTEROID, SaveManager.asteroid_ref, the
## &"mine_asteroid" job id and the "asteroids" save section - three of which are
## save-format identifiers - for a rename the player can never see. The
## player-facing noun lives in [member body_name] instead; the code-facing one is
## wrong but stable. Don't start the rename.

@export var sprite: Sprite2D
@export var resource_weighted_values: Dictionary[ResourceData, float] = {}
@export var max_resources: int = 10
## The word the inspector uses for this body ("Asteroid", "Comet"). Set from the
## profile at spawn; the scene's value is the fallback for a bare instance.
@export var body_name: String = "Asteroid"
@export var rotation_speed_deg_per_sec: float = 30.0
## Point the sprite along [member direction] instead of spinning it. Comets do;
## asteroids tumble.
@export var faces_travel_direction: bool = false
## Where this sprite's art already points, in degrees. blue_comet.png has its
## head at the bottom-left and its tail to the upper-right, i.e. 135. In data
## rather than code because it is a property of the art: a mod's body sprite
## points somewhere else.
@export var sprite_forward_offset_deg: float = 0.0

var cur_resources: int
var resource_total_weights: float = 0

## Stable save id (WI-21), assigned by AsteroidManager at spawn. -1 = never
## registered (a bare instance not owned by the manager). Jobs that target this
## rock persist it as SaveManager.asteroid_ref({"id": asteroid_id}).
var asteroid_id: int = -1

## Which [SpaceBodyProfile] spawned this (WI-61). Saved, and the only thing a
## load needs in order to rebuild the right scene - without it every restored
## comet comes back as a rock.
var profile_id: StringName = &"asteroid"

var speed_pixels_per_sec: float = 15
var direction: Vector2 = Vector2.ZERO:
	set(new_direction):
		direction = new_direction
		_apply_orientation()

## Where the despawn distance is measured from. Per-body since WI-61: the belt
## measures from its start marker (which is what it has always done), a crossing
## body from its own entry point. A single manager-wide rule would free every
## comet on its first frame, silently, because a comet spawning on the far side
## of the station is already outside the belt's radius.
var despawn_anchor: Vector2 = Vector2.ZERO
var despawn_distance: float = 2000.0

## Keep this body out of the minimap's fitted box and draw it clamped to the map
## edge instead (WI-61). Set from the profile's trajectory at spawn. A body that
## spawns thousands of pixels out would otherwise drag the fit with it and zoom
## the whole station down to a smudge for its entire crossing.
var map_edge_contact: bool = false

## Per-asteroid richness band, assigned at spawn (richer asteroids are rarer -
## see AsteroidManager.spawn_asteroid). Every stack mined off this asteroid
## samples its richness inside this range.
var richness_range: Vector2 = Vector2(0.3, 0.7)

## Player-flagged for priority mining: the mining job targets designated
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
	add_to_group(Groups.ASTEROID)
	cur_resources = max_resources
	for weight: float in resource_weighted_values.values():
		resource_total_weights += weight
	# Covers a direction assigned before the sprite resolved, and a scene whose
	# direction was never set at all.
	_apply_orientation()
	$ClickArea.input_event.connect(_on_click_area_input_event)

func _on_click_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event.is_action_pressed("build"):
		get_viewport().set_input_as_handled()
		asteroid_clicked.emit(self)
		Global.ui_main.asteroid_clicked(self)

func _update_designation_visual() -> void:
	sprite.modulate = DESIGNATED_TINT if designated else Color.WHITE

## Points the art along the heading, for a body that doesn't tumble. Applied on
## every direction change rather than per frame: a crossing body's heading is
## fixed at spawn, so re-deriving it every frame would be work for nothing.
func _apply_orientation() -> void:
	if not faces_travel_direction or sprite == null or direction == Vector2.ZERO:
		return
	sprite.rotation = direction.angle() - deg_to_rad(sprite_forward_offset_deg)

func _exit_tree() -> void:
	despawning.emit()
	Global.path_manager.remove_vertex(self)

func _process(delta: float) -> void:
	var sim_delta: float = Global.time_manager.scale(delta)
	if sim_delta <= 0.0:
		return
	position += speed_pixels_per_sec * sim_delta * direction
	if rotation_speed_deg_per_sec != 0.0:
		sprite.rotation_degrees += sim_delta * rotation_speed_deg_per_sec

## True once this body has travelled its whole route and should leave. Kept here
## rather than in the manager's sweep so the rule and the two fields it reads
## live together, and so it can be tested on a bare instance.
func should_despawn() -> bool:
	return position.distance_squared_to(despawn_anchor) > despawn_distance * despawn_distance

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

## Whether richness means anything for this body (WI-61). Action_Mine only
## attaches an OreInstanceData when the mined resource has_variance, so a comet
## carrying only ice and carbon has a richness band that describes nothing - and
## the inspector must not print a quality readout for it. Since carbon became a
## directly mined resource with no variance of its own, a *belt* asteroid can
## roll an all-carbon (or carbon + ice) mix too, so this is no longer a
## comet-only case - which is exactly why it is asked per body rather than
## per body kind.
func has_variable_yield() -> bool:
	for resource: ResourceData in resource_weighted_values:
		if resource != null and resource.has_variance:
			return true
	return false

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
		"profile": String(profile_id),
		"position": [position.x, position.y],
		"direction": [direction.x, direction.y],
		"speed": speed_pixels_per_sec,
		"rotation": sprite.rotation_degrees if sprite != null else 0.0,
		"max_resources": max_resources,
		"cur_resources": cur_resources,
		"richness_range": [richness_range.x, richness_range.y],
		"ore_mix": ore_mix,
		"designated": designated,
		"despawn_anchor": [despawn_anchor.x, despawn_anchor.y],
		"despawn_distance": despawn_distance,
	}
