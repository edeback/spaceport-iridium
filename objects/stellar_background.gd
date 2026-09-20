class_name StellarBackground
extends Node

## Mounts the star and planet a run is played under, and drives Deep-Fold's
## Pixel Planet shaders from outside them (WI-66).
##
## `assets/external/pixel_planets/` is vendored third-party code and stays
## byte-for-byte unmodified, so every piece of knowledge about those scenes -
## which node carries which shader, which uniforms are safe to write - lives
## here and in [PlanetVariant], never in them. That also means this project
## never inherits their warning surface: they are untyped GDScript against a
## project that runs `untyped_declaration` and both `unsafe_*` warnings on.
##
## The vendored setters this file DOES call - `set_pixels`, `set_light`,
## `set_rotates` - are reached through the [StellarObjectVisual] base class, so
## they type-check. `set_pixels` in particular must go through the vendored path:
## it writes the `pixels` uniform AND resizes the ColorRect, and on the star it
## re-centres the flare and blob layers by `relative_scale`. Writing the uniform
## alone leaves the rects stale and the corona off-centre.
##
## What it deliberately never calls: `set_seed` (it secretly rolls `cloud_cover`
## off the global RNG), `randomize_colors` (arbitrary hues, and broken on the
## star), and `set_colors` (the star's slicing is wrong). Colours and seeds are
## written straight onto the materials instead.
##
## NOT a manager: no tick, no save section, and one signal it only listens to
## (the sim's pause state, which freezes the sky). It registers on Global
## purely so the cheats have a handle on it, which is the same reason
## `ui_in_game`, `ui_main`, `tilemap` and `cheats` are there.

const STAR_SCENE: PackedScene = preload("res://assets/external/pixel_planets/Star/Star.tscn")

## The star's three layers, by node name inside `Star.tscn`. Here rather than in
## data because - unlike planets - there is exactly one star scene, and a
## [StarClass] varies its palette and knobs, never its structure.
const STAR_BLOB_LAYER: StringName = &"Blobs"
const STAR_DISC_LAYER: StringName = &"Star"
const STAR_FLARE_LAYER: StringName = &"StarFlares"

## How far the planet's terminator sits from centre, as a fraction of the UV
## square. The vendored scenes author `light_origin` around (0.39, 0.39), which
## is this distance along the up-left diagonal.
const LIGHT_OFFSET: float = 0.35

## What a layer paints when its ramp is missing entirely - a save hand-edited, or
## written by a mod that has since changed its roles. Deliberately loud: a
## background that quietly renders grey is a bug nobody reports.
const MISSING_RAMP_COLOR: Color = Color.MAGENTA

## Where the two bodies are mounted. Typed [Node2D] rather than [Parallax2D] -
## which is what main.tscn actually wires in - so the contact-sheet cheat can
## mount preview systems into plain holders. A sheet that could not use this
## exact applier would be verifying something other than the game.
@export var star_layer: Node2D
@export var planet_layer: Node2D

## True for a preview instance built in code: it neither registers on Global nor
## applies anything in `_ready`, and its creator calls [method apply] with the
## system it wants. Without this, every contact-sheet cell would claim to be the
## game's sky on the way past.
@export var is_preview: bool = false

var _star: StellarObjectVisual
var _planet: StellarObjectVisual

func _ready() -> void:
	if is_preview:
		return
	Global.stellar_background = self
	# The sky stops when the sim does. WI-66 originally left it running in real
	# time as "UI-side decoration", and playtesters read the churning star and
	# spinning planet as the game still running: the one moving thing on a paused
	# screen is what tells you whether it is paused. See [method _sync_motion].
	Global.time_manager.pause_state_changed.connect(_on_pause_state_changed)
	apply(Global.get_star_system())

## Hands the slot back (WI-71 §7). Godot 4.7 reports a freed object as `== null`,
## so the guards around the game already take their null branch after a Quit to
## Menu - but `is_instance_valid(Global.stellar_background)` and the debugger both lie until
## the slot is actually cleared. `== self` because a second scene can register
## before this one leaves.
func _exit_tree() -> void:
	if Global.stellar_background == self:
		Global.stellar_background = null

## Rebuilds both bodies from `system`. Idempotent - the cheats re-apply live.
func apply(system: StarSystemData) -> void:
	_clear()
	if system == null:
		return
	_star = _mount_star(system)
	_planet = _mount_planet(system)
	_apply_light(system)
	# Freshly mounted bodies process by default; a load or a cheat re-apply
	# while paused must come up frozen, not start moving.
	_sync_motion()

func _on_pause_state_changed(_paused: bool) -> void:
	_sync_motion()

