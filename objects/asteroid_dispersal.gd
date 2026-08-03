class_name AsteroidDispersal
extends Node2D

## The debris puff left behind by an asteroid that has been mined dry.
##
## It shatters the rock's OWN sprite into a grid of shards that tumble outward
## and fade, so the first frame is pixel-identical to the asteroid that was
## standing there and the rock visibly comes apart instead of popping into
## generic dust. That is also why this is built in code and handed its texture at
## spawn rather than being an authored .tscn: the texture belongs to whichever
## asteroid died, and a mod's asteroid brings its own.
##
## Sim-scaled, unlike the cosmetic flashes in PirateShipHud - this is a world
## event, so it freezes with pause and runs fast at 3x like everything else out
## in the belt.

## How finely the sprite is cut up. 3x3 keeps the shards big enough to still read
## as rock at the game's normal zoom.
const GRID: int = 3
## Sim-seconds from intact to gone.
const DURATION: float = 1.2
## Fraction of DURATION the shards stay fully opaque, so the shatter is readable
## before the fade starts.
const SOLID_FRACTION: float = 0.25
## Outward shard speed, as a multiple of a shard's own diagonal per sim-second.
## Sized relative to the rock rather than in absolute pixels so a big asteroid
## throws its debris proportionally further and the spread reads the same.
const SPEED_MIN_FACTOR: float = 1.6
const SPEED_MAX_FACTOR: float = 3.2
## Velocity retained per sim-second, so shards ease out rather than flying off.
const DRAG: float = 0.6
const SPIN_MAX_DEG: float = 220.0
## How far shards shrink by the end - they crumble as they scatter rather than
## just dimming.
const END_SCALE: float = 0.55
## Dust bloom colour, sampled to sit near the asteroid sprite's own grey-brown.
## Deliberately faint: it is a hint of dust between the shards, not a puff of
## smoke replacing the rock.
const DUST_COLOR: Color = Color(0.62, 0.56, 0.48, 0.1)
## How far the bloom expands over the effect's life, as a multiple of its start.
const DUST_GROWTH: float = 3.0

## One flying piece of the original sprite.
class Shard extends RefCounted:
	## Source rectangle in the asteroid texture.
	var region: Rect2
	## Centre position of the piece, in this effect's local space.
	var offset: Vector2
	var velocity: Vector2
	var angle: float
	var spin: float

var _texture: Texture2D = null
var _shards: Array[Shard] = []
## Drawn size of one shard, i.e. the source cell scaled by the sprite's scale.
var _shard_size: Vector2 = Vector2.ZERO
var _dust_radius: float = 0.0
## The dead asteroid's own velocity, carried by the whole cloud so the debris
## keeps its momentum instead of stopping dead where the rock was.
var _drift: Vector2 = Vector2.ZERO
var _elapsed: float = 0.0

## Cuts `sprite` into shards. Call before add_child; a null or textureless sprite
## leaves the effect empty and it frees itself on its first frame.
func setup(sprite: Sprite2D, drift: Vector2) -> void:
	_drift = drift
	if sprite == null or sprite.texture == null:
		return
	_texture = sprite.texture
	var cell: Vector2 = _texture.get_size() / float(GRID)
	_shard_size = cell * sprite.scale
	# Smaller than a single shard, so the bloom is completely hidden behind the
	# intact rock on frame one and only emerges through the widening cracks.
	_dust_radius = minf(_shard_size.x, _shard_size.y) * 0.8
	var speed_min: float = _shard_size.length() * SPEED_MIN_FACTOR
	var speed_max: float = _shard_size.length() * SPEED_MAX_FACTOR
	var spin_max: float = deg_to_rad(SPIN_MAX_DEG)
	var center_index: float = (GRID - 1) * 0.5
	for x: int in GRID:
		for y: int in GRID:
			var shard := Shard.new()
			shard.region = Rect2(Vector2(x, y) * cell, cell)
			# Cell centre relative to the sprite's centre, then into the
			# asteroid's frame. The sprite spins as it drifts, so its rotation
			# has to be baked in here or the cloud starts visibly misaligned
			# with the rock it replaced.
			var local: Vector2 = (Vector2(x, y) - Vector2.ONE * center_index) * _shard_size
			var placed: Vector2 = local.rotated(sprite.rotation)
			shard.offset = sprite.position + placed
			shard.angle = sprite.rotation
			# The centre cell sits on the origin and so has no outward direction
			# of its own - give it a random heading.
			var outward: Vector2 = placed
			if outward.length() < 0.01:
				outward = Vector2.from_angle(randf() * TAU)
			shard.velocity = outward.normalized().rotated(randf_range(-0.35, 0.35)) \
				* randf_range(speed_min, speed_max)
			shard.spin = randf_range(-spin_max, spin_max)
			_shards.append(shard)

func _process(delta: float) -> void:
	var sim_delta: float = Global.time_manager.scale(delta)
	if sim_delta <= 0.0:
		return
	_elapsed += sim_delta
	if _elapsed >= DURATION or _shards.is_empty():
		queue_free()
		return
	position += _drift * sim_delta
	var retained: float = pow(DRAG, sim_delta)
	for shard: Shard in _shards:
		shard.offset += shard.velocity * sim_delta
		shard.velocity *= retained
		shard.angle += shard.spin * sim_delta
	queue_redraw()

func _draw() -> void:
	if _texture == null:
		return
	var t: float = clampf(_elapsed / DURATION, 0.0, 1.0)
	var alpha: float = 1.0
	if t > SOLID_FRACTION:
		alpha = 1.0 - (t - SOLID_FRACTION) / (1.0 - SOLID_FRACTION)
	# Bloom first, so it is hidden behind the intact rock on frame one and only
	# shows through as the shards spread apart. It also thins out ahead of the
	# shards - dust disperses faster than rubble does.
	var dust: Color = DUST_COLOR
	dust.a *= alpha * (1.0 - t)
	var radius: float = lerpf(_dust_radius, _dust_radius * DUST_GROWTH, t)
	# Stacked rings instead of one disc: a single flat circle reads as a hard-edged
	# grey plate against the starfield, and there is no gradient brush in _draw().
	for ring: float in [1.0, 0.72, 0.46]:
		draw_circle(Vector2.ZERO, radius * ring, dust)
	var tint := Color(1.0, 1.0, 1.0, alpha)
	var rect := Rect2(-_shard_size * 0.5, _shard_size)
	var shrink: Vector2 = Vector2.ONE * lerpf(1.0, END_SCALE, t)
	for shard: Shard in _shards:
		draw_set_transform(shard.offset, shard.angle, shrink)
		draw_texture_rect_region(_texture, rect, shard.region, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
