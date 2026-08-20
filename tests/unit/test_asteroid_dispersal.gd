extends GutTest

## AsteroidDispersal's shard layout - the part that decides whether the debris
## puff lines up with the rock it replaced.
##
## Only setup() is pure: _process() and _draw() need Global.time_manager and a
## canvas, so the animation and the drawing belong to the in-game check. What is
## worth pinning down here is that frame one reconstructs the sprite exactly,
## because that is the whole trick - a cloud that starts even slightly offset
## reads as the rock teleporting rather than breaking apart.

const TEX_SIZE: float = 60.0

func _sprite(rotation_radians: float = 0.0, scale: Vector2 = Vector2.ONE) -> Sprite2D:
	var texture := PlaceholderTexture2D.new()
	texture.size = Vector2(TEX_SIZE, TEX_SIZE)
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.position = Vector2(-7, -8)
	sprite.rotation = rotation_radians
	sprite.scale = scale
	return sprite

func _offsets(effect: AsteroidDispersal) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for shard: AsteroidDispersal.Shard in effect._shards:
		out.append(shard.offset)
	return out

func test_sprite_is_cut_into_a_full_grid() -> void:
	var effect := AsteroidDispersal.new()
	var sprite := _sprite()
	effect.setup(sprite, Vector2.ZERO)
	assert_eq(effect._shards.size(), AsteroidDispersal.DEFAULT_GRID * AsteroidDispersal.DEFAULT_GRID,
		"every cell of the grid becomes a shard - no gaps in the rock")
	sprite.free()
	effect.free()

func test_shard_regions_tile_the_texture_without_overlap() -> void:
	var effect := AsteroidDispersal.new()
	var sprite := _sprite()
	effect.setup(sprite, Vector2.ZERO)
	var covered: float = 0.0
	var seen: Array[Vector2] = []
	for shard: AsteroidDispersal.Shard in effect._shards:
		covered += shard.region.size.x * shard.region.size.y
		assert_false(seen.has(shard.region.position), "each cell is claimed once")
		seen.append(shard.region.position)
	assert_almost_eq(covered, TEX_SIZE * TEX_SIZE, 0.01,
		"the regions together are exactly the source texture")
	sprite.free()
	effect.free()

func test_shards_start_laid_out_as_the_intact_sprite() -> void:
	var effect := AsteroidDispersal.new()
	var sprite := _sprite()
	effect.setup(sprite, Vector2.ZERO)
	var step: float = TEX_SIZE / float(AsteroidDispersal.DEFAULT_GRID)
	# A 3x3 grid of cell centres around the sprite's own position.
	var expected: Array[Vector2] = []
	for x: int in AsteroidDispersal.DEFAULT_GRID:
		for y: int in AsteroidDispersal.DEFAULT_GRID:
			var cell := Vector2(x - 1, y - 1) * step
			expected.append(sprite.position + cell)
	var actual: Array[Vector2] = _offsets(effect)
	for point: Vector2 in expected:
		var matched: bool = false
		for offset: Vector2 in actual:
			if offset.distance_to(point) < 0.01:
				matched = true
				break
		assert_true(matched, "a shard sits at %s, where that piece of the rock was" % point)
	sprite.free()
	effect.free()

func test_layout_follows_the_sprites_rotation() -> void:
	# Asteroids spin as they drift, so the shard grid has to be rotated into the
	# rock's frame - not axis-aligned like the source texture.
	var effect := AsteroidDispersal.new()
	var sprite := _sprite(PI * 0.5)
	effect.setup(sprite, Vector2.ZERO)
	var step: float = TEX_SIZE / float(AsteroidDispersal.DEFAULT_GRID)
	var corner: Vector2 = sprite.position + (Vector2(-step, -step)).rotated(PI * 0.5)
	var found: bool = false
	for offset: Vector2 in _offsets(effect):
		if offset.distance_to(corner) < 0.01:
			found = true
			break
	assert_true(found, "the top-left piece lands where rotation put it, at %s" % corner)
	sprite.free()
	effect.free()

func test_shard_draw_size_follows_sprite_scale() -> void:
	var effect := AsteroidDispersal.new()
	var sprite := _sprite(0.0, Vector2(2.0, 2.0))
	effect.setup(sprite, Vector2.ZERO)
	var step: float = TEX_SIZE / float(AsteroidDispersal.DEFAULT_GRID)
	assert_almost_eq(effect._shard_size.x, step * 2.0, 0.01, "a scaled-up rock breaks into scaled-up shards")
	sprite.free()
	effect.free()

func test_every_shard_gets_an_outward_heading() -> void:
	# The centre cell sits on the origin and has no direction of its own; without
	# the random-heading fallback it would hang motionless in the middle of the
	# cloud for the whole effect.
	var effect := AsteroidDispersal.new()
	var sprite := _sprite()
	effect.setup(sprite, Vector2.ZERO)
	for shard: AsteroidDispersal.Shard in effect._shards:
		assert_gt(shard.velocity.length(), 0.0, "no shard is left standing still")
	sprite.free()
	effect.free()

func test_missing_sprite_produces_an_empty_effect() -> void:
	# Guards the mod case: an asteroid scene with no sprite assigned should make
	# the rock vanish quietly rather than crash the despawn.
	var effect := AsteroidDispersal.new()
	effect.setup(null, Vector2.ZERO)
	assert_eq(effect._shards.size(), 0, "nothing to shatter, nothing drawn")
	effect.free()

func test_drift_is_carried_from_the_dead_rock() -> void:
	var effect := AsteroidDispersal.new()
	var sprite := _sprite()
	effect.setup(sprite, Vector2(12.0, -3.0))
	assert_eq(effect._drift, Vector2(12.0, -3.0), "the cloud keeps the asteroid's momentum")
	sprite.free()
	effect.free()