## Runs the bodies while the sim runs and freezes them while it is stopped - on
## the COMBINED answer, [method TimeManager.is_paused], so a dialogue or
## tutorial hold freezes the sky too. That matches the console's pause button,
## which also shows the combined state; a sky that disagreed with it is the
## confusion this exists to remove.
##
## The vendored [StellarObjectVisual._process] is the bodies' only clock (no
## shader reads the builtin TIME), so switching it off stops them dead without
## editing vendored code. Pause only, not speed: at 5x the sky keeps its
## real-time rate, because a star churning five times faster reads as a glitch.
##
## Previews never freeze - the contact sheet is an inspection tool.
func _sync_motion() -> void:
	var running: bool = is_preview or Global.time_manager == null \
			or not Global.time_manager.is_paused()
	for body: StellarObjectVisual in [_star, _planet]:
		if body == null:
			continue
		if not running:
			# Push the current clock into the shader before stopping. A body
			# mounted while already paused has never run _process, so its
			# `time` uniform is still the .tscn's authored value - and would
			# visibly jump to the accumulated clock on the first unpaused frame.
			body.update_time(body.time)
		body.set_process(running)

func _clear() -> void:
	for body: Node in [_star, _planet]:
		if body != null and is_instance_valid(body):
			# Removed before freeing, not just queued: a re-apply in the same
			# frame would otherwise mount the new body beside the old one, which
			# a queue_free() alone does not prevent.
			body.get_parent().remove_child(body)
			body.queue_free()
	_star = null
	_planet = null

# --- star ---------------------------------------------------------------------

func _mount_star(system: StarSystemData) -> StellarObjectVisual:
	if star_layer == null:
		return null
	var star: StellarObjectVisual = STAR_SCENE.instantiate() as StellarObjectVisual
	if star == null:
		return null
	star.position = system.star_offset
	star.scale = Vector2(system.star_scale, system.star_scale)
	star_layer.add_child(star)

	var blobs: ShaderMaterial = _own_material(star, STAR_BLOB_LAYER)
	var disc: ShaderMaterial = _own_material(star, STAR_DISC_LAYER)
	var flares: ShaderMaterial = _own_material(star, STAR_FLARE_LAYER)

	# The remaining two layers derive from the ramp rather than being authored
	# twice, exactly as the shipped Star.tscn does: the blobs take the core
	# colour, the flares take [mid, core].
	var ramp: PackedColorArray = system.star_ramp
	var core: Color = ramp[0] if ramp.size() > 0 else Color.WHITE
	var mid: Color = ramp[1] if ramp.size() > 1 else core
	_write(blobs, &"colors", PackedColorArray([core]))
	if ramp.size() == StarClass.RAMP_LENGTH:
		_write(disc, &"colors", ramp)
	_write(flares, &"colors", PackedColorArray([mid, core]))

	for material: ShaderMaterial in [blobs, disc, flares]:
		_write(material, &"seed", system.star_seed)
		_write(material, &"time_speed", system.star_time_speed)
	_write(disc, &"size", system.star_noise_size)
	_write(blobs, &"size", system.star_blob_size)
	_write(blobs, &"circle_amount", system.star_circle_amount)
	_write(blobs, &"circle_size", system.star_circle_size)
	_write(flares, &"circle_amount", system.star_circle_amount)
	_write(flares, &"storm_width", system.star_storm_width)

	star.set_pixels(system.star_pixels)
	return star

# --- planet -------------------------------------------------------------------

func _mount_planet(system: StarSystemData) -> StellarObjectVisual:
	if planet_layer == null or not system.has_planet():
		return null
	var variant: PlanetVariant = PlanetVariant.by_id(system.planet_variant_id)
	if variant == null or variant.scene == null:
		return null
	var planet: StellarObjectVisual = variant.scene.instantiate() as StellarObjectVisual
	if planet == null:
		return null
	planet.position = system.planet_offset
	planet.scale = Vector2(system.planet_scale, system.planet_scale)
	planet_layer.add_child(planet)

	for layer: PlanetLayerSpec in variant.layers:
		if layer == null:
			continue
		var material: ShaderMaterial = _own_material(planet, layer.node_name)
		if material == null:
			continue
		_write(material, &"colors", _layer_colors(system, layer))
		_write(material, &"seed", system.planet_seed)
		# Read-then-write, and the read is only correct because the material was
		# just duplicated out of the PackedScene: on a re-apply the authored
		# value is back, so the multiplier cannot compound.
		var authored_speed: Variant = material.get_shader_parameter(&"time_speed")
		if authored_speed != null:
			_write(material, &"time_speed", float(authored_speed) * system.planet_time_scale)
		# NOTE `size` here is the shader's NOISE SCALE uniform - continent and
		# cloud-bank size. It has nothing to do with ColorRect.size, which
		# set_pixels below writes.
		if PlanetLayerSpec.has_range(layer.noise_size_range):
			_write(material, &"size", _map(system.planet_noise_scale, layer.noise_size_range))
		if layer.cutoff_param != &"":
			_write(material, layer.cutoff_param,
					_map_threshold(system.planet_coverage, layer.cutoff_range))
		if PlanetLayerSpec.has_range(layer.cloud_cover_range):
			_write(material, &"cloud_cover",
					_map_threshold(system.planet_cloudiness, layer.cloud_cover_range))

	planet.set_pixels(system.planet_pixels)
	planet.set_rotates(system.planet_rotation)
	return planet

## A layer's `colors` uniform, assembled by concatenating its segments' ramps in
## declaration order. This is what lets `Rivers` pack four land shades and two
## river shades into one six-element uniform without anyone writing a special
## case for it.
func _layer_colors(system: StarSystemData, layer: PlanetLayerSpec) -> PackedColorArray:
	var out: PackedColorArray = PackedColorArray()
	for segment: PlanetPaletteSegment in layer.segments:
		if segment == null:
			continue
		var ramp: PackedColorArray = system.palette_for(PlanetPaletteSegment.role_id(segment.role))
		for index: int in segment.count:
			if ramp.is_empty():
				out.append(MISSING_RAMP_COLOR)
			else:
				# A ramp shorter than a segment asks for holds its darkest stop,
				# so the uniform is never left short of what the shader indexes.
				out.append(ramp[mini(index, ramp.size() - 1)])
	return out

# --- lighting -----------------------------------------------------------------

## Points the planet's terminator at where the star actually is.
##
## Computed ONCE, here, and never per frame. The two bodies sit on Parallax2D
## layers with different scroll_scale (0.1 against 0.15), so their relative
## offset drifts as the camera pans - a per-frame recompute would make the
## shadow swim across the planet while the player scrolls the station.
func _apply_light(system: StarSystemData) -> void:
	if _planet == null:
		return
	var star_centre: Vector2 = system.star_offset \
			+ Vector2.ONE * (system.star_pixels * system.star_scale * 0.5)
	var planet_centre: Vector2 = system.planet_offset \
			+ Vector2.ONE * (system.planet_pixels * system.planet_scale * 0.5)
	var direction: Vector2 = star_centre - planet_centre
	# Perfectly co-located bodies would normalise to zero and light the planet
	# from its own centre, which renders as a flat disc.
	if direction.is_zero_approx():
		direction = Vector2(-1.0, -1.0)
	var origin: Vector2 = Vector2(0.5, 0.5) + direction.normalized() * LIGHT_OFFSET
	_planet.set_light(Vector2(clampf(origin.x, 0.05, 0.95), clampf(origin.y, 0.05, 0.95)))

# --- helpers ------------------------------------------------------------------

## The layer's material, made this instance's own before anything writes to it.
##
## **Load-bearing.** A SubResource inside a PackedScene is SHARED across every
## instantiation of that scene unless `resource_local_to_scene` is set, and none
## of the vendored materials set it. Godot also caches the PackedScene, so the
## `reload_current_scene()` a load performs hands the very same material objects
## to the new tree - meaning any parameter this file does not overwrite on every
## apply would leak from the previous run into the next one. It does not
## overwrite every parameter, by variant, so it duplicates instead.
func _own_material(body: StellarObjectVisual, node_name: StringName) -> ShaderMaterial:
	var rect: ColorRect = body.get_node_or_null(NodePath(String(node_name))) as ColorRect
	if rect == null:
		push_warning("StellarBackground: '%s' has no layer named '%s'" % [body.name, node_name])
		return null
	var material: ShaderMaterial = rect.material as ShaderMaterial
	if material == null:
		return null
	material = material.duplicate() as ShaderMaterial
	rect.material = material
	return material

static func _write(material: ShaderMaterial, parameter: StringName, value: Variant) -> void:
	if material != null:
		material.set_shader_parameter(parameter, value)

## A normalised 0..1 factor from [StarSystemData] into one layer's own band. The
## factor is what the save stores, so the save stays variant-agnostic and each
## layer keeps the authored relationship to its neighbours.
static func _map(factor: float, band: Vector2) -> float:
	return lerpf(band.x, band.y, clampf(factor, 0.0, 1.0))

## A semantic "how much of this is there" factor into a shader uniform that is a
## THRESHOLD, and therefore runs the other way.
##
## Every one of these uniforms is consumed as `step(uniform, noise)` -
## `cloud_cover`, `land_cutoff`, `river_cutoff`, `lake_cutoff` - so a HIGHER
## value means LESS of the thing, which is the opposite of what all four of
## their names suggest. Reading `cloud_cover` as "how cloudy" is what filled the
## first contact sheet with featureless overcast white balls: the clear-world
## roll was producing total whiteout, and no headless check could have told you.
##
## The inversion lives here, once, so both the factor in the save and the band in
## the .tres stay semantic.
static func _map_threshold(factor: float, band: Vector2) -> float:
	return lerpf(band.y, band.x, clampf(factor, 0.0, 1.0))
